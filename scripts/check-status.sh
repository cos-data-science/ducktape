#!/bin/bash

################################################################################
# ducktape Status Checker
################################################################################
# Check the status of your ducktape pipeline and data files
################################################################################

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Load config if available
load_config || set_default_config

print_header "ducktape Pipeline Status"

################################################################################
# PostgreSQL Workflow Status
################################################################################

echo "📊 PostgreSQL Workflow"
echo ""

if [ -f "tables.txt" ]; then
    TABLE_COUNT=$(wc -l < tables.txt | tr -d ' ')
    print_check 1 "Tables list generated ($TABLE_COUNT tables)"
else
    print_check 0 "Tables list not found (run PostgreSQL workflow)"
fi

if [ -f "pg-to-parquet.sql" ]; then
    SQL_LINES=$(wc -l < pg-to-parquet.sql | tr -d ' ')
    print_check 1 "Parquet export SQL generated ($SQL_LINES lines)"
else
    print_check 0 "Parquet export SQL not found"
fi

if [ -f "$KEYS_PATH" ]; then
    KEY_SIZE=$(stat -f%z "$KEYS_PATH" 2>/dev/null || stat -c%s "$KEYS_PATH" 2>/dev/null)
    KEY_SIZE_FMT=$(format_size $KEY_SIZE)
    print_check 1 "Relational keys extracted ($KEY_SIZE_FMT)"
else
    print_check 0 "Relational keys not found"
fi

################################################################################
# Parquet Workflow Status
################################################################################

echo ""
echo "📦 Parquet Workflow"
echo ""

if [ -d "$PARQUET_DIR" ]; then
    PARQUET_COUNT=$(find "$PARQUET_DIR" -name "*.parquet" 2>/dev/null | wc -l | tr -d ' ')
    
    if [ $PARQUET_COUNT -gt 0 ]; then
        # Calculate total size
        if [[ "$OSTYPE" == "darwin"* ]]; then
            TOTAL_SIZE=$(find "$PARQUET_DIR" -name "*.parquet" -exec stat -f%z {} + 2>/dev/null | awk '{s+=$1} END {print s}')
        else
            TOTAL_SIZE=$(find "$PARQUET_DIR" -name "*.parquet" -exec stat -c%s {} + 2>/dev/null | awk '{s+=$1} END {print s}')
        fi
        TOTAL_SIZE=${TOTAL_SIZE:-0}
        TOTAL_SIZE_FMT=$(format_size $TOTAL_SIZE)
        
        print_check 1 "Parquet files created ($PARQUET_COUNT files, $TOTAL_SIZE_FMT)"
        
        # Show newest and oldest files
        echo ""
        echo "  Newest file: $(ls -t "$PARQUET_DIR"/*.parquet 2>/dev/null | head -1 | xargs basename)"
        echo "  Oldest file: $(ls -t "$PARQUET_DIR"/*.parquet 2>/dev/null | tail -1 | xargs basename)"
        
        # Check if count matches expected
        if [ -f "tables.txt" ]; then
            EXPECTED_COUNT=$(wc -l < tables.txt | tr -d ' ')
            if [ $PARQUET_COUNT -eq $EXPECTED_COUNT ]; then
                echo -e "  ${GREEN}All tables exported${NC}"
            else
                echo -e "  ${YELLOW}Warning: Expected $EXPECTED_COUNT files, found $PARQUET_COUNT${NC}"
            fi
        fi
    else
        print_check 0 "No Parquet files found in $PARQUET_DIR"
    fi
else
    print_check 0 "Parquet directory not found: $PARQUET_DIR"
fi

################################################################################
# DuckDB Workflow Status
################################################################################

echo ""
echo "🦆 DuckDB Workflow"
echo ""

if [ -f "$DUCKDB_PATH" ]; then
    DB_SIZE=$(stat -f%z "$DUCKDB_PATH" 2>/dev/null || stat -c%s "$DUCKDB_PATH" 2>/dev/null)
    DB_SIZE_FMT=$(format_size $DB_SIZE)
    print_check 1 "DuckDB database created ($DB_SIZE_FMT)"
    
    # Get database info
    echo ""
    echo "  Database: $DUCKDB_PATH"
    echo "  Modified: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$DUCKDB_PATH" 2>/dev/null || stat -c '%y' "$DUCKDB_PATH" 2>/dev/null | cut -d'.' -f1)"
    
    # Try to get table count from DuckDB
    if command -v duckdb &> /dev/null; then
        TABLE_COUNT=$(duckdb "$DUCKDB_PATH" -csv -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='main'" 2>/dev/null | tail -1)
        if [ ! -z "$TABLE_COUNT" ]; then
            echo "  Tables: $TABLE_COUNT"
            
            # Get total row count (sample)
            echo ""
            echo "  Sample table row counts:"
            duckdb "$DUCKDB_PATH" -box -c "
                SELECT table_name, 
                       (SELECT COUNT(*) FROM sqlite_master) as row_count 
                FROM information_schema.tables 
                WHERE table_schema='main' 
                LIMIT 5
            " 2>/dev/null || echo "    (Unable to query database)"
        fi
    fi
else
    print_check 0 "DuckDB database not found: $DUCKDB_PATH"
fi

################################################################################
# Log Files
################################################################################

echo ""
echo "📝 Recent Logs"
echo ""

if [ -d "logs" ]; then
    LOG_COUNT=$(find logs -name "*.log" 2>/dev/null | wc -l | tr -d ' ')
    
    if [ $LOG_COUNT -gt 0 ]; then
        print_check 1 "Found $LOG_COUNT log file(s)"
        
        # Show most recent log
        RECENT_LOG=$(ls -t logs/*.log 2>/dev/null | head -1)
        if [ ! -z "$RECENT_LOG" ]; then
            echo ""
            echo "  Most recent: $(basename $RECENT_LOG)"
            
            # Check if there are any errors
            ERROR_COUNT=$(grep -i "error" "$RECENT_LOG" 2>/dev/null | wc -l | tr -d ' ')
            WARNING_COUNT=$(grep -i "warning" "$RECENT_LOG" 2>/dev/null | wc -l | tr -d ' ')
            
            if [ $ERROR_COUNT -gt 0 ]; then
                echo -e "  ${RED}Errors found: $ERROR_COUNT${NC}"
            fi
            
            if [ $WARNING_COUNT -gt 0 ]; then
                echo -e "  ${YELLOW}Warnings: $WARNING_COUNT${NC}"
            fi
            
            # Show last few lines
            echo ""
            echo "  Last 3 log entries:"
            tail -3 "$RECENT_LOG" | sed 's/^/    /'
        fi
    else
        print_check 0 "No log files found"
    fi
else
    print_check 0 "Logs directory not found"
fi

################################################################################
# Disk Space
################################################################################

echo ""
echo "💾 Disk Space"
echo ""

if [ -d "$PARQUET_DIR" ]; then
    PARQUET_PARENT=$(dirname "$PARQUET_DIR")
    if command -v df &> /dev/null; then
        AVAILABLE=$(df -h "$PARQUET_PARENT" 2>/dev/null | tail -1 | awk '{print $4}')
        USED_PCT=$(df -h "$PARQUET_PARENT" 2>/dev/null | tail -1 | awk '{print $5}')
        echo "  Available: $AVAILABLE"
        echo "  Used: $USED_PCT"
    fi
fi

################################################################################
# Pipeline Completion Status
################################################################################

echo ""
print_header "Overall Status"

COMPLETION_SCORE=0
TOTAL_CHECKS=4

[ -f "tables.txt" ] && ((COMPLETION_SCORE++))
[ $PARQUET_COUNT -gt 0 ] 2>/dev/null && ((COMPLETION_SCORE++))
[ -f "$DUCKDB_PATH" ] && ((COMPLETION_SCORE++))
[ -f "$KEYS_PATH" ] && ((COMPLETION_SCORE++))

COMPLETION_PCT=$((COMPLETION_SCORE * 100 / TOTAL_CHECKS))

echo "Pipeline completion: $COMPLETION_SCORE/$TOTAL_CHECKS steps ($COMPLETION_PCT%)"
echo ""

if [ $COMPLETION_SCORE -eq $TOTAL_CHECKS ]; then
    echo -e "${GREEN}✓ Pipeline complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  - Query your data: duckdb $DUCKDB_PATH"
    echo "  - See example queries: cat example-queries.sql"
    echo "  - Explore in R/Python (see README.md)"
elif [ $COMPLETION_SCORE -eq 0 ]; then
    echo -e "${YELLOW}⚠ Pipeline not started${NC}"
    echo ""
    echo "To start the pipeline:"
    echo "  1. Review config.sh"
    echo "  2. Run: ./run.sh"
else
    echo -e "${YELLOW}⚠ Pipeline partially complete${NC}"
    echo ""
    echo "Missing steps:"
    [ ! -f "tables.txt" ] && echo "  - PostgreSQL workflow (extract tables)"
    [ $PARQUET_COUNT -eq 0 ] 2>/dev/null && echo "  - Parquet workflow (export data)"
    [ ! -f "$DUCKDB_PATH" ] && echo "  - DuckDB workflow (create database)"
    [ ! -f "$KEYS_PATH" ] && echo "  - Key extraction"
    echo ""
    echo "Run ./run.sh with appropriate RUN_* flags in config.sh"
fi

echo ""
