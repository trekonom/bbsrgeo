# One transition per element of `year_from`; each unit maps to itself.
transition_rows <- function(year_from, year_to = year_from + 1L) {
  tibble::tibble(
    ags_old = "01000001",
    ags_new = "01000001",
    year_from = as.integer(year_from),
    year_to = as.integer(year_to)
  )
}

step_years <- function(steps) {
  vapply(
    steps,
    function(step) paste(step$year_from[[1]], step$year_to[[1]]),
    character(1)
  )
}

test_that("a direct transition is one step", {
  crosswalk <- transition_rows(c(2020, 2021, 2022))
  steps <- conversion_steps(crosswalk, 2020L, 2021L, allow_backcast = FALSE)
  expect_equal(step_years(steps), "2020 2021")
})

test_that("a longer path is chained year by year, forward in order", {
  crosswalk <- transition_rows(c(2020, 2021, 2022))
  steps <- conversion_steps(crosswalk, 2020L, 2023L, allow_backcast = FALSE)
  expect_equal(step_years(steps), c("2020 2021", "2021 2022", "2022 2023"))
})

test_that("a direct multi-year transition is preferred to a chain", {
  crosswalk <- rbind(
    transition_rows(2020, 2022),
    transition_rows(c(2020, 2021))
  )
  steps <- conversion_steps(crosswalk, 2020L, 2022L, allow_backcast = FALSE)
  expect_equal(step_years(steps), "2020 2022")
})

test_that("a backcast needs permission and then runs newest step first", {
  crosswalk <- transition_rows(c(2020, 2021, 2022))
  expect_error(
    conversion_steps(crosswalk, 2023L, 2020L, allow_backcast = FALSE),
    "allow_backcast = TRUE"
  )
  steps <- conversion_steps(crosswalk, 2023L, 2020L, allow_backcast = TRUE)
  expect_equal(step_years(steps), c("2022 2023", "2021 2022", "2020 2021"))
})

test_that("a missing year step names the transition", {
  crosswalk <- transition_rows(c(2020, 2022))
  expect_error(
    conversion_steps(crosswalk, 2020L, 2023L, allow_backcast = FALSE),
    "No crosswalk found for the 2021 -> 2022 transition"
  )
})

test_that("a conversion crosswalk names its fixed target year", {
  crosswalk <- transition_rows(c(2018, 2019), year_to = 2020)
  expect_error(
    conversion_steps(crosswalk, 2018L, 2022L, allow_backcast = FALSE),
    "must be 2020"
  )
})

test_that("the target-year rule keeps everything when no transition leads there", {
  crosswalk <- transition_rows(2020)
  expect_equal(
    unmapped_at_target_year(c("01000001", "99999999"), crosswalk, 2022L),
    character()
  )
  expect_equal(
    unmapped_at_target_year(c("01000001", "99999999"), crosswalk, 2021L),
    "99999999"
  )
})
