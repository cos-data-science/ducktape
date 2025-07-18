#!/usr/local/bin/Rscript --vanilla
source(here::here(".Rprofile"))

# Load modules
box::use(
  ./src/helpers[pg_connect],
)

# Capture and parse arguments
ARGS <- commandArgs(trailingOnly = TRUE)
OUTFILE <- ARGS[1]
TABLES <- ARGS[2:length(ARGS)]

# Postgres connection
db_pg <- pg_connect()
dm_pg <- dm::dm_from_con(db_pg, table_names = TABLES, learn_keys = TRUE)

# Get all keys
pks <- dm::dm_get_all_pks(dm_pg)
fks <- dm::dm_get_all_fks(dm_pg)
keys <- list(
  primary_keys = pks,
  foreign_keys = fks
)

# Save
saveRDS(keys, file = OUTFILE)