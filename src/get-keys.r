#!/usr/local/bin/Rscript --vanilla
source(here::here(".Rprofile"))

# Capture and parse arguments
# Usage: get-keys.r <outfile> [comma-separated table names]
ARGS <- commandArgs(trailingOnly = TRUE)
OUTFILE <- ARGS[1]
TABLE_FILTER <- if (length(ARGS) >= 2 && nchar(ARGS[2]) > 0) {
  strsplit(ARGS[2], ",")[[1]]
} else {
  NULL
}

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

# Filter to subset if table list provided
if (!is.null(TABLE_FILTER)) {
  pks <- pks[pks$table %in% TABLE_FILTER, ]
  fks <- fks[fks$child_table %in% TABLE_FILTER &
             fks$parent_table %in% TABLE_FILTER, ]
}

keys <- list(
  primary_keys = pks,
  foreign_keys = fks
)

# Save
saveRDS(keys, file = OUTFILE)

# Close connection
DBI::dbDisconnect(db_pg)
