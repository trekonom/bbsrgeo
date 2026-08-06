test_that("check_regions recognizes fully matched data", {
  crosswalk <- tibble::tibble(
    ags_old = "01000001", ags_new = "01000001", year_from = 2020L, year_to = 2021L
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 100)

  expect_message(res <- check_regions(data, crosswalk, "ags"), "All 1 rows")
  expect_equal(nrow(res), 0)
})

test_that("check_regions finds unknown AGS", {
  crosswalk <- tibble::tibble(
    ags_old = "01000001", ags_new = "01000001", year_from = 2020L, year_to = 2021L
  )
  data <- tibble::tibble(ags = c("01000001", "99999999"), year = 2020L, population = c(100, 50))

  expect_message(res <- check_regions(data, crosswalk, "ags"), "1 of 2 rows")
  expect_equal(nrow(res), 1)
  expect_equal(res$ags, "99999999")
})

test_that("check_regions also warns about uncovered years", {
  crosswalk <- tibble::tibble(
    ags_old = "01000001", ags_new = "01000001", year_from = 2020L, year_to = 2021L
  )
  data <- tibble::tibble(ags = "01000001", year = 1950L, population = 100)

  expect_message(
    check_regions(data, crosswalk, "ags", year_col = "year"),
    "not covered"
  )
})
