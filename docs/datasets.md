# Example datasets and validation

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
