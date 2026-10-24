# Report shares that disagree with the counts, without changing the conversion

Status: needs-triage
Category: enhancement

Split off from issue 01 (decision: keep the shares, ADR 0001). Wrong shares
that sum to exactly 1 are neither corrected nor detected today.

## Observation

For multi-row groups whose counts differ between rows, `count / sum(count)`
agrees with the share within 0.011 in almost all cases (area: 244 of 248
groups; population outside 1990-2000: 136 of 136). The disagreements are the
four 1990-2000 share-of-1 groups (already handled by the off-1 rule) and the
1990-2000 population groups, mostly explained by counts rounded to one decimal
(issue 01 triage comment). So a disagreement check would today flag only known
cases; its value is catching new ones in future BBSR files.

## To establish

1. Where it reports: a pass in `bbsr_crosswalk_read()` next to the share-sum
   warning, a helper for users, or a test on the cached files only.
2. How to avoid reporting the rounded 1990-2000 population counts (a tolerance
   from the count rounding, as in `SHARE_SUM_TOLERANCE`, stated with its
   measured basis).
3. Whether groups with equal counts are skipped (they cannot be told from the
   unit's total repeated on each row; ADR 0001).

## Out of scope

Changing how `harmonize_regions()` converts (ADR 0001). Correcting the BBSR
data.

## Comments
