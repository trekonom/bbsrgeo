# 2000-2010 municipal file: rows with ags_old = NA

Status: needs-triage
Category: bug

Follow-up from issue 01 (municipal crosswalk reading, commit 1f98881). Found
by reading the cached municipal files and checking share sums; not
investigated beyond the observation below.

## Observation

Reading `ref-gemeinden-2000-2010.xlsx` reports 10 `ags_old`/`year_from` combinations off 1 by area share, including `ags_old = 'NA'`, `year_from = 2000` (sum 0). Likely header, footer or note rows read as data.

## To establish

1. Which sheets and rows have an NA `ags_old`; whether they are non-data rows that `bbsr_crosswalk_read()` should drop.
2. Whether any real municipality is lost by dropping them.

## Out of scope

Changing the share-sum warning wording; correcting the BBSR data itself.

## Comments
