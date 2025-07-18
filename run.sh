#!/bin/bash

# SETUP ------------------------------------------------------------------------
# Parameters
source ./runparams.sh

# Control variables
RUN_PURGEDB=1
RUN_PURGEPQ=0
RUN_TABLESET=1
RUN_EXPORT=1
RUN_GETKEYS=1
RUN_CREATEDB=1
#RUN_TEST=1
#RUN_UPLOAD=1


# PIPELINE ---------------------------------------------------------------------
# Staging Files and Directories
mkdir -p $PARQUETDIR

if [ $RUN_PURGEDB == 1 ]; then
	echo "Purging previous data DuckDB"
	if [ -d $DBPATH ]; then
		rm -fr $DBPATH
	fi
fi

if [ $RUN_PURGEPQ == 1 ]; then
	echo "Purging previous Parquet files"
	if [ -d $PARQUETDIR ]; then
		rm -fr $PARQUETDIR
		mkdir -p $PARQUETDIR
	fi
fi


# Subset Tables to Export/Convert
if [ $RUN_TABLESET == 1 ]; then
	echo "Selecting tables of interest..."
	if [ $TABLE_METHOD == "EXPLICIT" ]; then
		echo "Using EXPLICIT method to define tables..."
		DBTABLES=${TABLES_EXPLICIT[@]}
	else
		echo "Using REGEX method to define tables..."
		./scripts/get-tables.r $TABLES_REGEX
		DBTABLES=()
		while read line; do
			DBTABLES+=($line)
		done < tables.txt
	fi
fi


# Parquet Exports
if [ $RUN_EXPORT == 1 ]; then 
	echo "Exporting tables to individual Parquet files..."
	./scripts/pg-parquet.sh pg-to-parquet.sql $PARQUETDIR ${DBTABLES[@]}
	duckdb < pg-to-parquet.sql
fi


# Extract Relational Keys and Create DuckDB
if [ $RUN_CREATEDB == 1 ]; then
	echo "Writing Parquet files to DuckDB..."
	./scripts/parquet-duck.sh parquet-to-duck.sql $PARQUETDIR $DBPATH ${DBTABLES[@]}
	duckdb < parquet-to-duck.sql
fi

if [ $RUN_GETKEYS == 1 ]; then
	echo "Extracting keys...."
	./scripts/get-keys.r $KEYPATH ${DBTABLES[@]} 
fi


# Cleanup
rm -f pg-to-parquet.sql parquet-to-duck.sql tables.txt




# IN DEVELOPMENT --------------------------------------------------------------
# # Compare Postgres and DuckDB versions
# if [ $RUN_TEST == 1 ]; then
# 	echo "Comparing Postgres and DuckDB versions..."
# 	./scripts/compare-dms.r $DBPATH $KEYPATH ${DBTABLES[@]} 
# fi

# # Save the database and keyfile
# if [ $RUN_UPLOAD == 1 ]; then
# 	echo "Uploading database..."
# 	./scripts/upload.r $GOOGLE_USER $DRIVEID $DBPATH $KEYPATH
# fi

