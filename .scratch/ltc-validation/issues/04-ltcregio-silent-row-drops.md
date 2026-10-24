# data-raw/ltcregio.R drops rows silently, no shape checks

Status: done
Category: enhancement

Found in review of commit b0e071a (`data-raw/ltcregio.R`).

The valid-AGS filter and the `inner_join` with `popregio` discard unmatched rows without notice; a missing `valid_ags_by_year` entry becomes NULL and `%in%` yields FALSE. The Berlin 399/400 problem was only caught by the test.

Fix: add `stopifnot()` checks on the final shape (400 districts x 8 biennial years, 2009-2023) and report dropped row counts.

## Triage notes

Verified by reading `data-raw/ltcregio.R`: the valid-AGS filter and the `inner_join` with `popregio` drop rows without notice, and there are no shape checks. No existing test or doc covers the build step (`test-validate-ltc.R` only checks harmonized output). Whether the current build dropped anything beyond Berlin cannot be told without the raw API data.

Correction to the proposed fix: "400 districts x 8 biennial years" is wrong. `ltcregio` is on each year's historical boundary. Bundled counts per year: 2009: 412, 2011/2013/2015: 402, 2017/2019: 401, 2021/2023: 400 (3,220 rows, no NA), identical to `popregio`'s district counts for those years.

Decision (maintainer): unexpected drops abort the build.

## Agent Brief (ready-for-human)

**Category:** enhancement
**Summary:** Make the `ltcregio` build script abort on unexpected row loss and assert the final table's shape.

**Why human:** running the script needs GENESIS-Regio credentials (`restatis::gen_auth_save()`, `GENESIS_KEY` in `.Renviron`) and regenerates the bundled `data/ltcregio.rda`. An agent can write the changes, but a human must run the script and review the diff of the regenerated data.

**Current behavior:**
The build script discards rows without notice in two places: the valid-AGS filter against the crosswalk (a year missing from the valid-AGS lookup yields `NULL`, so every row of that year is dropped) and the `inner_join` with `popregio`. There are no checks on the final table.

**Desired behavior:**
- After the valid-AGS filter and after the join with `popregio`, any dropped row aborts the script with a message listing the affected AGS and years. If an expected drop exists, it must be an explicit, commented allow-list in the script; the Berlin DLAND patch is applied before these steps and needs none.
- A missing lookup entry for any year present in the data aborts, instead of silently dropping that year.
- The final table is asserted to have: years exactly 2009 to 2023 in steps of 2; no NA values in any column; unique `ags`/`year` pairs; per-year district counts equal to the district counts of `popregio` in the same years (historical boundaries, 412/402/402/402/401/401/400/400 at the time of writing, not a flat 400).
- Comments in the script state that the counts are historical-boundary counts.

**Key interfaces:**
- The `ltcregio` build script (`data-raw/`): the only file that changes in logic.
- Bundled `ltcregio` must come out identical to the current one (same rows and values) unless the checks reveal a real problem; if they do, report it instead of patching around it.

**Acceptance criteria:**
- [ ] Script run end to end with credentials completes without aborting and reproduces the current `ltcregio` (compare with `all.equal` against the committed data).
- [ ] Temporarily removing a year from the valid-AGS lookup, or an AGS from `popregio`, makes the script abort with a message naming the AGS/year (check once manually, no test needed for a data-raw script).
- [ ] Shape assertions are present as listed above.

**Out of scope:**
- `data-raw/ltcinkar.R` input validation (issue 06) and the ltc test skip/exclusion handling (issue 05).
- Changing which years or districts `ltcregio` covers.
- Adding automated tests for `data-raw/` scripts.

## Resolution

`data-raw/ltcregio.R` now aborts, naming the AGS and years, on a year missing
from the valid-AGS lookup and on any row dropped by the valid-AGS filter or the
join with `popregio` (explicit `expected_drops` allow-list, empty), and asserts
the final shape (years 2009-2023 in steps of 2, no NA, unique `ags`/`year`,
per-year district counts equal to `popregio`'s). Verified offline only: the
post-fetch part of the script, run on a table rebuilt from the bundled
`ltcregio`, reproduces it exactly (`all.equal`) and aborts with the expected
message for a removed year, a removed `popregio` row and an unknown AGS. The
full build against GENESIS-Regio was not run (needs credentials): a human still
has to run it once; if it aborts on a genuine drop, add the row to
`expected_drops` with the reason.
