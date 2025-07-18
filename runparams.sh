################################################################################
# Please fill in the following parameters before running the pipeline!
#
# DIRECTORIES ------------------------------------------------------------------
# By default, the directory structure is as follows:
#
# - $HOME/osfdata             - Top-level data directory
#   - $HOME/osfdata/pg        - PostgreSQL backup files
#   - $HOME/osfdata/parquet   - Parquet files
#   - $HOME/osfdata/osf.db    - DuckDB database
#   - $HOME/osfdata/keys.rds  - PostgreSQL keyfile
#
# TABLES OF INTEREST ------------------------------------------------------------
# There are two options for selecting tables of interest:
# 1. Use a regular expression to select tables of interest (TABLES_REGEX)
# 2. Define a list of tables of interest explicity in an array (TABLES_EXPLICIT)
#
# Designate which method to use (REGEX or EXPLICIT) by setting TABLE_METHOD to 
# either "REGEX" or "EXPLICIT"
################################################################################

# Identities
#GOOGLE_USER="alex@cos.io"

# Directories & Paths
OSFDATA="${HOME}/osfdata"
DBPATH="${OSFDATA}/osf.db"
KEYPATH="${OSFDATA}/keys.rds"
PGDATA="${OSFDATA}/pg"
PARQUETDIR="${OSFDATA}/parquet"

# Tables of interest
TABLES_REGEX="^osf"
TABLES_EXPLICIT=(\
	"osf_osfuser" \
	"osf_abstractnode" "osf_nodelog" \
	"osf_preprint" "osf_preprintlog" "osf_preprintrequestaction" \
	"osf_guid" "osf_basefilenode" "osf_pagecounter"
)
TABLE_METHOD="REGEX"  #must be "REGEX" or "EXPLICIT"