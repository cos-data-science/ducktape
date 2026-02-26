#!/bin/bash

################################################################################
# ducktape Clean Script
################################################################################
# Safely clean up pipeline files with interactive prompts
################################################################################

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Load config if available
load_config || set_default_config

print_header "ducktape Cleanup Utility"

echo "This script helps you safely clean up ducktape files."
echo ""

################################################################################
# Show current disk usage
################################################################################

echo "Current disk usage:"
echo ""

# Parquet files
if [ -d "$PARQUET_DIR" ]; then
    PARQUET_SIZE=$(get_dir_size "$PARQUET_DIR")
    PARQUET_SIZE_FMT=$(format_size $PARQUET_SIZE)
    PARQUET_COUNT=$(find "$PARQUET_DIR" -name "*.parquet" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Parquet files: $PARQUET_SIZE_FMT ($PARQUET_COUNT files)"
    PARQUET_EXISTS=1
else
    echo "  Parquet files: Not found"
    PARQUET_EXISTS=0
fi

# DuckDB database
if [ -f "$DUCKDB_PATH" ]; then
    DB_SIZE=$(stat -f%z "$DUCKDB_PATH" 2>/dev/null || stat -c%s "$DUCKDB_PATH" 2>/dev/null)
    DB_SIZE_FMT=$(format_size $DB_SIZE)
    echo "  DuckDB database: $DB_SIZE_FMT"
    DUCKDB_EXISTS=1
else
    echo "  DuckDB database: Not found"
    DUCKDB_EXISTS=0
fi

# Generated SQL files
SQL_SIZE=0
SQL_COUNT=0
for file in pg-to-parquet.sql parquet-to-duck.sql; do
    if [ -f "$file" ]; then
        SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        SQL_SIZE=$((SQL_SIZE + SIZE))
        SQL_COUNT=$((SQL_COUNT + 1))
    fi
done
if [ $SQL_COUNT -gt 0 ]; then
    SQL_SIZE_FMT=$(format_size $SQL_SIZE)
    echo "  Generated SQL: $SQL_SIZE_FMT ($SQL_COUNT files)"
    SQL_EXISTS=1
else
    echo "  Generated SQL: Not found"
    SQL_EXISTS=0
fi

# Logs
if [ -d "logs" ]; then
    LOG_SIZE=$(get_dir_size "logs")
    LOG_SIZE_FMT=$(format_size $LOG_SIZE)
    LOG_COUNT=$(find logs -name "*.log" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Log files: $LOG_SIZE_FMT ($LOG_COUNT files)"
    LOGS_EXIST=1
else
    echo "  Log files: Not found"
    LOGS_EXIST=0
fi

echo ""

if [ $PARQUET_EXISTS -eq 0 ] && [ $DUCKDB_EXISTS -eq 0 ] && [ $SQL_EXISTS -eq 0 ] && [ $LOGS_EXIST -eq 0 ]; then
    echo "Nothing to clean up!"
    exit 0
fi

################################################################################
# Cleanup options
################################################################################

print_header "Cleanup Options"

echo "What would you like to clean?"
echo ""
echo "  1) Parquet files only (keep DuckDB database)"
echo "  2) DuckDB database only (keep Parquet files)"
echo "  3) Both Parquet and DuckDB (keep SQL/logs)"
echo "  4) Generated SQL files"
echo "  5) Log files"
echo "  6) Everything (full clean)"
echo "  7) Custom selection"
echo "  q) Cancel"
echo ""

read -p "Select option (1-7, q): " choice

case $choice in
    1)
        if [ $PARQUET_EXISTS -eq 0 ]; then
            echo "No Parquet files to delete."
            exit 0
        fi
        echo ""
        echo -e "${YELLOW}This will DELETE:${NC}"
        echo "  - $PARQUET_DIR ($PARQUET_SIZE_FMT)"
        echo ""
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
            rm -rf "$PARQUET_DIR"
            echo -e "${GREEN}✓ Parquet files deleted${NC}"
        else
            echo "Cancelled."
        fi
        ;;
        
    2)
        if [ $DUCKDB_EXISTS -eq 0 ]; then
            echo "No DuckDB database to delete."
            exit 0
        fi
        echo ""
        echo -e "${YELLOW}This will DELETE:${NC}"
        echo "  - $DUCKDB_PATH ($DB_SIZE_FMT)"
        echo ""
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
            rm -f "$DUCKDB_PATH"
            echo -e "${GREEN}✓ DuckDB database deleted${NC}"
        else
            echo "Cancelled."
        fi
        ;;
        
    3)
        if [ $PARQUET_EXISTS -eq 0 ] && [ $DUCKDB_EXISTS -eq 0 ]; then
            echo "Nothing to delete."
            exit 0
        fi
        echo ""
        echo -e "${YELLOW}This will DELETE:${NC}"
        [ $PARQUET_EXISTS -eq 1 ] && echo "  - $PARQUET_DIR ($PARQUET_SIZE_FMT)"
        [ $DUCKDB_EXISTS -eq 1 ] && echo "  - $DUCKDB_PATH ($DB_SIZE_FMT)"
        echo ""
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
            [ $PARQUET_EXISTS -eq 1 ] && rm -rf "$PARQUET_DIR"
            [ $DUCKDB_EXISTS -eq 1 ] && rm -f "$DUCKDB_PATH"
            echo -e "${GREEN}✓ Data files deleted${NC}"
        else
            echo "Cancelled."
        fi
        ;;
        
    4)
        if [ $SQL_EXISTS -eq 0 ]; then
            echo "No SQL files to delete."
            exit 0
        fi
        echo ""
        echo -e "${YELLOW}This will DELETE:${NC}"
        echo "  - pg-to-parquet.sql"
        echo "  - parquet-to-duck.sql"
        echo ""
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
            rm -f pg-to-parquet.sql parquet-to-duck.sql
            echo -e "${GREEN}✓ SQL files deleted${NC}"
        else
            echo "Cancelled."
        fi
        ;;
        
    5)
        if [ $LOGS_EXIST -eq 0 ]; then
            echo "No log files to delete."
            exit 0
        fi
        echo ""
        echo -e "${YELLOW}This will DELETE:${NC}"
        echo "  - logs/ directory ($LOG_SIZE_FMT, $LOG_COUNT files)"
        echo ""
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
            rm -rf logs/
            mkdir -p logs
            echo -e "${GREEN}✓ Log files deleted${NC}"
        else
            echo "Cancelled."
        fi
        ;;
        
    6)
        echo ""
        echo -e "${RED}WARNING: This will DELETE EVERYTHING!${NC}"
        echo ""
        [ $PARQUET_EXISTS -eq 1 ] && echo "  - $PARQUET_DIR ($PARQUET_SIZE_FMT)"
        [ $DUCKDB_EXISTS -eq 1 ] && echo "  - $DUCKDB_PATH ($DB_SIZE_FMT)"
        [ $SQL_EXISTS -eq 1 ] && echo "  - Generated SQL files"
        [ $LOGS_EXIST -eq 1 ] && echo "  - Log files"
        echo "  - tables.txt"
        [ -f "$KEYS_PATH" ] && echo "  - $KEYS_PATH"
        echo ""
        read -p "Are you ABSOLUTELY sure? Type 'DELETE EVERYTHING' to confirm: " confirm
        if [ "$confirm" = "DELETE EVERYTHING" ]; then
            [ $PARQUET_EXISTS -eq 1 ] && rm -rf "$PARQUET_DIR"
            [ $DUCKDB_EXISTS -eq 1 ] && rm -f "$DUCKDB_PATH"
            rm -f pg-to-parquet.sql parquet-to-duck.sql
            rm -f tables.txt
            [ -f "$KEYS_PATH" ] && rm -f "$KEYS_PATH"
            rm -rf logs/
            mkdir -p logs
            echo -e "${GREEN}✓ Everything deleted${NC}"
        else
            echo "Cancelled."
        fi
        ;;
        
    7)
        echo ""
        echo "Custom cleanup:"
        echo ""
        
        DELETE_PARQUET=0
        DELETE_DUCKDB=0
        DELETE_SQL=0
        DELETE_LOGS=0
        DELETE_TABLES=0
        DELETE_KEYS=0
        
        if [ $PARQUET_EXISTS -eq 1 ]; then
            read -p "Delete Parquet files? (y/n): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_PARQUET=1
        fi
        
        if [ $DUCKDB_EXISTS -eq 1 ]; then
            read -p "Delete DuckDB database? (y/n): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_DUCKDB=1
        fi
        
        if [ $SQL_EXISTS -eq 1 ]; then
            read -p "Delete generated SQL files? (y/n): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_SQL=1
        fi
        
        if [ $LOGS_EXIST -eq 1 ]; then
            read -p "Delete log files? (y/n): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_LOGS=1
        fi
        
        if [ -f "tables.txt" ]; then
            read -p "Delete table list (tables.txt)? (y/n): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_TABLES=1
        fi
        
        if [ -f "$KEYS_PATH" ]; then
            read -p "Delete relational keys? (y/n): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_KEYS=1
        fi
        
        echo ""
        read -p "Proceed with deletion? Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
            [ $DELETE_PARQUET -eq 1 ] && rm -rf "$PARQUET_DIR" && echo "  ✓ Deleted Parquet files"
            [ $DELETE_DUCKDB -eq 1 ] && rm -f "$DUCKDB_PATH" && echo "  ✓ Deleted DuckDB database"
            [ $DELETE_SQL -eq 1 ] && rm -f pg-to-parquet.sql parquet-to-duck.sql && echo "  ✓ Deleted SQL files"
            [ $DELETE_LOGS -eq 1 ] && rm -rf logs/ && mkdir -p logs && echo "  ✓ Deleted log files"
            [ $DELETE_TABLES -eq 1 ] && rm -f tables.txt && echo "  ✓ Deleted table list"
            [ $DELETE_KEYS -eq 1 ] && rm -f "$KEYS_PATH" && echo "  ✓ Deleted relational keys"
            echo -e "${GREEN}✓ Cleanup complete${NC}"
        else
            echo "Cancelled."
        fi
        ;;
        
    q|Q)
        echo "Cancelled."
        exit 0
        ;;
        
    *)
        echo "Invalid option."
        exit 1
        ;;
esac

echo ""
