# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this package does

`bbsrgeo` is an R package that downloads and reads BBSR "Umstiegsschluessel"
(area crosswalks) for German municipalities and districts, and uses them to
convert regional statistics time series (e.g. from GENESIS-Regio /
Regionaldatenbank Deutschland) onto a single, consistent set of area
boundaries despite municipality mergers and district reorganizations.

Not yet on CRAN; install locally with `pak::pak("local::.")`.

## Commands

Write R code to a `.R` file and run it with `Rscript file.R`; the scripts below
are in `dev/`. Scratch scripts go in `dev/scratch/` (gitignored, not formatted; create it with `mkdir -p dev/scratch`). `devtools`/
`testthat`/`pkgdown` are not on `Suggests`, so prefer base tools already listed
in `DESCRIPTION`.

- Format code: `dev/format.sh` (finds `air` even when it is not on the `PATH`; `--check` only reports). The pre-commit hook in `.githooks/` runs the check and `dev/check-refs.R` (fails when a doc names a file or function that no longer exists) and the pre-push hook runs the full test suite (about a minute; a push that only changes Markdown or `.scratch/` runs `dev/check-refs.R` instead); after a fresh clone enable both with `git config core.hooksPath .githooks`
- Run all tests: `Rscript dev/test-all.R` (lists any test that skipped)
- Run a single test file: `Rscript dev/test-file.R tests/testthat/test-harmonize-regions.R`
  (a bare `testthat::test_file()` skips the network-guarded validation tests
  silently, because it leaves `NOT_CRAN` unset)
- Regenerate docs from roxygen comments: `Rscript dev/document.R`
- Build the package: `R CMD build . --no-build-vignettes`
- Full check: `NOT_CRAN=true R CMD check bbsrgeo_0.0.0.9000.tar.gz --no-manual --no-build-vignettes -o /tmp/rcheck`
- Rebuild README from README.Rmd: `Rscript dev/render-readme.R`
- List open GitHub issues with their labels: `dev/issues.sh` (the issues under `.scratch/` are history)

Tests use `testthat` edition 3 (`Config/testthat/edition: 3` in DESCRIPTION).
Tests that hit the live BBSR site or require network access are guarded with
`skip_on_cran()` / `skip_if_offline()` — see `test-validate-inkar.R` and
`test-crosswalk-download.R`.

## Architecture

The package has two independent halves that compose through one shared data
shape (the crosswalk tibble):

1. **Acquiring a crosswalk** (`R/crosswalk-*.R`):
   - `bbsr_crosswalk_available()` looks up a static table of known BBSR xlsx
     files, bundled in `R/sysdata.rda` (built by
     `data-raw/bbsr_crosswalk_urls.R`). `bbsr_crosswalk_available_live()` is
     the live alternative, scraping the current BBSR overview page (German)
     with `rvest` when the static table has gone stale.
   - `bbsr_crosswalk_download()` fetches and caches the xlsx file(s) under
     `tools::R_user_dir("bbsrgeo", "cache")`.
   - `bbsr_crosswalk_read()` parses the xlsx sheets into one long tibble with
     columns `ags_old`, `ags_new`, `year_from`, `year_to`, `level`,
     `share_area`/`share_population`/`share_employment`, and the
     corresponding absolute `*_old` values. It infers `level`/`kind` from the
     (German) file name and sheet names, and warns if a given
     `ags_old`/`year_from` combination's shares don't sum to ~1 — this is a
     known upstream BBSR data-quality issue, not a bug in this package. The
     read-time checks and the renormalization in `harmonize_regions()` both ask
     `classify_share_deviations()` which transition groups deviate and which
     treatment applies.
   - The real files have up to ~150k `ags_old`/transition groups. Evaluating
     R code per group is slow at that size: a `map_dfr` over groups exceeds
     the 2-minute tool timeout, and a grouped `dplyr::mutate()` with several
     expressions made `test-crosswalk-read.R` about 4.5x slower than `ave()`
     (measured 2026-10-24). A group id with `rowsum()` and sorting is as fast
     as `ave()` (see `transition_group_ids()` and `group_sum()`).

2. **Applying a crosswalk**. `plan_conversion()` builds the Conversion plan
   (the transitions each year passes through, via `conversion_steps()`, and
   the unmapped units it drops), shared by `harmonize_regions()` and
   `check_regions()` so the two cannot disagree:
   - `harmonize_regions()` takes a long panel dataset
     (AGS + year + value column(s)) and re-expresses it on one target-year
     boundary. For `"annual"` crosswalks it chains single-year transitions
     year by year (the plan's steps, applied by `harmonize_path()` →
     `harmonize_step()`) when a direct transition isn't available; `"conversion_*"` crosswalks convert
     directly. `type = "absolute"` sums shares; `type = "ratio"` computes a
     weighted mean using the chosen `weight` basis (`population`/`area`/
     `employment`) as weights.
   - Forward conversion (older → newer boundary) is the default/intended use;
     backcasting (newer → older) requires `allow_backcast = TRUE` and emits a
     warning, since it's inherently less reliable.
   - `check_regions()` is a pre-flight helper: it reads the same plan as
     `harmonize_regions()` over the area units alone and reports the rows the
     conversion would drop as unmapped units.

AGS (Amtlicher Gemeindeschluessel) handling is centralized in
`normalize_ags()`: BBSR xlsx cells are inconsistently
text/numeric, and federal states "01"–"09" lose their leading zero once
read as a number — this function re-pads everything to a consistent 8-digit
string. Any new code path that reads AGS values from a file should go
through it.

## Example datasets and validation

Touching `data-raw/*.R`, `data/*.rda`, `R/data.R`, or the INKAR validation
tests (`test-validate-*.R`): read `docs/datasets.md` first. It holds the 5-digit
vs 8-digit AGS join rule, the dl-de/by-2-0 attribution requirement, and the
previously debugged source-data quirks.

## Working with this repo

- Reviewers: `CODING_STANDARDS.md` holds the judgement-call rules (read it during review).
- All comments/docs in the package are in English; the BBSR *source* file
  names, sheet names, and scraped page content are in German by nature
  (e.g. "gemeinden"/"kreise", "Umrechnung auf ..." ) — code that parses them
  documents the German terms inline rather than translating on the fly.
- `NAMESPACE` and `man/*.Rd` are generated by roxygen2 from comments in
  `R/*.R` (`Roxygen: list(markdown = TRUE)` in DESCRIPTION) — edit the
  roxygen comments, not the generated files, then re-roxygenise.
- `README.md` is generated from `README.Rmd` — edit the latter, not the
  former. Its sample output shows the package's current warnings and messages:
  after a change to them, run `dev/render-readme.R` (needs the cached BBSR
  files) and commit the re-rendered `README.md` on its own, since the
  re-render also picks up any earlier drift.

## Agent skills

### Issue tracker

Issues and specs are GitHub issues in `trekonom/bbsrgeo` (use the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one root `GLOSSARY.md` plus `docs/adr/`. See `docs/agents/domain.md`.
