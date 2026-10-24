# Municipal files: share sums of 2 to 11 for ...444 codes

Status: done
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

## Resolution

Cause of the zero-population cases (maintainer's observation, confirmed in the
counts columns): units without population have `population_old` = 0 and a
share of 1 on every target row. That the shares of these units are a BBSR
convention for an undefined share was a guess and is not claimed in the docs.

Recomputing all shares from the counts was rejected after checking the five
crosswalk files (four municipal, one district), split groups only: in 25 of 27 split groups of the 2020-2024
municipal file (and some 2010-2020 groups) `area_old`/`population_old` is the
unit's total repeated on each row, so part sizes are not in the file; where
counts are parts, the shares already equal count / total; the 1990-2000
population counts look rounded to one decimal (unit not verified), so they are
less precise than the shares. Counts are used only for off-1 groups, and only when they are all observed, non-negative, differ between rows and have a positive total; equal counts are not read as parts, since they cannot be told from the unit's total repeated on every row (those groups are renormalized with a warning). The rule also applies to `area_old` and `employment_old` for the matching weight; this is untested on real data beyond the cases above.

`renormalize_forward_shares()` (`R/harmonize-regions.R`), `type = "absolute"`,
for a group whose shares sum off 1 and which has a `<weight>_old` column:
1. Basis observed and 0 on every row: split by area share, no warning (not
   for `weight = "area"`).
2. Basis observed on every row, differing between rows, positive total: the
   counts are the parts; shares become count / total, no warning. This covers
   the four 1990-2000 cases (01060102, 12039430, 12043470, 15321210), e.g.
   12039430 goes from 1 / 1 to 0.304 / 0.696.
3. Otherwise renormalized to sum to 1 with a warning, as in ltc-validation 07.
An all-NA basis is not a zero basis; a missing `*_old` column skips 1 and 2.
Documented in the roxygen of `harmonize_regions()`.

Real municipal files, `renormalize_forward_shares(share_population)`: no
warning for any of the four municipal files (before: 5, 0, 33 and 1 combinations). The
district crosswalk still warns for 07135000/07137000 (single-row groups).

## Comments
