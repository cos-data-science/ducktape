#' Get keys for a data model
#' 
#' @param db Data model (`dm` object)
#' @export
get_all_keys <- function(dm, tables = NULL) {
  # Optional table selection; default is all tables in the data model
  if (!is.null(tables)) {
    dm <- dm |>
      dm::dm_select_tbl(all_of(tables))
  } 

  # Get primary and foreign keys
  primary_keys <- dm::dm_get_all_pks(dm)
  foreign_keys <- dm::dm_get_all_fks(dm)

  return(list(pk = primary_keys, fk = foreign_keys))
}


#' Add a primary key to a data model
#' 
#' @param dm Data model (`dm` object)
#' @param table Name of table to add primary key
#' @param pk_col Name of column to use as primary key
#' @export
add_pk <- function(dm, table, pk_col) {
  tbl <- rlang::sym(table)
  col <- rlang::sym(pk_col)

  dm |>
    dm::dm_add_pk(table = !!tbl, columns = !!col, force = force)
}


#' Add foreign keys to a data model
#' 
#' @param dm Data model (`dm` object)
#' @param child_table Name of the child table
#' @param child_fk_cols Name of the column(s) in the child table that reference the parent table
#' @param parent_table Name of the parent table
#' @param ... Additional arguments passed to `dm::dm_add_fk()`
#' @export
add_fk <- function(dm, child_table, child_fk_cols, parent_table, col_name) {
  tbl <- rlang::sym(child_table)
  col <- rlang::sym(child_fk_cols)
  ref_tbl <- rlang::sym(parent_table)

  dm |>
    dm::dm_add_fk(table = !!tbl, columns = !!col, ref_table = !!ref_tbl)
}


#' Add primary and foreign keys to a data model
#' 
#' @param dm Data model (`dm` object)
#' @param tbl_pk Data frame generated from `dm::dm_get_all_pks()`
#' @param tbl_fk Data frame generated from `dm::dm_get_all_fks()`
#' @export
add_all_keys <- function(dm, tbl_pk, tbl_fk) {
  # Assign primary keys
  for (i in 1:nrow(tbl_pk)) {
    dm <- add_pk(dm, tbl_pk$table[i], tbl_pk$pk_col[[i]])
  }

  # Assign foreign keys
  for (i in 1:nrow(tbl_fk)) {
    dm <- add_fk(dm, tbl_fk$child_table[i], tbl_fk$child_fk_cols[[i]], tbl_fk$parent_table[i])
  }

  return(dm)
}



#' Check constraints in data model
#' 
#' @param dm Data model (`dm` object)
#' @export
check_constraints <- function(dm) {
  result <- dm::dm_examine_constraints(dm)
  
  if (length(which(result$problem !="")) > 0) {
    print(result)
    return(FALSE)
  } else {
    return(TRUE)
  }
}


#' Get field names for each table in a data model
#' 
#' @param dm Data model (`dm` object)
#' @param tables Character vector of table names. Defaults to NULL.
#' @export
dm_get_cols <- function(dm, tables = NULL) {
  # Use all tables if no tables specified
  if (is.null(tables)) {
    TABLES <- names(dm)
  } else {
    TABLES <- tables
  }

  cols <- purrr::map(
    TABLES,
    ~ dm |>
        dm::dm_zoom_to(!!sym(.x)) |>
        colnames()
  )
  names(cols) <- TABLES

  return(cols)
}


#' Get number of rows for each table in a data model
#' @export
dm_get_nrows <- function(dm) {
  sort(dm::dm_nrow(dm))
}


#' Compare two data models
#' 
#' @param dm1 Data model 1 (`dm` object)
#' @param dm2 Data model 2 (`dm` object)
#' @param logger Logger object. Defaults to NULL, in which case a logger will be initialized at run time.
#' @export
compare_dms <- function(dm1, dm2) {
  message("Checking number of rows across all tables...")
  dm1_rows <- dm_get_nrows(dm1)
  mydm_rows <- dm_get_nrows(dm2)
  row_pass <- identical(dm1_rows, mydm_rows)
  if (row_pass) {
    message("Number of rows match!")
  } else {
    message("Number of rows do not match!")
  }

  message("Checking column names...")
  dm1_cols <- dm_get_cols(dm1)
  mydm_cols <- dm_get_cols(dm2)
  col_pass <- identical(dm1_cols, mydm_cols)
  if (col_pass) {
    message("Column names match!")
  } else {
    message("Column names do not match!")
  }
 
  if (row_pass & col_pass) {
    message("Data models match!")
    return(TRUE)
  } else {
    message("Data models do not match!")
    return(FALSE)
  }
}