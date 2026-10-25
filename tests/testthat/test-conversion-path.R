# One transition per element of `year_from`; each unit maps to itself.
transition_rows <- function(year_from, year_to = year_from + 1L) {
  tibble::tibble(
    ags_old = "01000001",
    ags_new = "01000001",
    year_from = as.integer(year_from),
    year_to = as.integer(year_to)
  )
}

# The steps the plan holds for a unit that starts in `start_year`.
plan_steps <- function(
  crosswalk,
  start_year,
  target_year,
  allow_backcast = FALSE
) {
  plan <- plan_conversion(
    "01000001",
    start_year,
    crosswalk,
    target_year,
    allow_backcast
  )
  plan$steps[[as.character(start_year)]]
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
  steps <- plan_steps(crosswalk, 2020L, 2021L, allow_backcast = FALSE)
  expect_equal(step_years(steps), "2020 2021")
})

test_that("a longer path is chained year by year, forward in order", {
  crosswalk <- transition_rows(c(2020, 2021, 2022))
  steps <- plan_steps(crosswalk, 2020L, 2023L, allow_backcast = FALSE)
  expect_equal(step_years(steps), c("2020 2021", "2021 2022", "2022 2023"))
})

test_that("a direct multi-year transition is preferred to a chain", {
  crosswalk <- rbind(
    transition_rows(2020, 2022),
    transition_rows(c(2020, 2021))
  )
  steps <- plan_steps(crosswalk, 2020L, 2022L, allow_backcast = FALSE)
  expect_equal(step_years(steps), "2020 2022")
})

test_that("a backcast needs permission and then runs newest step first", {
  crosswalk <- transition_rows(c(2020, 2021, 2022))
  expect_error(
    plan_steps(crosswalk, 2023L, 2020L, allow_backcast = FALSE),
    "allow_backcast = TRUE"
  )
  steps <- plan_steps(crosswalk, 2023L, 2020L, allow_backcast = TRUE)
  expect_equal(step_years(steps), c("2022 2023", "2021 2022", "2020 2021"))
})

test_that("a missing year step names the transition", {
  crosswalk <- transition_rows(c(2020, 2022))
  expect_error(
    plan_steps(crosswalk, 2020L, 2023L, allow_backcast = FALSE),
    "No crosswalk found for the 2021 -> 2022 transition"
  )
})

test_that("a conversion crosswalk names its fixed target year", {
  crosswalk <- transition_rows(c(2018, 2019), year_to = 2020)
  expect_error(
    plan_steps(crosswalk, 2018L, 2022L, allow_backcast = FALSE),
    "must be 2020"
  )
})

test_that("the target-year rule keeps everything when no transition leads there", {
  crosswalk <- transition_rows(2020)
  data <- c("01000001", "99999999")
  plan <- plan_conversion(data, 2022L, crosswalk, 2022L)
  expect_equal(nrow(plan$dropped), 0)

  plan <- plan_conversion(data, 2021L, crosswalk, 2021L)
  expect_equal(plan$dropped$ags, "99999999")
  expect_equal(plan$dropped$year_from, 2021L)
  expect_equal(plan$dropped$year_to, 2021L)
})

test_that("a plan normalizes the panel and resolves the target year", {
  crosswalk <- transition_rows(c(2020, 2021))
  plan <- plan_conversion(
    c(1000001, 1000001),
    c(2020, 2020),
    crosswalk,
    "current"
  )
  expect_equal(plan$ags, rep("01000001", 2))
  expect_equal(plan$year, c(2020L, 2020L))
  expect_equal(plan$target_year, 2022L)
  expect_equal(names(plan$steps), "2020")
  expect_equal(step_years(plan$steps[["2020"]]), c("2020 2021", "2021 2022"))
})

test_that("a plan lists a unit lost at a later step with that transition", {
  crosswalk <- rbind(
    tibble::tibble(
      ags_old = c("01000001", "01000003"),
      ags_new = c("01000002", "01000003"),
      year_from = 2020L,
      year_to = 2021L
    ),
    tibble::tibble(
      ags_old = "01000003",
      ags_new = "01000003",
      year_from = 2021L,
      year_to = 2022L
    )
  )
  plan <- plan_conversion(
    c("01000001", "01000003", "99999999"),
    2020L,
    crosswalk,
    2022L
  )
  expect_equal(plan$dropped$ags, c("99999999", "01000001"))
  expect_equal(plan$dropped$year_from, c(2020L, 2021L))
  expect_equal(plan$dropped$year_to, c(2021L, 2022L))
})

test_that("a plan aborts on a mixed-level crosswalk", {
  crosswalk <- rbind(transition_rows(2020), transition_rows(2020))
  crosswalk$level <- c("districts", "municipalities")
  expect_error(
    plan_conversion("01000001", 2020L, crosswalk, 2021L),
    "mixes levels"
  )
})

test_that("a step maps from and to in the direction of the conversion", {
  crosswalk <- tibble::tibble(
    ags_old = "01000001",
    ags_new = "01000002",
    year_from = 2020L,
    year_to = 2021L
  )
  forward <- plan_conversion("01000001", 2020L, crosswalk, 2021L)
  step <- forward$steps[["2020"]][[1]]
  expect_equal(c(step$..from, step$..to), c("01000001", "01000002"))

  back <- plan_conversion("01000002", 2021L, crosswalk, 2020L, TRUE)
  step <- back$steps[["2021"]][[1]]
  expect_equal(c(step$..from, step$..to), c("01000002", "01000001"))
})
