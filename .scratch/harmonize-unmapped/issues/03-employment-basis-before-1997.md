# weight = "employment" with source years before 1997 fails silently

Status: done
Category: bug

Found while grilling the domain model (GLOSSARY.md).

## Observation

`share_employment` and `employment_old` are `NA` before 1997. With `weight = "employment"` and data from earlier years, absolute values become `NA` and ratios `NaN`, with no explanation.

## Intended behaviour

Hard error in `harmonize_regions()`, before conversion, naming the first year the employment weight basis is available, when `weight = "employment"` and any needed transition lacks it.

## To establish

1. Decide how "needed transition" is computed (data years vs. target year, annual vs. conversion crosswalk).
2. Document the 1997 limit in the `weight` argument docs.
