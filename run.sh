#!/bin/bash

# CONFIG -----------------------------------------------------------------------
PG_DIR="$HOME/osfdata/pg"			#local uncompressed postgres backup dir
PARQUET_DIR="$HOME/osfdata/parquet"	#local directory to save parquet files
DUCKDB_PATH="$HOME/osfdata/osf.db"	#local DuckDB database
KEYS_PATH="$HOME/osfdata/keys.rds"	#local copy of relational keys from postgres

# Run options
RUN_CLEAN_SLATE=1 	#purge existing parquet files and duck database (1=Yes)
RUN_PURGE_PG=0 		#purge postgres database after parquet/duck creation (1=Yes)


# GENERATE HELPER FILES --------------------------------------------------------
# Reusable command to access postgres from within duckdb cli
PG_ATTACH="ATTACH 'dbname=osf user=postgres host=127.0.0.1 port=5432' \
	AS osf (TYPE postgres);"

# Get list of all tables in the database
echo "Getting list of all tables in the database..."
duckdb < get-tables.sql
echo "Tables saved to ./tables.txt"

# Write sql file to export all tables to parquet
SQL_FILE="pg-to-parquet.sql"
echo "Generating export commands..."
echo "$PG_ATTACH" > $SQL_FILE

DBTABLES=()
while read line; do
	DBTABLES+=($line)
done < tables.txt

for table in "${DBTABLES[@]}"; do
	file="${PARQUET_DIR}/${table}.parquet"
	if [ -f $file ]; then
		continue
	fi
	echo "COPY osf.${table} TO '${file}';" >> $SQL_FILE
done

# Write sql file to create duckdb database from parquet files
SQL_FILE="parquet-to-duck.sql"
echo "Generating database creation commands..."
echo "ATTACH '${DUCKDB_PATH}' as duck;" > $SQL_FILE

for table in "${DBTABLES[@]}"; do
	echo "CREATE TABLE IF NOT EXISTS duck.${table} AS" >> $SQL_FILE
    echo "    SELECT * FROM '${PARQUET_DIR}/${table}.parquet';" >> $SQL_FILE
done


# EXECUTE ----------------------------------------------------------------------
mkdir -p $PARQUET_DIR

if [ $RUN_CLEAN_SLATE == 1 ]; then 
	echo "Purging any previous parquet and duckdb files..."
	rm -fr $PARQUET_DIR
	sleep 30
	rm -fr $DUCKDB_PATH
	sleep 30
	mkdir -p $PARQUET_DIR
fi

echo "Exporting all tables from postgres to parquet..."
duckdb < pg-to-parquet.sql

echo "Extracting relational keys from postgres..."
Rscript -e "renv::run(here::here('get-keys.r'),  args = c('${KEYS_PATH}'))"
#get-keys.r ${KEYS_PATH}


if [ $RUN_PURGE_PG == 1 ]; then 
	echo "Purging uncompressed SQL Database..."
	rm -fr $PG_DIR
	sleep 60
fi

echo "Creating new database at ${DUCKDB_PATH}..."
duckdb < parquet-to-duck.sql
