#' Check that the names of one code are constant within a transition
#'
#' Within one `ags_old`/`year_from`/`year_to` group `name_old` should be one
#' name, and likewise `name_new` within an `ags_new` group. A code with more
#' than one distinct name in one transition is reported (e.g. 07235000 in
#' 2011 -> 2012 with the name Bernkastel-Wittlich). Missing names are ignored.
#' Reported as one warning, without a cause.
#'
#' @param data Tibble read by [bbsr_crosswalk_read()].
#' @return A [finding()], or `NULL` when nothing is found.
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
#' @return A [finding()], or `NULL` when nothing is found.
#' @noRd
bbsrgeo_check_count_shares <- function(data) {
  items <- list()
  for (basis in c("area", "population", "employment")) {
    share_col <- paste0("share_", basis)
    count_col <- paste0(basis, "_old")
    if (!all(c(share_col, count_col) %in% names(data))) {
      next
    }
    d <- data.frame(
      ags_old = data$ags_old,
      year_from = data$year_from,
      year_to = data$year_to,
      share = data[[share_col]],
      count = data[[count_col]]
    )
    facts <- transition_group_facts(data, basis)
    group_n <- facts$n_rows
    total <- facts$count_total
    share_sum <- facts$share_sum
    eligible <- group_n > 1 &
      facts$counts_observed &
      facts$counts_differ &
      facts$counts_non_negative &
      !is.na(total) &
      total > 0 &
      !is.na(share_sum) &
      !share_sum_deviates(share_sum)
    excess <- abs(d$count / total - d$share) -
      COUNT_RESOLUTION * (1 + group_n) / total
    disagree <- eligible & !is.na(excess) & excess > 0
    if (!any(disagree)) {
      next
    }
    d$deviation <- abs(d$count / total - d$share)
    d <- dplyr::ungroup(dplyr::mutate(
      dplyr::group_by(d, .data$ags_old, .data$year_from, .data$year_to),
      largest = max(.data$deviation, na.rm = TRUE)
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
#' @return A [finding()], or `NULL` when nothing is found.
#' @noRd
bbsrgeo_check_share_sums <- function(data) {
  facts <- lapply(
    c(area = "area", population = "population", employment = "employment"),
    function(basis) transition_group_facts(data, basis)
  )
  rows <- data.frame(
    ags_old = data$ags_old,
    year_from = data$year_from,
    year_to = data$year_to,
    n_rows = facts$area$n_rows,
    area_sum = facts$area$share_sum,
    all_one = abs(data$share_area - 1) <= SHARE_SUM_TOLERANCE,
    counts_differ = facts$area$counts_differ |
      facts$population$counts_differ |
      facts$employment$counts_differ
  )
  summary <- dplyr::summarise(
    dplyr::group_by(rows, .data$ags_old, .data$year_from, .data$year_to),
    n_rows = dplyr::first(.data$n_rows),
    area_sum = dplyr::first(.data$area_sum),
    all_one = all(.data$all_one),
    counts_differ = dplyr::first(.data$counts_differ),
    .groups = "drop"
  )
  off <- summary[share_sum_deviates(summary$area_sum), , drop = FALSE]
  if (nrow(off) == 0) {
    return(NULL)
  }

  # Patterns are named from what the rows look like, not from a cause.
  off$pattern <- dplyr::case_when(
    off$n_rows > 1 & off$all_one & off$counts_differ ~ "a",
    off$n_rows == 1 & off$area_sum < 1 ~ "b",
    TRUE ~ "c"
  )
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
        "deviates from 1 by more than 1%%. By pattern:"
      ),
      nrow(off)
    ),
    items,
    "Please check the original file if in doubt."
  )
}
