#!/usr/local/bin/Rscript --vanilla
source(here::here(".Rprofile"))

ARGS <- commandArgs(trailingOnly = TRUE)
WHO <- ARGS[1]
GID <- ARGS[2]
PAYLOAD <- ARGS[3:length(ARGS)]


googledrive::drive_auth(email = WHO)

DRIVEID <- googledrive::drive_get(GID)$id
for (i in 1:length(PAYLOAD)) {
  googledrive::drive_upload(
    file = PAYLOAD,
    path = as_id(DRIVEID),
    name = basename(PAYLOAD[i])
  )
}
