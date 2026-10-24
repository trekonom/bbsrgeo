# One definition of the facts about a transition group

Status: done
Category: enhancement

From the architecture review of 2026-10-24 (candidate 1) and its grilling.
Behaviour-neutral refactor: no output of `harmonize_regions()` or of the
checks changes.

## Observation

Three functions each rebuild the same per-`ags_old`/`year_from`/`year_to` summary
and the same test for "the counts are parts" (counts all observed, non-negative,
differing between rows, positive total):

- `renormalize_forward_shares()` (`R/harmonize-regions.R`): `ave()` over a
  pasted key, per weight basis (`<weight>_old`), plus a separate "all observed"
  vector.
- `bbsrgeo_check_count_shares()` (`R/crosswalk-read.R`): `ave()` over a pasted
  key, per basis, missing count makes "differs" FALSE.
- `bbsrgeo_check_share_sums()` (`R/crosswalk-read.R`): `dplyr::group_by`, area
  shares only, "any of the three count columns differs".

`COUNT_DIFFERENCE_TOLERANCE` is used three times. The only difference between
the copies is how a missing count is treated; `renormalize_forward_shares()`
guards that separately, so one missing-safe definition gives the same results.

## Out of scope

Message wording, the findings/reporter and moving the checks to another file
(ticket 02). Extending the share-sum check beyond area shares. Anything about
`forward`/backcast or `level` (review candidates 2 and 5). Changing ADR 0001.

## Comments

## Agent Brief

**Category:** enhancement
**Summary:** Compute the facts about each transition group once, per weight basis, and let the two checks and `renormalize_forward_shares()` read from them.

**Current behavior:** see Observation.

**Desired behavior:**
- A new internal function in `R/crosswalk-groups.R` (suggested name `transition_group_facts()`) takes a crosswalk and one weight basis (`"area"`, `"population"`, `"employment"`) and returns one value per crosswalk row, for that row's group (`ags_old`, `year_from`, `year_to`): number of rows, sum of the basis's share column (missing shares ignored), total of the basis's count column (`<basis>_old`), whether all counts are observed, whether the counts differ between rows, whether all counts are non-negative.
- "Counts differ" is defined once: all counts observed and `diff(range(counts)) > COUNT_DIFFERENCE_TOLERANCE * max(abs(counts))`; a missing count makes it FALSE. `COUNT_DIFFERENCE_TOLERANCE` is used only there.
- `renormalize_forward_shares()` takes its group sums, count totals and the observed / differs / non-negative conditions from these facts (for the weight's basis, and for the area basis where it needs `area_sums`). Its three-case order, its warning and `renormalize = FALSE` behave as before.
- `bbsrgeo_check_count_shares()` takes its eligibility conditions (more than one row, counts observed, differing, non-negative, positive total, share sum within `SHARE_SUM_TOLERANCE`) from the facts of each basis.
- `bbsrgeo_check_share_sums()` takes its row counts, area share sum and "counts differ" (any count column that is present) from the facts; it keeps checking area shares only.
- A column absent from the crosswalk (e.g. no `employment_old`) still means "skip that basis" without an error.
- `GLOSSARY.md` gets the term **Transition group**: the rows of one old area unit in one transition (`ags_old`, `year_from`, `year_to`), whose shares and counts the checks and the renormalization compare. `_Avoid_: group, bucket`.

**Acceptance criteria:**
- [ ] Tests for the facts function on small constructed tibbles: two groups with different `year_to` are separate groups; a missing count makes "observed" and "differs" FALSE; equal counts do not differ; a negative count makes "non-negative" FALSE; share sum ignores a missing share; a missing count or share column does not error.
- [ ] No existing test changes (message tests, `harmonize_regions()` tests, real-file tests), and the full suite passes.
- [ ] `COUNT_DIFFERENCE_TOLERANCE` appears once in `R/`, in the facts function (and its definition in `R/utils.R`).
- [ ] `grep` for `stats::ave` and `paste(.*year_from` in `renormalize_forward_shares`, `bbsrgeo_check_count_shares` and `bbsrgeo_check_share_sums` finds no remaining hand-built group key.
- [ ] Grouping stays vectorised: the real files have up to ~150k groups, so no per-group loop (see `CLAUDE.md`); the real-file tests do not slow down noticeably (currently about 20 s for `test-crosswalk-read.R`).

**Out of scope:** see above.
