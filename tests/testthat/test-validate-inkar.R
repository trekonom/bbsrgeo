test_that("harmonize_regions() output for popregio matches INKAR (independent source)", {
  skip_on_cran()
  skip_if_offline()

  crosswalk <- tryCatch(
    {
      path <- bbsr_crosswalk_download(level = "districts", kind = "annual")
      # Warns about the known share-sum anomalies handled by renormalization.
      suppressWarnings(bbsr_crosswalk_read(path))
    },
    error = function(e) NULL
  )
  if (is.null(crosswalk)) {
    skip(
      "Could not download/read the BBSR area crosswalk (offline or BBSR unreachable)."
    )
  }

  # Expected warning: renormalization of the crosswalk's off-1 shares.
  converted <- suppressWarnings(harmonize_regions(
    popregio,
    crosswalk = crosswalk,
    ags_col = "ags",
    year_col = "year",
    value_cols = "population_total",
    type = "absolute",
    weight = "population",
    target_year = "current"
  ))
  converted$kreiskennziffer <- substr(converted$ags, 1, 5)
  n_current_districts <- length(unique(converted$kreiskennziffer))

  # BBSR's annual crosswalk has self-mapping rows whose share_population sums
  # to far less than 1 (e.g. 07137000 Mayen-Koblenz, 0.017, 2014->2015 and
  # 2015->2016). harmonize_regions() renormalizes them and warns (issue 07), so
  # no district is excluded from the comparison below.

  # popinkar is bundled with the package (see R/data.R,
  # data-raw/popinkar.R) - no INKAR API call needed here.
  # Its `ags` is INKAR's native 5-digit Kreisschluessel, unlike
  # `converted$ags` (8-digit, Kreisschluessel + "000") - see
  # ?popinkar for why, and the join below for the pattern.

  # Two representative years: 2000 (before most district reforms and
  # before the 2011 census break - requires chaining through several
  # reforms to reach the current boundary) and 2015 (after the
  # Sachsen-Anhalt/Mecklenburg-Vorpommern reforms and after the census
  # break - mostly a no-op conversion for already-current districts). See
  # vignette("bbsrgeo"), section "Validation with INKAR", for why these
  # two years are informative and for the census-2011 caveat.
  for (check_year in c(2000L, 2015L)) {
    ours <- converted[
      converted$year == check_year,
      c("kreiskennziffer", "population_total")
    ]
    inkar_year <- popinkar[
      popinkar$year == check_year,
      c("ags", "population_total")
    ]

    compared <- merge(
      ours,
      inkar_year,
      by.x = "kreiskennziffer",
      by.y = "ags",
      suffixes = c("_ours", "_inkar")
    )

    # Every current district (popregio's AGS recoding, see
    # data-raw/popregio.R, fixes the two cases - Aachen,
    # Region Hannover - that used to leave real gaps here) is present in
    # both sources.
    expect_equal(
      nrow(compared),
      n_current_districts,
      info = paste("year", check_year)
    )

    rel_diff <- abs(
      compared$population_total_ours - compared$population_total_inkar
    ) /
      compared$population_total_inkar

    # The bulk of the distribution should match almost exactly (median
    # ~0). A small residual (here: < 2%) can exceed the 1% mark - traced
    # to real, small area corrections recorded in BBSR's own crosswalk
    # (e.g. a 2002/2003 boundary correction transferring ~5.5% of
    # Potsdam-Mittelmark's area/population to Potsdam) that INKAR's own
    # series evidently does not apply (INKAR's raw, pre-2003 Potsdam
    # values match popregio's raw, unconverted values almost
    # exactly - the divergence is introduced entirely by
    # harmonize_regions() faithfully following the BBSR crosswalk through
    # that correction). This is the same class of legitimate
    # methodology difference as the Saalekreis ~0.6% case discussed in
    # vignette("bbsrgeo"), not a data or conversion bug - but a hard
    # ceiling below still guards against a genuine regression (e.g. the
    # Aachen ~44%/near-total-loss bug this test caught before the AGS
    # recoding fix).
    expect_lt(
      stats::median(rel_diff),
      0.001,
      label = paste("year", check_year, "median rel. diff.")
    )
    expect_gte(
      mean(rel_diff < 0.01),
      0.98,
      label = paste("year", check_year, "share of districts within 1%")
    )
    expect_lt(
      max(rel_diff),
      0.10,
      label = paste("year", check_year, "max rel. diff.")
    )
  }
})
