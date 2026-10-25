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

  plan <- plan_conversion(
    data[[ags_col]],
    data[[year_col]],
    crosswalk,
    target_year,
    allow_backcast
  )
  unmapped <- plan$dropped
  dropped <- paste(plan$ags, plan$year) %in%
    paste(unmapped$ags, unmapped$year)

  if (!any(dropped)) {
    message(sprintf(
      "All %d rows can be mapped to the boundary year %d.",
      nrow(data),
      plan$target_year
    ))
  } else {
    message(sprintf(
      "%d of %d rows have an AGS the crosswalk cannot map to the boundary year %d and would be dropped (e.g. %s).",
      sum(dropped),
      nrow(data),
      plan$target_year,
      describe_dropped(unmapped[1, ])
    ))
  }

  invisible(data[dropped, , drop = FALSE])
}
