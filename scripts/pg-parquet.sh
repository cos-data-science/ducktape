#!/bin/bash

# Capture arguments
SQL_FILE=$1
shift
LOCAL_DIR=$1
shift
TABLE_ARRAY=("$@")

# Define local variables
PG_ATTACH="ATTACH 'dbname=osf user=postgres host=127.0.0.1 port=5432' \
	AS osf (TYPE postgres);"

# Initialize file
echo "-- SQL auto-generated from scripts/src/pg-parquet.sh" > $SQL_FILE
echo "$PG_ATTACH" >> $SQL_FILE

# Loop through tables
for table in "${TABLE_ARRAY[@]}"; do
	file="${LOCAL_DIR}/${table}.parquet"
	if [ -f $file ]; then
		rm -f $file
	fi
	echo "COPY osf.${table} TO '${file}';" >> $SQL_FILE
done