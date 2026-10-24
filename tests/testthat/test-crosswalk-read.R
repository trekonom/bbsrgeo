test_that("bbsr_crosswalk_read parses an 'annual' file correctly", {
  d <- bbsr_crosswalk_read(test_path(
    "fixtures",
    "ref-kreise-testfixture-jaehrlich.xlsx"
  ))

  expect_named(
    d,
    c(
      "ags_old",
      "name_old",
      "ags_new",
      "name_new",
      "year_from",
      "year_to",
      "share_area",
      "share_population",
      "share_employment",
      "area_old",
      "population_old",
      "employment_old"
    )
  )
  expect_equal(nrow(d), 6)

  # Sheet "1999-2000": hyphenated sheet name -> year_from/year_to taken directly from it
  unchanged <- d[d$year_from == 1999 & d$ags_old == "01000001", ]
  expect_equal(unchanged$year_to, 2000)
  expect_equal(unchanged$share_area, 1)

  # Split of district B into two rows, shares sum to 1
  split <- d[d$year_from == 1999 & d$ags_old == "01000002", ]
  expect_equal(nrow(split), 2)
  expect_equal(sum(split$share_area), 1)
  expect_equal(sum(split$share_population), 1)

  # Sheet "2000-2001": 10-column variant with employment data
  with_employment <- d[d$year_from == 2000, ]
  expect_true(all(!is.na(with_employment$share_employment)))
  expect_true(all(!is.na(with_employment$employment_old)))

  # Sheet "2001": single-year sheet name -> year_to derived as year_from + 1
  single_year <- d[d$year_from == 2001, ]
  expect_equal(single_year$year_to, 2002)
})

test_that("bbsr_crosswalk_read parses a 'conversion_*' file correctly (fixed target year)", {
  d <- bbsr_crosswalk_read(test_path(
    "fixtures",
    "ref-kreise-umrech-2021-testfixture.xlsx"
  ))

  expect_equal(nrow(d), 2)
  # Target year comes from the file name (umrech-2021), not the sheet name
  expect_true(all(d$year_to == 2021))
  expect_equal(sort(d$year_from), c(1999, 2000))
})

test_that("bbsr_crosswalk_read normalizes AGS to 8 digits", {
  d <- bbsr_crosswalk_read(test_path(
    "fixtures",
    "ref-kreise-testfixture-jaehrlich.xlsx"
  ))
  expect_true(all(nchar(d$ags_old) == 8))
  expect_true(all(nchar(d$ags_new) == 8))
})

test_that("bbsr_crosswalk_read can read multiple files at once", {
  d <- bbsr_crosswalk_read(c(
    test_path("fixtures", "ref-kreise-testfixture-jaehrlich.xlsx"),
    test_path("fixtures", "ref-kreise-umrech-2021-testfixture.xlsx")
  ))
  expect_equal(nrow(d), 6 + 2)
})

test_that("bbsr_crosswalk_read aborts with a clear message for a missing file", {
  expect_error(bbsr_crosswalk_read("does-not-exist.xlsx"), "not found")
})

test_that("bbsrgeo_sheet_years parses two-digit end years in annual sheet names", {
  meta <- list(kind = "annual", file_name = "ref-gemeinden-1990-2000.xlsx")

  expect_equal(
    bbsrgeo_sheet_years("1990-91", meta),
    list(from = 1990L, to = 1991L)
  )
  expect_equal(
    bbsrgeo_sheet_years("1996-97", meta),
    list(from = 1996L, to = 1997L)
  )
  # Century rollover: the end year is the next year, not 1900.
  expect_equal(
    bbsrgeo_sheet_years("1999-00", meta),
    list(from = 1999L, to = 2000L)
  )
  # The existing patterns are unchanged.
  expect_equal(
    bbsrgeo_sheet_years("1997-1998", meta),
    list(from = 1997L, to = 1998L)
  )
  expect_equal(
    bbsrgeo_sheet_years("2005", meta),
    list(from = 2005L, to = 2006L)
  )
})

test_that("bbsrgeo_sheet_years rejects a two-digit end year that is not the next year", {
  meta <- list(kind = "annual", file_name = "ref-gemeinden-1990-2000.xlsx")
  expect_error(bbsrgeo_sheet_years("1990-93", meta), "Unexpected sheet name")
})

test_that("bbsr_crosswalk_read parses the municipal Regionalschluessel layout", {
  # Reading must not warn: the 12-digit Regionalschluessel is not an AGS.
  d <- expect_no_warning(bbsr_crosswalk_read(test_path(
    "fixtures",
    "ref-gemeinden-testfixture-regionalschluessel.xlsx"
  )))

  expect_equal(nrow(d), 4)
  # The 12-digit Regionalschluessel columns are not read as AGS, and the
  # 10 columns are not mistaken for the employment layout.
  expect_equal(
    sort(unique(c(d$ags_old, d$ags_new))),
    c("01001000", "01002000", "01009000", "01010000")
  )
  expect_equal(
    d$name_old[d$year_from == 2022 & d$ags_old == "01001000"],
    "Town A"
  )
  expect_true(all(is.na(d$share_employment)))
  expect_true(all(is.na(d$employment_old)))

  split <- d[d$year_from == 2022 & d$ags_old == "01002000", ]
  expect_equal(sort(split$share_area), c(0.4, 0.6))
  expect_equal(sort(split$share_population), c(0.3, 0.7))
  expect_equal(sum(split$population_old), 1000)
  expect_equal(d$population_old[d$year_from == 2023], 92667)
})
