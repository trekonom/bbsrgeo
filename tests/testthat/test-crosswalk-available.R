test_that("bbsr_crosswalk_available returns the expected columns", {
  d <- bbsr_crosswalk_available()
  expect_s3_class(d, "tbl_df")
  expect_named(
    d,
    c("level", "kind", "year_from", "year_to", "url", "file_size")
  )
  expect_true(all(c("municipalities", "districts") %in% d$level))
})

test_that("bbsr_crosswalk_available filters by level", {
  d <- bbsr_crosswalk_available("districts")
  expect_true(all(d$level == "districts"))
  expect_true(nrow(d) > 0)
})

test_that("bbsr_crosswalk_available validates level", {
  expect_error(bbsr_crosswalk_available("states"))
})

test_that("every kind/level combination has at least one row", {
  d <- bbsr_crosswalk_available()
  expected_kinds <- c(
    "annual",
    "conversion_2019",
    "conversion_2020",
    "conversion_2021"
  )
  expect_true(all(expected_kinds %in% d$kind))
  expect_true(all(grepl("^https://www\\.bbsr\\.bund\\.de/.*\\.xlsx\\?", d$url)))
})
