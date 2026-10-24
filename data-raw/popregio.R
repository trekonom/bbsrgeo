## code to prepare `popregio` dataset goes here
##
## Source: Regionaldatenbank Deutschland (GENESIS-Regio), table 12411-01-01-4
## "Bevoelkerung nach Geschlecht - Stichtag 31.12. - Kreise und kreisfreie
## Staedte" ["Population by sex - reference date Dec 31 - districts and
## district-free cities"], Statistische Aemter des Bundes und der Laender.
## Retrieved via the {restatis} package (GENESIS-Regio API).
##
## Coverage: ALL districts/district-free cities in Germany, 1995-2024, i.e.
## on the respective HISTORICAL area boundary of each year. This spans every
## district boundary reform that happened anywhere in Germany in this
## period - most prominently the Sachsen-Anhalt reform of 2007-07-01 and the
## Mecklenburg-Vorpommern reform of 2011-09-04 (both individually documented
## and used as the worked examples in `vignette("bbsrgeo")`), but also e.g.
## the Sachsen reform of 2008-08-01 and the Niedersachsen/Region Hannover
## reorganization of 2001-11-01. See R/data.R for how this is meant to be
## used together with bbsr_crosswalk_read()/harmonize_regions().
##
## It ALSO spans the 2011 census ("Zensus 2011") methodological break: from
## 2011 onward, population figures are based on the 2011 census and are NOT
## directly comparable to earlier fortschreibung-based figures. This is a
## SEPARATE phenomenon from the boundary reforms above and is NOT corrected
## by the BBSR area crosswalk - see the "Validation with INKAR" vignette
## section and the note in `?popregio`.
##
## GENESIS-Regio requires a free account (https://www.regionalstatistik.de/).
## Credentials are never stored in this script or the repo: this script uses
## whatever credentials {restatis} already has stored (see
## `restatis::gen_auth_save()`, which encrypts username/password on disk and
## keys the encryption with the `GENESIS_KEY` environment variable, typically
## kept in `.Renviron`, never in code).

library(dplyr)
library(tidyr)
library(restatis)

pkgload::load_all(".")

## GENESIS-Regio regional key "KREISE", all of Germany. The wildcard also
## matches the state- and Regierungsbezirk-level aggregates and both the
## historical (pre-reform) and current (post-reform) district keys, which is
## exactly what is needed here - these are filtered down to district level
## below.
population_raw <- gen_table(
  name = "12411-01-01-4",
  database = "regio",
  regionalvariable = "KREISE",
  regionalkey = "*",
  startyear = 1995,
  endyear = 2024
)

## RDB (Regionaldatenbank/GENESIS-Regio) code quirks: a handful of districts
## are stored under codes that do not match the official AGS the BBSR
## crosswalk expects, or under a code shared ambiguously across a later
## split/merger. Left un-recoded, these cause silent, large data loss or
## corruption once converted with harmonize_regions() - not a crosswalk
## bug, an RDB one. 4 known cases, verified against this table's live data
## and against the BBSR crosswalk's own recorded ags_old/population_old
## for each transition (see the data-raw commit history/PR description for
## the verification):
## - Aachen: the pre-2009 city population is real, but is only exposed
##   under an 8-digit RDB-internal code "05334002" ("Aachen, krfr. Stadt"),
##   not under the district-level "05313" the crosswalk expects (which
##   returns no values at all under this table). Un-recoded, a plain
##   5-digit-code filter drops this entirely (the ~44% Aachen deviation
##   found during initial nationwide INKAR validation).
## - Hannover: "03241" (5-digit) already carries the *combined*
##   Stadt+Landkreis total for years before the 2001 merger (verified:
##   its year-2000 value matches the crosswalk's own recorded
##   population_old for the 2000->2001 transition, summed across both
##   predecessors, almost exactly) rather than genuine Landkreis-only
##   data; the separate city sub-code "03241001" has no data before 2008
##   either way. Recoding "03241" -> "03253" (Landkreis) for these years
##   is not a literally precise label, but produces the numerically
##   correct converted total (the only other predecessor never has real
##   data for these years to double-count against) and removes an
##   otherwise-unrecoverable coverage gap.
## - Eisenach: raw "16056"/"16063" are already two separate codes from
##   1995, but the BBSR crosswalk only starts modeling "16056" as its own
##   entity from the 1996->1997 transition (1995->1996 is modeled as one
##   still-unified "16063"). Un-recoded, the real pre-1998 "16056" rows
##   have no matching crosswalk transition and are silently dropped.
## Recoding collapses some (code, year) pairs together (the Eisenach case)
## - re-aggregated via pivot_wider(values_fn = sum) below.
recode_ags_quirks <- function(code, year) {
  code[year < 2009 & code == "05334002"] <- "05313" # Aachen, Stadt
  code[year < 2001 & code == "03241001"] <- "03201" # Hannover, Landeshauptstadt
  code[year < 2001 & code == "03241"] <- "03253" # Hannover, Landkreis
  code[year < 1998 & code == "16056"] <- "16063" # Eisenach
  code
}

## Keep only district-level rows (drop state/Regierungsbezirk aggregates
## and the handful of confirmed-redundant sub-city breakdowns, e.g.
## Berlin's 12 Bezirke or Saarbruecken city - their 5-digit parent code
## already carries the complete population), i.e. the historical (5-digit)
## Kreisschluessel actually used by harmonize_regions()/bbsr_crosswalk_read()
## at `level = "districts"`. Recoding happens first so the 4 quirky codes
## above are reduced to plain 5-digit codes before this filter.
districts_raw <- population_raw |>
  filter(.data$"1_variable_code" == "KREISE") |>
  mutate(
    "1_variable_attribute_code" := recode_ags_quirks(
      .data$"1_variable_attribute_code",
      as.integer(substr(.data$time, 1, 4))
    )
  ) |>
  filter(nchar(.data$"1_variable_attribute_code") == 5)

## "-" / "." are GENESIS-Regio's placeholders for "district did not
## (yet/still) exist under this key in this year" (e.g. a pre-reform key
## after a merger, or a post-reform key before it existed) - not data gaps
## for an existing district. They become NA here and are dropped below.
##
## AGS are stored zero-padded to 8 digits (Kreisschluessel + "000"), the
## district-level AGS convention used throughout this package/the BBSR
## crosswalks (see `normalize_ags()` in R/utils.R and the vignette).
##
## district_name is re-derived per (now-recoded) ags from its most recent
## year's label, since recoding can otherwise leave two different labels
## (e.g. "Eisenach, krsfr. Stadt" vs. "Wartburgkreis") attached to the same
## code.
popregio_long <- districts_raw |>
  transmute(
    ags = paste0(.data$"1_variable_attribute_code", "000"),
    district_name = .data$"1_variable_attribute_label",
    year = as.integer(substr(.data$time, 1, 4)),
    sex = c(
      "Total" = "total",
      "männlich" = "male",
      "weiblich" = "female"
    )[.data$"2_variable_attribute_label"],
    population = suppressWarnings(as.integer(.data$value))
  ) |>
  filter(!is.na(.data$population))

canonical_name_by_ags <- popregio_long |>
  slice_max(.data$year, n = 1, by = "ags", with_ties = FALSE) |>
  select("ags", district_name_canonical = "district_name")

popregio_raw <- popregio_long |>
  select(-"district_name") |>
  left_join(canonical_name_by_ags, by = "ags") |>
  rename(district_name = "district_name_canonical") |>
  pivot_wider(
    names_from = "sex",
    values_from = "population",
    values_fn = sum,
    names_glue = "population_{sex}"
  )

## IMPORTANT data-quality step: GENESIS-Regio's 12411-01-01-4 does not only
## contain the population actually reported under each district's AGS at
## each historical reference date - it also contains a retrospective
## recalculation under the *post-reform* AGS for years *before* the reform
## (the value for the new, merged district, backward-summed from its former
## constituent districts; e.g. AGS 15088000 "Saalekreis" already carries a
## value for 2006, a year before it was created on 2007-07-01, equal to the
## sum of its two predecessor districts). If left in, this would silently
## double-count when combined with harmonize_regions() (the true historical
## rows for the predecessor districts are also present). This has nothing
## to do with Umstiegsschluessel-based conversion - it is Destatis's own
## back-series - so it is filtered out here using the BBSR crosswalk itself
## as the authoritative list of which AGS was actually valid in which year.
crosswalk_path <- bbsr_crosswalk_download(level = "districts", kind = "annual")
crosswalk <- bbsr_crosswalk_read(crosswalk_path)

valid_ags_by_year <- c(
  lapply(
    stats::setNames(nm = sort(unique(crosswalk$year_from))),
    function(y) unique(crosswalk$ags_old[crosswalk$year_from == y])
  ),
  list(
    `2024` = unique(crosswalk$ags_new[
      crosswalk$year_to == max(crosswalk$year_to)
    ])
  )
)

## Official two-digit AGS state ("Bundesland") prefixes.
state_by_ags_prefix <- c(
  "01" = "Schleswig-Holstein",
  "02" = "Hamburg",
  "03" = "Niedersachsen",
  "04" = "Bremen",
  "05" = "Nordrhein-Westfalen",
  "06" = "Hessen",
  "07" = "Rheinland-Pfalz",
  "08" = "Baden-Württemberg",
  "09" = "Bayern",
  "10" = "Saarland",
  "11" = "Berlin",
  "12" = "Brandenburg",
  "13" = "Mecklenburg-Vorpommern",
  "14" = "Sachsen",
  "15" = "Sachsen-Anhalt",
  "16" = "Thüringen"
)

popregio <- popregio_raw |>
  filter(
    purrr::map2_lgl(
      .data$ags,
      .data$year,
      \(ags, year) ags %in% valid_ags_by_year[[as.character(year)]]
    )
  ) |>
  mutate(state = state_by_ags_prefix[substr(.data$ags, 1, 2)]) |>
  select(
    "ags",
    "state",
    "district_name",
    "year",
    "population_total",
    "population_male",
    "population_female"
  ) |>
  arrange(.data$state, .data$ags, .data$year)

usethis::use_data(popregio, overwrite = TRUE)
