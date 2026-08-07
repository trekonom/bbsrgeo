#' Example population data for every German district, 1995-2024
#'
#' Population figures (total/male/female) at 31 December of each year,
#' 1995-2024, for every district ("Kreis")/district-free city
#' ("kreisfreie Stadt") in Germany, each on the area boundary that was
#' actually valid at that reference date. This spans every district
#' boundary reform that happened anywhere in Germany in this period, most
#' prominently the Sachsen-Anhalt district reform of 2007-07-01 (21
#' districts merged into 11) and the Mecklenburg-Vorpommern district reform
#' of 2011-09-04 (12 districts merged into 6) - the two reforms used as the
#' worked examples in `vignette("bbsrgeo")` - but also e.g. the Sachsen
#' reform of 2008-08-01 and the Niedersachsen/Region Hannover reorganization
#' of 2001-11-01. This makes it a good example for [harmonize_regions()]:
#' converting `example_population` onto a single consistent boundary (e.g.
#' `target_year = "current"`) requires chaining through all of these.
#'
#' @section Zensus 2011 caveat:
#' Population figures for 2011 onward are based on the 2011 census
#' ("Zensus 2011") and are **not directly comparable** to earlier,
#' Fortschreibung-based figures - independently of any boundary reform. This
#' is a well-documented methodological break (the census found the
#' previously fortgeschriebene population to be too high, mostly in eastern
#' Germany), not a boundary/area effect, and it is deliberately **not**
#' spared out of this dataset: `example_population` covers 1995-2010 and
#' 2011-2024 so that both effects - boundary reforms and the 2011 census
#' break - are visible side by side. Crucially, the BBSR area crosswalk
#' used by [harmonize_regions()] corrects only for boundary reforms; it
#' does **not** and cannot correct for the census break. Do not interpret a
#' level shift in a converted `example_population` series around 2010/2011
#' as a boundary effect - see `vignette("bbsrgeo")` for a worked example and
#' further discussion.
#'
#' @section Data quality note:
#' The source table already contains, for some post-reform districts, a
#' retrospective recalculation for years before that district existed
#' (Destatis's own back-series, summing the values of the former
#' constituent districts under the new AGS). This is unrelated to the
#' Umstiegsschluessel-based conversion this package performs and would
#' double-count if left in, so it has been removed for this package's
#' example dataset (identified using the BBSR area crosswalk itself as the
#' authoritative record of which AGS was valid in which year; see
#' `data-raw/example_population.R`). `example_population` therefore has
#' exactly one row per district actually valid at that reference date.
#'
#' Separately, GENESIS-Regio/the Regionaldatenbank stores a small number of
#' districts under codes that do not match the official AGS the BBSR
#' crosswalk expects, or under a code shared ambiguously across a later
#' split/merger - an RDB data quirk, not a crosswalk one. Four such cases
#' (Aachen, the Hannover city/district split, Eisenach) are recoded to the
#' official AGS before inclusion here (see `recode_ags_quirks()` in
#' `data-raw/example_population.R` for the exact codes/years and the
#' verification against the BBSR crosswalk's own recorded populations).
#' Left un-recoded, some of these caused large, silent errors when
#' converted with [harmonize_regions()] (e.g. Aachen's pre-2009 population
#' was entirely dropped, since it was only exposed under an RDB-internal
#' 8-digit code that a plain district-level filter excludes) - this is
#' documented in detail in `vignette("bbsrgeo")`, "Validation with INKAR".
#'
#' @format A tibble with 12,546 rows and 7 columns:
#' \describe{
#'   \item{ags}{Amtlicher Gemeindeschluessel, zero-padded to 8 digits
#'     (5-digit Kreisschluessel + `"000"`), on the historical boundary valid
#'     in `year`. Matches the `ags_old`/`ags_new` format returned by
#'     [bbsr_crosswalk_read()].}
#'   \item{state}{Federal state ("Bundesland").}
#'   \item{district_name}{Official district name as published by Destatis
#'     (German, unmodified).}
#'   \item{year}{Reference year (population as of 31 December).}
#'   \item{population_total, population_male, population_female}{Population
#'     counts (persons).}
#' }
#'
#' @source Statistische Aemter des Bundes und der Laender, Regionaldatenbank
#'   Deutschland (GENESIS-Regio), table 12411-01-01-4 "Bevoelkerung nach
#'   Geschlecht - Stichtag 31.12. - Kreise und kreisfreie Staedte"
#'   (statistic 12411 "Fortschreibung des Bevoelkerungsstandes"),
#'   retrieved 2026-08-07 via the \pkg{restatis} package. See
#'   `data-raw/example_population.R` for the full retrieval/cleaning code.
#'
#'   Licensed under the "Datenlizenz Deutschland - Namensnennung - Version
#'   2.0" (dl-de/by-2-0),
#'   <https://www.govdata.de/dl-de/by-2-0>, which permits redistribution
#'   with attribution; the citation above constitutes that attribution.
#'
#' @references BBSR (Bundesinstitut fuer Bau-, Stadt- und Raumforschung)
#'   (2010): *Gebietsreformen - politische Entscheidungen und Folgen fuer
#'   die Statistik*. BBSR-Berichte KOMPAKT 6/2010. Bonn.
#'   ISBN 978-3-87994-391-3, ISSN 1867-0547.
#'
#' @seealso [example_population_inkar], an independent reference series from
#'   INKAR used to validate [harmonize_regions()]'s conversion of this
#'   dataset (see `vignette("bbsrgeo")`, section "Validation with INKAR").
#'
#' @examples
#' example_population
"example_population"

#' INKAR reference population data for validating `harmonize_regions()`
#'
#' Total population by district, 1995-2023, from INKAR ("Indikatoren und
#' Karten zur Raum- und Stadtentwicklung", <https://www.inkar.de/>) - a BBSR
#' data product distinct from the Regionaldatenbank Deutschland
#' (GENESIS-Regio) that [example_population] is sourced from. INKAR already
#' reports every district's population on a single, current area boundary
#' for every year, which makes it a genuine **independent** check on
#' [harmonize_regions()]'s conversion of [example_population] onto a
#' consistent boundary: both `tests/testthat/test-validate-inkar.R` and
#' `vignette("bbsrgeo")` ("Validation with INKAR") compare the two. Bundled
#' with the package so this validation does not require reaching the INKAR
#' API at test/vignette-build time.
#'
#' @section AGS convention differs from `example_population`:
#' `ags` here is INKAR's native **5-digit** Kreisschluessel (e.g.
#' `"15088"`), *not* the 8-digit `ags_old`/`ags_new` convention
#' ([example_population], the BBSR crosswalks; Kreisschluessel + `"000"`).
#' This is deliberate - `example_population_inkar` is a comparison *target*
#' for [harmonize_regions()] output, not an input to it - but the two must
#' not be joined by `ags` directly without accounting for this, e.g.
#' `substr(harmonized$ags, 1, 5) == example_population_inkar$ags` (see
#' `tests/testthat/test-validate-inkar.R` and the vignette for the exact
#' pattern used).
#'
#' @section Zensus 2011 caveat:
#' Like [example_population], this series is not census-corrected - see
#' `?example_population` and `vignette("bbsrgeo")` for why this means the
#' comparison validates only the boundary conversion, not the 2011 census
#' break. INKAR separately offers a census-corrected indicator (`"bev_korr"`
#' via [inkaR::get_inkar_data()]), not bundled here and out of scope for
#' this package.
#'
#' @format A tibble with 11,600 rows and 4 columns:
#' \describe{
#'   \item{ags}{INKAR's 5-digit Kreisschluessel (see above - not the same
#'     convention as [example_population]'s `ags`).}
#'   \item{district_name}{District name as published by INKAR (German).}
#'   \item{year}{Reference year (population as of 31 December).}
#'   \item{population_total}{Population count (persons), indicator `"xbev"`
#'     ("Bevoelkerung gesamt").}
#' }
#'
#' @source INKAR, indicator `"xbev"` ("Bevoelkerung gesamt"), district level
#'   (`level = "KRE"`), retrieved 2026-08-07 via the \pkg{inkaR} package
#'   (`inkaR::get_inkar_data("xbev", level = "KRE")`; requires no
#'   credentials - the INKAR API is public). See
#'   `data-raw/example_population_inkar.R` for the full retrieval code.
#'
#'   Licensed under the "Datenlizenz Deutschland - Namensnennung - Version
#'   2.0" (dl-de/by-2-0), <https://www.govdata.de/dl-de/by-2-0> (confirmed
#'   via the GDI-DE geodata catalog metadata record for INKAR), which
#'   permits redistribution with attribution; the citation above
#'   constitutes that attribution ("BBSR Bonn 2026").
#'
#' @seealso [example_population]
#'
#' @examples
#' example_population_inkar
"example_population_inkar"
