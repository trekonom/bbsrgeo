#' Check regional data for compatibility with a crosswalk
#'
#' Checks whether all AGS values occurring in `data` are present in the
#' crosswalk as `ags_old`, and reports missing or unmatched values (e.g.
#' typos or years outside the covered time span). Useful as a preliminary
#' step before [harmonize_regions()], to surface data loss from a silent
#' `inner_join` filter early.
#'
#' @param data A dataset with an AGS column and a year column.
#' @param crosswalk A crosswalk read with [bbsr_crosswalk_read()].
#' @param ags_col Name of the AGS column in `data`.
#' @param year_col Optional name of a year column in `data`. If given, also
#'   checks whether a transition exists in the crosswalk for the respective
#'   year at all.
#'
#' @return Invisibly, the rows from `data` whose AGS was not found in the
#'   crosswalk (0 rows if everything matched). A summary is printed as a
#'   message.
#' @export
check_regions <- function(data, crosswalk, ags_col, year_col = NULL) {
  stopifnot(ags_col %in% names(data))

  ags_values <- normalize_ags(data[[ags_col]])
  known_ags <- unique(c(crosswalk$ags_old, crosswalk$ags_new))

  unknown <- !(ags_values %in% known_ags)
  n_unknown <- sum(unknown)

  if (n_unknown == 0) {
    message(sprintf("All %d rows have an AGS known to the crosswalk.", nrow(data)))
  } else {
    message(sprintf(
      "%d of %d rows have an AGS that does not occur in the crosswalk (possible causes: typos, an AGS outside the covered level, or a year outside the table).",
      n_unknown, nrow(data)
    ))
  }

  if (!is.null(year_col)) {
    stopifnot(year_col %in% names(data))
    year_values <- data[[year_col]]
    known_years <- unique(c(crosswalk$year_from, crosswalk$year_to))
    year_unknown <- !(year_values %in% known_years)
    n_year_unknown <- sum(year_unknown)
    if (n_year_unknown > 0) {
      message(sprintf(
        "%d rows have a year that is not covered by the crosswalk.",
        n_year_unknown
      ))
    }
  }

  invisible(data[unknown, , drop = FALSE])
}
