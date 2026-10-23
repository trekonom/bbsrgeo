# Harmonized ltcregio vs ltcinkar, for every check year, one row per current
# district. Skips (does not fail) when the BBSR crosswalk cannot be fetched.
ltc_harmonized_vs_inkar <- function() {
  skip_on_cran()
  skip_if_offline()

  crosswalk <- tryCatch(
    {
      path <- bbsr_crosswalk_download(level = "districts", kind = "annual")
      # Warns about the known share-sum anomalies handled below.
      suppressWarnings(bbsr_crosswalk_read(path))
    },
    error = function(e) NULL
  )
  if (is.null(crosswalk)) {
    skip("Could not download/read the BBSR area crosswalk (offline or BBSR unreachable).")
  }

  converted <- harmonize_regions(
    ltcregio,
    crosswalk = crosswalk,
    ags_col = "ags",
    year_col = "year",
    value_cols = "care_rate",
    type = "ratio",
    weight = "population",
    target_year = "current",
    level = "districts"
  )
  converted$kreiskennziffer <- substr(converted$ags, 1, 5)

  # ltcinkar is bundled with the package (see R/data.R, data-raw/ltcinkar.R)
  # - no INKAR API call needed here. Its `ags` is INKAR's native 5-digit
  # Kreisschluessel, unlike `converted$ags` (8-digit, Kreisschluessel +
  # "000") - see ?ltcinkar for why, and the join below for the pattern.
  compared <- merge(
    converted[, c("kreiskennziffer", "year", "care_rate")],
    ltcinkar[, c("ags", "year", "care_rate")],
    by.x = c("kreiskennziffer", "year"), by.y = c("ags", "year"),
    suffixes = c("_ours", "_inkar")
  )
  compared$rel_diff <- abs(compared$care_rate_ours - compared$care_rate_inkar) /
    compared$care_rate_inkar

  # Same known BBSR-source data-quality issue as test-validate-inkar.R (a
  # handful of transitions where share_population sums to far less than 1
  # for a self-mapping district): here it's AGS 07135000 "Cochem-Zell" and
  # 07137000 "Mayen-Koblenz" 2014->2015 and 2015->2016 (share_population
  # 0.983/0.017 instead of 1.0/0.0). Districts whose conversion chain
  # passes through such a transition are excluded from the comparison.
  share_sums <- stats::aggregate(
    share_population ~ ags_old + year_from + year_to,
    crosswalk,
    sum,
    na.rm = TRUE
  )
  affected <- unique(substr(
    share_sums$ags_old[abs(share_sums$share_population - 1) > 0.01],
    1, 5
  ))

  list(
    compared = compared,
    n_current_districts = length(unique(converted$kreiskennziffer)),
    affected = affected
  )
}

# Biennial reference dates of ltcregio (2009-2023). 2009-2017 chain through
# several year-steps to the current (2024) boundary, including the
# Mecklenburg-Vorpommern 2011-09-04 reform and the 2013->2014 and
# 2014->2016 transitions; 2021 and 2023 need no chaining. 2023 specifically guards the Berlin DLAND-level patch in
# data-raw/ltcregio.R (Berlin's KREISE-level row was "-" for 2023-12-31 at
# retrieval time; see the "Data quality note" in ?ltcregio) - without that
# patch it would fail the district-count check below (399 instead of 400).
ltc_check_years <- seq(2009L, 2023L, by = 2L)

# AGS 07140 Rhein-Hunsrueck-Kreis: harmonized population agrees with
# popinkar within 0.2%, yet the rate is ~1.3% above INKAR's for 2009-2013.
# The cause is unexplained - INKAR's method for indicator 280 is not
# documented in a source we could find - so it is a named known residual,
# not a tolerance. Rows for years after 2013 agree with INKAR and stay in
# the generic comparison below.
ltc_known_residual_ags <- "07140"
ltc_known_residual_years <- c(2009L, 2011L, 2013L)

test_that("harmonize_regions(type = 'ratio') output for ltcregio matches INKAR within 0.6% (independent source)", {
  res <- ltc_harmonized_vs_inkar()

  # Every current district is present in both sources for every check year.
  per_year <- table(res$compared$year)
  expect_equal(
    as.integer(per_year[as.character(ltc_check_years)]),
    rep(res$n_current_districts, length(ltc_check_years))
  )

  known_residual <- res$compared$kreiskennziffer == ltc_known_residual_ags &
    res$compared$year %in% ltc_known_residual_years
  compared <- res$compared[
    !res$compared$kreiskennziffer %in% res$affected & !known_residual,
  ]

  # Max relative difference observed outside the exclusions is 0.48%
  # (Vorpommern-Greifswald 2009); the bound leaves room for INKAR's
  # rounding. A single district over this bound is a real regression, not
  # noise - there is no "98% within 1%" tolerance here.
  for (check_year in ltc_check_years) {
    rel_diff <- compared$rel_diff[compared$year == check_year]
    expect_lt(max(rel_diff), 0.006, label = paste("year", check_year, "max rel. diff."))
  }
})

test_that("Rhein-Hunsrueck-Kreis keeps its known ~1.3% residual against INKAR (2009-2013)", {
  res <- ltc_harmonized_vs_inkar()
  residual <- res$compared[
    res$compared$kreiskennziffer == ltc_known_residual_ags &
      res$compared$year %in% ltc_known_residual_years,
  ]

  expect_equal(nrow(residual), length(ltc_known_residual_years))
  # Observed 1.17%, 1.35%, 1.31%. The band is a tripwire, not an
  # explanation: if the residual shrinks or grows, someone should look.
  expect_true(
    all(residual$rel_diff > 0.01 & residual$rel_diff < 0.02),
    info = paste(round(residual$rel_diff, 4), collapse = ", ")
  )
})
