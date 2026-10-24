# A function that documents known crosswalk bugs and fixes them before conversion

Status: needs-triage
Category: enhancement

Raised by the maintainer after the miscoded district row (shares-from-counts
issue 02): as a general rule, known bugs in the BBSR files should be documented
in one place and fixed before the conversion, instead of being absorbed by
renormalization.

## Observation

Known source-data bugs so far (all in the downloads of 2026-10-24; each is an
observation from the issues named, not a fix):

- District 2011 -> 2012: a row with `name_old` Bernkastel-Wittlich is coded
  `ags_old` 07235000; it belongs to 07231000 (shares-from-counts issue 02).
- District 2014 and 2015: single-row groups of 07135000 and 07137000 repeat the
  2013 share values (0.962 / 0.038); cause not established (municipal issue 06).
- Municipal 1990-2000: four units (12039430, 12043470, 15321210, 01060102)
  with a share of 1 on every row; handled by the counts rule in
  `renormalize_forward_shares()` (municipal issues 05 and 06).

Today these are handled by renormalization (`renormalize = TRUE`), which keeps
totals but, for the miscoded row, passes 0.86 % of one district's value on to
the wrong unit. `data-raw/popregio.R` already documents and applies recodes for
the GENESIS-Regio series (Aachen, Hannover, Eisenach), but only in the dataset
build, not for crosswalks.

## To establish

1. Form: a table of fixes shipped with the package (like the URL table in
   `R/sysdata.rda`) with, per row, file/level, transition, the affected
   `ags_old`/`ags_new`, the replacement, and the evidence; and an exported
   function that applies it to a crosswalk and reports what it changed.
2. When it runs: inside `bbsr_crosswalk_read()` by default, or as a separate
   step the user calls before `harmonize_regions()`; and how a user switches it
   off.
3. Which known bugs qualify: only those with a verified correct value (the
   Bernkastel-Wittlich row: yes; the 2014 and 2015 district rows: cause not
   established, so probably not). Whether the counts-rule cases stay in
   `renormalize_forward_shares()`.
4. How a fix survives a changed upstream file: a fix should check that the
   row it targets is still as described and say so if not.
5. Whether this deserves an ADR (it changes converted numbers).

## Out of scope

Detecting new bugs (issue 01, shares-from-counts issue 02). Contacting BBSR;
see `ltc-validation` issue 08.

## Comments
