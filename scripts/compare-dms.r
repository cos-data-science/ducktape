#!/usr/local/bin/Rscript --vanilla
source(here::here(".Rprofile"))

# Load modules
box::use(
  ./src/helpers[pg_connect],
  ./src/datamodel[add_all_keys, check_constraints, compare_dms]
)

# Capture and parse arguments
ARGS <- commandArgs(trailingOnly = TRUE)
DUCKDB_PATH <- ARGS[1]
KEYPATH <- ARGS[2]
TABLES <- ARGS[3:length(ARGS)]


# Postgres model ---------------------------------------------------------------
pg_db <- pg_connect()
pg_dm <- dm::dm_from_con(db_pg, table_names = TABLES, learn_keys = TRUE)


# DuckDB model -----------------------------------------------------------------
duck_db <- DBI::dbConnect(duckdb::duckdb(), DUCKDB_PATH)
duck_dm <- dm::dm_from_con(db_duck, table_names = TABLES, learn_keys = FALSE)

# Add keys
keys <- load(KEYPATH)
duck_dm <- duck_dm |> 
  add_all_keys(keys$primary_keys, keys$foreign_keys)
constraint_pass <- check_constraints(pg_dm)

if (!constraint_pass) {
  msg <- "Key constraints not met!"
  log_update(logger, msg, error = TRUE)
  stop(msg)
}

# Compare ----------------------------------------------------------------------
comparison_pass <- compare_dms(pg_dm, duck_dm)

if (!comparison_pass) {
  msg <- "Data models not identical!"
  log_update(logger, msg, error = TRUE)
  stop(msg)
} else {
  msg <- "Data models identical!"
  log_update(logger, msg)
}