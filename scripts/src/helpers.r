#' Define connection to Postgres
#' @export
pg_connect <- function() {
  DBI::dbConnect(
    RPostgres::Postgres(),
    user = Sys.getenv("PGUSER"),
    host = Sys.getenv("PGHOST"),
    port = Sys.getenv("PGPORT"),
    dbname = Sys.getenv("PGDATABASE"),
  )
}


# #' Update log
# #' 
# #' @param logger Logger object
# #' @param msg Message to log
# #' @param error Log as an error. Defaults to `FALSE`
# #' @param echo Print message to console. Defaults to `TRUE`
# #' @export
# log_update <- function(logger, msg, error = FALSE, echo = TRUE) {
#   if (error) {
#     log4r::error(logger, msg)
#   } else {
#     log4r::info(logger, msg)
#   }
#   if (echo) {
#     message(msg)
#   }
# }