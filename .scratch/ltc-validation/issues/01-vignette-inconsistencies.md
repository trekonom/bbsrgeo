# Vignette ratio section contradicts itself and the test

Status: needs-triage
Category: bug

Found in review of commit b0e071a (`vignettes/bbsrgeo.Rmd`, "A ratio example").

- Says the Rhein-Hunsrück residual of "~1.2-1.3%" is "smaller than the 1% cutoff"; 1.2% is larger.
- Says `test-validate-ltc.R` checks "every current district for 2009 and 2013"; the test loops over 2009, 2013 and 2023.
- `comparison_ltc` and `comparison_ltc_methods` are hand-typed `tribble()`s that are never executed, so they can drift from the data. `rel_diff_pct` is computed from values already rounded to 2 decimals.

Fix: compute the tables from the real objects (or at least unrounded values) and correct the prose.
