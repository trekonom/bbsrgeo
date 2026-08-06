test_that("normalize_ags pads missing leading zeros", {
  expect_equal(normalize_ags("1001000"), "01001000")
  expect_equal(normalize_ags("13001000"), "13001000")
  expect_equal(normalize_ags(1001000), "01001000")
})

test_that("normalize_ags is idempotent for already 8-digit values", {
  expect_equal(normalize_ags("01001000"), "01001000")
})

test_that("normalize_ags treats empty/missing values as NA", {
  expect_equal(normalize_ags(""), NA_character_)
  expect_equal(normalize_ags(NA), NA_character_)
  expect_equal(normalize_ags("  "), NA_character_)
})

test_that("normalize_ags warns on non-numeric values and sets NA", {
  expect_warning(res <- normalize_ags("abc"), "could not be parsed")
  expect_equal(res, NA_character_)
})
