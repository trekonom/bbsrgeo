## code to prepare `ltcinkar` dataset goes here
##
## Source: INKAR ("Indikatoren und Karten zur Raum- und Stadtentwicklung"),
## a BBSR data product distinct from the Regionaldatenbank Deutschland
## (GENESIS-Regio) used for `ltcregio`. Indicator 280
## ("Pflegebeduerftige je 100 Einwohner" / persons in need of long-term
## care per 100 inhabitants), district level ("KRE"). Retrieved via the
## {inkaR} package (CRAN), which wraps the public INKAR API - no
## credentials required. Indicator id found via
## `inkaR::search_indicators("pflege")`.
##
## This is the independent reference series `ltcregio` is validated
## against in `tests/testthat/test-validate-ltc.R` and
## `vignette("bbsrgeo")`: INKAR already reports this rate for every
## district on a single, current area boundary for every year, so
## comparing it to harmonize_regions()'s output on `ltcregio` (converted
## with `type = "ratio"`) is a genuine external check on the
## BBSR-crosswalk conversion this package performs - this time for a
## ratio/rate indicator rather than an absolute quantity (see `?popinkar`
## for that earlier, absolute-quantity example).
##
## Coverage: all current districts/district-free cities in Germany,
## biennial reference dates 2009-2023 (INKAR's own coverage for this
## indicator, matching `ltcregio`'s coverage exactly).
##
## IMPORTANT: `ags` here is INKAR's native 5-digit Kreisschluessel, NOT the
## 8-digit `ags_old`/`ags_new` convention used by `ltcregio`/the
## BBSR crosswalks (Kreisschluessel + "000"). This is deliberate - this
## dataset is a comparison *target* for harmonize_regions() output, not an
## input to it - but do not join the two datasets' `ags` columns directly
## without accounting for this (see `?ltcinkar` and the
## vignette for the join pattern actually used; same convention as
## `popinkar`).

library(inkaR)

## get_inkar_data() silently returns an empty tibble unless {inkaR} has
## been library()-attached first (a quirk of that package, not ours) -
## `library(inkaR)` above, not `inkaR::get_inkar_data()`, is required.
## The numeric indicator id doubles as the API code here (unlike "xbev" for
## popinkar, no separate string code lookup was needed).
inkar_raw <- get_inkar_data("280", level = "KRE")

ltcinkar <- inkar_raw[, c("Kennziffer", "Raumeinheit", "Zeit", "Wert")]
names(ltcinkar) <- c("ags", "district_name", "year", "care_rate")
ltcinkar <- ltcinkar[
  order(ltcinkar$ags, ltcinkar$year),
]
rownames(ltcinkar) <- NULL
ltcinkar <- tibble::as_tibble(ltcinkar)

usethis::use_data(ltcinkar, overwrite = TRUE)
