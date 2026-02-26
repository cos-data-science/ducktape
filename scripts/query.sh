#!/bin/bash

################################################################################
# ducktape Query Helper
################################################################################
# Quick DuckDB query interface with shortcuts
################################################################################

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Load config if available
load_config || set_default_config

# Check if database exists
if [ ! -f "$DUCKDB_PATH" ]; then
    echo "Error: DuckDB database not found: $DUCKDB_PATH"
    echo ""
    echo "Have you run the pipeline yet?"
    echo "  ./run.sh"
    exit 1
fi

# Function to run query
run_query() {
    duckdb "$DUCKDB_PATH" -box -c "$1"
}

# If query provided as argument, run it
if [ $# -gt 0 ]; then
    QUERY="$*"
    echo -e "${BLUE}Running query:${NC} $QUERY"
    echo ""
    run_query "$QUERY"
    exit 0
fi

# Interactive mode
echo -e "${BLUE}=============================================="
echo "  ducktape Query Helper"
echo "==============================================\n${NC}"
echo "Database: $DUCKDB_PATH"
echo ""
echo "Quick commands:"
echo "  1) List all tables"
echo "  2) Show table schemas"
echo "  3) Count rows in all tables"
echo "  4) Show osf_abstractnode summary"
echo "  5) Show osf_osfuser summary"
echo "  6) Show recent activity"
echo "  7) Open DuckDB shell"
echo "  8) Run example queries"
echo "  q) Quit"
echo ""

while true; do
    read -p "Select option (1-8, q): " choice
    echo ""
    
    case $choice in
        1)
            echo -e "${GREEN}All tables:${NC}"
            run_query "SHOW TABLES;"
            ;;
        2)
            echo -e "${GREEN}Table schemas:${NC}"
            read -p "Enter table name (or 'all' for all tables): " table
            if [ "$table" = "all" ]; then
                run_query "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema='main' ORDER BY table_name, ordinal_position;"
            else
                run_query "DESCRIBE $table;"
            fi
            ;;
        3)
            echo -e "${GREEN}Row counts:${NC}"
            duckdb "$DUCKDB_PATH" -csv -noheader -c "SELECT table_name FROM information_schema.tables WHERE table_schema='main' ORDER BY table_name;" | while read -r table; do
                if [ ! -z "$table" ]; then
                    count=$(duckdb "$DUCKDB_PATH" -csv -c "SELECT COUNT(*) FROM \"$table\"" 2>/dev/null | tail -1)
                    printf "%-40s %10s rows\n" "$table" "$count"
                fi
            done
            ;;
        4)
            echo -e "${GREEN}osf_abstractnode summary:${NC}"
            run_query "SELECT type, COUNT(*) as count, SUM(CASE WHEN is_public THEN 1 ELSE 0 END) as public_count FROM osf_abstractnode WHERE is_deleted = false GROUP BY type ORDER BY count DESC;"
            ;;
        5)
            echo -e "${GREEN}osf_osfuser summary:${NC}"
            run_query "SELECT COUNT(*) as total_users, SUM(CASE WHEN is_active THEN 1 ELSE 0 END) as active_users, MIN(date_registered) as first_registration, MAX(date_registered) as latest_registration FROM osf_osfuser;"
            ;;
        6)
            echo -e "${GREEN}Recent activity (last 20 osf_abstractnode):${NC}"
            run_query "SELECT id, title, type, created, is_public FROM osf_abstractnode WHERE is_deleted = false ORDER BY created DESC LIMIT 20;"
            ;;
        7)
            echo -e "${GREEN}Opening DuckDB shell...${NC}"
            echo "Type .quit to exit"
            echo ""
            duckdb "$DUCKDB_PATH"
            ;;
        8)
            if [ -f "example-queries.sql" ]; then
                echo -e "${GREEN}Running example queries...${NC}"
                echo ""
                echo "This will run queries from example-queries.sql"
                read -p "Continue? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    duckdb "$DUCKDB_PATH" < example-queries.sql
                fi
            else
                echo "example-queries.sql not found"
            fi
            ;;
        q|Q)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
    
    echo ""
done
