# Checks return findings; one reporter signals them

Status: done
Category: enhancement
Blocked by: 01

From the architecture review of 2026-10-24 (candidates 3 and 4) and its
grilling. Behaviour-neutral refactor: message texts stay as they are wherever a
test matches them.

## Observation

Four places format the same message shape by hand ("N group(s) ..., e.g. ...",
a header, a closing hint) and differ in small ways:

- `bbsrgeo_check_names()` (`R/crosswalk-read.R`): `rlang::warn()`, up to 5
  examples per side.
- `bbsrgeo_check_share_sums()` (`R/crosswalk-read.R`): `rlang::warn()`, one
  example per pattern.
- `bbsrgeo_check_count_shares()` (`R/crosswalk-read.R`): `rlang::inform()`, up
  to 5 examples per basis.
- `report_share_deviations()` (`R/harmonize-regions.R`): one sentence, signalled
  as warning (beyond `SHARE_SUM_TOLERANCE`), message (within it) or message
  (`renormalize = FALSE`).

`R/crosswalk-read.R` (about 480 lines) also mixes the xlsx parsing with the
three checks, which change for unrelated reasons.

## Out of scope

The group facts (ticket 01). Any change to which cases are reported or to
`harmonize_regions()` output. Review candidates 2 and 5.

## Comments

## Agent Brief

**Category:** enhancement
**Summary:** The three read-time checks return findings as data, one reporter turns findings into the warning or message, `report_share_deviations()` uses the same reporter, and the checks move to their own file.

**Current behavior:** see Observation.

**Desired behavior:**
- A finding is data: a header string, a list of items (each a label, a group count and a character vector of example strings the check formatted), a closing hint, and a severity (`"warning"` or `"message"`). A check returns `NULL` when it finds nothing.
- One internal reporter in `R/utils.R` takes a finding and signals it: the header, one bullet per item (`<n> <label>, e.g. <examples>` in the current wording), the closing hint, via `rlang::warn()` or `rlang::inform()` according to the severity. It does not cap or reformat the examples.
- `bbsrgeo_check_names()` (severity warning), `bbsrgeo_check_share_sums()` (warning) and `bbsrgeo_check_count_shares()` (message) return findings. `bbsr_crosswalk_read()` calls them in the current order (fix, names, share sums, counts) and passes each non-`NULL` finding to the reporter, one signal per check.
- `report_share_deviations()` builds a finding with one item (severity: warning beyond the tolerance, message within it and for `renormalize = FALSE`) and uses the same reporter.
- The three checks move to `R/crosswalk-checks.R`; `R/crosswalk-read.R` keeps only the xlsx parsing and `bbsr_crosswalk_read()`.
- The checks read their group facts from ticket 01's function.

**Acceptance criteria:**
- [ ] Reporter tests on constructed findings: a warning finding warns once, a message finding informs once, `NULL` signals nothing, items appear in order with count and examples, the hint is last.
- [ ] Check tests on constructed tibbles assert the returned findings (labels, counts, examples), replacing the existing `expect_warning`/`expect_message` regex tests for the checks, which are not kept alongside.
- [ ] The existing message-content tests of `harmonize_regions()` (`test-harmonize-regions.R`: "deviate slightly from 1", "used as given", `07231000 (2011 -> 2012, sum 0.9900)` style matches) and the real-file tests in `test-crosswalk-read.R` pass unchanged. Those still see exactly one warning for the 1990 municipal and the district file, and none for the other municipal files.
- [ ] `harmonize_regions()` output is unchanged and the full suite passes.
- [ ] `R/crosswalk-read.R` contains no check; `R/crosswalk-checks.R` contains the three; `CLAUDE.md` mentions the checks file next to `bbsr_crosswalk_read()` if its description of the reader changes.

**Out of scope:** see above.
