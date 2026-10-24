#' Check regional data for compatibility with a crosswalk
#'
#' Reports the rows of `data` that [harmonize_regions()] would drop as
#' unmapped units when converting to `target_year`: an area unit the crosswalk
#' has no entry for in a transition the conversion passes through, in every
#' year including `target_year` (see Details of [harmonize_regions()]). It
#' follows the same transitions as the conversion, chaining year-to-year
#' crosswalks where needed, but looks at the area units only, so no values are
#' needed and nothing is converted. Useful as a preliminary step, to surface
#' data loss early.
#'
#' A row is reported if any part of its value is lost, also when the unit maps
#' at the first transition but one of its targets has no entry at a later one.
#' A path the crosswalk cannot cover, or a backcast without
#' `allow_backcast = TRUE`, is an error with the same message as in
#' [harmonize_regions()].
#'
#' @param data A dataset with an AGS column and a year column.
#' @param crosswalk A crosswalk read with [bbsr_crosswalk_read()].
#' @param ags_col Name of the AGS column in `data`.
#' @param year_col Name of the year column in `data`.
#' @param target_year Target year of the boundary, or `"current"`, as in
#'   [harmonize_regions()].
#' @param allow_backcast Allow backcasting, as in [harmonize_regions()].
#'   Default `FALSE`.
#'
#' @return Invisibly, the rows from `data` that would be dropped (0 rows if
#'   everything maps). A summary is printed as a message.
#' @export
check_regions <- function(
  data,
  crosswalk,
  ags_col,
  year_col,
  target_year,
  allow_backcast = FALSE
) {
  stopifnot(ags_col %in% names(data), year_col %in% names(data))

  target_year_resolved <- resolve_target_year(target_year, crosswalk)
  ags <- normalize_ags(data[[ags_col]])
  year <- as.integer(data[[year_col]])

  unmapped <- purrr::map_dfr(sort(unique(year)), function(y) {
    found <- find_unmapped_units(
      ags[year %in% y],
      crosswalk,
      y,
      target_year_resolved,
      allow_backcast
    )
    found$year <- rep(y, nrow(found))
    found
  })
  dropped <- paste(ags, year) %in% paste(unmapped$ags, unmapped$year)

  if (!any(dropped)) {
    message(sprintf(
      "All %d rows can be mapped to the boundary year %d.",
      nrow(data),
      target_year_resolved
    ))
  } else {
    first <- unmapped[1, ]
    where <- if (first$year_from == first$year_to) {
      "not an ags_new of any transition into the target year"
    } else {
      sprintf(
        "no entry in the %d -> %d transition",
        first$year_from,
        first$year_to
      )
    }
    message(sprintf(
      "%d of %d rows have an AGS the crosswalk cannot map to the boundary year %d and would be dropped (e.g. %s in %d: %s).",
      sum(dropped),
      nrow(data),
      target_year_resolved,
      first$ags,
      first$year,
      where
    ))
  }

  invisible(data[dropped, , drop = FALSE])
}
