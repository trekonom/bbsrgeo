# Absolute conversion turns missing inputs into 0

Status: needs-triage
Category: bug

Found while grilling the domain model (GLOSSARY.md).

## Observation

`harmonize_step()` sums with `na.rm = TRUE`. A new unit whose contributing old values are all `NA` comes out as `0`, which is a false observation.

## Intended behaviour

A missing input stays missing: an all-`NA` result is `NA`. Partial `NA` (some contributors missing) should also give `NA`, since the sum would understate the true total. Applies per value column. Ratio variables (`weighted.mean`) should be checked for the same all-`NA` case (currently `NaN`).

## To establish

1. Reproduce with a merger where one contributing unit is `NA`.
2. Check the interaction with chaining (an `NA` in an early step must propagate, not become 0 and then a real-looking value).
