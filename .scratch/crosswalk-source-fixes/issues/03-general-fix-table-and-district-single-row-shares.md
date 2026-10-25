# Make the source-data fix table general and add the 2014/2015 district single-row shares

Status: ready-for-agent
Category: enhancement

Raised by the maintainer: more **Source-data fixes** (see `GLOSSARY.md`) are to
be added to `crosswalk_fixes` one by one, so the table needs a general form.
Today a row can only set one cell on one uniquely matched row, and the
message prints one line per table row. Follows issue 02.

## Observation

District file (`ref-kreise-1990-2024.xlsx`, download of 2026-10-24): the
sheets 2014 -> 2015 and 2015 -> 2016 hold one self-mapping row each for
07135000 (Cochem-Zell) and 07137000 (Mayen-Koblenz), with the 2013 split
repeated on all three share columns:

| ags_old | share_area | share_population | share_employment |
| --- | --- | --- | --- |
| 07135000 | 0.96166294 | 0.98284864 | 0.996122263 |
| 07137000 | 0.03833706 | 0.01715136 | 0.003877737 |

Each is the only row of its group (`area_old` 692 and 817, the unit's own
totals), so the share can only be 1. Why BBSR repeats the 2013 values is not
established (municipal issue 06). `harmonize_regions()` already rescales both
groups to 1 (ADR 0001), so converted values do not change; the read-time
share-sum warning names these as pattern (b) and the conversion reports them
as renormalized.

## Decisions (maintainer, from the grilling session)

- Kinds of fix: set a cell (any column) and drop a row. Adding rows is out of
  scope (it would invent shares).
- Inclusion bar unchanged: a verified correct value, with evidence. For this
  fix the evidence is the single-row group (the share can only be 1); the
  evidence string says the cause is not established.
- One table, `crosswalk_fixes`, with an `action` column (`"set"` or `"drop"`;
  `column` and `value` are `NA` for a drop), the fixed key `year_from`,
  `year_to`, `ags_old`, `name_old`, `ags_new`, an `n_rows` column (rows the
  fix must match, default 1) and an `id` column (one `id` per documented bug).
- "set" writes `value` to every matched row; "drop" removes every matched row.
  Dropping one of two identical rows is not expressible and stays out.
- A fix is all-or-nothing: it applies only if every one of its table rows
  matches exactly `n_rows` rows; otherwise none of it is applied and the
  message says so. One message line per `id`.
- One table row per column set: the 2014/2015 fix is 12 rows (2 units x 2
  transitions x 3 share columns) under one `id`.
- Documentation: the roxygen "Current fixes" list gives one short line per
  `id` and points to `crosswalk_fixes`; the evidence lives only in the table.
- No ADR: easy to reverse, recorded here and in the table.

## Agent Brief

**Category:** enhancement
**Summary:** Generalise `crosswalk_fixes` / `bbsr_crosswalk_fix()` to the table shape above, then add the Cochem-Zell / Mayen-Koblenz single-row share fix as its second entry.

**Current behavior:**
`crosswalk_fixes` has columns `year_from`, `year_to`, `ags_old`, `name_old`, `ags_new`, `column`, `value`, `evidence` and one row. `bbsr_crosswalk_fix()` sets `column` to `value` on the single matching row, one message line per table row, a table row not matching exactly one row is "not applied".

**Desired behavior:**
- New columns `id`, `action`, `n_rows`; the existing row gets `action = "set"`, `n_rows = 1` and its own `id`. `evidence` is per `id` (repeated or identical on the rows of one id).
- `bbsr_crosswalk_fix()` handles an `id` as a unit: relevant when the crosswalk contains the transition and both codes of its rows (as today, per row; an id is relevant if any of its rows is). Applied only if every row of the id matches exactly its `n_rows`; otherwise nothing of the id is applied and the message line says "not applied", names the id and how many rows each failing table row matched. An id with no relevant row is silent (municipal files).
- "set" writes `value` to `column` on all matched rows (coerced to the column's type); "drop" removes the matched rows. Rows of different table rows are matched against the crosswalk as it is before the id's changes, so one fix's rows cannot depend on each other's order.
- One message line per id, applied or not applied, as today's header and bullet format; applied lines name the id, the transition(s) and the number of rows changed, and point to `?bbsr_crosswalk_fix`.
- New fix, id e.g. `district-single-row-shares-2014-2015`: for `year_from` 2014 and 2015 (`year_to` 2015 and 2016), `ags_old = ags_new` 07135000 (Cochem-Zell) and 07137000 (Mayen-Koblenz), set `share_area`, `share_population` and `share_employment` to 1. `evidence`: single-row group so the share can only be 1; the 2013 split repeated; area_old equals the unit's own total; cause not established; download of 2026-10-24.
- Roxygen of `bbsr_crosswalk_fix()`: replace the "Current fixes" bullets with one short line per id, pointing to `crosswalk_fixes` for the evidence; describe the all-or-nothing rule and the two actions.
- `GLOSSARY.md` **Source-data fix** already exists; keep the code's wording consistent with it.

**Acceptance criteria:**
- [ ] Tests on small constructed tibbles (`test-crosswalk-fix.R`, a constructed fix table passed in or the internal table swapped, whichever the existing tests use): a "set" fix on one row; a "set" fix with `n_rows = 2` on two rows; a "drop" fix removes exactly the matched rows and leaves the others; a multi-row id applies all its rows; one of its rows matching 0 or 2 rows (vs `n_rows`) leaves the whole id unapplied with a "not applied" line naming the id; an id whose transition is absent is silent; one message line per id; `fix = FALSE` unchanged.
- [ ] The existing Bernkastel-Wittlich tests and the real-file test still pass with unchanged results (07231000 and 07235000 sum to 1 in 2011 -> 2012).
- [ ] Real-file test (network-guarded) on the district file: after the default read, the four rows (07135000 and 07137000, 2014 -> 2015 and 2015 -> 2016) have all three share columns equal to 1; exactly two fix messages (Bernkastel-Wittlich and the new id); the share-sum warning no longer names pattern (b); municipal files read with no fix message. With `fix = FALSE` the rows are as published.
- [ ] `harmonize_regions()` on the district crosswalk gives the same converted values as before for these units (constructed data), and no renormalization message for them.
- [ ] Update the expectations that name the district file's remaining share-sum warnings (municipal issue 06's real-file test and the README sample output) to match; re-render `README.md` with `dev/render-readme.R` in its own commit.
- [ ] `ltc-validation/02-reproduce-cochem-zell-residual`: note under its Comments whether its residual changes with the fix (the unit is the same). Do not change that issue's status.
- [ ] `Rscript dev/document.R`, the full test suite and `dev/format.sh --check` pass.

**Out of scope:**
- Adding rows, and dropping one of two identical rows.
- Any fix without a verified correct value (the 1990-2000 municipal units stay on the counts rule).
- Explaining why BBSR repeats the 2013 shares; contacting BBSR (`ltc-validation` issue 08).
- Exporting the fix table as a function.
