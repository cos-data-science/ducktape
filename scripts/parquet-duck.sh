#!/bin/bash

# Capture arguments
SQL_FILE=$1
shift
LOCAL_DIR=$1
shift
DUCKDB_PATH=$1
shift
TABLE_ARRAY=("$@")

# Initialize SQL file
echo "-- SQL auto-generated from src/parquet2duck.sh" > $SQL_FILE
echo "ATTACH '${DUCKDB_PATH}' as duck;" >> $SQL_FILE

# Loop through tables
for table in "${TABLE_ARRAY[@]}"; do
	echo "CREATE TABLE IF NOT EXISTS duck.${table} AS" >> $SQL_FILE
    echo "    SELECT * FROM '${LOCAL_DIR}/${table}.parquet';" >> $SQL_FILE
done