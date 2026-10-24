# Facts about the transition group (ags_old, year_from, year_to) of every
# crosswalk row, for one weight basis ("area", "population" or "employment").
# One value per crosswalk row, repeated over the rows of its group:
# - n_rows: rows in the group
# - share_sum: sum of `share_<basis>`, missing shares ignored
# - count_total: sum of `<basis>_old`
# - counts_observed: every count is observed
# - counts_differ: counts observed and differing between rows beyond rounding
#   noise (equal counts cannot be told from the unit's total repeated on every
#   row); a missing count makes it FALSE
# - counts_non_negative: no observed count is negative
# An absent share or count column gives NA sums and FALSE conditions, so
# callers skip that basis without an error.
transition_group_facts <- function(crosswalk, basis) {
  share <- crosswalk[[paste0("share_", basis)]]
  count <- crosswalk[[paste0(basis, "_old")]]
  has_share <- !is.null(share)
  if (!has_share) {
    share <- rep(NA_real_, nrow(crosswalk))
  }
  has_count <- !is.null(count)
  if (!has_count) {
    count <- rep(NA_real_, nrow(crosswalk))
  }
  n <- nrow(crosswalk)
  gid <- dplyr::group_indices(dplyr::group_by(
    data.frame(
      ags_old = crosswalk$ags_old,
      year_from = crosswalk$year_from,
      year_to = crosswalk$year_to
    ),
    .data$ags_old,
    .data$year_from,
    .data$year_to
  ))
  # Vectorised over the groups (the real files have ~150k): sums by rowsum(),
  # extremes from the counts sorted within each group, missing last.
  group_sum <- function(x) {
    unname(drop(rowsum(x, gid, reorder = TRUE))[gid])
  }
  n_missing <- group_sum(as.numeric(is.na(count)))
  ordered <- order(gid, count)
  first_row <- ordered[!duplicated(gid[ordered])]
  last_row <- ordered[!duplicated(gid[ordered], fromLast = TRUE)]
  group_min <- count[first_row][gid]
  group_max <- count[last_row][gid]
  counts_observed <- n_missing == 0
  out <- tibble::tibble(
    n_rows = group_sum(rep(1, n)),
    share_sum = group_sum(replace(share, is.na(share), 0)),
    count_total = group_sum(count),
    counts_observed = counts_observed,
    counts_differ = counts_observed &
      (group_max - group_min) >
        COUNT_DIFFERENCE_TOLERANCE * pmax(abs(group_min), abs(group_max)),
    counts_non_negative = is.na(group_min) | group_min >= 0
  )
  if (!has_share) {
    out$share_sum <- NA_real_
  }
  if (!has_count) {
    out$count_total <- NA_real_
    out$counts_observed <- FALSE
    out$counts_differ <- FALSE
    out$counts_non_negative <- FALSE
  }
  out
}
