# Reproduce the Cochem-Zell to Rhein-Hunsrück residual; tighten ltc test tolerances

Status: needs-triage
Category: bug

Found in review of commit b0e071a (`tests/testthat/test-validate-ltc.R`, vignette).

The ~1.2-1.3% Rhein-Hunsrück gap is attributed to INKAR "evidently" not applying BBSR's 2013->2014 ~1.7% boundary correction. No code verifies this. The test then accepts median < 0.005, >= 98% within 1%, and max < 0.05; a 5% ceiling can hide a real regression.

Fix: reproduce the gap with and without that transfer; then assert on an explicit set of expected-outlier districts and tighten the generic bounds. (Root cause over tolerance.)
