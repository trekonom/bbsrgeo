# bbsr_crosswalk_read() aborts on the municipal annual file (sheet '1990-91')

Status: done
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

## Triage notes

Confirmed against the cached files: seven sheets in `ref-gemeinden-1990-2000.xlsx`
(`1990-91` to `1996-97`) use a two-digit end year. The other sheets in all five
municipal and district files match the existing patterns. No `1999-00` sheet
exists, but the rule handles it.

## Resolution

`bbsrgeo_sheet_years()` (`R/crosswalk-read.R`) now accepts `YYYY-YY` when the
two digits equal the year after the start year (modulo 100, so `1999-00`
works); anything else, e.g. `1990-93`, still aborts. Tests in
`tests/testthat/test-crosswalk-read.R`. All five municipal files read.

Question 3 (municipal share sums off 1, population share, tolerance 0.01):

| File | Off-1 `ags_old`/`year_from` |
| --- | --- |
| 1990-2000 | 5, e.g. 12039430 1992 (sum 2), 01060102 1996 (2), 09474444 1997 (3) |
| 2000-2010 | 0 by population share, but 10 by area share, including `ags_old = NA` |
| 2010-2020 | 33, e.g. 09377444 2016 (3), 09272444 2018 (11); mostly `...444` codes |
| 2020-2024 | 1 by population share (09671456 2020, sum 3), but 32,924 by area share, e.g. 01001000 2022 (sum 0) |

Not investigated, candidates for separate issues:
- Sums of 2-11 for `...444` codes: cause not examined (unverified whether
  duplicated rows or something else). Renormalization (ltc-validation 07)
  applies to them at the municipal level, so the effect should be checked.
- 2020-2024: 32,924 area-share combinations at sum 0 and 2,464 AGS values
  parsed as NA from scientific notation (e.g. `1,0041E+11`).
- `ags_old = NA` rows in the 2000-2010 file.

## Comments
