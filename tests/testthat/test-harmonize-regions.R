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

test_that("harmonize_regions names the fixed target year of a conversion crosswalk", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000009", 1999L, 2021L),
    crosswalk_row("01000001", "01000009", 2005L, 2021L)
  )
  data <- tibble::tibble(ags = "01000001", year = 1999L, population = 100)

  expect_error(
    harmonize_regions(
      data, crosswalk, "ags", "year", "population",
      type = "absolute", weight = "population", target_year = 2015L, level = "districts"
    ),
    "target_year must be 2021"
  )
})

test_that("harmonize_regions keeps missing inputs missing for absolute values", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000099", 2020L, 2021L),
    crosswalk_row("01000002", "01000099", 2020L, 2021L),
    crosswalk_row("01000003", "01000098", 2020L, 2021L),
    crosswalk_row("01000004", "01000098", 2020L, 2021L)
  )
  data <- tibble::tibble(
    ags = c("01000001", "01000002", "01000003", "01000004"), year = 2020L,
    population = c(NA, NA, 10, NA)
  )

  res <- harmonize_regions(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = 2021L, level = "districts"
  )

  expect_true(is.na(res$population[res$ags == "01000099"]))
  expect_true(is.na(res$population[res$ags == "01000098"]))
})

test_that("harmonize_regions returns NA, not NaN, for an all-missing ratio", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000099", 2020L, 2021L),
    crosswalk_row("01000002", "01000099", 2020L, 2021L)
  )
  data <- tibble::tibble(
    ags = c("01000001", "01000002"), year = 2020L, rate = NA_real_
  )

  res <- harmonize_regions(
    data, crosswalk, "ags", "year", "rate",
    type = "ratio", weight = "population", target_year = 2021L, level = "districts"
  )

  expect_identical(res$rate, NA_real_)
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

# Issue 07: BBSR's annual districts crosswalk has self-mapping rows whose
# share_population sums to far less than 1 (07137000 Mayen-Koblenz, 0.017, for
# 2014->2015 and 2015->2016). Without renormalization the chained absolute
# count shrinks to 0.017^2 of the input.
test_that("absolute conversion renormalizes off-1 shares of a self-mapping AGS across a chain", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000001", 2020L, 2021L, share_population = 0.017),
    crosswalk_row("01000001", "01000001", 2021L, 2022L, share_population = 0.017)
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 1000)

  # Expected warning: the crosswalk's shares were renormalized.
  res <- suppressWarnings(harmonize_regions(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = 2022L, level = "districts"
  ))
  expect_equal(res$population, 1000)
})

test_that("absolute conversion distributes the full count proportionally when split shares sum to 0.9", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000002", 2020L, 2021L, share_population = 0.6),
    crosswalk_row("01000001", "01000003", 2020L, 2021L, share_population = 0.3)
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 900)

  res <- suppressWarnings(harmonize_regions(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = 2021L, level = "districts"
  ))
  expect_equal(res$population[res$ags == "01000002"], 600)
  expect_equal(res$population[res$ags == "01000003"], 300)
})

test_that("shares within tolerance of 1 are left untouched and do not warn", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000002", 2020L, 2021L, share_population = 0.595),
    crosswalk_row("01000001", "01000003", 2020L, 2021L, share_population = 0.40)
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 1000)

  expect_no_warning(res <- harmonize_regions(
    data, crosswalk, "ags", "year", "population",
    type = "absolute", weight = "population", target_year = 2021L, level = "districts"
  ))
  expect_equal(res$population[res$ags == "01000002"], 595)
  expect_equal(res$population[res$ags == "01000003"], 400)
})

test_that("renormalization warns once, naming the affected AGS, the transition and the crosswalk as cause", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000001", 2020L, 2021L, share_population = 0.017),
    crosswalk_row("01000001", "01000001", 2021L, 2022L, share_population = 0.017)
  )
  data <- tibble::tibble(ags = "01000001", year = c(2020L, 2021L), population = 1000)

  warnings <- list()
  withCallingHandlers(
    harmonize_regions(
      data, crosswalk, "ags", "year", "population",
      type = "absolute", weight = "population", target_year = 2022L, level = "districts"
    ),
    warning = function(w) {
      warnings[[length(warnings) + 1L]] <<- conditionMessage(w)
      invokeRestart("muffleWarning")
    }
  )
  expect_length(warnings, 1L)
  expect_match(warnings[[1]], "01000001", fixed = TRUE)
  expect_match(warnings[[1]], "2020 -> 2021", fixed = TRUE)
  expect_match(warnings[[1]], "2021 -> 2022", fixed = TRUE)
  expect_match(warnings[[1]], "crosswalk")
})

test_that("type = 'ratio' ignores off-1 shares and does not warn about them", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000001", 2020L, 2021L, share_population = 0.017),
    crosswalk_row("01000001", "01000001", 2021L, 2022L, share_population = 0.017)
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, rate = 4.2)

  expect_no_warning(res <- harmonize_regions(
    data, crosswalk, "ags", "year", "rate",
    type = "ratio", weight = "population", target_year = 2022L, level = "districts"
  ))
  expect_equal(res$rate, 4.2)
})
