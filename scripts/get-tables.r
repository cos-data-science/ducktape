#!/usr/local/bin/Rscript --vanilla
source(here::here(".Rprofile"))

# Load modules
library(dbplyr)
box::use(
  ./src/helpers[pg_connect],
)

# Capture and parse arguments
ARGS <- commandArgs(trailingOnly = TRUE)
REGEX <- ARGS[1]

# Postgres connection
db_pg <- pg_connect()
dm_pg <- dm::dm_from_con(db_pg, learn_keys = FALSE)

# Get all tables
tables <- names(dm_pg)[grepl(REGEX, names(dm_pg))]
writeLines(tables, here::here("tables.txt"))