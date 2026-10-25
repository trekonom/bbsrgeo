#' Check that the names of one code are constant within a transition
#'
#' Within one `ags_old`/`year_from`/`year_to` group `name_old` should be one
#' name, and likewise `name_new` within an `ags_new` group. A code with more
#' than one distinct name in one transition is reported (e.g. 07235000 in
#' 2011 -> 2012 with the name Bernkastel-Wittlich). Missing names are ignored.
#' Reported as one warning, without a cause.
#'
#' @param data Tibble read by [bbsr_crosswalk_read()].
#' @return A `finding()`, or `NULL` when nothing is found.
#' @noRd
bbsrgeo_check_names <- function(data) {
  inconsistent <- function(code_col, name_col) {
    if (!all(c(code_col, name_col) %in% names(data))) {
      return(NULL)
    }
    d <- data.frame(
      code = data[[code_col]],
      name = data[[name_col]],
      year_from = data$year_from,
      year_to = data$year_to
    )
    d <- unique(d[!is.na(d$name), , drop = FALSE])
    key <- paste(d$code, d$year_from, d$year_to)
    n_names <- stats::ave(seq_len(nrow(d)), key, FUN = length)
    d <- d[n_names > 1, , drop = FALSE]
    if (nrow(d) == 0) {
      return(NULL)
    }
    d <- d[order(d$code, d$year_from), , drop = FALSE]
    groups <- split(d, paste(d$code, d$year_from, d$year_to), drop = TRUE)
    list(
      code_col = code_col,
      n = length(groups),
      examples = purrr::map_chr(
        unname(utils::head(groups, MAX_FINDING_EXAMPLES)),
        function(g) {
          sprintf(
            "%s '%s' (%d -> %d): %s",
            code_col,
            g$code[1],
            g$year_from[1],
            g$year_to[1],
            paste0("'", g$name, "'", collapse = ", ")
          )
        }
      )
    )
  }

  found <- purrr::compact(list(
    inconsistent("ags_old", "name_old"),
    inconsistent("ags_new", "name_new")
  ))
  if (length(found) == 0) {
    return(NULL)
  }
  finding(
    "The names of one code differ within a transition:",
    purrr::map(found, function(f) {
      finding_item(
        sprintf("%s group(s) with more than one name", f$code_col),
        f$n,
        f$examples
      )
    }),
    "Please check the original file if in doubt."
  )
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
#' @return A `finding()`, or `NULL` when nothing is found.
#' @noRd
bbsrgeo_check_count_shares <- function(data) {
  items <- list()
  for (basis in c("area", "population", "employment")) {
    share_col <- paste0("share_", basis)
    count_col <- paste0(basis, "_old")
    if (!all(c(share_col, count_col) %in% names(data))) {
      next
    }
    classified <- classify_share_deviations(data, basis)
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
#' @return A `finding()`, or `NULL` when nothing is found.
#' @noRd
bbsrgeo_check_share_sums <- function(data) {
  classified <- share_deviation_patterns(data)
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
