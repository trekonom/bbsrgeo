#' Convert a regional statistics time series onto a consistent boundary
#'
#' Converts a regional statistics dataset (AGS district/municipality key +
#' year + value column(s)) onto a single, consistent set of area boundaries
#' using a BBSR area crosswalk (see [bbsr_crosswalk_read()]).
#'
#' `data` must be in "long" panel format: one row per combination of area
#' (`ags_col`) and year (`year_col`), with one or more numeric value columns
#' (`value_cols`). If the data is wide (years as columns), reshape it first
#' with `tidyr::pivot_longer()`.
#'
#' Depending on `type`, values are treated differently:
#' * `"absolute"`: weighted aggregation - the value of an old unit is
#'   multiplied by the chosen share and summed up per new target unit.
#'   Suitable for absolute quantities such as population, employment, area.
#' * `"ratio"`: weighted average - the weights are the absolute values
#'   (area/population/employment) of the contributing old units, scaled by
#'   their share. Suitable for ratios and indicators (e.g. unemployment
#'   rate, population per km²).
#'
#' For `type = "absolute"` in the forward direction, the shares of one source
#' AGS (`ags_old`) in a transition are expected to sum to 1. Where they
#' deviate by more than 0.01 (e.g. BBSR's annual districts crosswalk has
#' self-mapping rows with `share_population` 0.017 for 07137000 in
#' 2014 -> 2015), the shares are renormalized to sum to 1, so no part of a
#' count is lost, and a warning names the affected AGS and transitions. The
#' deviation is in the crosswalk, not in `data`. A sum within 0.01 of 1 (e.g.
#' three shares of 0.33) is also rescaled to 1, with a message instead of a
#' warning. With `renormalize = FALSE` the shares are used as given and a
#' message names the combinations that deviate. Two exceptions apply to
#' deviations beyond 0.01, both without a warning. First, where the counts of a source unit
#' (`population_old`, `area_old` or `employment_old` in the crosswalk) are
#' all observed, differ between its target rows and have a positive total,
#' they are read as the parts going to each target and the shares become
#' count / total. Second, a source unit without population (or employment, for
#' `weight = "employment"`), e.g. a municipality-free area, has a count of 0
#' and a share of 1 on every target row in the BBSR crosswalks (e.g. 09671456,
#' 2020), which cannot be a split; it is split by area share instead. `type = "ratio"` is not
#' affected (its weights are normalized anyway), and backcasting is left as
#' is, since shares are not expected to sum to 1 per `ags_new`.
#'
#' Missing values stay missing: with `type = "absolute"`, a converted value is
#' `NA` if any contributing old unit with a non-zero share is `NA`, since a
#' partial sum would understate the total. With `type = "ratio"`, old units
#' with a missing value are left out of the weighted mean, and the result is
#' `NA` only if all of them are missing.
#'
#' An AGS in `data` that the crosswalk does not know is dropped with one
#' warning per call, in every year including `target_year`. The warning names
#' the first case; the complete list is in `attr(result, "unmapped")` (a
#' tibble with `ags`, `year`, `year_from` and `year_to`, present only when
#' something was dropped) and from [check_regions()]. For rows already at
#' `target_year`, "known" means the AGS occurs as `ags_new` in a transition
#' into `target_year`; if the crosswalk has no such transition, those rows are
#' kept as they are.
#'
#' If the crosswalk is of kind `"annual"` and `target_year` is more than one
#' year-step away, the year-to-year crosswalks are chained automatically
#' (provided the chain is unbroken). With a `"conversion_*"` crosswalk, the
#' conversion happens directly in a single step.
#'
#' BBSR crosswalks are designed for **forward conversion** (older to
#' newer/current boundary). If `target_year` is earlier than the year of
#' individual data rows (disaggregation onto an older boundary), the result
#' carries a higher uncertainty (see BBSR's own notes) and must be enabled
#' explicitly with `allow_backcast = TRUE`.
#'
#' @param data Dataset in long panel format (see Details).
#' @param crosswalk A crosswalk read with [bbsr_crosswalk_read()]. Its `level`
#'   (districts or municipalities) is the level of `data`; a crosswalk that mixes
#'   levels is an error.
#' @param ags_col Name of the AGS column in `data`.
#' @param year_col Name of the year column in `data`.
#' @param value_cols Character vector with the names of the value columns to
#'   convert.
#' @param type `"absolute"` or `"ratio"` (see Details).
#' @param weight Weighting basis: `"population"`, `"area"`, or
#'   `"employment"` (see the BBSR recommendations in `vignette("bbsrgeo")`).
#'   `"employment"` is only available for transitions from 1997 onward; an
#'   earlier conversion is an error.
#' @param target_year Target year of the boundary (e.g. `2024L`) or
#'   `"current"` for the most recent boundary available in the crosswalk.
#' @param allow_backcast Explicitly allow backcasting (disaggregation onto
#'   an older boundary). Default `FALSE`.
#' @param renormalize With `type = "absolute"`, rescale the crosswalk's shares
#'   where they do not sum to 1 (see Details). Default `TRUE`. With `FALSE`,
#'   the shares are used as given, so a value is lost or created where they
#'   sum below or above 1; the deviating combinations are still reported in a
#'   message.
#'
#' @return A tibble with columns `ags_col`, `year_col`, `value_cols`
#'   (converted), and `boundary_year` (= `target_year`, resolved to a year).
#'   If units were dropped, the attribute `"unmapped"` lists them (see Details).
#' @export
harmonize_regions <- function(
  data,
  crosswalk,
  ags_col,
  year_col,
  value_cols,
  type = c("absolute", "ratio"),
  weight = c("population", "area", "employment"),
  target_year,
  allow_backcast = FALSE,
  renormalize = TRUE
) {
  type <- match.arg(type)
  weight <- match.arg(weight)
  stopifnot(
    ags_col %in% names(data),
    year_col %in% names(data),
    all(value_cols %in% names(data))
  )

  if (weight == "employment") {
    # Before the plan, so a missing employment basis is not reported as a gap.
    years <- as.integer(data[[year_col]])
    target <- resolve_target_year(target_year, crosswalk)
    check_employment_available(
      crosswalk,
      min(years, target),
      max(years, target)
    )
  }

  plan <- plan_conversion(
    data[[ags_col]],
    data[[year_col]],
    crosswalk,
    target_year,
    allow_backcast
  )
  target_year_resolved <- plan$target_year
  report_dropped(plan$dropped)

  base <- tibble::tibble(..ags = plan$ags, ..year = plan$year)
  base <- dplyr::bind_cols(base, data[value_cols])

  crosswalk_forward <- crosswalk
  if (type == "absolute") {
    crosswalk_forward <- renormalize_forward_shares(
      crosswalk,
      paste0("share_", weight),
      min(base$..year),
      target_year_resolved,
      renormalize
    )
  }

  if (allow_backcast && any(base$..year > target_year_resolved)) {
    rlang::warn(paste(
      "Backcasting (disaggregation from a newer to an older boundary) is",
      "experimental and carries a higher estimation error than the forward",
      "conversion BBSR crosswalks are designed for."
    ))
  }

  groups <- split(base, base$..year)
  result <- purrr::map_dfr(groups, function(group) {
    start_year <- group$..year[[1]]
    harmonize_path(
      group,
      plan,
      # Only the forward shares are renormalized; a backcast uses them as given.
      if (start_year > target_year_resolved) crosswalk else crosswalk_forward,
      value_cols,
      type,
      weight
    )
  })

  result$boundary_year <- target_year_resolved
  col_names <- c(ags_col, year_col, value_cols, "boundary_year")
  names(result)[names(result) == "..ags"] <- ags_col
  names(result)[names(result) == "..year"] <- year_col
  result <- result[, col_names]
  if (nrow(plan$dropped) > 0) {
    attr(result, "unmapped") <- plan$dropped
  }
  result
}

harmonize_path <- function(
  group,
  plan,
  crosswalk,
  value_cols,
  type,
  weight
) {
  start_year <- group$..year[[1]]
  if (start_year == plan$target_year) {
    lost <- plan$dropped$ags[plan$dropped$year == start_year]
    return(group[!(group$..ags %in% lost), , drop = FALSE])
  }

  current <- group
  for (step in plan$steps[[as.character(start_year)]]) {
    current <- harmonize_step(
      current,
      step,
      crosswalk,
      value_cols,
      type,
      weight
    )
  }
  current
}

# Applies one step of the plan to `group`. The plan holds the structure (which
# unit maps to which, in the direction of the conversion); the shares and counts
# come from the rows `step$..row` of `crosswalk`, which may differ from the
# planned crosswalk in its shares only.
harmonize_step <- function(group, step, crosswalk, value_cols, type, weight) {
  share_col <- paste0("share_", weight)
  base_col <- switch(
    weight,
    area = "area_old",
    population = "population_old",
    employment = "employment_old"
  )

  rows <- crosswalk[step$..row, , drop = FALSE]
  stopifnot(
    identical(rows$ags_old, step$ags_old),
    identical(rows$ags_new, step$ags_new),
    identical(rows$year_from, step$year_from),
    identical(rows$year_to, step$year_to)
  )

  crosswalk_join <- tibble::tibble(
    ..ags = step$..from,
    ..ags_target = step$..to,
    ..share = rows[[share_col]],
    ..base = rows[[base_col]]
  )

  joined <- dplyr::inner_join(group, crosswalk_join, by = "..ags")

  if (type == "absolute") {
    result <- dplyr::group_by(joined, .data$..ags_target, .data$..year)
    result <- dplyr::summarise(
      result,
      dplyr::across(
        dplyr::all_of(value_cols),
        ~ sum_absolute(.x, .data$..share)
      ),
      .groups = "drop"
    )
  } else {
    joined$..weight <- joined$..share * joined$..base
    result <- dplyr::group_by(joined, .data$..ags_target, .data$..year)
    result <- dplyr::summarise(
      result,
      dplyr::across(
        dplyr::all_of(value_cols),
        ~ weighted_mean_or_na(.x, .data$..weight)
      ),
      .groups = "drop"
    )
  }

  dplyr::rename(result, ..ags = "..ags_target")
}

# Warns once about the area units of the plan whose values the conversion loses, and
# where to find the complete list.
report_dropped <- function(dropped) {
  if (nrow(dropped) == 0) {
    return(invisible())
  }
  rlang::warn(sprintf(
    paste(
      "%d area unit/year combination(s) have no matching crosswalk entry in a",
      "transition, so their values are lost at least in part (e.g. %s). Run",
      "check_regions() with the same arguments for a complete list; it is also",
      "in attr(<result>, \"unmapped\")."
    ),
    nrow(dropped),
    paste(
      describe_dropped(utils::head(dropped, MAX_FINDING_EXAMPLES)),
      collapse = "; "
    )
  ))
}

# BBSR only offers employment as a weight basis from 1997 onward; the earlier
# crosswalk rows have NA there. Fails early instead of returning NA/NaN values.
check_employment_available <- function(crosswalk, from_year, to_year) {
  needed <- crosswalk[
    crosswalk$year_from >= from_year & crosswalk$year_to <= to_year,
    ,
    drop = FALSE
  ]
  if (!anyNA(needed$share_employment)) {
    return(invisible())
  }
  usable <- crosswalk$year_from[!is.na(crosswalk$share_employment)]
  hint <- if (length(usable) > 0) {
    sprintf("is only available for transitions from %d onward", min(usable))
  } else {
    "is not available in this crosswalk"
  }
  rlang::abort(sprintf(
    paste(
      "weight = \"employment\" %s, but the conversion needs transitions",
      "from %d to %d. Use weight = \"population\" or \"area\", or restrict",
      "the data to later years."
    ),
    hint,
    from_year,
    to_year
  ))
}

# Sums value * share over the old units feeding one new unit. A missing value
# makes the result missing (a partial sum would understate the true total),
# unless its share is 0, in which case it contributes nothing anyway.
sum_absolute <- function(x, share) {
  if (any(is.na(x) & !(share %in% 0))) {
    return(NA_real_)
  }
  sum(x * share, na.rm = TRUE)
}

# Weighted mean over the old units with a value; missing only when no unit has
# one (stats::weighted.mean() would return NaN there).
weighted_mean_or_na <- function(x, w) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  stats::weighted.mean(x, w = w, na.rm = TRUE)
}

# Corrects `share_col` where classify_share_deviations() finds a group's shares
# off a sum of 1 (see there for the treatments; ADR 0001). Reports the
# renormalized groups once, as a warning, and the ones within the tolerance as
# a message, for the transitions that conversion from `from_year` to `to_year`
# passes through. With `renormalize = FALSE` the shares are used as given and
# only reported.
renormalize_forward_shares <- function(
  crosswalk,
  share_col,
  from_year,
  to_year,
  renormalize = TRUE
) {
  classified <- classify_share_deviations(
    crosswalk,
    sub("^share_", "", share_col)
  )
  off <- classified$treatment != "ok"
  if (!any(off)) {
    return(crosswalk)
  }
  in_window <- crosswalk$year_from >= from_year & crosswalk$year_to <= to_year
  sums <- classified$share_sum
  if (!renormalize) {
    report_share_deviations(
      crosswalk,
      share_col,
      off & in_window,
      sums,
      "were used as given (renormalize = FALSE)"
    )
    return(crosswalk)
  }
  report_share_deviations(
    crosswalk,
    share_col,
    classified$treatment == "renormalize" & in_window,
    sums,
    "do not sum to 1 (tolerance %s). They were renormalized so that no part of an absolute value is lost. The inconsistency is in the BBSR crosswalk, not in `data`",
    severity = "warning"
  )
  report_share_deviations(
    crosswalk,
    share_col,
    classified$treatment == "rounding" & in_window,
    sums,
    "deviate slightly from 1 (within the tolerance %s) and were renormalized to sum to 1",
    severity = "message"
  )
  crosswalk[[share_col]] <- classified$share
  crosswalk
}
