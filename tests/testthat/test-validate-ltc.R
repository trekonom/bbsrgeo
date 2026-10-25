# Biennial reference dates of ltcregio (2009-2023). All chain through one or
# more year-steps to the current (2024) boundary; 2009-2017 include the
# Mecklenburg-Vorpommern 2011-09-04 reform and the 2013->2014 and
# 2014->2016 transitions. 2023 specifically
# guards the Berlin DLAND-level patch in data-raw/ltcregio.R (Berlin's
# KREISE-level row was "-" for 2023-12-31 at retrieval time; see the "Data
# quality note" in ?ltcregio) - without that patch it would fail the
# district-count check below (399 instead of 400).
ltc_check_years <- seq(2009L, 2023L, by = 2L)

# Harmonized ltcregio vs ltcinkar, for every check year, one row per current
# district. Skips (does not fail) only when the BBSR crosswalk cannot be
# downloaded.
ltc_harmonized_vs_inkar <- function() {
  skip_on_cran()
  skip_if_offline()

  path <- tryCatch(
    bbsr_crosswalk_download(level = "districts", kind = "annual"),
    error = function(e) {
      skip(
        "Could not download the BBSR area crosswalk (offline or BBSR unreachable)."
      )
    }
  )
  # Warns about share-sum deviations, messages about the documented fixes. A read error is
  # a real regression and must fail, not skip.
  crosswalk <- suppressWarnings(bbsr_crosswalk_read(path))

  converted <- harmonize_regions(
    ltcregio,
    crosswalk = crosswalk,
    ags_col = "ags",
    year_col = "year",
    value_cols = "care_rate",
    type = "ratio",
    weight = "population",
    target_year = "current"
  )
  converted$kreiskennziffer <- substr(converted$ags, 1, 5)

  # ltcinkar is bundled with the package (see R/data.R, data-raw/ltcinkar.R)
  # - no INKAR API call needed here. Its `ags` is INKAR's native 5-digit
  # Kreisschluessel, unlike `converted$ags` (8-digit, Kreisschluessel +
  # "000") - see ?ltcinkar for why, and the join below for the pattern.
  compared <- merge(
    converted[, c("kreiskennziffer", "year", "care_rate")],
    ltcinkar[, c("ags", "year", "care_rate")],
    by.x = c("kreiskennziffer", "year"),
    by.y = c("ags", "year"),
    suffixes = c("_ours", "_inkar")
  )
  compared$rel_diff <- abs(compared$care_rate_ours - compared$care_rate_inkar) /
    compared$care_rate_inkar

  # Cochem-Zell (07135) and Mayen-Koblenz (07137) are excluded for check years
  # whose conversion chain passes through their 2014->2015 and 2015->2016
  # transitions (year_from >= check_year). These rows used to be selected by
  # their share sums of 0.983/0.017; the read now fixes them to 1
  # (district-single-row-shares-2014-2015), which does not change the converted
  # values, so the exclusion is named. Their rates disagree with INKAR by up to
  # 2% in 2009-2013 (see ltc-validation issue 02, unexplained).
  affected <- lapply(ltc_check_years, function(check_year) {
    if (check_year <= ltc_excluded_until) ltc_excluded_ags else character()
  })
  names(affected) <- ltc_check_years

  list(
    compared = compared,
    n_current_districts = length(unique(converted$kreiskennziffer)),
    affected = affected
  )
}

ltc_excluded_ags <- c("07135", "07137")
ltc_excluded_until <- 2015L

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
  affected <- vapply(
    seq_len(nrow(res$compared)),
    function(i) {
      res$compared$kreiskennziffer[i] %in%
        res$affected[[as.character(res$compared$year[i])]]
    },
    logical(1)
  )
  compared <- res$compared[!affected & !known_residual, ]

  # Max relative difference observed outside the per-year exclusions is
  # 0.48% (Vorpommern-Greifswald 2009), re-measured with 2017-2023 now
  # including Cochem-Zell and Mayen-Koblenz; the bound leaves room for INKAR's
  # rounding. A single district over this bound is a real regression, not
  # noise - there is no "98% within 1%" tolerance here.
  for (check_year in ltc_check_years) {
    rel_diff <- compared$rel_diff[compared$year == check_year]
    expect_lt(
      max(rel_diff),
      0.006,
      label = paste("year", check_year, "max rel. diff.")
    )
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
