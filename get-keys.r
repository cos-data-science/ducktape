#!/usr/local/bin/Rscript --vanilla
#source(here::here(".Rprofile"))

# Capture and parse arguments
ARGS <- commandArgs(trailingOnly = TRUE)
OUTFILE <- ARGS[1]

# Postgres connection
db_pg <- DBI::dbConnect(
  RPostgres::Postgres(),
  user = "postgres",
  host = "127.0.0.1",
  port = "5432",
  dbname = "osf"
)

dm_pg <- dm::dm_from_con(db_pg, learn_keys = TRUE)

# Get all keys
pks <- dm::dm_get_all_pks(dm_pg)
fks <- dm::dm_get_all_fks(dm_pg)
keys <- list(
  primary_keys = pks,
  foreign_keys = fks
)

# Save
saveRDS(keys, file = OUTFILE)
