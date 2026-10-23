# Unsupported claim that converting counts first is more robust

Status: needs-triage
Category: bug

Found in review of commit b0e071a (vignette, "Converting the underlying counts instead").

The vignette calls counts-then-divide "the more broadly robust technique", but its own table shows it further from INKAR for Rhein-Hunsrück (3.234 vs 3.19) than `type = "ratio"` (3.227). The statement that crosswalk `population_old` and `ltcregio$population_total` are "nearly the same series" is also unverified.

Fix: compare the two population series in the vignette, or soften the claim.
