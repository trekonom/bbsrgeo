# harmonize_regions(type = "absolute") collapses Mayen-Koblenz counts to ~0

Status: needs-triage
Category: bug

Found while re-running the ltc-validation check on harmonized output (issue 02 grilling). Not yet investigated beyond the observation below.

## Observation

Harmonizing `ltcregio` with `type = "absolute"` (`value_cols = c("pflegebeduerftige", "population_total")`, `weight = "population"`, `target_year = "current"`, `level = "districts"`, annual crosswalk) gives AGS 07137000 (Mayen-Koblenz) a harmonized `population_total` of about 0.03% of `popinkar` for 2009, 2011 and 2013 (ratio 0.000294), and 1.7% for 2015 (ratio 0.017151). All other districts match `popinkar` within about 0.4% for those years, apart from the Cochem-Zell (07135000) anomaly below.

The BBSR annual crosswalk has a known share-sum anomaly for 07135000 and 07137000, 2014->2015 and 2015->2016: `share_population` is 0.983 / 0.017 instead of 1.0 / 0.0 (see `tests/testthat/test-validate-ltc.R`, `bbsrgeo_check_share_sums()`, and the warning `harmonize_regions()` emits about 4 `ags_old`/`year_from` combinations). Likely mechanism (unverified): chaining multiplies the anomalous shares, so almost all of Mayen-Koblenz's absolute count is assigned elsewhere or dropped.

Cochem-Zell (07135000) is also off under `type = "absolute"`: harmonized population is 0.969 of `popinkar` for 2009-2013.

`type = "ratio"` is not visibly affected: rate deviation vs INKAR for 07137000 is below 0.14% in every year, because the weights are normalized.

## Why it matters

- `type = "absolute"` silently returns a wrong value (about 0.03% of the true count) for a whole district, with only a generic share-sum warning. The sum of absolute values across Germany is therefore also off.
- The popregio/popinkar validation (`tests/testthat/test-validate-inkar.R`) may hide this through its exclusion list; check before relying on it.

## To establish

1. Reproduce for `popregio` (`type = "absolute"`) and confirm which transition(s) in the chain lose the count.
2. Decide the intended behaviour: renormalize shares per `ags_old`/`year_from` when the sum deviates from 1, error or warn per affected district, or leave as is and document it.
3. Check whether `harmonize_regions_municipalities()` has the same exposure.

Related: issue 02 (test exclusion for the same districts), issue 05 (exclusion list scope).

## Comments

> *Reproduction was run ad hoc during the issue 02 grilling session; the script was not kept.*
