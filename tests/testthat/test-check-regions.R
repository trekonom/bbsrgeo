# One row per transition of a unit: `from` -> `to` between the given years.
path_crosswalk <- function(from, to, year_from, year_to) {
  tibble::tibble(
    ags_old = from,
    ags_new = to,
    year_from = as.integer(year_from),
    year_to = as.integer(year_to),
    share_area = 1,
    share_population = 1,
    share_employment = 1,
    area_old = 10,
    population_old = 100,
    employment_old = 50
  )
}

test_that("check_regions recognizes fully matched data", {
  crosswalk <- path_crosswalk("01000001", "01000001", 2020, 2021)
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 100)

  expect_message(
    res <- check_regions(data, crosswalk, "ags", "year", 2021L),
    "All 1 rows"
  )
  expect_equal(nrow(res), 0)
})

test_that("check_regions finds a unit without an entry in the first transition", {
  crosswalk <- path_crosswalk("01000001", "01000001", 2020, 2021)
  data <- tibble::tibble(
    ags = c("01000001", "99999999"),
    year = 2020L,
    population = c(100, 50)
  )

  expect_message(
    res <- check_regions(data, crosswalk, "ags", "year", 2021L),
    "1 of 2 rows.*99999999 in 2020: no entry in the 2020 -> 2021 transition"
  )
  expect_equal(res$ags, "99999999")
})

test_that("check_regions finds a unit lost at a later step of a chain", {
  # 01000001 maps to 01000002 in 2020 -> 2021, which the 2021 -> 2022
  # transition does not know.
  crosswalk <- rbind(
    path_crosswalk("01000001", "01000002", 2020, 2021),
    path_crosswalk("01000003", "01000003", 2020, 2021),
    path_crosswalk("01000003", "01000003", 2021, 2022)
  )
  data <- tibble::tibble(
    ags = c("01000001", "01000003"),
    year = 2020L,
    population = 1
  )

  expect_message(
    res <- check_regions(data, crosswalk, "ags", "year", 2022L),
    "no entry in the 2021 -> 2022 transition"
  )
  expect_equal(res$ags, "01000001")
})

test_that("check_regions applies the unmapped rule to rows at the target year", {
  crosswalk <- path_crosswalk("01000001", "01000001", 2020, 2021)
  data <- tibble::tibble(
    ags = c("01000001", "99999999"),
    year = 2021L,
    population = 1
  )

  expect_message(
    res <- check_regions(data, crosswalk, "ags", "year", 2021L),
    "not an ags_new of any transition into the target year"
  )
  expect_equal(res$ags, "99999999")
})

test_that("check_regions keeps rows at the target year when no transition leads there", {
  crosswalk <- path_crosswalk("01000001", "01000001", 2020, 2021)
  data <- tibble::tibble(ags = "99999999", year = 2022L, population = 1)
  expect_message(
    res <- check_regions(data, crosswalk, "ags", "year", 2022L),
    "All 1 rows"
  )
  expect_equal(nrow(res), 0)
})

test_that("check_regions errors like harmonize_regions for an uncovered path", {
  crosswalk <- path_crosswalk("01000001", "01000001", 2020, 2021)
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 1)

  expect_error(
    check_regions(data, crosswalk, "ags", "year", 2023L),
    "No crosswalk found for the 2021 -> 2022 transition"
  )
  expect_error(
    check_regions(data, crosswalk, "ags", "year", 2019L),
    "allow_backcast = TRUE"
  )
})

test_that("check_regions reports exactly the rows harmonize_regions drops", {
  crosswalk <- rbind(
    path_crosswalk("01000001", "01000002", 2020, 2021),
    path_crosswalk("01000003", "01000003", 2020, 2021),
    path_crosswalk("01000004", "01000004", 2020, 2021),
    path_crosswalk("01000003", "01000003", 2021, 2022),
    path_crosswalk("01000004", "01000004", 2021, 2022)
  )
  data <- tibble::tibble(
    ags = c("01000001", "01000003", "01000004", "99999999", "01000004"),
    year = c(2020L, 2020L, 2020L, 2020L, 2021L),
    population = 1
  )

  reported <- suppressMessages(
    check_regions(data, crosswalk, "ags", "year", 2022L)
  )
  converted <- suppressWarnings(
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      target_year = 2022L,
      level = "districts"
    )
  )
  # Every data row the check does not report converts to a unit of the target
  # year; the reported ones are the rows that contribute nothing.
  kept <- data[
    !(paste(data$ags, data$year) %in%
      paste(reported$ags, reported$year)),
  ]
  expect_equal(sum(converted$population), nrow(kept))
  expect_equal(sort(reported$ags), c("01000001", "99999999"))
})
