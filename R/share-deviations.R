# Share deviations: which Transition groups of a crosswalk have shares that do
# not sum to 1, which treatment applies to each, and how the shares of the
# others compare with their counts. The read-time checks and the renormalization
# in harmonize_regions() both ask this module, so the rule exists once. The
# module also words both reports: bbsrgeo_check_share_sums() and
# bbsrgeo_check_count_shares() at read time, report_treatments() at conversion.
# See "Share deviation", "Treatment" and "Count gap" in GLOSSARY.md and ADR 0001.

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
classify_share_deviations <- function(
  crosswalk,
  basis,
  analysis = share_deviation_analysis(crosswalk)
) {
  facts <- group_facts(analysis, basis)
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
    area_sums <- group_facts(analysis, "area")$share_sum
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
share_deviation_patterns <- function(
  crosswalk,
  analysis = share_deviation_analysis(crosswalk)
) {
  n <- nrow(crosswalk)
  area <- group_facts(analysis, "area")
  counts_differ <- area$counts_differ |
    group_facts(analysis, "population")$counts_differ |
    group_facts(analysis, "employment")$counts_differ
  not_one <- !is_true(abs(crosswalk$share_area - 1) <= SHARE_SUM_TOLERANCE)
  all_one <- group_sum(as.numeric(not_one), analysis$gid) == 0

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

# The Transition groups of a crosswalk and, once asked for, their facts per
# weight basis. Built once for a crosswalk and passed to the functions below, so
# the group ids and the facts are not recomputed for every basis and every
# caller (the real files have ~150k groups). An environment, so the facts it
# computes are kept. It must be used with the crosswalk it was built for.
share_deviation_analysis <- function(crosswalk) {
  analysis <- new.env(parent = emptyenv())
  analysis$crosswalk <- crosswalk
  analysis$gid <- transition_group_ids(crosswalk)
  analysis$facts <- list()
  analysis
}

# The transition_group_facts() of one weight basis, computed on first use.
group_facts <- function(analysis, basis) {
  if (is.null(analysis$facts[[basis]])) {
    analysis$facts[[basis]] <- transition_group_facts(
      analysis$crosswalk,
      basis,
      analysis$gid
    )
  }
  analysis$facts[[basis]]
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
transition_group_facts <- function(
  crosswalk,
  basis,
  gid = transition_group_ids(crosswalk)
) {
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

#' Check that shares agree with their own counts
#'
#' For each weight basis, in an `ags_old`/transition group with several target
#' rows, counts that are all observed, non-negative and differ between rows
#' (as in [harmonize_regions()]), a positive total and shares summing to 1
#' within `SHARE_SUM_TOLERANCE`, `count / total` should equal the share. A
#' row deviates by more than the counts' resolution allows when
#' `|count / total - share| > COUNT_RESOLUTION * (1 + n_rows) / total`. Groups
#' with equal counts or shares summing off 1 are skipped. Reported as one
#' message; the conversion uses the shares as given (ADR 0001).
#'
#' @param data Tibble read by [bbsr_crosswalk_read()].
#' @param analysis The `share_deviation_analysis()` of `data`.
#' @return A `finding()`, or `NULL` when nothing is found.
#' @noRd
bbsrgeo_check_count_shares <- function(
  data,
  analysis = share_deviation_analysis(data)
) {
  items <- list()
  for (basis in c("area", "population", "employment")) {
    share_col <- paste0("share_", basis)
    count_col <- paste0(basis, "_old")
    if (!all(c(share_col, count_col) %in% names(data))) {
      next
    }
    classified <- classify_share_deviations(data, basis, analysis)
    disagree <- classified$count_gap_exceeds_resolution
    if (!any(disagree)) {
      next
    }
    # The largest gap per group is taken over its rows with a gap, which are
    # all rows of a group that has one.
    has_gap <- !is.na(classified$count_gap)
    d <- data.frame(
      ags_old = data$ags_old,
      year_from = data$year_from,
      year_to = data$year_to,
      deviation = classified$count_gap
    )[has_gap, , drop = FALSE]
    disagree <- disagree[has_gap]
    d <- dplyr::ungroup(dplyr::mutate(
      dplyr::group_by(d, .data$ags_old, .data$year_from, .data$year_to),
      largest = max(.data$deviation)
    ))
    groups <- unique(d[
      disagree,
      c("ags_old", "year_from", "year_to", "largest")
    ])
    groups <- groups[order(groups$ags_old, groups$year_from), , drop = FALSE]
    shown <- utils::head(groups, MAX_FINDING_EXAMPLES)
    items[[length(items) + 1]] <- finding_item(
      "group(s)",
      nrow(groups),
      sprintf(
        "ags_old = '%s', year_from = %d, largest deviation %.4f",
        shown$ags_old,
        shown$year_from,
        shown$largest
      ),
      scope = basis
    )
  }
  if (length(items) == 0) {
    return(NULL)
  }
  finding(
    paste(
      "Some shares disagree with their counts by more than the counts'",
      "resolution allows (count / total differs from the share):"
    ),
    items,
    paste(
      "The conversion uses the shares as given. Please check the original",
      "file if in doubt."
    ),
    severity = "message"
  )
}

#' Sanity-check share sums per ags_old/year_from
#'
#' The area-proportional shares of all target areas of an `ags_old` should
#' sum to 1 per year transition (see Details in [bbsr_crosswalk_read()]). The
#' BBSR source files, however, contain combinations where this is not the
#' case. They are surfaced here as one warning that counts them by the pattern
#' observed in the rows (see "Share deviation" in `GLOSSARY.md`), without
#' stating a cause.
#'
#' @param data Tibble read by [bbsr_crosswalk_read()].
#' @param analysis The `share_deviation_analysis()` of `data`.
#' @return A `finding()`, or `NULL` when nothing is found.
#' @noRd
bbsrgeo_check_share_sums <- function(
  data,
  analysis = share_deviation_analysis(data)
) {
  classified <- share_deviation_patterns(data, analysis)
  deviating <- !is.na(classified$pattern)
  if (!any(deviating)) {
    return(NULL)
  }
  off <- unique(data.frame(
    ags_old = data$ags_old[deviating],
    year_from = data$year_from[deviating],
    year_to = data$year_to[deviating],
    area_sum = classified$share_sum[deviating],
    pattern = classified$pattern[deviating]
  ))
  off <- off[order(off$ags_old, off$year_from, off$year_to), , drop = FALSE]

  labels <- c(
    a = paste(
      "a share of 1 on every target row of a multi-row group, with counts",
      "that differ between rows"
    ),
    b = "a single target row with a share below 1",
    c = "other"
  )
  items <- purrr::map(
    intersect(names(labels), off$pattern),
    function(p) {
      rows <- off[off$pattern == p, , drop = FALSE]
      finding_item(
        sprintf("combination(s): %s", labels[[p]]),
        nrow(rows),
        sprintf(
          "ags_old = '%s', year_from = %d: sum = %.3f",
          rows$ags_old[1],
          rows$year_from[1],
          rows$area_sum[1]
        )
      )
    }
  )
  finding(
    sprintf(
      paste(
        "%d ags_old/year_from combination(s) have a sum of area shares that",
        "deviates from 1 by more than %g%%. By pattern:"
      ),
      nrow(off),
      SHARE_SUM_TOLERANCE * 100
    ),
    items,
    "Please check the original file if in doubt."
  )
}

# Reports (by default as a message) that the shares of the `ags_old`/transition
# combinations selected by `mask` deviate from 1, naming the first
# MAX_FINDING_EXAMPLES. `what`
# completes the sentence "The crosswalk's <share_col> for N combination(s) ...";
# a `%s` in it is filled with SHARE_SUM_TOLERANCE.
report_share_deviations <- function(
  crosswalk,
  share_col,
  mask,
  sums,
  what,
  severity = "message"
) {
  affected <- unique(data.frame(
    ags = crosswalk$ags_old[mask],
    year_from = crosswalk$year_from[mask],
    year_to = crosswalk$year_to[mask],
    share_sum = sums[mask]
  ))
  if (nrow(affected) == 0) {
    return(invisible())
  }
  affected <- affected[order(affected$ags, affected$year_from), , drop = FALSE]
  shown <- utils::head(affected, MAX_FINDING_EXAMPLES)
  what <- if (grepl("%s", what, fixed = TRUE)) {
    sprintf(what, SHARE_SUM_TOLERANCE)
  } else {
    what
  }
  report_finding(finding(
    sprintf(
      "The crosswalk's %s for %d ags_old/transition combination(s) %s.",
      share_col,
      nrow(affected),
      what
    ),
    list(finding_item(
      sprintf("combination(s) affected (first %d shown)", nrow(shown)),
      nrow(affected),
      sprintf(
        "%s (%d -> %d, sum %.4f)",
        shown$ags,
        shown$year_from,
        shown$year_to,
        shown$share_sum
      )
    )),
    severity = severity
  ))
  invisible()
}

# Reports the Treatments of `classified` (classify_share_deviations() of
# `share_col`'s basis) for the crosswalk rows in `rows`: groups that were
# renormalized as a warning, groups within the tolerance as a message. With
# `renormalize = FALSE` every deviation in `rows` is reported once, as a
# message.
report_treatments <- function(
  crosswalk,
  share_col,
  classified,
  rows,
  renormalize = TRUE
) {
  sums <- classified$share_sum
  if (!renormalize) {
    report_share_deviations(
      crosswalk,
      share_col,
      classified$treatment != "ok" & rows,
      sums,
      "were used as given (renormalize = FALSE)"
    )
    return(invisible())
  }
  report_share_deviations(
    crosswalk,
    share_col,
    classified$treatment == "renormalize" & rows,
    sums,
    "do not sum to 1 (tolerance %s). They were renormalized so that no part of an absolute value is lost. The inconsistency is in the BBSR crosswalk, not in `data`",
    severity = "warning"
  )
  report_share_deviations(
    crosswalk,
    share_col,
    classified$treatment == "rounding" & rows,
    sums,
    "deviate slightly from 1 (within the tolerance %s) and were renormalized to sum to 1",
    severity = "message"
  )
  invisible()
}
