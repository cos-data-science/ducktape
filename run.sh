#!/bin/bash

# Load configuration from config.sh (create from config.template.sh)
if [ -f "config.sh" ]; then
    source config.sh
    echo "✓ Loaded configuration from config.sh"
else
    echo "⚠️  WARNING: config.sh not found, using defaults from run.sh"
    echo "   For easier configuration, run: cp config.template.sh config.sh"
    echo ""
fi

# CONFIG -----------------------------------------------------------------------
# Default values (used if config.sh doesn't exist or is missing variables)
PG_DIR="${PG_DIR:-$HOME/osfdata/pg}"
OSFIO_DIR="${OSFIO_DIR:-$HOME/osfio}"
PARQUET_DIR="${PARQUET_DIR:-$HOME/osfdata/parquet}"
DUCKDB_PATH="${DUCKDB_PATH:-$HOME/osfdata/osf.db}"
KEYS_PATH="${KEYS_PATH:-$HOME/osfdata/keys.rds}"
GPATH="${GPATH:-cos-gdrive:/data-science-warehouse/OSF Backups}"

# Run options
RUN_CLEAN_SLATE=${RUN_CLEAN_SLATE:-1}
RUN_PG_WORKFLOW=${RUN_PG_WORKFLOW:-1}
RUN_PARQUET_WORKFLOW=${RUN_PARQUET_WORKFLOW:-1}
RUN_DUCKDB_WORKFLOW=${RUN_DUCKDB_WORKFLOW:-0}

# Upload options (default to enabled)
UPLOAD_TO_GDRIVE=${UPLOAD_TO_GDRIVE:-1}


# VALIDATION -------------------------------------------------------------------
# Check prerequisites before running the pipeline

VALIDATION_FAILED=0

echo ""
echo "=============================================="
echo "  ducktape - Prerequisite Validation"
echo "=============================================="
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to report validation status
check_requirement() {
    local name=$1
    local command=$2
    local required=$3  # "required" or "optional"
    
    if command_exists "$command"; then
        echo "✓ $name is installed"
        if [ "$name" = "DuckDB" ]; then
            duckdb --version 2>&1 | head -n1 | sed 's/^/  /'
        elif [ "$name" = "rclone" ]; then
            rclone version 2>&1 | head -n1 | sed 's/^/  /'
        elif [ "$name" = "Docker" ]; then
            docker --version 2>&1 | sed 's/^/  /'
        elif [ "$name" = "R" ]; then
            Rscript --version 2>&1 | head -n1 | sed 's/^/  /'
        fi
        return 0
    else
        if [ "$required" = "required" ]; then
            echo "✗ $name is NOT installed (REQUIRED)"
            VALIDATION_FAILED=1
        else
            echo "⚠ $name is NOT installed (optional)"
        fi
        return 1
    fi
}

# Check required tools
echo "Checking required tools..."
check_requirement "DuckDB" "duckdb" "required"
check_requirement "Docker" "docker" "required"
check_requirement "R" "Rscript" "required"

# Check optional tools
echo ""
echo "Checking optional tools..."
if [ "$UPLOAD_TO_GDRIVE" = "1" ]; then
    check_requirement "rclone" "rclone" "required"
else
    check_requirement "rclone" "rclone" "optional"
    echo "  (Google Drive uploads disabled)"
fi

# Check R packages
echo ""
echo "Checking R packages..."
R_PACKAGES_OK=1
for pkg in "DBI" "RPostgres" "dm" "here"; do
    if Rscript -e "if (!require('$pkg', quietly=TRUE)) quit(status=1)" &> /dev/null; then
        echo "✓ R package: $pkg"
    else
        echo "✗ R package: $pkg is NOT installed"
        VALIDATION_FAILED=1
        R_PACKAGES_OK=0
    fi
done

if [ $R_PACKAGES_OK -eq 0 ]; then
    echo ""
    echo "  To install missing R packages, run:"
    echo "    Rscript -e \"renv::restore()\""
fi

# Check paths and directories
echo ""
echo "Checking paths and directories..."

if [ "$RUN_PG_WORKFLOW" = "1" ]; then
    if [ -d "$PG_DIR" ]; then
        echo "✓ PostgreSQL backup directory exists: $PG_DIR"
        # Check if directory has content
        if [ -n "$(ls -A "$PG_DIR" 2>/dev/null)" ]; then
            echo "  (Directory contains files)"
        else
            echo "  ⚠ WARNING: Directory is empty"
        fi
    else
        echo "✗ PostgreSQL backup directory NOT found: $PG_DIR"
        VALIDATION_FAILED=1
    fi
    
    if [ -d "$OSFIO_DIR" ]; then
        echo "✓ OSF.io directory exists: $OSFIO_DIR"
        # Check for docker-compose.yml
        if [ -f "$OSFIO_DIR/docker-compose.yml" ]; then
            echo "  (docker-compose.yml found)"
        else
            echo "  ⚠ WARNING: docker-compose.yml not found in $OSFIO_DIR"
        fi
    else
        echo "✗ OSF.io directory NOT found: $OSFIO_DIR"
        VALIDATION_FAILED=1
    fi
fi

# Check if Parquet directory can be created
PARQUET_PARENT=$(dirname "$PARQUET_DIR")
if [ -d "$PARQUET_PARENT" ] && [ -w "$PARQUET_PARENT" ]; then
    echo "✓ Can create Parquet directory at: $PARQUET_DIR"
elif [ -d "$PARQUET_DIR" ]; then
    echo "✓ Parquet directory exists: $PARQUET_DIR"
else
    echo "✗ Cannot create Parquet directory: $PARQUET_DIR"
    echo "  Parent directory does not exist or is not writable: $PARQUET_PARENT"
    VALIDATION_FAILED=1
fi

# Check if DuckDB path is writable
DUCKDB_PARENT=$(dirname "$DUCKDB_PATH")
if [ -d "$DUCKDB_PARENT" ] && [ -w "$DUCKDB_PARENT" ]; then
    echo "✓ Can create DuckDB database at: $DUCKDB_PATH"
elif [ -f "$DUCKDB_PATH" ]; then
    echo "✓ DuckDB database exists: $DUCKDB_PATH"
else
    echo "✗ Cannot create DuckDB database: $DUCKDB_PATH"
    echo "  Parent directory does not exist or is not writable: $DUCKDB_PARENT"
    VALIDATION_FAILED=1
fi

# Check rclone configuration
if [ "$UPLOAD_TO_GDRIVE" = "1" ]; then
    echo ""
    echo "Checking rclone configuration..."
    REMOTE_NAME=$(echo "$GPATH" | cut -d: -f1)
    if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:$"; then
        echo "✓ rclone remote configured: $REMOTE_NAME"
    else
        echo "✗ rclone remote NOT configured: $REMOTE_NAME"
        echo "  Run 'rclone config' to set up Google Drive access"
        echo "  Or set UPLOAD_TO_GDRIVE=0 in config.sh to skip uploads"
        VALIDATION_FAILED=1
    fi
fi

# Check Docker
if [ "$RUN_PG_WORKFLOW" = "1" ]; then
    echo ""
    echo "Checking Docker..."
    if docker info &> /dev/null; then
        echo "✓ Docker is running"
    else
        echo "⚠ Docker is installed but not running"
        echo "  The script will attempt to start Docker Desktop"
    fi
fi

# Check disk space
echo ""
echo "Checking disk space..."
if command_exists df; then
    AVAILABLE_GB=$(df -g "$PARQUET_PARENT" 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$AVAILABLE_GB" ] && [ "$AVAILABLE_GB" -ge 150 ]; then
        echo "✓ Sufficient disk space: ${AVAILABLE_GB}GB available"
    else
        echo "⚠ WARNING: Low disk space (${AVAILABLE_GB}GB available)"
        echo "  Pipeline may require 150GB+ for Parquet files and DuckDB"
    fi
fi

# Warn about CLEAN_SLATE
if [ "$RUN_CLEAN_SLATE" = "1" ]; then
    echo ""
    echo "⚠️  WARNING: RUN_CLEAN_SLATE is enabled!"
    echo "   This will DELETE:"
    echo "     - $PARQUET_DIR"
    echo "     - $DUCKDB_PATH"
    echo ""
    read -p "   Continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Aborted by user."
        exit 0
    fi
fi

# Summary
echo ""
echo "=============================================="
if [ $VALIDATION_FAILED -eq 1 ]; then
    echo "❌ VALIDATION FAILED"
    echo "=============================================="
    echo ""
    echo "Please fix the issues above before running the pipeline."
    echo ""
    echo "Common fixes:"
    echo "  - Install DuckDB: brew install duckdb (macOS) or see https://duckdb.org/docs/installation/"
    echo "  - Install R packages: Rscript -e \"renv::restore()\""
    echo "  - Configure rclone: rclone config"
    echo "  - Check paths in config.sh"
    echo ""
    exit 1
else
    echo "✅ ALL CHECKS PASSED"
    echo "=============================================="
    echo ""
    echo "Pipeline configuration:"
    echo "  PostgreSQL Workflow: $([ "$RUN_PG_WORKFLOW" = "1" ] && echo "ENABLED" || echo "disabled")"
    echo "  Parquet Workflow:    $([ "$RUN_PARQUET_WORKFLOW" = "1" ] && echo "ENABLED" || echo "disabled")"
    echo "  DuckDB Workflow:     $([ "$RUN_DUCKDB_WORKFLOW" = "1" ] && echo "ENABLED" || echo "disabled")"
    echo "  Google Drive Upload: $([ "$UPLOAD_TO_GDRIVE" = "1" ] && echo "ENABLED" || echo "disabled")"
    echo ""
    echo "Starting pipeline in 3 seconds... (Ctrl+C to cancel)"
    sleep 3
fi


# CONTANTS AND HELPERS ---------------------------------------------------------
# Reusable command to access postgres from within duckdb cli
PG_ATTACH="ATTACH 'dbname=osf user=postgres host=127.0.0.1 port=5432' \
	AS osf (TYPE postgres);"

# Logging
LOGFILE=logs/ducktape-$(date '+%Y-%m-%d').log
mkdir -p logs
log_message() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOGFILE
}

# Progress indicators
STEP_COUNTER=0
TOTAL_STEPS=0
PIPELINE_START_TIME=0

# Calculate total steps based on enabled workflows
[ "$RUN_CLEAN_SLATE" = "1" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
[ "$RUN_PG_WORKFLOW" = "1" ] && TOTAL_STEPS=$((TOTAL_STEPS + 5))
[ "$RUN_PARQUET_WORKFLOW" = "1" ] && TOTAL_STEPS=$((TOTAL_STEPS + 2))
[ "$RUN_DUCKDB_WORKFLOW" = "1" ] && TOTAL_STEPS=$((TOTAL_STEPS + 3))

# Calculate percentage and ETA
get_percentage() {
	if [ $TOTAL_STEPS -eq 0 ]; then
		echo "0"
	else
		echo $((STEP_COUNTER * 100 / TOTAL_STEPS))
	fi
}

get_eta() {
	local current_time=$(date +%s)
	local elapsed=$((current_time - PIPELINE_START_TIME))
	
	if [ $STEP_COUNTER -eq 0 ]; then
		echo "calculating..."
		return
	fi
	
	local avg_time_per_step=$((elapsed / STEP_COUNTER))
	local remaining_steps=$((TOTAL_STEPS - STEP_COUNTER))
	local eta_seconds=$((avg_time_per_step * remaining_steps))
	
	if [ $eta_seconds -lt 60 ]; then
		echo "${eta_seconds}s"
	elif [ $eta_seconds -lt 3600 ]; then
		local minutes=$((eta_seconds / 60))
		local seconds=$((eta_seconds % 60))
		echo "${minutes}m ${seconds}s"
	else
		local hours=$((eta_seconds / 3600))
		local minutes=$(((eta_seconds % 3600) / 60))
		echo "${hours}h ${minutes}m"
	fi
}

# Progress bar generator
progress_bar() {
	local percent=$1
	local width=40
	local filled=$((percent * width / 100))
	local empty=$((width - filled))
	
	printf "["
	printf "%${filled}s" | tr ' ' '█'
	printf "%${empty}s" | tr ' ' '░'
	printf "]"
}

print_step() {
	STEP_COUNTER=$((STEP_COUNTER + 1))
	local percent=$(get_percentage)
	local eta=$(get_eta)
	
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	printf "  Step %d/%d: %s\n" $STEP_COUNTER $TOTAL_STEPS "$1"
	printf "  Progress: %s %d%% | ETA: %s\n" "$(progress_bar $percent)" $percent "$eta"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	log_message "Step $STEP_COUNTER/$TOTAL_STEPS ($percent%): $1"
}

print_progress() {
	echo "  ➜ $1"
	log_message "  $1"
}

print_success() {
	echo "  ✓ $1"
	log_message "  SUCCESS: $1"
}

# Enhanced spinner with message, percent complete, and ETA
spinner() {
	local pid=$1
	local message=$2
	local delay=0.1
	local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

	while ps -p $pid > /dev/null 2>&1; do
		local temp=${spinstr#?}
		local percent=$(get_percentage)
		local eta=$(get_eta)
		printf "\r  %s %s  %d%% | ETA: %-12s" "${spinstr:0:1}" "$message" "$percent" "$eta"
		local spinstr=$temp${spinstr%"$temp"}
		sleep $delay
	done
	printf "\r%*s\r" 80 ""
}

# Run command with spinner
run_with_spinner() {
	local message=$1
	shift
	
	# Run command in background
	"$@" > /dev/null 2>&1 &
	local pid=$!
	
	# Show spinner
	spinner $pid "$message"
	
	# Wait for completion and return status
	wait $pid
	return $?
}

# Progress tracker for loops
track_progress() {
	local current=$1
	local total=$2
	local message=$3
	local percent=$((current * 100 / total))
	local bar=$(progress_bar $percent)
	
	printf "\r  ➜ %s: %s %d%% (%d/%d)" "$message" "$bar" $percent $current $total
	
	# New line when complete
	if [ $current -eq $total ]; then
		echo ""
	fi
}


# EXECUTE ----------------------------------------------------------------------
START_TIME=$(date +%s)
PIPELINE_START_TIME=$START_TIME
log_message "Pipeline started."

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════════╗"
echo "║                           ducktape Pipeline Starting                           ║"
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Total steps to execute: $TOTAL_STEPS"
echo "  Log file: $LOGFILE"
echo "  Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Purge Existing Files -----
if [ $RUN_CLEAN_SLATE == 1 ]; then
	print_step "Clean Slate - Purging Existing Files"
	print_progress "Deleting Parquet directory: $PARQUET_DIR"
	rm -fr $PARQUET_DIR
	print_progress "Deleting DuckDB database: $DUCKDB_PATH"
	rm -fr $DUCKDB_PATH
	print_progress "Waiting for system cleanup (120s)..."
	sleep 120
	tmutil deletelocalsnapshots . 2>/dev/null
	print_progress "Final cleanup wait (60s)..."
	sleep 60
	print_success "Clean slate complete"
fi
mkdir -p $PARQUET_DIR


# PostgreSQL Workflow -----
if [ $RUN_PG_WORKFLOW == 1 ]; then
	print_step "PostgreSQL - Starting Docker Container"
	
	# Start Docker with spinner
	docker desktop start 2>/dev/null &
	DOCKER_PID=$!
	spinner $DOCKER_PID "Starting Docker Desktop..."
	wait $DOCKER_PID
	
	print_progress "Starting PostgreSQL container..."
	docker compose -f $OSFIO_DIR/docker-compose.yml up -d postgres > /dev/null 2>&1
	print_success "PostgreSQL container running"

	print_step "PostgreSQL - Extracting Table List"
	
	# Query database (must output to create tables.txt)
	print_progress "Querying database for tables..."
	duckdb < src/get-tables.sql
	
	sleep 5
	DBTABLES=()
	while read line; do
		DBTABLES+=($line)
	done < tables.txt
	TABLE_COUNT=${#DBTABLES[@]}
	print_success "Found $TABLE_COUNT tables"

	print_step "PostgreSQL - Generating Export SQL"
	# Initialize SQL file
	echo "ATTACH '${DUCKDB_PATH}' as duck;" > parquet-to-duck.sql
	echo "" > pg-to-parquet.sql
	echo "$PG_ATTACH" >> pg-to-parquet.sql
	
	# Loop through tables with progress bar
	PROCESSED=0
	for table in "${DBTABLES[@]}"; do
		# Postgres to Parquet
		file="${PARQUET_DIR}/${table}.parquet"
		echo "COPY osf.${table} TO '${file}';" >> pg-to-parquet.sql

		# Parquet to DuckDB
		echo "CREATE TABLE IF NOT EXISTS duck.${table} AS" >> parquet-to-duck.sql
		echo "    SELECT * FROM '${PARQUET_DIR}/${table}.parquet';" >> parquet-to-duck.sql
		
		PROCESSED=$((PROCESSED + 1))
		track_progress $PROCESSED $TABLE_COUNT "Generating SQL"
	done
	print_success "SQL generation complete ($TABLE_COUNT tables)"

	print_step "PostgreSQL - Extracting Metadata"
	print_progress "Saving database version info..."
	for file in ${PG_DIR}/backup_manifest.*; do
		filename=$(basename "$file")
    	timestamp="${filename##*.}"
    	echo $timestamp > DB_VERSION.txt
		if [ "$UPLOAD_TO_GDRIVE" = "1" ]; then
			rclone copyto --update DB_VERSION.txt "${GPATH}/DB_VERSION.txt" 2>/dev/null
		fi
	done

	# Extract keys with spinner
	./src/get-keys.r $KEYS_PATH > /dev/null 2>&1 &
	KEYS_PID=$!
	spinner $KEYS_PID "Extracting relational keys..."
	wait $KEYS_PID
	print_success "Keys extracted: $KEYS_PATH"

	if [ "$UPLOAD_TO_GDRIVE" = "1" ]; then
		print_step "PostgreSQL - Uploading to Google Drive"
		
		rclone copyto --update ${KEYS_PATH} "${GPATH}/keys.rds" > /dev/null 2>&1 &
		UPLOAD_PID=$!
		spinner $UPLOAD_PID "Uploading relational keys..."
		wait $UPLOAD_PID
		print_success "Metadata uploaded to Google Drive"
	fi
fi


# Parquet Workflow -----
if [ $RUN_PARQUET_WORKFLOW == 1 ]; then
	print_step "Parquet - Exporting Tables from PostgreSQL"
	
	# Run export with spinner
	duckdb < pg-to-parquet.sql > /dev/null 2>&1 &
	EXPORT_PID=$!
	spinner $EXPORT_PID "Exporting tables to Parquet format (this may take a while)..."
	wait $EXPORT_PID
	
	# Count exported files
	PARQUET_COUNT=$(find "$PARQUET_DIR" -name "*.parquet" 2>/dev/null | wc -l | tr -d ' ')
	print_success "Exported $PARQUET_COUNT tables to Parquet format"

	if [ "$UPLOAD_TO_GDRIVE" = "1" ]; then
		print_step "Parquet - Uploading to Google Drive"
		
		# Note: rclone shows its own progress, so we don't use spinner here
		print_progress "Uploading Parquet files (this will take a while)..."
		rclone copy --progress --update ${PARQUET_DIR} "${GPATH}/parquet"
		print_success "Parquet files uploaded to Google Drive"
	fi
fi



# DuckDB Workflow -----
if [ $RUN_DUCKDB_WORKFLOW == 1 ]; then
	print_step "DuckDB - Cleanup Before Import"
	
	# Stop Docker with spinner
	docker desktop stop 2>/dev/null &
	STOP_PID=$!
	spinner $STOP_PID "Shutting down Docker..."
	wait $STOP_PID
	
	print_progress "Purging PostgreSQL directory to free space..."
	rm -fr $PG_DIR
	print_progress "Waiting for cleanup (180s)..."
	sleep 180
	tmutil deletelocalsnapshots . 2>/dev/null
	print_progress "Final wait (120s)..."
	sleep 120
	print_success "Cleanup complete"

	print_step "DuckDB - Creating Database"
	print_progress "Database location: ${DUCKDB_PATH}"
	
	# Import with spinner
	duckdb < parquet-to-duck.sql > /dev/null 2>&1 &
	IMPORT_PID=$!
	spinner $IMPORT_PID "Importing Parquet files into DuckDB (this may take a while)..."
	wait $IMPORT_PID
	
	# Get database info
	if [ -f "$DUCKDB_PATH" ]; then
		DB_SIZE=$(stat -f%z "$DUCKDB_PATH" 2>/dev/null || stat -c%s "$DUCKDB_PATH" 2>/dev/null)
		DB_SIZE_MB=$((DB_SIZE / 1024 / 1024))
		TABLE_COUNT=$(duckdb "$DUCKDB_PATH" -csv -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='main'" 2>/dev/null | tail -1)
		print_success "Database created: ${DB_SIZE_MB}MB with $TABLE_COUNT tables"
	fi

	if [ "$UPLOAD_TO_GDRIVE" = "1" ]; then
		print_step "DuckDB - Uploading to Google Drive"
		
		# Upload with spinner
		rclone copyto --update ${DUCKDB_PATH} "${GPATH}/osf.db" > /dev/null 2>&1 &
		UPLOAD_PID=$!
		spinner $UPLOAD_PID "Uploading database file to Google Drive..."
		wait $UPLOAD_PID
		print_success "Database uploaded to Google Drive"
	fi
fi

# Completion -----
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
ELAPSED_MIN=$(( ELAPSED / 60 ))
ELAPSED_SEC=$(( ELAPSED % 60 ))

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════════╗"
echo "║                         Pipeline Completed Successfully!                       ║"
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  ✓ Total execution time: ${ELAPSED_MIN} minutes and ${ELAPSED_SEC} seconds"
echo "  ✓ Steps completed: $STEP_COUNTER/$TOTAL_STEPS"
echo ""

# Show what was created
if [ -f "$DUCKDB_PATH" ]; then
	DB_SIZE=$(stat -f%z "$DUCKDB_PATH" 2>/dev/null || stat -c%s "$DUCKDB_PATH" 2>/dev/null)
	DB_SIZE_MB=$((DB_SIZE / 1024 / 1024))
	echo "  📊 DuckDB database: $DUCKDB_PATH (${DB_SIZE_MB}MB)"
fi

if [ -d "$PARQUET_DIR" ]; then
	PARQUET_COUNT=$(find "$PARQUET_DIR" -name "*.parquet" 2>/dev/null | wc -l | tr -d ' ')
	echo "  📦 Parquet files: $PARQUET_COUNT files in $PARQUET_DIR"
fi

echo ""
echo "Next steps:"
echo "  • Check status: ./scripts/check-status.sh"
echo "  • Query data:   ./scripts/query.sh"
echo "  • Verify data:  ./scripts/verify-data.sh"
echo "  • View logs:    tail -f $LOGFILE"
echo ""
echo "Happy data exploring! 🦆"
echo ""

log_message "Pipeline completed successfully in ${ELAPSED_MIN}m ${ELAPSED_SEC}s"

# Submit log file to google drive
if [ "$UPLOAD_TO_GDRIVE" = "1" ]; then
	rclone copyto --progress --update ${LOGFILE} "${GPATH}/logs/$(basename ${LOGFILE})" 2>/dev/null
fi