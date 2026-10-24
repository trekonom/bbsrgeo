# Municipal files: share sums of 2 to 11 for ...444 codes

Status: needs-triage
Category: bug

Follow-up from issue 01 (municipal crosswalk reading, commit 1f98881). Found
by reading the cached municipal files and checking share sums; not
investigated beyond the observation below.

## Observation

Population share sums per `ags_old`/`year_from` are far above 1 for a set of codes ending in 444, e.g. 12039430 1992 (2), 01060102 1996 (2), 09474444 1997 (3), 09377444 2016 (3), 09272444 2018 (11). 1990-2000 has 5 such combinations, 2010-2020 has 33, 2020-2024 has 1. The cause is not examined (unverified whether duplicated rows or several targets each carrying a full share). ltc-validation 07's renormalization applies to these rows for `type = "absolute"` at the municipal level.

## To establish

1. What the rows look like for one affected `ags_old` (duplicates, or several targets).
2. What `harmonize_regions(type = "absolute")` returns for them after renormalization compared with the source value.
3. Whether renormalization is the right behavior here or the warning needs a different explanation.

## Out of scope

Changing the share-sum warning wording; correcting the BBSR data itself.

## Comments
