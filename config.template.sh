#!/bin/bash

################################################################################
# ducktape Configuration Template
################################################################################
# 
# INSTRUCTIONS:
# 1. Copy this file: cp config.template.sh config.sh
# 2. Edit config.sh with your local paths and settings
# 3. config.sh is in .gitignore and won't be committed
# 4. Run the pipeline: ./run.sh
#
################################################################################

# PATHS ------------------------------------------------------------------------
# PostgreSQL backup location (uncompressed)
# Example: "$HOME/osfdata/pg" or "/data/postgres/backup"
PG_DIR="$HOME/osfdata/pg"

# OSF codebase directory (if you have it locally)
# Example: "$HOME/code/osf.io" or "$HOME/osfio"
OSFIO_DIR="$HOME/osfio"

# Directory to save Parquet files (requires several GB)
# Example: "$HOME/osfdata/parquet" or "/data/parquet"
PARQUET_DIR="$HOME/osfdata/parquet"

# Path for the final DuckDB database file
# Example: "$HOME/osfdata/osf.db" or "/data/osf.db"
DUCKDB_PATH="$HOME/osfdata/osf.db"

# Path for relational keys extracted from PostgreSQL
# Example: "$HOME/osfdata/keys.rds"
KEYS_PATH="$HOME/osfdata/keys.rds"

# Google Drive remote path (rclone)
# Format: "remote-name:/path/to/folder"
# Example: "cos-gdrive:/data-science-warehouse/OSF Backups"
# Leave as-is if you configured rclone with 'cos-gdrive' as remote name
GPATH="cos-gdrive:/data-science-warehouse/OSF Backups"


# WORKFLOW OPTIONS -------------------------------------------------------------
# Set to 1 to enable, 0 to disable each workflow stage

# Purge all existing databases/files before starting
# WARNING: This deletes PARQUET_DIR and DUCKDB_PATH!
# Set to 0 for incremental updates or if you want to keep existing data
RUN_CLEAN_SLATE=1

# Extract table list and relational keys from PostgreSQL
# Outputs: src/tables.txt, keys.rds, pg-to-parquet.sql
RUN_PG_WORKFLOW=1

# Export PostgreSQL tables to Parquet files
# Requires: PostgreSQL workflow completed (or existing pg-to-parquet.sql)
# Outputs: Multiple .parquet files in PARQUET_DIR
RUN_PARQUET_WORKFLOW=1

# Import Parquet files into DuckDB database
# Requires: Parquet workflow completed (or existing .parquet files)
# Outputs: DuckDB database at DUCKDB_PATH
RUN_DUCKDB_WORKFLOW=1


# GOOGLE DRIVE OPTIONS ---------------------------------------------------------
# Set to 1 to upload files to Google Drive, 0 to skip uploads
# Requires: rclone configured with access to GPATH

UPLOAD_TO_GDRIVE=1

# Upload relational keys to Google Drive
UPLOAD_KEYS=1

# Upload Parquet files to Google Drive (can be slow for 100+ files)
UPLOAD_PARQUET=1

# Upload final DuckDB database to Google Drive
UPLOAD_DUCKDB=1


# ADVANCED OPTIONS -------------------------------------------------------------
# Only modify these if you know what you're doing

# PostgreSQL connection settings (for DuckDB attach)
PG_HOST="127.0.0.1"
PG_PORT="5432"
PG_USER="postgres"
PG_DBNAME="osf"

# Clean slate sleep timers (macOS Time Machine snapshot cleanup)
# Set to 0 to skip waits
CLEAN_SLATE_WAIT_1=120  # Seconds to wait after deletion
CLEAN_SLATE_WAIT_2=60   # Seconds to wait after tmutil command

# Docker Desktop auto-start (macOS specific)
# Set to 0 if you manage Docker manually
AUTO_START_DOCKER=1


# VALIDATION -------------------------------------------------------------------
# Basic path validation (don't edit this section)

if [ "$RUN_PG_WORKFLOW" == "1" ] && [ ! -d "$PG_DIR" ]; then
    echo "WARNING: PG_DIR does not exist: $PG_DIR"
    echo "         Create it or update the path in config.sh"
fi

if [ "$RUN_PARQUET_WORKFLOW" == "1" ] && [ ! -d "$PARQUET_DIR" ]; then
    echo "INFO: PARQUET_DIR will be created: $PARQUET_DIR"
fi

if [ "$UPLOAD_TO_GDRIVE" == "1" ] && ! command -v rclone &> /dev/null; then
    echo "WARNING: rclone not found. Install it or set UPLOAD_TO_GDRIVE=0"
fi

################################################################################
# End of configuration
################################################################################
