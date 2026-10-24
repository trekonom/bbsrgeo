# 2020-2024 municipal file: 32,924 ags_old/year_from combinations with area share sum 0

Status: needs-triage
Category: bug

Follow-up from issue 01 (municipal crosswalk reading, commit 1f98881). Found
by reading the cached municipal files and checking share sums; not
investigated beyond the observation below.

## Observation

`bbsr_crosswalk_read()` warns about 32,924 `ags_old`/`year_from` combinations whose area shares deviate from 1 by more than 1%, e.g. `ags_old = '01001000'`, `year_from = 2022`: sum = 0.000. The population share check finds only 1 (09671456, 2020, sum 3). Possibly the file has no area shares for later sheets, or the column is read wrongly.

## To establish

1. Which sheets have all-zero or missing area shares, and whether the xlsx column is empty there or mis-parsed (`bbsrgeo_read_sheet()`).
2. Whether this makes `weight = "area"` unusable for those years, and what `harmonize_regions()` does then.
3. Whether the warning should name the affected sheets instead of one example.

## Out of scope

Changing the share-sum warning wording; correcting the BBSR data itself.

## Comments
