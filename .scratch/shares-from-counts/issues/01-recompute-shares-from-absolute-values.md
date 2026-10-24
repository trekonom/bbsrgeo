# Recompute shares from the absolute values instead of trusting the shares columns?

Status: needs-triage
Category: enhancement

Raised by the maintainer while triaging crosswalk-read-municipal issue 06
(commit badb752): the share anomalies found so far (1990-2000 units with a share
of 1 on every row, the district rows of 2014 and 2015, 09377444) suggest that
computing shares from `area_old` / `population_old` / `employment_old` is more
robust than reading `share_*`. Issue 05 rejected a full recomputation on
evidence from the 2020-2024 file; this issue reopens the question with all five
files measured. Not decided.

## Observation

Today `harmonize_regions()` uses the `share_*` columns as given. Only for an
`ags_old` / transition group whose shares sum off 1 does it use the counts
(parts when they differ between rows, positive total, see
`renormalize_forward_shares()` and issue 05), and otherwise renormalizes with a
warning.

For every multi-row group (more than one target row) in the five cached files
(downloads of 2026-10-24), the counts of the weight basis were compared with the
shares, with this rule: counts equal on all rows (rounded to 6 digits) are
"equal"; counts summing to 0 are "zero"; otherwise `count / sum(count)` is
compared with the share, and the group "agrees" when every row is within 0.011.

Area (`area_old` against `share_area`):

| File | agrees | disagrees | equal |
| --- | --- | --- | --- |
| municipal 1990-2000 | 75 | 4 | 6 |
| municipal 2000-2010 | 3 | 0 | 0 |
| municipal 2010-2020 | 38 | 0 | 1 |
| municipal 2020-2024 | 2 | 0 | 25 |
| districts 1990-2024 | 126 | 0 | 3 |

Population (`population_old` against `share_population`):

| File | agrees | disagrees | equal | zero |
| --- | --- | --- | --- | --- |
| municipal 1990-2000 | 33 | 41 | 10 | 1 |
| municipal 2000-2010 | 3 | 0 | 0 | 0 |
| municipal 2010-2020 | 6 | 0 | 0 | 33 |
| municipal 2020-2024 | 1 | 0 | 21 | 5 |
| districts 1990-2024 | 126 | 0 | 3 | 0 |

Single-row groups are not in these tables. For them `count / sum(count)` is
always 1, which is what the 2014 and 2015 district rows (07135000, 07137000)
and any other single-row group with a share below 1 would get.

## What this suggests, and what it does not

- Where the counts differ between rows they almost always agree with the shares
  (area: 244 of 248 groups; population apart from 1990-2000: 136 of 136). The
  disagreements are the four 1990-2000 area cases from issue 06 and 41
  1990-2000 population groups. Issue 05 noted that the 1990-2000 population
  counts look rounded to one decimal (unit not verified); that would explain
  the 41, but this was not checked here.
- Where the area counts are equal on all rows (35 groups in total, 25 of them
  in 2020-2024) the file does not say whether they are equal parts or the unit's
  total repeated on each row. Recomputing gives an equal split in both readings,
  which is wrong in the second. Issue 05 found the second reading for 25 of 27
  split groups in the 2020-2024 file; that count matches the 25 "equal" area
  groups above.
- So recomputation would fix the cases found so far, but it cannot fix the
  ambiguous "equal" groups, and for the rounded 1990-2000 population counts it
  would be less precise than the shares.

## To establish

1. What the maintainer wants: always recompute from counts, recompute only where the counts qualify as parts (differ between rows), or keep the shares and only fix known-bad groups. The second is the current off-1 rule widened from "groups that sum off 1" to "all groups".
2. For the 41 population disagreements in 1990-2000: whether the rounding of the counts explains them, and the unit of the counts.
3. Whether the target units' own areas (the `area_old` of `ags_new` in the following sheet) can resolve the "equal" groups; not explored.
4. The effect on the validation tests: `popregio` against `popinkar` and `ltcregio` against `ltcinkar` (`test-validate-inkar.R`, `test-validate-ltc.R`) under each option, using the existing tolerances.
5. Whether the answer is a hard-to-reverse decision worth an ADR (it changes every converted number at the municipal level).

## Out of scope

Correcting or recoding the BBSR data itself. The wording of the share-sum warning (municipal issue 06).

## Comments
