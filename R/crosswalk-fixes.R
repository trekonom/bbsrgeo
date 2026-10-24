# Documented corrections to the BBSR crosswalk files. One row per fix, applied
# by bbsr_crosswalk_fix() to the row that matches `year_from`, `year_to`,
# `ags_old`, `name_old` and `ags_new`: `column` is set to `value`. A fix is
# listed only with a verified correct value; `evidence` records what was
# observed, and in which download.
crosswalk_fixes <- tibble::tibble(
  year_from = 2011L,
  year_to = 2012L,
  ags_old = "07235000",
  name_old = "Bernkastel-Wittlich",
  ags_new = "07235000",
  column = "ags_old",
  value = "07231000",
  evidence = paste(
    "ref-kreise-1990-2024.xlsx (download of 2026-10-24), sheet 2011-2012: a",
    "row with name_old Bernkastel-Wittlich is coded ags_old 07235000",
    "(Trier-Saarburg). Bernkastel-Wittlich is 07231000, whose own row in the",
    "sheet sums to 0.991 (area_old 1168 against 1178 in 2010 -> 2011, a loss of",
    "10.1 km2 = the area_old of this row); with the recode both 07231000 and",
    "07235000 sum to 1 for area and population."
  )
)

#' Apply documented corrections to a BBSR crosswalk
#'
#' Corrects rows of a crosswalk read with [bbsr_crosswalk_read()] where the
#' BBSR file is known to be wrong and the correct value is verified. The
#' corrections change the data; `bbsr_crosswalk_read()` applies them by
#' default (`fix = TRUE`). Each fix is listed with its evidence in
#' `R/crosswalk-fixes.R`.
#'
#' A fix applies only when exactly one row matches its transition, codes and
#' name. If the crosswalk contains the fix's transition but no single matching
#' row (e.g. BBSR corrected the file), the fix is not applied and the message
#' says so.
#'
#' @param crosswalk A crosswalk tibble as returned by [bbsr_crosswalk_read()].
#' @return `crosswalk` with the fixes applied. A message names each fix that
#'   was applied or not applied.
#' @export
bbsr_crosswalk_fix <- function(crosswalk) {
  fixes <- crosswalk_fixes
  lines <- character()
  for (i in seq_len(nrow(fixes))) {
    fix <- fixes[i, ]
    in_transition <- crosswalk$year_from == fix$year_from &
      crosswalk$year_to == fix$year_to
    if (!any(in_transition)) {
      next
    }
    matches <- which(
      in_transition &
        crosswalk$ags_old == fix$ags_old &
        crosswalk$name_old == fix$name_old &
        crosswalk$ags_new == fix$ags_new
    )
    label <- sprintf(
      "%s '%s' -> '%s' (%d -> %d, %s)",
      fix$column,
      fix$ags_old,
      fix$value,
      fix$year_from,
      fix$year_to,
      fix$name_old
    )
    if (length(matches) == 1) {
      crosswalk[[fix$column]][matches] <- fix$value
      lines <- c(lines, paste0("Applied: ", label, ". ", fix$evidence))
    } else {
      lines <- c(
        lines,
        paste0(
          "not applied: ",
          label,
          " matches ",
          length(matches),
          " row(s); the file may have changed."
        )
      )
    }
  }
  if (length(lines) > 0) {
    rlang::inform(c(
      "Documented fixes to the BBSR crosswalk:",
      stats::setNames(lines, rep("*", length(lines)))
    ))
  }
  crosswalk
}
