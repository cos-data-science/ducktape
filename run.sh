#!/bin/bash

# CONFIG -----------------------------------------------------------------------
PG_DIR="$HOME/osfdata/pg"			#local uncompressed postgres backup dir
OSFIO_DIR=$HOME/osfio 				#local directory with osf-codebase
PARQUET_DIR="$HOME/osfdata/parquet"	#local directory to save parquet files
DUCKDB_PATH="$HOME/osfdata/osf.db"	#local DuckDB database
KEYS_PATH="$HOME/osfdata/keys.rds"	#local copy of relational keys from postgres
GPATH="cos-gdrive:/data-science-warehouse/OSF Backups" #Google Drive remote path

# Run options
RUN_CLEAN_SLATE=1	    #purge existing all existing databases/files (1=Yes)
RUN_PG_WORKFLOW=1 	    #run postgres workflow (1=Yes)
RUN_PARQUET_WORKFLOW=1 	#run parquet workflow (1=Yes)
RUN_DUCKDB_WORKFLOW=0 	#run duckdb workflow (1=Yes)


# CONTANTS AND HELPERS ---------------------------------------------------------
# Reusable command to access postgres from within duckdb cli
PG_ATTACH="ATTACH 'dbname=osf user=postgres host=127.0.0.1 port=5432' \
	AS osf (TYPE postgres);"

# Logging
LOGFILE=logs/ducktape-$(date '+%Y-%m-%d').log
mkdir -p logs
log_message() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1 \n" | tee -a $LOGFILE
}


# EXECUTE ----------------------------------------------------------------------
# Purge Existing Files -----
START_TIME=$(date +%s)
log_message "Script started."
if [ $RUN_CLEAN_SLATE == 1 ]; then
	log_message "Purging previous parquet and duckdb files..."
	rm -fr $PARQUET_DIR
	rm -fr $DUCKDB_PATH

	sleep 120
	tmutil deletelocalsnapshots .
	sleep 60
fi
mkdir -p $PARQUET_DIR


# PostgreSQL Workflow -----
if [ $RUN_PG_WORKFLOW == 1 ]; then
	log_message "Starting up postgres docker container..."
	docker desktop start
	docker compose -f $OSFIO_DIR/docker-compose.yml up -d postgres

	log_message "Getting list of tables from postgres..."
	duckdb < src/get-tables.sql
	sleep 5
	DBTABLES=()
	while read line; do
		DBTABLES+=($line)
	done < tables.txt

	log_message "Generating SQL files for data export/import..."

	# Initialize SQL file
	echo "ATTACH '${DUCKDB_PATH}' as duck;" > parquet-to-duck.sql

	# Loop through tables to create SQL commands
	for table in "${DBTABLES[@]}"; do
		# Postgres to Parquet
		file="${PARQUET_DIR}/${table}.parquet"
		echo "COPY osf.${table} TO '${file}';" >> pg-to-parquet.sql

		# Parquet to DuckDB
		echo "CREATE TABLE IF NOT EXISTS duck.${table} AS" >> parquet-to-duck.sql
		echo "    SELECT * FROM '${PARQUET_DIR}/${table}.parquet';" >> parquet-to-duck.sql
	done

	log_message "Sending version info to google drive..."
	for file in ${PG_DIR}/backup_manifest.*; do
		filename=$(basename "$file")
    	timestamp="${filename##*.}"
    	echo $timestamp > DB_VERSION.txt
		rclone copyto --progress --update DB_VERSION.txt "${GPATH}/DB_VERSION.txt"
	done

	log_message "Extracting relational keys from postgres..."
	sleep 5
	./src/get-keys.r $KEYS_PATH

	log_message "Uploading relational key file to google drive..."
	rclone copyto --progress --update ${KEYS_PATH} "${GPATH}/keys.rds"


	# echo "Benchmarking postgres performance..."
	# ./src/benchmark.r postgres
fi


# Parquet Workflow -----
if [ $RUN_PARQUET_WORKFLOW == 1 ]; then
	log_message "Exporting all tables from postgres to parquet..."
	duckdb < pg-to-parquet.sql

	# echo "Benchmarking parquet performance..."
	# ./src/benchmark.r parquet

	log_message "Uploading parquet files to google drive..."
	rclone copy --progress --update ${PARQUET_DIR} "${GPATH}/parquet"
	
fi



# DuckDB Workflow -----
if [ $RUN_DUCKDB_WORKFLOW == 1 ]; then
	# Purge postgres to make space
	log_message "Shutting down docker and purging uncompressed SQL Database..."
	docker desktop stop
	rm -fr $PG_DIR
	sleep 180
	tmutil deletelocalsnapshots .
	sleep 120

	log_message "Creating new database at ${DUCKDB_PATH}..."
	duckdb < parquet-to-duck.sql

	# echo "Benchmarking duckdb performance..."
	# ./src/benchmark.r duckdb

	log_message "Uploading duckdb to google drive..."
	rclone copyto --progress --update ${DUCKDB_PATH} "${GPATH}/osf.db"
fi

# Completion -----
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
log_message "Total execution time: $(( ELAPSED / 60 )) minutes and $(( ELAPSED % 60 )) seconds."

# Submit log file to google drive
rclone copyto --progress --update ${LOGFILE} "${GPATH}/logs/$(basename ${LOGFILE})"

#EOF