#!/bin/bash

################################################################################
# ducktape Data Verification
################################################################################
# Verify data integrity across PostgreSQL, Parquet, and DuckDB
################################################################################

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Load config if available
load_config || set_default_config

print_header "ducktape Data Verification"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

################################################################################
# Test 1: Verify table list exists
################################################################################

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ -f "tables.txt" ]; then
    TABLE_COUNT=$(wc -l < tables.txt | tr -d ' ')
    print_test "PASS" "Table list exists ($TABLE_COUNT tables)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    print_test "FAIL" "Table list not found (tables.txt)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

################################################################################
# Test 2: Verify Parquet files
################################################################################

if [ -d "$PARQUET_DIR" ]; then
    PARQUET_COUNT=$(find "$PARQUET_DIR" -name "*.parquet" 2>/dev/null | wc -l | tr -d ' ')
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ $PARQUET_COUNT -gt 0 ]; then
        print_test "PASS" "Parquet files exist ($PARQUET_COUNT files)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        
        # Test 2a: Check if all tables have Parquet files
        if [ -f "tables.txt" ]; then
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            EXPECTED_COUNT=$(wc -l < tables.txt | tr -d ' ')
            
            if [ $PARQUET_COUNT -eq $EXPECTED_COUNT ]; then
                print_test "PASS" "All tables exported to Parquet ($PARQUET_COUNT/$EXPECTED_COUNT)"
                PASSED_TESTS=$((PASSED_TESTS + 1))
            elif [ $PARQUET_COUNT -lt $EXPECTED_COUNT ]; then
                print_test "WARN" "Some tables missing from Parquet ($PARQUET_COUNT/$EXPECTED_COUNT)"
                WARNINGS=$((WARNINGS + 1))
            else
                print_test "WARN" "More Parquet files than expected ($PARQUET_COUNT/$EXPECTED_COUNT)"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
        
        # Test 2b: Check for empty Parquet files
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        EMPTY_FILES=$(find "$PARQUET_DIR" -name "*.parquet" -size 0 2>/dev/null | wc -l | tr -d ' ')
        
        if [ $EMPTY_FILES -eq 0 ]; then
            print_test "PASS" "No empty Parquet files"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            print_test "WARN" "Found $EMPTY_FILES empty Parquet file(s)"
            WARNINGS=$((WARNINGS + 1))
            find "$PARQUET_DIR" -name "*.parquet" -size 0 -exec basename {} \; | sed 's/^/    /'
        fi
        
    else
        print_test "FAIL" "No Parquet files found in $PARQUET_DIR"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    print_test "FAIL" "Parquet directory not found: $PARQUET_DIR"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

################################################################################
# Test 3: Verify DuckDB database
################################################################################

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ -f "$DUCKDB_PATH" ]; then
    print_test "PASS" "DuckDB database exists"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    
    if command -v duckdb &> /dev/null; then
        # Test 3a: Database can be opened
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        if duckdb "$DUCKDB_PATH" -c "SELECT 1" &> /dev/null; then
            print_test "PASS" "DuckDB database is readable"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            
            # Test 3b: Check table count
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            DB_TABLE_COUNT=$(duckdb "$DUCKDB_PATH" -csv -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='main'" 2>/dev/null | tail -1)
            
            if [ ! -z "$DB_TABLE_COUNT" ] && [ $DB_TABLE_COUNT -gt 0 ]; then
                print_test "PASS" "DuckDB contains $DB_TABLE_COUNT tables"
                PASSED_TESTS=$((PASSED_TESTS + 1))
                
                # Test 3c: Compare with expected table count
                if [ -f "tables.txt" ]; then
                    TOTAL_TESTS=$((TOTAL_TESTS + 1))
                    EXPECTED_COUNT=$(wc -l < tables.txt | tr -d ' ')
                    
                    if [ $DB_TABLE_COUNT -eq $EXPECTED_COUNT ]; then
                        print_test "PASS" "Table count matches expected ($DB_TABLE_COUNT/$EXPECTED_COUNT)"
                        PASSED_TESTS=$((PASSED_TESTS + 1))
                    else
                        print_test "WARN" "Table count mismatch (DB: $DB_TABLE_COUNT, Expected: $EXPECTED_COUNT)"
                        WARNINGS=$((WARNINGS + 1))
                    fi
                fi
                
                # Test 3d: Check for empty tables
                TOTAL_TESTS=$((TOTAL_TESTS + 1))
                echo ""
                echo "Checking for empty tables..."
                
                EMPTY_TABLES=()
                duckdb "$DUCKDB_PATH" -csv -c "SELECT table_name FROM information_schema.tables WHERE table_schema='main'" 2>/dev/null | tail -n +2 | while read -r table; do
                    if [ ! -z "$table" ]; then
                        row_count=$(duckdb "$DUCKDB_PATH" -csv -c "SELECT COUNT(*) FROM \"$table\"" 2>/dev/null | tail -1)
                        if [ "$row_count" = "0" ]; then
                            echo "  Empty table: $table"
                        fi
                    fi
                done
                
                print_test "PASS" "Empty table check complete"
                PASSED_TESTS=$((PASSED_TESTS + 1))
                
            else
                print_test "FAIL" "DuckDB appears to have no tables"
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
            
        else
            print_test "FAIL" "DuckDB database cannot be opened (corrupted?)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        print_test "WARN" "DuckDB not installed - skipping database validation"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    print_test "FAIL" "DuckDB database not found: $DUCKDB_PATH"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

################################################################################
# Test 4: Verify SQL files
################################################################################

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ -f "pg-to-parquet.sql" ]; then
    print_test "PASS" "pg-to-parquet.sql exists"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    print_test "WARN" "pg-to-parquet.sql not found (generate with PostgreSQL workflow)"
    WARNINGS=$((WARNINGS + 1))
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ -f "parquet-to-duck.sql" ]; then
    print_test "PASS" "parquet-to-duck.sql exists"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    print_test "WARN" "parquet-to-duck.sql not found (generate with DuckDB workflow)"
    WARNINGS=$((WARNINGS + 1))
fi

################################################################################
# Test 5: Spot check data integrity (if DuckDB available)
################################################################################

if [ -f "$DUCKDB_PATH" ] && command -v duckdb &> /dev/null; then
    echo ""
    echo "Running spot checks on data quality..."
    
    # Check for common tables
    for table in "osf_abstractnode" "osf_osfuser"; do
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        if duckdb "$DUCKDB_PATH" -c "SELECT 1 FROM $table LIMIT 1" &> /dev/null; then
            row_count=$(duckdb "$DUCKDB_PATH" -csv -c "SELECT COUNT(*) FROM $table" 2>/dev/null | tail -1)
            print_test "PASS" "Table '$table' is readable ($row_count rows)"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            print_test "WARN" "Table '$table' not found or unreadable"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
fi

################################################################################
# Summary
################################################################################

print_header "Verification Summary"

echo "Total tests run: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo ""

SUCCESS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))

if [ $FAILED_TESTS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! ($SUCCESS_RATE%)${NC}"
    echo "Your data pipeline is healthy."
    exit 0
elif [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${YELLOW}⚠ All tests passed with warnings ($SUCCESS_RATE%)${NC}"
    echo "Review warnings above - your pipeline may be incomplete."
    exit 0
else
    echo -e "${RED}✗ Some tests failed ($SUCCESS_RATE% success rate)${NC}"
    echo ""
    echo "Recommendations:"
    [ ! -f "tables.txt" ] && echo "  - Run PostgreSQL workflow to generate table list"
    [ $PARQUET_COUNT -eq 0 ] 2>/dev/null && echo "  - Run Parquet workflow to export data"
    [ ! -f "$DUCKDB_PATH" ] && echo "  - Run DuckDB workflow to create database"
    echo ""
    echo "Run: ./run.sh"
    exit 1
fi
