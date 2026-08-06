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
#' @param crosswalk A crosswalk read with [bbsr_crosswalk_read()], matching
#'   `level`.
#' @param ags_col Name of the AGS column in `data`.
#' @param year_col Name of the year column in `data`.
#' @param value_cols Character vector with the names of the value columns to
#'   convert.
#' @param type `"absolute"` or `"ratio"` (see Details).
#' @param weight Weighting basis: `"population"`, `"area"`, or
#'   `"employment"` (see the BBSR recommendations in `vignette("bbsrgeo")`).
#' @param target_year Target year of the boundary (e.g. `2024L`) or
#'   `"current"` for the most recent boundary available in the crosswalk.
#' @param level `"districts"` or `"municipalities"`.
#' @param allow_backcast Explicitly allow backcasting (disaggregation onto
#'   an older boundary). Default `FALSE`.
#'
#' @return A tibble with columns `ags_col`, `year_col`, `value_cols`
#'   (converted), and `boundary_year` (= `target_year`, resolved to a year).
#' @export
harmonize_regions <- function(data,
                               crosswalk,
                               ags_col,
                               year_col,
                               value_cols,
                               type = c("absolute", "ratio"),
                               weight = c("population", "area", "employment"),
                               target_year,
                               level = c("districts", "municipalities"),
                               allow_backcast = FALSE) {
  type <- match.arg(type)
  weight <- match.arg(weight)
  level <- match.arg(level)

  if (level == "districts") {
    harmonize_regions_districts(
      data, crosswalk, ags_col, year_col, value_cols,
      type, weight, target_year, allow_backcast
    )
  } else {
    harmonize_regions_municipalities(
      data, crosswalk, ags_col, year_col, value_cols,
      type, weight, target_year, allow_backcast
    )
  }
}

#' @rdname harmonize_regions
#' @export
harmonize_regions_districts <- function(data, crosswalk, ags_col, year_col,
                                         value_cols, type = c("absolute", "ratio"),
                                         weight = c("population", "area", "employment"),
                                         target_year, allow_backcast = FALSE) {
  type <- match.arg(type)
  weight <- match.arg(weight)
  harmonize_regions_impl(
    data, crosswalk, ags_col, year_col, value_cols,
    type, weight, target_year, allow_backcast
  )
}

#' @rdname harmonize_regions
#' @export
harmonize_regions_municipalities <- function(data, crosswalk, ags_col, year_col,
                                              value_cols, type = c("absolute", "ratio"),
                                              weight = c("population", "area", "employment"),
                                              target_year, allow_backcast = FALSE) {
  type <- match.arg(type)
  weight <- match.arg(weight)
  harmonize_regions_impl(
    data, crosswalk, ags_col, year_col, value_cols,
    type, weight, target_year, allow_backcast
  )
}

harmonize_regions_impl <- function(data, crosswalk, ags_col, year_col,
                                    value_cols, type, weight, target_year,
                                    allow_backcast) {
  stopifnot(
    ags_col %in% names(data),
    year_col %in% names(data),
    all(value_cols %in% names(data))
  )

  target_year_resolved <- if (identical(target_year, "current")) {
    max(crosswalk$year_to, na.rm = TRUE)
  } else {
    as.integer(target_year)
  }

  base <- tibble::tibble(
    ..ags = normalize_ags(data[[ags_col]]),
    ..year = as.integer(data[[year_col]])
  )
  base <- dplyr::bind_cols(base, data[value_cols])

  groups <- split(base, base$..year)
  result <- purrr::map_dfr(groups, function(group) {
    harmonize_path(
      group, crosswalk, value_cols, type, weight,
      group$..year[[1]], target_year_resolved, allow_backcast
    )
  })

  result$boundary_year <- target_year_resolved
  col_names <- c(ags_col, year_col, value_cols, "boundary_year")
  names(result)[names(result) == "..ags"] <- ags_col
  names(result)[names(result) == "..year"] <- year_col
  result[, col_names]
}

harmonize_path <- function(group, crosswalk, value_cols, type, weight,
                            start_year, target_year, allow_backcast) {
  if (start_year == target_year) {
    return(group)
  }

  forward <- start_year < target_year

  if (!forward) {
    if (!allow_backcast) {
      rlang::abort(sprintf(
        paste(
          "Year %d is after the target boundary year %d (this would be a",
          "backcast/disaggregation onto an older boundary). BBSR crosswalks",
          "are designed for forward conversion; backcasting is more",
          "error-prone. Enable explicitly with allow_backcast = TRUE."
        ),
        start_year, target_year
      ))
    }
    rlang::warn(paste(
      "Backcasting (disaggregation from a newer to an older boundary) is",
      "experimental and carries a higher estimation error than the forward",
      "conversion BBSR crosswalks are designed for."
    ))
  }

  direct <- crosswalk[
    crosswalk$year_from == (if (forward) start_year else target_year) &
      crosswalk$year_to == (if (forward) target_year else start_year),
    ,
    drop = FALSE
  ]

  if (nrow(direct) > 0) {
    return(harmonize_step(group, direct, value_cols, type, weight, forward))
  }

  hop_years <- if (forward) {
    seq(start_year, target_year - 1L)
  } else {
    seq(start_year - 1L, target_year, by = -1L)
  }

  current <- group
  for (j in hop_years) {
    from <- if (forward) j else j + 1L
    to <- if (forward) j + 1L else j
    step_crosswalk <- crosswalk[crosswalk$year_from == from & crosswalk$year_to == to, , drop = FALSE]
    if (nrow(step_crosswalk) == 0) {
      rlang::abort(sprintf(
        paste(
          "No crosswalk found for the %d -> %d transition.",
          "Chaining from %d to %d is not possible - the crosswalk provided",
          "does not cover this year step."
        ),
        from, to, start_year, target_year
      ))
    }
    current <- harmonize_step(current, step_crosswalk, value_cols, type, weight, forward)
  }
  current
}

harmonize_step <- function(group, step_crosswalk, value_cols, type, weight, forward) {
  share_col <- paste0("share_", weight)
  base_col <- switch(weight,
    area = "area_old",
    population = "population_old",
    employment = "employment_old"
  )

  if (forward) {
    from_col <- "ags_old"
    to_col <- "ags_new"
  } else {
    from_col <- "ags_new"
    to_col <- "ags_old"
  }

  crosswalk_join <- tibble::tibble(
    ..ags = step_crosswalk[[from_col]],
    ..ags_target = step_crosswalk[[to_col]],
    ..share = step_crosswalk[[share_col]],
    ..base = step_crosswalk[[base_col]]
  )

  joined <- dplyr::inner_join(group, crosswalk_join, by = "..ags")

  missing <- setdiff(unique(group$..ags), unique(joined$..ags))
  if (length(missing) > 0) {
    rlang::warn(sprintf(
      "%d AGS value(s) without a matching crosswalk entry for this transition were dropped: %s",
      length(missing), paste(utils::head(missing, 5), collapse = ", ")
    ))
  }

  if (type == "absolute") {
    for (v in value_cols) {
      joined[[v]] <- joined[[v]] * joined$..share
    }
    result <- dplyr::group_by(joined, .data$..ags_target, .data$..year)
    result <- dplyr::summarise(
      result,
      dplyr::across(dplyr::all_of(value_cols), ~ sum(.x, na.rm = TRUE)),
      .groups = "drop"
    )
  } else {
    joined$..weight <- joined$..share * joined$..base
    result <- dplyr::group_by(joined, .data$..ags_target, .data$..year)
    result <- dplyr::summarise(
      result,
      dplyr::across(
        dplyr::all_of(value_cols),
        ~ stats::weighted.mean(.x, w = .data$..weight, na.rm = TRUE)
      ),
      .groups = "drop"
    )
  }

  dplyr::rename(result, ..ags = "..ags_target")
}
