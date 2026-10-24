# The transitions a conversion passes through, and the Unmapped unit rule that
# goes with them (see "Unmapped unit" in GLOSSARY.md). harmonize_regions()
# applies a path to values; check_regions() applies it to the area units alone
# and reports what the conversion would drop, so the two cannot disagree.

# Aborts if a crosswalk read with bbsr_crosswalk_read() mixes levels
# ("districts" and "municipalities"): a district AGS is also a valid municipal
# one for a kreisfreie Stadt, so the units of the two cannot be told apart. A
# crosswalk without a `level` column is accepted.
check_single_level <- function(crosswalk) {
  levels <- unique(stats::na.omit(crosswalk[["level"]]))
  if (length(levels) > 1) {
    rlang::abort(sprintf(
      paste(
        "The crosswalk mixes levels (%s). Read the districts and the",
        "municipalities files separately."
      ),
      paste(levels, collapse = ", ")
    ))
  }
  invisible()
}

# `target_year` as a year: "current" is the latest `year_to` in the crosswalk.
resolve_target_year <- function(target_year, crosswalk) {
  if (identical(target_year, "current")) {
    max(crosswalk$year_to, na.rm = TRUE)
  } else {
    as.integer(target_year)
  }
}

# The crosswalk columns an old area unit is mapped from and to, in the forward
# direction `ags_old` -> `ags_new`; a backcast applies them the other way round.
step_columns <- function(forward) {
  if (forward) {
    list(from = "ags_old", to = "ags_new")
  } else {
    list(from = "ags_new", to = "ags_old")
  }
}

# The steps (a list of crosswalk subsets, one per transition) that take
# boundary year `start_year` to `target_year`, in order of application: the
# direct transition if the crosswalk has one, else the year-to-year transitions
# between them. A backcast must be allowed explicitly. Aborts if the crosswalk
# cannot cover the path.
conversion_steps <- function(
  crosswalk,
  start_year,
  target_year,
  allow_backcast
) {
  forward <- start_year < target_year

  if (!forward && !allow_backcast) {
    rlang::abort(sprintf(
      paste(
        "Year %d is after the target boundary year %d (this would be a",
        "backcast/disaggregation onto an older boundary). BBSR crosswalks",
        "are designed for forward conversion; backcasting is more",
        "error-prone. Enable explicitly with allow_backcast = TRUE."
      ),
      start_year,
      target_year
    ))
  }

  transition <- function(from, to) {
    crosswalk[
      crosswalk$year_from == from & crosswalk$year_to == to,
      ,
      drop = FALSE
    ]
  }

  direct <- if (forward) {
    transition(start_year, target_year)
  } else {
    transition(target_year, start_year)
  }
  if (nrow(direct) > 0) {
    return(list(direct))
  }

  hop_years <- if (forward) {
    seq(start_year, target_year - 1L)
  } else {
    seq(start_year - 1L, target_year, by = -1L)
  }

  lapply(hop_years, function(j) {
    # The crosswalk holds the transition j -> j + 1 in either direction.
    from <- j
    to <- j + 1L
    step <- transition(from, to)
    if (nrow(step) > 0) {
      return(step)
    }
    fixed_target <- unique(crosswalk$year_to)
    if (
      forward &&
        length(fixed_target) == 1L &&
        length(unique(crosswalk$year_from)) > 1L
    ) {
      # A "conversion_*" crosswalk converts straight to its fixed year and
      # cannot be chained, so the real problem is the requested target_year.
      rlang::abort(sprintf(
        paste(
          "The crosswalk converts directly to the boundary year %d, so",
          "target_year must be %d (or \"current\"), not %d."
        ),
        fixed_target,
        fixed_target,
        target_year
      ))
    }
    rlang::abort(sprintf(
      paste(
        "No crosswalk found for the %d -> %d transition.",
        "Chaining from %d to %d is not possible - the crosswalk provided",
        "does not cover this year step."
      ),
      from,
      to,
      start_year,
      target_year
    ))
  })
}

# The area units among `ags` that one step has no entry for.
unmapped_in_step <- function(ags, step_crosswalk, forward) {
  from_col <- step_columns(forward)$from
  setdiff(unique(ags), unique(step_crosswalk[[from_col]]))
}

# Rows already at the target year need no conversion, but face the same
# unmapped-unit rule: an AGS is mapped if it is an `ags_new` of a transition
# into `target_year`. Without any such transition nothing can be judged, so
# every unit counts as mapped.
unmapped_at_target_year <- function(ags, crosswalk, target_year) {
  into_target <- crosswalk$ags_new[crosswalk$year_to == target_year]
  if (length(into_target) == 0) {
    return(character())
  }
  unique(ags[!(ags %in% into_target)])
}

# The area units among `ags` (all in boundary year `start_year`) whose value the
# conversion to `target_year` would lose at least in part, and the first
# transition each is lost at: a tibble with `ags`, `year_from`, `year_to`
# (both equal to `target_year` for the target-year rule). Follows each unit
# through the steps of conversion_steps(), so one that maps at the first step
# but whose target has no entry at a later one is found as well.
find_unmapped_units <- function(
  ags,
  crosswalk,
  start_year,
  target_year,
  allow_backcast = FALSE
) {
  ags <- unique(ags)
  if (start_year == target_year) {
    return(tibble::tibble(
      ags = unmapped_at_target_year(ags, crosswalk, target_year),
      year_from = target_year,
      year_to = target_year
    ))
  }
  forward <- start_year < target_year
  steps <- conversion_steps(crosswalk, start_year, target_year, allow_backcast)
  cols <- step_columns(forward)

  lineage <- tibble::tibble(origin = ags, current = ags)
  lost <- list()
  for (step in steps) {
    mapped <- lineage$current %in% step[[cols$from]]
    if (any(!mapped)) {
      lost[[length(lost) + 1L]] <- tibble::tibble(
        ags = unique(lineage$origin[!mapped]),
        year_from = step$year_from[[1]],
        year_to = step$year_to[[1]]
      )
    }
    onward <- unique(tibble::tibble(
      current = step[[cols$from]],
      onward = step[[cols$to]]
    ))
    lineage <- dplyr::inner_join(
      lineage[mapped, , drop = FALSE],
      onward,
      by = "current",
      relationship = "many-to-many"
    )
    lineage <- unique(tibble::tibble(
      origin = lineage$origin,
      current = lineage$onward
    ))
  }
  lost <- dplyr::bind_rows(
    tibble::tibble(
      ags = character(),
      year_from = integer(),
      year_to = integer()
    ),
    lost
  )
  lost[!duplicated(lost$ags), , drop = FALSE]
}
