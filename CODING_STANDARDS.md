# Coding standards

Read by the reviewer (`/code-review`), not loaded into every implementation
run. Mechanical rules belong in checks (`dev/`, CI), not here.

## Causes need evidence

A comment, vignette passage, test comment or issue brief that says *why*
something differs (a residual, an outlier, a mismatch with INKAR) must
point to one of:

- a script or test that reproduces the cause,
- a primary source, cited by path or URL,
- the word "unverified" or "unexplained", stated where the claim is made.

Report a cause stated as fact without one of these. State what was
measured instead ("population agrees within 0.2% and the rate is still 1.3%
off") and leave the mechanism out. Precedent: the "INKAR evidently does
not apply the Cochem-Zell transfer" wording this rule replaces
(`.scratch/ltc-validation/issues/02-reproduce-cochem-zell-residual.md`).

## Tests

- Match the sibling test file's shape (`test-validate-inkar.R`). A shared
  helper that does expensive work (a download, a file read, a conversion)
  needs a reason beyond tidiness: if two tests call it, each reruns the work.
  A helper that only builds a small constructed tibble is fine.
- Keep `suppressWarnings()` around the one call that emits the known
  warning, with a comment naming the warning.
- Give a value that appears in two places (year range, district code,
  tolerance) one named constant.
- Tolerances come from measured data: state the observed maximum in the
  comment next to the bound.

## Docs

When a function's responsibility moves, grep `docs/`, `GLOSSARY.md` and
`CLAUDE.md` for its name and check that each doc still says where the rule
lives. `dev/check-refs.R` finds a doc that names something that no longer
exists; it cannot find one that names something that exists but no longer does
what the doc says. Precedent: ADR 0001 kept pointing at
`renormalize_forward_shares()` for the treatment order after it moved to
`classify_share_deviations()`.
