# Rows already at the target year bypass the unmapped-unit check

Status: needs-triage
Category: bug

Found while grilling the domain model (GLOSSARY.md).

## Observation

`harmonize_path()` returns rows with `start_year == target_year` unchanged, before any crosswalk lookup. An AGS in `data` that the crosswalk does not know is therefore dropped (with a warning) in earlier years, but kept silently in the target year.

## Intended behaviour

Every row should face the same unmapped-unit rule: an AGS with no crosswalk entry is dropped with a warning, never passed through. Decide what "has a crosswalk entry" means for target-year rows (e.g. present as `ags_new` in the last transition into the target year).

## To establish

1. Reproduce with a target-year row whose AGS is absent from the crosswalk.
2. Decide the lookup rule for target-year rows.
3. Check whether `check_regions()` already reports these.
