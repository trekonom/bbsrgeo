# Use the crosswalk's shares; counts only for groups that sum off 1

Status: accepted (2026-10-24)

## Decision

`harmonize_regions()` converts with the `share_*` columns of the BBSR crosswalk
as given. The absolute counts (`area_old`, `population_old`, `employment_old`)
are used only for an `ags_old`/transition group whose shares sum off 1 by more
than `SHARE_SUM_TOLERANCE`, in the order set out in
`renormalize_forward_shares()`: area split for a zero basis, counts as parts
when they differ between rows, otherwise renormalization with a warning. Shares
are not recomputed from the counts for groups that sum to 1. Every group that
does not sum to 1 is rescaled by default (sums within the tolerance only with a
message); `renormalize = FALSE` uses the shares as given.

## Why

Measured on the five cached files (downloads of 2026-10-24); details in
`.scratch/shares-from-counts/issues/01-recompute-shares-from-absolute-values.md`
and `.scratch/crosswalk-read-municipal/issues/05-municipal-444-share-sums-above-one.md`:

- Where counts differ between rows they agree with the shares (area: 244 of 248
  groups; population outside 1990-2000: 136 of 136), so recomputing changes
  nothing there.
- The 1990-2000 population counts are rounded to one decimal, so recomputing
  from them is less precise than the shares (91 % of the deviating rows are
  within the rounding bound).
- Where counts are equal on every row (35 groups, 25 in 2020-2024) they are in
  most cases the unit's total repeated on each row, so recomputing gives an
  equal split, which is wrong. The targets' own areas in the following sheet do
  not give the part either.

## Consequences

- Wrong shares that sum to exactly 1 are not corrected or detected by the
  conversion. A diagnostic that reports disagreements between shares and counts
  is a separate issue (`.scratch/shares-from-counts/issues/02-*`).
- Changing this changes every converted municipal number; revisit only with new
  evidence, e.g. a corrected BBSR file or the method documentation.
