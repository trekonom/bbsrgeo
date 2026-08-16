## code to prepare `ltcregio` dataset goes here
##
## Source: Regionaldatenbank Deutschland (GENESIS-Regio), table 22411-02-02-4
## "Pflegebeduerftige nach Leistungsart und Geschlecht - Stichtag - regionale
## Tiefe: Kreise und krfr. Staedte - ab 2009" ["Persons in need of long-term
## care by type of benefit and sex - reference date - regional depth:
## districts and district-free cities - from 2009"], statistic 22411
## "Pflegestatistik" (Statistische Aemter des Bundes und der Laender).
## Retrieved via the {restatis} package (GENESIS-Regio API) - same
## credentials setup as `data-raw/popregio.R` (GENESIS-Regio account,
## `restatis::gen_auth_save()`, `GENESIS_KEY` in `.Renviron`; not repeated
## here).
##
## Coverage: ALL districts/district-free cities in Germany, biennial
## reference dates 2009-2023 (this table's own coverage; the older, source
## table 22411-02-01-4 covers 2003-2007 under a different, incompatible
## variable coding scheme and is deliberately not spliced in here - INKAR's
## own indicator 280, used to validate this dataset in
## `tests/testthat/test-validate-ltc.R`, has no data before 2009 either).
## This still spans a real boundary reform: Mecklenburg-Vorpommern's
## 2011-09-04 district reform (12 districts merged into 6) falls inside this
## window - verified directly against this table before building this
## script: pre-reform codes report a real value for 2009 and the RDB
## not-applicable placeholder ("-") from 2011 on, post-reform codes the
## reverse. Unlike `popregio`'s source table, this table does NOT backfill
## post-reform AGS with a retrospective pre-reform recalculation, so - unlike
## popregio.R - no double-counting correction is needed here. The
## crosswalk-based valid-AGS filter below is kept anyway, purely as a
## defensive/consistency measure matching popregio.R's approach.
##
## Unlike `popregio` (an absolute count), `ltcregio` bundles a RATE:
## `care_rate` = Pflegebeduerftige ("PFL016", the table's total headline
## count, Geschlecht = Total) per 100 inhabitants, using `population_total`
## from the already-bundled, already-cleaned `popregio` dataset as the
## denominator (rather than re-deriving population from a second RDB
## source). This mirrors INKAR indicator 280's own "je 100 Einwohner"
## framing and is meant to be converted with
## `harmonize_regions(type = "ratio", weight = "population")` - unlike
## `popregio`, which uses `type = "absolute"`. See `?ltcregio` and
## `vignette("bbsrgeo")` for why this matters (a ratio must be converted as
## a weighted average, not summed).
##
## None of popregio.R's 3 documented RDB AGS quirks (Aachen pre-2009,
## Hannover pre-2001, Eisenach pre-1998) fall inside this dataset's
## 2009-2023 window, so no equivalent recoding is needed here.
##
## One new quirk found while building this dataset: Berlin's KREISE-level
## row ("11000") is "-" for 2023-12-31 - not a genuine gap in the
## underlying statistic, but a publication lag specific to Berlin (Hamburg,
## the only other single-Kreis city-state, has a normal 2023 KREISE row).
## The identical number is already published under the DLAND (federal
## state) tag for Berlin ("11") - since Berlin has no Landkreise, its
## district and state extent are the same entity, so backfilling from
## DLAND is not a modeling choice, just recovering data GENESIS-Regio has
## already published under a different regional-variable tag. See the
## Berlin patch below.

library(dplyr)
library(restatis)

pkgload::load_all(".")

## GENESIS-Regio regional key "KREISE". Unlike popregio.R's source table,
## a single all-Germany request for this table exceeds GENESIS-Regio's
## simple-download size limit ("table too big for simple download") - this
## table carries 7 value variables (PFL016-PFL022) x 3 Geschlecht
## categories per district-year, vs. popregio's 3. Fetched per federal
## state (regionalkey wildcard on the 2-digit state prefix) instead. As in
## popregio.R, the wildcard also matches state-/Regierungsbezirk-level
## aggregates and both historical and current district keys within each
## state - filtered down to district level below.
state_prefixes <- sprintf("%02d", 1:16)
ltc_raw <- purrr::map_dfr(state_prefixes, function(prefix) {
  gen_table(
    name = "22411-02-02-4",
    database = "regio",
    regionalvariable = "KREISE",
    regionalkey = paste0(prefix, "*"),
    startyear = 2009,
    endyear = 2023
  )
})

## value_variable_code "PFL016" = "Pflegebeduerftige", the table's absolute
## headline count (verified against a known value during development:
## Flensburg 2009 male 744 + female 1438 = 2182 = the Total row's value).
## `2_variable_attribute_code` is NA for the Geschlecht = "Total" row (vs.
## "GESM"/"GESW" for the male/female breakdown, which is not needed here).
## nchar == 5 drops the state-/Land-level aggregate rows, keeping only the
## district-level (5-digit) Kreisschluessel actually used by
## harmonize_regions()/bbsr_crosswalk_read() at `level = "districts"`.
ltc_districts <- ltc_raw |>
  filter(
    .data$value_variable_code == "PFL016",
    is.na(.data$"2_variable_attribute_code"),
    nchar(.data$"1_variable_attribute_code") == 5
  ) |>
  transmute(
    ags = paste0(.data$"1_variable_attribute_code", "000"),
    district_name = .data$"1_variable_attribute_label",
    year = as.integer(substr(.data$time, 1, 4)),
    pflegebeduerftige = suppressWarnings(as.integer(.data$value))
  ) |>
  filter(!is.na(.data$pflegebeduerftige))

## Berlin DLAND-level patch (see header comment above): fills in any
## year where the KREISE-level Berlin row is missing, using the
## numerically identical DLAND-level row for Berlin ("11") - only added
## for years not already present via the normal KREISE-level route above.
berlin_dland <- ltc_raw |>
  filter(
    .data$"1_variable_code" == "DLAND",
    .data$"1_variable_attribute_code" == "11",
    .data$value_variable_code == "PFL016",
    is.na(.data$"2_variable_attribute_code")
  ) |>
  transmute(
    ags = "11000000",
    district_name = "Berlin",
    year = as.integer(substr(.data$time, 1, 4)),
    pflegebeduerftige = suppressWarnings(as.integer(.data$value))
  ) |>
  filter(!is.na(.data$pflegebeduerftige))

berlin_patch <- dplyr::anti_join(
  berlin_dland,
  dplyr::filter(ltc_districts, .data$ags == "11000000"),
  by = "year"
)

ltc_districts <- dplyr::bind_rows(ltc_districts, berlin_patch)

## Defensive valid-AGS filter (see header comment above) - same approach as
## popregio.R, using the BBSR crosswalk itself as the authoritative record
## of which AGS was valid in which year.
crosswalk_path <- bbsr_crosswalk_download(level = "districts", kind = "annual")
crosswalk <- bbsr_crosswalk_read(crosswalk_path)

valid_ags_by_year <- c(
  lapply(
    stats::setNames(nm = sort(unique(crosswalk$year_from))),
    function(y) unique(crosswalk$ags_old[crosswalk$year_from == y])
  ),
  list(
    `2024` = unique(crosswalk$ags_new[crosswalk$year_to == max(crosswalk$year_to)])
  )
)

## population_total and state: reused from the already-bundled, already-
## cleaned `popregio` dataset (denominator for care_rate, and the state
## lookup), rather than re-deriving either from a second RDB source or
## re-declaring the state-prefix map a second time.
ltcregio <- ltc_districts |>
  filter(
    purrr::map2_lgl(
      .data$ags, .data$year,
      \(ags, year) ags %in% valid_ags_by_year[[as.character(year)]]
    )
  ) |>
  inner_join(
    select(popregio, "ags", "year", "state", "population_total"),
    by = c("ags", "year")
  ) |>
  mutate(care_rate = .data$pflegebeduerftige / .data$population_total * 100) |>
  select(
    "ags", "state", "district_name", "year",
    "pflegebeduerftige", "population_total", "care_rate"
  ) |>
  arrange(.data$state, .data$ags, .data$year)

usethis::use_data(ltcregio, overwrite = TRUE)
