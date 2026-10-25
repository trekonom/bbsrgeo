# The Conversion plan (see GLOSSARY.md): the transitions a conversion passes
# through, and the Unmapped unit rule that goes with them. harmonize_regions()
# applies the plan to values; check_regions() reads what it would drop, so the
# two cannot disagree.

# Aborts if `crosswalk` lacks a column the conversion needs, naming all of
# them, or mixes levels ("districts" and "municipalities", as read with
# bbsr_crosswalk_read()): a district AGS is also a valid municipal one for a
# kreisfreie Stadt, so the units of the two cannot be told apart. A crosswalk
# without a `level` column is accepted. The columns are the four of the
# transitions; with a `weight` also its `share_<weight>`, and for a ratio
# `type` its `<weight>_old` count, which weights the mean.
check_crosswalk <- function(crosswalk, weight = NULL, type = NULL) {
  required <- c("ags_old", "ags_new", "year_from", "year_to")
  if (!is.null(weight)) {
    required <- c(required, paste0("share_", weight))
    if (identical(type, "ratio")) {
      required <- c(required, paste0(weight, "_old"))
    }
  }
  missing <- setdiff(required, names(crosswalk))
  if (length(missing) > 0) {
    rlang::abort(sprintf(
      "The crosswalk lacks the column(s) %s. Read it with bbsr_crosswalk_read().",
      paste0("`", missing, "`", collapse = ", ")
    ))
  }
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

# Plans the conversion of a panel to `target_year`: normalizes the inputs
# shared by harmonize_regions() and check_regions() and follows every area unit
# through the transitions of its year. Holds structure only, no values or
# shares. Returns a list with
# - ags, year: the normalized area units and integer years of the panel
# - target_year: `target_year` resolved to a year
# - steps: per year of the panel (named by year), the transitions to apply in
#   order; each is a crosswalk subset with its row number in `..row` and the
#   units it maps from and to, in the direction of the conversion, in `..from`
#   and `..to`. Empty for the target year.
# - dropped: the area units (per year) the conversion loses at least in part,
#   and the first transition each is lost at: a tibble with `ags`, `year`,
#   `year_from`, `year_to` (both equal to `target_year` for the target-year
#   rule).
# Aborts on an invalid crosswalk (see check_crosswalk()), a backcast without
# `allow_backcast` and a path the crosswalk cannot cover.
plan_conversion <- function(
  ags,
  year,
  crosswalk,
  target_year,
  allow_backcast = FALSE
) {
  check_crosswalk(crosswalk)
  target_year <- resolve_target_year(target_year, crosswalk)
  ags <- normalize_ags(ags)
  year <- as.integer(year)

  crosswalk$..row <- seq_len(nrow(crosswalk))
  years <- sort(unique(year))
  steps <- lapply(years, function(y) {
    if (y == target_year) {
      return(list())
    }
    cols <- step_columns(y < target_year)
    lapply(
      conversion_steps(crosswalk, y, target_year, allow_backcast),
      function(step) {
        # The units a step maps from and to, in the direction of the conversion.
        step$..from <- step[[cols$from]]
        step$..to <- step[[cols$to]]
        step
      }
    )
  })
  names(steps) <- years

  dropped <- lapply(years, function(y) {
    found <- find_lost_units(
      unique(ags[year %in% y]),
      steps[[as.character(y)]],
      crosswalk,
      y,
      target_year
    )
    found$year <- rep(y, nrow(found))
    found
  })
  dropped <- dplyr::bind_rows(
    tibble::tibble(
      ags = character(),
      year_from = integer(),
      year_to = integer(),
      year = integer()
    ),
    dropped
  )

  list(
    ags = ags,
    year = year,
    target_year = target_year,
    steps = steps,
    dropped = dropped[, c("ags", "year", "year_from", "year_to")]
  )
}

# The area units among `ags` (all in boundary year `start_year`) that `steps`
# would lose at least in part, and the first transition each is lost at.
# Follows each unit through the steps, so one that maps at the first step but
# whose target has no entry at a later one is found as well.
find_lost_units <- function(ags, steps, crosswalk, start_year, target_year) {
  if (start_year == target_year) {
    return(tibble::tibble(
      ags = unmapped_at_target_year(ags, crosswalk, target_year),
      year_from = target_year,
      year_to = target_year
    ))
  }
  lineage <- tibble::tibble(origin = ags, current = ags)
  lost <- list()
  for (step in steps) {
    mapped <- lineage$current %in% step$..from
    if (any(!mapped)) {
      lost[[length(lost) + 1L]] <- tibble::tibble(
        ags = unique(lineage$origin[!mapped]),
        year_from = step$year_from[[1]],
        year_to = step$year_to[[1]]
      )
    }
    onward <- unique(tibble::tibble(
      current = step$..from,
      onward = step$..to
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

# The rows of `plan$dropped` as "<ags> in <year>: <where>", for messages.
describe_dropped <- function(dropped) {
  where <- ifelse(
    dropped$year_from == dropped$year_to,
    "not an ags_new of any transition into the target year",
    sprintf(
      "no entry in the %d -> %d transition",
      dropped$year_from,
      dropped$year_to
    )
  )
  sprintf("%s in %d: %s", dropped$ags, dropped$year, where)
}
