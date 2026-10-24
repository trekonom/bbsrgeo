# Municipal files: share sums of 2 to 11 for ...444 codes

Status: needs-triage
Category: bug

Follow-up from issue 01 (municipal crosswalk reading, commit 1f98881). Found
by reading the cached municipal files and checking share sums; not
investigated beyond the observation below.

## Observation

Population share sums per `ags_old`/`year_from` are far above 1 for a set of codes ending in 444, e.g. 12039430 1992 (2), 01060102 1996 (2), 09474444 1997 (3), 09377444 2016 (3), 09272444 2018 (11). 1990-2000 has 5 such combinations, 2010-2020 has 33, 2020-2024 has 1. Cause (maintainer, checked against the counts columns): these units have no population, so BBSR followed the convention of setting the undefined population share (0/0) to 1 for every target row instead of splitting it. Checked: 09671456 (Rohrbrunner Forst, 2020) has `population_old` = 0 and `employment_old` = 0 in all three rows, with `share_population` = `share_employment` = 1 each, while `share_area` splits 0.01 / 0.49 / 0.50. All 34 off-1 combinations in the 2010-2020 and 2020-2024 files have `population_old` == 0; the 1990-2000 file has 1 of its 5 with zero (09474444, a gemeindefreies Gebiet). The other four 1990-2000 cases (12039430, 12043470, 15321210, 01060102) have small non-zero `population_old` (0.2 to 1.3) per row with share 1 each, so the same convention is likely but not verified. ltc-validation 07's renormalization applies to these rows for `type = "absolute"` at the municipal level.

## To establish

1. (Answered above for the zero-population cases; check the four non-zero 1990-2000 cases.)
2. What `harmonize_regions(type = "absolute")` returns for them after renormalization compared with the source value.
3. Renormalization turns the undefined 1 / 1 / 1 into thirds, which is harmless for a count of 0 but (a) fires the share-sum warning, whose text blames the crosswalk, for a documented convention, and (b) would split another variable of such a unit evenly instead of by area. Decide: skip renormalization and the warning for source units whose weight basis (`population_old` / `employment_old` / `area_old`) is 0, and what to use as the split instead (area share?). That is a change to `renormalize_forward_shares()`, not to reading.

## Out of scope

Changing the share-sum warning wording; correcting the BBSR data itself.

## Comments
