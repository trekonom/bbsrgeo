# 2020-2024 municipal file: AGS values parsed as NA from scientific notation

Status: needs-triage
Category: bug

Follow-up from issue 01 (municipal crosswalk reading, commit 1f98881). Found
by reading the cached municipal files and checking share sums; not
investigated beyond the observation below.

## Observation

Reading `ref-gemeinden-2020-2024.xlsx` warns that 2,464 AGS values could not be parsed as a number and were set to NA (e.g. '1,0041E+11'). The cell text is a number in German-locale scientific notation, so `normalize_ags()` (`R/utils.R`) cannot recover the 8-digit AGS. Rows with an NA AGS are dropped by `harmonize_regions()`'s inner join.

## To establish

1. Which cells and sheets have this form, and whether the original digits can be recovered (a rounded exponent form like 1,0041E+11 loses digits).
2. Whether the xlsx stores them as text or as numbers displayed that way.
3. Affected municipalities and years.

## Out of scope

Changing the share-sum warning wording; correcting the BBSR data itself.

## Comments
