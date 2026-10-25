# Documented corrections to the BBSR crosswalk files, applied by
# apply_crosswalk_fixes() (via bbsr_crosswalk_fix()). One table row per column
# set or row dropped; the rows of one documented bug share an `id`.
#
# A table row selects crosswalk rows by `year_from`, `year_to`, `ags_old`,
# `name_old` and `ags_new`, and must match exactly `n_rows` of them. `action`
# "set" writes `value` (a string, coerced to the column's type) to `column` on
# every matched row; "drop" removes every matched row (`column` and `value` are
# NA). A fix is listed only with a verified correct value; `evidence` records
# what was observed, and in which download.
crosswalk_fixes <- tibble::tibble(
  id = c(
    "district-miscoded-bernkastel-wittlich-2011",
    rep("district-single-row-shares-2014-2015", 12)
  ),
  action = "set",
  year_from = c(2011L, rep(c(2014L, 2015L), each = 6)),
  year_to = c(2012L, rep(c(2015L, 2016L), each = 6)),
  ags_old = c("07235000", rep(rep(c("07135000", "07137000"), each = 3), 2)),
  name_old = c(
    "Bernkastel-Wittlich",
    rep(rep(c("Cochem-Zell", "Mayen-Koblenz"), each = 3), 2)
  ),
  ags_new = c("07235000", rep(rep(c("07135000", "07137000"), each = 3), 2)),
  column = c(
    "ags_old",
    rep(c("share_area", "share_population", "share_employment"), 4)
  ),
  value = c("07231000", rep("1", 12)),
  n_rows = 1L,
  evidence = c(
    paste(
      "ref-kreise-1990-2024.xlsx (download of 2026-10-24), sheet 2011-2012: a",
      "row with name_old Bernkastel-Wittlich is coded ags_old 07235000",
      "(Trier-Saarburg). Bernkastel-Wittlich is 07231000, whose own row in the",
      "sheet sums to 0.991 (area_old 1168 against 1178 in 2010 -> 2011, a loss",
      "of 10.1 km2 = the area_old of this row); with the recode both 07231000",
      "and 07235000 sum to 1 for area and population."
    ),
    rep(
      paste(
        "ref-kreise-1990-2024.xlsx (download of 2026-10-24), sheets 2014-2015",
        "and 2015-2016: 07135000 (Cochem-Zell) and 07137000 (Mayen-Koblenz)",
        "each have one row mapping to themselves, with the 2013 split",
        "(0.9617 / 0.0383 for area) repeated on all three share columns. Each",
        "is the only row of its group, so the share can only be 1; its",
        "area_old (692 and 817) is the unit's own total. Why BBSR repeats the",
        "2013 shares is not established."
      ),
      12
    )
  )
)

#' Apply documented corrections to a BBSR crosswalk
#'
#' Corrects rows of a crosswalk read with [bbsr_crosswalk_read()] where the
#' BBSR file is known to be wrong and the correct value is verified. The
#' corrections change the data; `bbsr_crosswalk_read()` applies them by
#' default (`fix = TRUE`). Each fix is listed with its evidence in
#' `R/crosswalk-fixes.R` (the `crosswalk_fixes` table, one row per cell set or
#' row dropped, rows of one documented bug sharing an `id`).
#'
#' Current fixes:
#'
#' * `district-miscoded-bernkastel-wittlich-2011`: district file, 2011 -> 2012,
#'   a row of Bernkastel-Wittlich coded `ags_old` 07235000 is recoded to
#'   07231000.
#' * `district-single-row-shares-2014-2015`: district file, 2014 -> 2015 and
#'   2015 -> 2016, the single self-mapping row of Cochem-Zell (07135000) and
#'   Mayen-Koblenz (07137000) gets all three shares set to 1.
#'
#' A fix has two kinds of action: "set" writes a value to a column of every
#' matched row, "drop" removes every matched row. A fix applies as a whole or
#' not at all: only if every one of its table rows matches exactly the number of
#' rows it expects. If the crosswalk contains a transition and codes of the fix
#' but the rows do not match (e.g. BBSR corrected the file), nothing of the fix
#' is applied and the message says so. A crosswalk without them (e.g. a
#' municipal file) is left alone, silently.
#'
#' @param crosswalk A crosswalk tibble as returned by [bbsr_crosswalk_read()].
#' @return `crosswalk` with the fixes applied. A message names each fix that
#'   was applied or not applied.
#' @export
bbsr_crosswalk_fix <- function(crosswalk) {
  apply_crosswalk_fixes(crosswalk, crosswalk_fixes)
}

# `fixes` is a table shaped like `crosswalk_fixes`; a parameter so that tests
# can pass a constructed one.
apply_crosswalk_fixes <- function(crosswalk, fixes) {
  stopifnot(all(fixes$action %in% c("set", "drop")))
  lines <- character()
  for (id in unique(fixes$id)) {
    rows <- fixes[fixes$id == id, ]
    # Relevant where the crosswalk has a transition and both codes of the fix
    # (also for a crosswalk without a level column): municipal files share the
    # transitions of the district file.
    in_transition <- lapply(seq_len(nrow(rows)), function(i) {
      fix <- rows[i, ]
      which(
        crosswalk$year_from == fix$year_from &
          crosswalk$year_to == fix$year_to &
          crosswalk$ags_old == fix$ags_old &
          crosswalk$ags_new == fix$ags_new
      )
    })
    if (all(lengths(in_transition) == 0)) {
      next
    }
    # Matched against the crosswalk as it is before any change of this fix.
    matched <- lapply(seq_len(nrow(rows)), function(i) {
      intersect(
        in_transition[[i]],
        which(crosswalk$name_old == rows$name_old[i])
      )
    })
    n_matched <- lengths(matched)
    if (any(n_matched != rows$n_rows)) {
      failing <- which(n_matched != rows$n_rows)
      lines <- c(
        lines,
        paste0(
          "not applied: ",
          id,
          "; ",
          paste0(
            "ags_old ",
            rows$ags_old[failing],
            " (",
            rows$year_from[failing],
            " -> ",
            rows$year_to[failing],
            if_else_column(rows$column[failing]),
            ") matched ",
            n_matched[failing],
            " row(s) instead of ",
            rows$n_rows[failing],
            collapse = ", "
          ),
          "; the file may have changed."
        )
      )
      next
    }
    for (i in which(rows$action == "set")) {
      column <- rows$column[i]
      crosswalk[[column]][matched[[i]]] <- as_column_type(
        rows$value[i],
        crosswalk[[column]]
      )
    }
    drop <- unlist(matched[rows$action == "drop"])
    changed <- length(unique(unlist(matched)))
    if (length(drop) > 0) {
      crosswalk <- crosswalk[-drop, ]
    }
    transitions <- unique(paste(rows$year_from, "->", rows$year_to))
    lines <- c(
      lines,
      paste0(
        "Applied: ",
        id,
        " (",
        paste(transitions, collapse = ", "),
        "), ",
        changed,
        " row(s) changed. Evidence: ?bbsr_crosswalk_fix."
      )
    )
  }
  if (length(lines) > 0) {
    rlang::inform(c(
      "Documented fixes to the BBSR crosswalk:",
      stats::setNames(lines, rep("*", length(lines)))
    ))
  }
  crosswalk
}

as_column_type <- function(value, column) {
  if (is.integer(column)) {
    as.integer(value)
  } else if (is.numeric(column)) {
    as.numeric(value)
  } else {
    value
  }
}

# " , column x" for a set, nothing for a drop.
if_else_column <- function(column) {
  ifelse(is.na(column), "", paste0(", ", column))
}
