# Share deviations: which Transition groups of a crosswalk have shares that do
# not sum to 1, which treatment applies to each, and how the shares of the
# others compare with their counts. The read-time checks and the renormalization
# in harmonize_regions() both ask this module, so the rule exists once. See
# "Share deviation", "Treatment" and "Count gap" in GLOSSARY.md and ADR 0001.

# Largest deviation of a crosswalk's shares per ags_old/transition from a sum of
# 1 that is treated as rounding.
SHARE_SUM_TOLERANCE <- 0.01

# Slack for comparing a share sum's deviation against SHARE_SUM_TOLERANCE: a
# deviation of exactly the tolerance is not one, but three shares of 0.33
# deviate from 1 by 0.010000000000000009 in floating point. Any value far above
# floating-point error (~1e-16) and far below the data's resolution works.
SHARE_SUM_FLOAT_SLACK <- 1e-9

# Smallest relative difference between the counts (`area_old` etc.) of a
# group's rows that is read as a real difference, not rounding noise.
COUNT_DIFFERENCE_TOLERANCE <- 1e-8

# Largest rounding error of one count (`area_old` etc.) that is assumed: half
# of the coarsest resolution observed, 0.1 (the 1990-2000 population counts).
# Bounds how far `count / total` may lie from a share before the difference is
# a count gap beyond the counts' resolution.
COUNT_RESOLUTION <- 0.05

# Whether a share sum deviates from 1 by more than SHARE_SUM_TOLERANCE.
share_sum_deviates <- function(sums) {
  abs(sums - 1) - SHARE_SUM_TOLERANCE > SHARE_SUM_FLOAT_SLACK
}

# Classifies every crosswalk row by the Transition group (ags_old, year_from,
# year_to) it belongs to, for one weight basis ("area", "population" or
# "employment"). One row per crosswalk row, repeated over the rows of its group:
# - share_sum: sum of `share_<basis>`, missing shares ignored (NA if the column
#   is absent)
# - treatment: how the group's shares are corrected. "ok" (sum 1, 0 or
#   negative: left as they are), otherwise one of, in order of precedence
#   within a deviation beyond SHARE_SUM_TOLERANCE:
#   - "rounding": the sum is off 1 but within the tolerance; rescaled to 1
#   - "zero_basis": the basis is observed and 0 on every row (a unit without
#     population/employment). The crosswalks give it a share of 1 on every
#     target row (observed, e.g. 09671456, 2020; see
#     .scratch/crosswalk-read-municipal issue 05), which cannot be a split.
#     Split by area share instead (not for the area basis)
#   - "parts": the counts are observed on every row, differ between rows and
#     have a positive total (observed, e.g. 12039430, 1992, whose count shares
#     are 0.30 / 0.70; see issue 05); read as the parts going to each target,
#     so the shares are count / total
#   - "renormalize": anything else (e.g. the unit's total repeated on every
#     row); rescaled to sum to 1
# - share: the share after its treatment (the given share for "ok")
# - count_gap: |count / total - share| for a group whose counts read as parts
#   and whose shares sum to 1 within the tolerance; NA elsewhere
# - count_gap_exceeds_resolution: the gap is larger than the counts' resolution
#   allows, `COUNT_RESOLUTION * (1 + n_rows) / total`
# An absent share or count column gives treatment "ok" and no count gap, so
# callers skip that basis without an error.
classify_share_deviations <- function(crosswalk, basis) {
  facts <- transition_group_facts(crosswalk, basis)
  n <- nrow(crosswalk)
  sums <- facts$share_sum
  share <- crosswalk[[paste0("share_", basis)]] %||% rep(NA_real_, n)
  count <- crosswalk[[paste0(basis, "_old")]] %||% rep(NA_real_, n)
  total <- facts$count_total

  off <- is_true(sums > 0 & abs(sums - 1) > SHARE_SUM_FLOAT_SLACK)
  beyond <- off & is_true(share_sum_deviates(sums))
  rounding <- off & !beyond

  # A missing count (NA) is neither zero nor a part: only observed values count.
  zero_candidate <- beyond &
    basis != "area" &
    is_true(facts$counts_observed & total == 0)
  area_sums <- rep(NA_real_, n)
  if (any(zero_candidate)) {
    area_sums <- transition_group_facts(crosswalk, "area")$share_sum
  }
  zero_basis <- zero_candidate & is_true(area_sums > 0)

  counts_as_parts <- is_true(
    facts$counts_observed &
      facts$counts_differ &
      facts$counts_non_negative &
      total > 0
  )
  parts <- beyond & !zero_basis & counts_as_parts
  renormalize <- beyond & !zero_basis & !parts

  corrected <- share
  if (any(zero_basis)) {
    corrected[zero_basis] <- crosswalk$share_area[zero_basis] /
      area_sums[zero_basis]
  }
  corrected[parts] <- count[parts] / total[parts]
  rescale <- rounding | renormalize
  corrected[rescale] <- share[rescale] / sums[rescale]

  treatment <- rep("ok", n)
  treatment[rounding] <- "rounding"
  treatment[zero_basis] <- "zero_basis"
  treatment[parts] <- "parts"
  treatment[renormalize] <- "renormalize"

  comparable <- counts_as_parts &
    facts$n_rows > 1 &
    is_true(!share_sum_deviates(sums))
  gap <- abs(count / total - share)
  gap[!comparable] <- NA_real_

  tibble::tibble(
    share_sum = sums,
    treatment = treatment,
    share = corrected,
    count_gap = gap,
    count_gap_exceeds_resolution = comparable &
      is_true(gap - COUNT_RESOLUTION * (1 + facts$n_rows) / total > 0)
  )
}

# Names the pattern of every share deviation beyond SHARE_SUM_TOLERANCE in the
# area shares, from what the rows look like and not from a cause (see "Share
# deviation" in GLOSSARY.md). One row per crosswalk row, repeated over its
# group: `share_sum` (area) and `pattern`, "a", "b" or "c", NA where the area
# shares sum to 1 within the tolerance.
share_deviation_patterns <- function(crosswalk) {
  n <- nrow(crosswalk)
  area <- transition_group_facts(crosswalk, "area")
  counts_differ <- area$counts_differ |
    transition_group_facts(crosswalk, "population")$counts_differ |
    transition_group_facts(crosswalk, "employment")$counts_differ
  not_one <- !is_true(abs(crosswalk$share_area - 1) <= SHARE_SUM_TOLERANCE)
  all_one <- group_sum(as.numeric(not_one), transition_group_ids(crosswalk)) ==
    0

  deviates <- is_true(share_sum_deviates(area$share_sum))
  pattern <- rep(NA_character_, n)
  pattern[deviates] <- "c"
  pattern[deviates & area$n_rows == 1 & is_true(area$share_sum < 1)] <- "b"
  pattern[deviates & area$n_rows > 1 & all_one & counts_differ] <- "a"
  tibble::tibble(share_sum = area$share_sum, pattern = pattern)
}

is_true <- function(x) {
  !is.na(x) & x
}

# Group id (1..k) of the Transition group of every crosswalk row.
transition_group_ids <- function(crosswalk) {
  dplyr::group_indices(dplyr::group_by(
    data.frame(
      ags_old = crosswalk$ags_old,
      year_from = crosswalk$year_from,
      year_to = crosswalk$year_to
    ),
    .data$ags_old,
    .data$year_from,
    .data$year_to
  ))
}

# Sum of `x` over each group of `gid`, repeated on every row of the group.
# Vectorised over the groups (the real files have ~150k) with rowsum().
group_sum <- function(x, gid) {
  unname(drop(rowsum(x, gid, reorder = TRUE))[gid])
}

# Facts about the transition group of every crosswalk row, for one weight
# basis. One value per crosswalk row, repeated over the rows of its group:
# - n_rows: rows in the group
# - share_sum: sum of `share_<basis>`, missing shares ignored
# - count_total: sum of `<basis>_old`
# - counts_observed: every count is observed
# - counts_differ: counts observed and differing between rows beyond rounding
#   noise (equal counts cannot be told from the unit's total repeated on every
#   row); a missing count makes it FALSE
# - counts_non_negative: no observed count is negative
# An absent share or count column gives NA sums and FALSE conditions.
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
  gid <- transition_group_ids(crosswalk)
  # Extremes from the counts sorted within each group, missing last.
  n_missing <- group_sum(as.numeric(is.na(count)), gid)
  ordered <- order(gid, count)
  first_row <- ordered[!duplicated(gid[ordered])]
  last_row <- ordered[!duplicated(gid[ordered], fromLast = TRUE)]
  group_min <- count[first_row][gid]
  group_max <- count[last_row][gid]
  counts_observed <- n_missing == 0
  out <- tibble::tibble(
    n_rows = group_sum(rep(1, n), gid),
    share_sum = group_sum(replace(share, is.na(share), 0), gid),
    count_total = group_sum(count, gid),
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
