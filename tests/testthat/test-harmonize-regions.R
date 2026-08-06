# Helper for synthetic crosswalks in tests
crosswalk_row <- function(ags_old, ags_new, year_from, year_to,
                           share_area = 1, share_population = 1, share_employment = NA,
                           area_old = 100, population_old = 1000, employment_old = NA) {
  tibble::tibble(
    ags_old = ags_old, name_old = ags_old, ags_new = ags_new, name_new = ags_new,
    year_from = year_from, year_to = year_to,
    share_area = share_area, share_population = share_population,
    share_employment = share_employment,
    area_old = area_old, population_old = population_old, employment_old = employment_old
  )
}

test_that("harmonize_regions aggregates absolute values on a full merger", {
  # Districts A and B fully merge (share = 1 each) into district C; district D unchanged
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000099", 2020L, 2021L, population_old = 1000),
    crosswalk_row("01000002", "01000099", 2020L, 2021L, population_old = 2000),
    crosswalk_row("01000003", "01000003", 2020L, 2021L, population_old = 500)
  )
  data <- tibble::tibble(
    ags = c("01000001", "01000002", "01000003"), year = 2020L,
    population = c(1000, 2000, 500)
  )

  res <- harmonize_regions(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = 2021L, level = "districts"
  )

  c_value <- res$population[res$ags == "01000099"]
  d_value <- res$population[res$ags == "01000003"]
  expect_equal(c_value, 3000)
  expect_equal(d_value, 500)
  expect_true(all(res$boundary_year == 2021L))
})

test_that("harmonize_regions computes the weighted average for ratios", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000099", 2020L, 2021L, population_old = 1000),
    crosswalk_row("01000002", "01000099", 2020L, 2021L, population_old = 2000)
  )
  data <- tibble::tibble(ags = c("01000001", "01000002"), year = 2020L, rate = c(5, 8))

  res <- harmonize_regions(
    data, crosswalk, "ags", "year", "rate",
    type = "ratio", weight = "population", target_year = 2021L, level = "districts"
  )

  expected <- (5 * 1000 + 8 * 2000) / 3000
  expect_equal(res$rate, expected)
})

test_that("harmonize_regions distributes correctly to multiple target units on a split", {
  # District A splits: 40% (area) / 30% (population) to B, rest to C
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000002", 2020L, 2021L, share_area = 0.4, share_population = 0.3),
    crosswalk_row("01000001", "01000003", 2020L, 2021L, share_area = 0.6, share_population = 0.7),
    crosswalk_row("01000002", "01000002", 2020L, 2021L),
    crosswalk_row("01000003", "01000003", 2020L, 2021L)
  )
  data <- tibble::tibble(
    ags = c("01000001", "01000002", "01000003"), year = 2020L,
    population = c(1000, 500, 500)
  )

  res <- harmonize_regions(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = 2021L, level = "districts"
  )

  expect_equal(res$population[res$ags == "01000002"], 500 + 1000 * 0.3)
  expect_equal(res$population[res$ags == "01000003"], 500 + 1000 * 0.7)
})

test_that("harmonize_regions chains annual crosswalks across multiple years", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000001", 2018L, 2019L),
    crosswalk_row("01000001", "01000001", 2019L, 2020L),
    crosswalk_row("01000001", "01000009", 2020L, 2021L)
  )
  data <- tibble::tibble(ags = "01000001", year = 2018L, population = 100)

  res <- harmonize_regions(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = 2021L, level = "districts"
  )

  expect_equal(res$ags, "01000009")
  expect_equal(res$population, 100)
  expect_equal(res$year, 2018L)
})

test_that("harmonize_regions uses a direct conversion crosswalk without chaining", {
  # 'conversion_2021'-style: year_to is already the fixed target year
  crosswalk <- crosswalk_row("01000001", "01000009", 1999L, 2021L)
  data <- tibble::tibble(ags = "01000001", year = 1999L, population = 100)

  res <- harmonize_regions(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = 2021L, level = "districts"
  )
  expect_equal(res$ags, "01000009")
  expect_equal(res$population, 100)
})

test_that("harmonize_regions aborts on a missing hop in the chain", {
  crosswalk <- crosswalk_row("01000001", "01000001", 2018L, 2019L)
  data <- tibble::tibble(ags = "01000001", year = 2018L, population = 100)

  expect_error(
    harmonize_regions(
      data, crosswalk, "ags", "year", "population",
      type = "absolute", weight = "population", target_year = 2021L, level = "districts"
    ),
    "No crosswalk found"
  )
})

test_that("harmonize_regions refuses backcasting without explicit permission", {
  crosswalk <- crosswalk_row("01000001", "01000099", 2020L, 2021L)
  data <- tibble::tibble(ags = "01000099", year = 2021L, population = 100)

  expect_error(
    harmonize_regions(
      data, crosswalk, "ags", "year", "population",
      type = "absolute", weight = "population", target_year = 2020L, level = "districts"
    ),
    "backcast"
  )
})

test_that("harmonize_regions performs backcasting with a warning when explicitly allowed", {
  crosswalk <- crosswalk_row("01000001", "01000099", 2020L, 2021L)
  data <- tibble::tibble(ags = "01000099", year = 2021L, population = 100)

  expect_warning(
    res <- harmonize_regions(
      data, crosswalk, "ags", "year", "population",
      type = "absolute", weight = "population", target_year = 2020L, level = "districts",
      allow_backcast = TRUE
    ),
    "experimental"
  )
  expect_equal(res$ags, "01000001")
})

test_that("target_year = 'current' uses the most recent available boundary", {
  crosswalk <- crosswalk_row("01000001", "01000009", 2020L, 2021L)
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 100)

  res <- harmonize_regions(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = "current", level = "districts"
  )
  expect_equal(res$boundary_year, 2021L)
})

test_that("harmonize_regions_districts and harmonize_regions_municipalities return identical results", {
  crosswalk <- crosswalk_row("01000001", "01000001", 2020L, 2021L)
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 100)

  a <- harmonize_regions_districts(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = 2021L
  )
  b <- harmonize_regions_municipalities(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = 2021L
  )
  expect_equal(a, b)
})
