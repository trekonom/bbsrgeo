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

test_that("a backcast needs permission and then runs newest step first", {
  crosswalk <- transition_rows(c(2020, 2021, 2022))
  expect_error(
    conversion_steps(crosswalk, 2023L, 2020L, allow_backcast = FALSE),
    "allow_backcast = TRUE"
  )
  steps <- conversion_steps(crosswalk, 2023L, 2020L, allow_backcast = TRUE)
  expect_equal(step_years(steps), c("2022 2023", "2021 2022", "2020 2021"))
})
