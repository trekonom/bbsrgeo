# bbsr_crosswalk_read() aborts on the municipal annual file (sheet '1990-91')

Status: needs-triage
Category: bug

Found while closing ltc-validation issue 07: the municipal-level share sums
could not be checked because the municipal annual crosswalk cannot be read.

## Observation

`bbsr_crosswalk_read()` on the municipal annual file `ref-gemeinden-1990-2000.xlsx`
aborts with:

> Unexpected sheet name '1990-91' in an 'annual' file (ref-gemeinden-1990-2000.xlsx) - expected 'YYYY-YYYY' or 'YYYY'.

`bbsrgeo_sheet_years()` (`R/crosswalk-read.R`) accepts only `YYYY-YYYY` and
`YYYY` for annual files. This file names at least one sheet with a two-digit
end year. Not yet checked: which other sheets in this file, or in the other
municipal files, deviate from the pattern.

## Why it matters

- The municipal level of `harmonize_regions()` cannot be used with the 1990-2000
  annual crosswalk.
- ltc-validation issue 07 added share renormalization for
  `type = "absolute"`, which also applies to municipalities, but no one could
  check whether any municipal transitions have share sums off 1
  (`SHARE_SUM_TOLERANCE`).

## To establish

1. List all sheet names in every municipal xlsx in the static URL table and
   which ones `bbsrgeo_sheet_years()` rejects.
2. Decide the parse rule for two-digit end years (e.g. `1990-91` -> 1990/1991),
   including the century rollover if a sheet like `1999-00` exists.
3. Once readable, report whether any municipal transitions have share sums
   deviating from 1 by more than `SHARE_SUM_TOLERANCE`.

## Out of scope

Changing how `bbsr_crosswalk_read()` warns about share sums; correcting the
crosswalk data.

## Comments
