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
are in `dev/`. Scratch scripts go in `dev/scratch/` (gitignored). `devtools`/
`testthat`/`pkgdown` are not on `Suggests`, so prefer base tools already listed
in `DESCRIPTION`.

- Format code: `dev/format.sh` (run before every commit/push; finds `air` even when it is not on the `PATH`; `--check` only reports)
- Run all tests: `Rscript dev/test-all.R` (lists any test that skipped)
- Run a single test file: `Rscript dev/test-file.R tests/testthat/test-harmonize-regions.R`
  (a bare `testthat::test_file()` skips the network-guarded validation tests
  silently, because it leaves `NOT_CRAN` unset)
- Regenerate docs from roxygen comments: `Rscript dev/document.R`
- Build the package: `R CMD build . --no-build-vignettes`
- Full check: `NOT_CRAN=true R CMD check bbsrgeo_0.0.0.9000.tar.gz --no-manual --no-build-vignettes -o /tmp/rcheck`
- Rebuild README from README.Rmd: `Rscript dev/render-readme.R`

Tests use `testthat` edition 3 (`Config/testthat/edition: 3` in DESCRIPTION).
Tests that hit the live BBSR site or require network access are guarded with
`skip_on_cran()` / `skip_if_offline()` — see `test-validate-inkar.R` and
`test-crosswalk-download.R`.

## Architecture

The package has two independent halves that compose through one shared data
shape (the crosswalk tibble):

1. **Acquiring a crosswalk** (`R/crosswalk-available.R`,
   `R/crosswalk-available-live.R`, `R/crosswalk-download.R`,
   `R/crosswalk-read.R`):
   - `bbsr_crosswalk_available()` looks up a static table of known BBSR xlsx
     files, bundled in `R/sysdata.rda` (built by
     `data-raw/bbsr_crosswalk_urls.R`). `bbsr_crosswalk_available_live()` is
     the live alternative, scraping the current BBSR overview page (German)
     with `rvest` when the static table has gone stale.
   - `bbsr_crosswalk_download()` fetches and caches the xlsx file(s) under
     `tools::R_user_dir("bbsrgeo", "cache")`.
   - `bbsr_crosswalk_read()` parses the xlsx sheets into one long tibble with
     columns `ags_old`, `ags_new`, `year_from`, `year_to`,
     `share_area`/`share_population`/`share_employment`, and the
     corresponding absolute `*_old` values. It infers `level`/`kind` from the
     (German) file name and sheet names, and warns if a given
     `ags_old`/`year_from` combination's shares don't sum to ~1 — this is a
     known upstream BBSR data-quality issue, not a bug in this package (see
     `bbsrgeo_check_share_sums()`).

2. **Applying a crosswalk** (`R/harmonize-regions.R`, `R/check-regions.R`):
   - `harmonize_regions()` (dispatches to `harmonize_regions_districts()` /
     `harmonize_regions_municipalities()`) takes a long panel dataset
     (AGS + year + value column(s)) and re-expresses it on one target-year
     boundary. For `"annual"` crosswalks it chains single-year transitions
     year by year (`harmonize_path()` → `harmonize_step()`) when a direct
     transition isn't available; `"conversion_*"` crosswalks convert
     directly. `type = "absolute"` sums shares; `type = "ratio"` computes a
     weighted mean using the chosen `weight` basis (`population`/`area`/
     `employment`) as weights.
   - Forward conversion (older → newer boundary) is the default/intended use;
     backcasting (newer → older) requires `allow_backcast = TRUE` and emits a
     warning, since it's inherently less reliable.
   - `check_regions()` is a pre-flight helper to surface AGS values in `data`
     that the crosswalk won't recognize (would otherwise be silently dropped
     by `harmonize_regions()`'s internal `inner_join`).

AGS (Amtlicher Gemeindeschluessel) handling is centralized in
`normalize_ags()` (`R/utils.R`): BBSR xlsx cells are inconsistently
text/numeric, and federal states "01"–"09" lose their leading zero once
read as a number — this function re-pads everything to a consistent 8-digit
string. Any new code path that reads AGS values from a file should go
through it.

## Example datasets and validation

The package bundles two pairs of datasets (`R/data.R`), each pairing a
GENESIS-Regio input series with an independent INKAR reference series used
only to validate `harmonize_regions()`'s conversion of the former:
`popregio`/`popinkar` (population, `type = "absolute"`) and
`ltcregio`/`ltcinkar` (long-term care rate, `type = "ratio"` — INKAR
indicator 280, GENESIS-Regio table `22411-02-02-4`, 2009–2023 only). The
`type = "ratio"` code path has no real-data test coverage from the
population pair alone; `ltcregio`/`ltcinkar` (`tests/testthat/test-validate-ltc.R`,
`vignette("bbsrgeo")` "A ratio example") fills that gap.

`popregio` and `popinkar` (built by `data-raw/popregio.R` and
`data-raw/popinkar.R`) are two independently-sourced German district
population series bundled with the package:

- `popregio` (GENESIS-Regio, 1995–2024, on each year's *historical* boundary)
  is the worked input example for `harmonize_regions()`.
- `popinkar` (INKAR, already on a single current boundary) is an independent
  reference used only to validate that `harmonize_regions()`'s conversion of
  `popregio` produces numbers matching a real independent source —
  `tests/testthat/test-validate-inkar.R` and `vignette("bbsrgeo")` ("Validation
  with INKAR") both perform this comparison.
- `popinkar$ags` is INKAR's native **5-digit** Kreisschluessel, while
  `popregio`/crosswalk AGS values are 8-digit (`ags_old`/`ags_new` = 5-digit
  Kreisschluessel + `"000"`). Never join the two by `ags` directly — truncate
  the 8-digit side to 5 digits first (see the join pattern in
  `test-validate-inkar.R`).
- Both datasets are licensed under "Datenlizenz Deutschland - Namensnennung -
  Version 2.0" (dl-de/by-2-0), which requires attribution — see `?popregio`
  / `?popinkar` for the exact citation text before redistributing either.

`data-raw/popregio.R` documents several source-data quirks that were
corrected when building the bundled dataset (retrospective back-series
double-counting removed; four GENESIS-Regio AGS-coding quirks — Aachen,
Hannover, Eisenach — recoded to the AGS the BBSR crosswalk expects). If you
touch `data-raw/*.R` or regenerate `data/*.rda`, re-read the corresponding
section in `R/data.R`'s roxygen docs first; these are non-obvious,
previously-debugged edge cases, not stylistic choices.

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
  former.

## Agent skills

### Issue tracker

Issues and specs are local markdown files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one root `GLOSSARY.md` plus `docs/adr/`. See `docs/agents/domain.md`.
