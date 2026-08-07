## code to prepare `example_population_inkar` dataset goes here
##
## Source: INKAR ("Indikatoren und Karten zur Raum- und Stadtentwicklung"),
## a BBSR data product distinct from the Regionaldatenbank Deutschland
## (GENESIS-Regio) used for `example_population`. Indicator "xbev"
## ("Bevoelkerung gesamt" / total population), district level ("KRE").
## Retrieved via the {inkaR} package (CRAN), which wraps the public INKAR
## API - no credentials required.
##
## This is the independent reference series `example_population` is
## validated against in `tests/testthat/test-validate-inkar.R` and
## `vignette("bbsrgeo")` ("Validation with INKAR"): INKAR already reports
## every district's population on a single, current area boundary for
## every year, so comparing it to harmonize_regions()'s output on
## `example_population` is a genuine external check on the BBSR-crosswalk
## conversion this package performs.
##
## Coverage: all current districts/district-free cities in Germany,
## 1995-2023 (INKAR's actual coverage for this indicator - one year short
## of `example_population`'s 2024).
##
## IMPORTANT: `ags` here is INKAR's native 5-digit Kreisschluessel, NOT the
## 8-digit `ags_old`/`ags_new` convention used by `example_population`/the
## BBSR crosswalks (Kreisschluessel + "000"). This is deliberate - this
## dataset is a comparison *target* for harmonize_regions() output, not an
## input to it - but do not join the two datasets' `ags` columns directly
## without accounting for this (see `?example_population_inkar` and the
## vignette for the join pattern actually used).

library(inkaR)

## get_inkar_data() silently returns an empty tibble unless {inkaR} has
## been library()-attached first (a quirk of that package, not ours) -
## `library(inkaR)` above, not `inkaR::get_inkar_data()`, is required.
inkar_raw <- get_inkar_data("xbev", level = "KRE")

example_population_inkar <- inkar_raw[, c("Kennziffer", "Raumeinheit", "Zeit", "Wert")]
names(example_population_inkar) <- c("ags", "district_name", "year", "population_total")
example_population_inkar$population_total <- as.integer(example_population_inkar$population_total)
example_population_inkar <- example_population_inkar[
  order(example_population_inkar$ags, example_population_inkar$year),
]
rownames(example_population_inkar) <- NULL
example_population_inkar <- tibble::as_tibble(example_population_inkar)

usethis::use_data(example_population_inkar, overwrite = TRUE)
