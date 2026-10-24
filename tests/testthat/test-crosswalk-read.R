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
