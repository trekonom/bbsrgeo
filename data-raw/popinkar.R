## code to prepare `popinkar` dataset goes here
##
## Source: INKAR ("Indikatoren und Karten zur Raum- und Stadtentwicklung"),
## a BBSR data product distinct from the Regionaldatenbank Deutschland
## (GENESIS-Regio) used for `popregio`. Indicator "xbev"
## ("Bevoelkerung gesamt" / total population), district level ("KRE").
## Retrieved via the {inkaR} package (CRAN), which wraps the public INKAR
## API - no credentials required.
##
## This is the independent reference series `popregio` is
## validated against in `tests/testthat/test-validate-inkar.R` and
## `vignette("bbsrgeo")` ("Validation with INKAR"): INKAR already reports
## every district's population on a single, current area boundary for
## every year, so comparing it to harmonize_regions()'s output on
## `popregio` is a genuine external check on the BBSR-crosswalk
## conversion this package performs.
##
## Coverage: all current districts/district-free cities in Germany,
## 1995-2023 (INKAR's actual coverage for this indicator - one year short
## of `popregio`'s 2024).
##
## IMPORTANT: `ags` here is INKAR's native 5-digit Kreisschluessel, NOT the
## 8-digit `ags_old`/`ags_new` convention used by `popregio`/the
## BBSR crosswalks (Kreisschluessel + "000"). This is deliberate - this
## dataset is a comparison *target* for harmonize_regions() output, not an
## input to it - but do not join the two datasets' `ags` columns directly
## without accounting for this (see `?popinkar` and the
## vignette for the join pattern actually used).

library(inkaR)

## get_inkar_data() silently returns an empty tibble unless {inkaR} has
## been library()-attached first (a quirk of that package, not ours) -
## `library(inkaR)` above, not `inkaR::get_inkar_data()`, is required.
inkar_raw <- get_inkar_data("xbev", level = "KRE")

popinkar <- inkar_raw[, c("Kennziffer", "Raumeinheit", "Zeit", "Wert")]
names(popinkar) <- c("ags", "district_name", "year", "population_total")
popinkar$population_total <- as.integer(popinkar$population_total)
popinkar <- popinkar[
  order(popinkar$ags, popinkar$year),
]
rownames(popinkar) <- NULL
popinkar <- tibble::as_tibble(popinkar)

usethis::use_data(popinkar, overwrite = TRUE)
