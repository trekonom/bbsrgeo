# Helper for synthetic crosswalks in tests
crosswalk_row <- function(
  ags_old,
  ags_new,
  year_from,
  year_to,
  share_area = 1,
  share_population = 1,
  share_employment = NA,
  area_old = 100,
  population_old = 1000,
  employment_old = NA
) {
  tibble::tibble(
    ags_old = ags_old,
    name_old = ags_old,
    ags_new = ags_new,
    name_new = ags_new,
    year_from = year_from,
    year_to = year_to,
    share_area = share_area,
    share_population = share_population,
    share_employment = share_employment,
    area_old = area_old,
    population_old = population_old,
    employment_old = employment_old
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
    ags = c("01000001", "01000002", "01000003"),
    year = 2020L,
    population = c(1000, 2000, 500)
  )

  res <- harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "population",
    type = "absolute",
    weight = "population",
    target_year = 2021L
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
  data <- tibble::tibble(
    ags = c("01000001", "01000002"),
    year = 2020L,
    rate = c(5, 8)
  )

  res <- harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "rate",
    type = "ratio",
    weight = "population",
    target_year = 2021L
  )

  expected <- (5 * 1000 + 8 * 2000) / 3000
  expect_equal(res$rate, expected)
})

test_that("harmonize_regions distributes correctly to multiple target units on a split", {
  # District A splits: 40% (area) / 30% (population) to B, rest to C
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_area = 0.4,
      share_population = 0.3
    ),
    crosswalk_row(
      "01000001",
      "01000003",
      2020L,
      2021L,
      share_area = 0.6,
      share_population = 0.7
    ),
    crosswalk_row("01000002", "01000002", 2020L, 2021L),
    crosswalk_row("01000003", "01000003", 2020L, 2021L)
  )
  data <- tibble::tibble(
    ags = c("01000001", "01000002", "01000003"),
    year = 2020L,
    population = c(1000, 500, 500)
  )

  res <- harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "population",
    type = "absolute",
    weight = "population",
    target_year = 2021L
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
    data,
    crosswalk,
    "ags",
    "year",
    "population",
    type = "absolute",
    weight = "population",
    target_year = 2021L
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
    data,
    crosswalk,
    "ags",
    "year",
    "population",
    type = "absolute",
    weight = "population",
    target_year = 2021L
  )
  expect_equal(res$ags, "01000009")
  expect_equal(res$population, 100)
})

test_that("harmonize_regions aborts on a missing hop in the chain", {
  crosswalk <- crosswalk_row("01000001", "01000001", 2018L, 2019L)
  data <- tibble::tibble(ags = "01000001", year = 2018L, population = 100)

  expect_error(
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      type = "absolute",
      weight = "population",
      target_year = 2021L
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
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      type = "absolute",
      weight = "population",
      target_year = 2015L
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
    ags = c("01000001", "01000002", "01000003", "01000004"),
    year = 2020L,
    population = c(NA, NA, 10, NA)
  )

  res <- harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "population",
    type = "absolute",
    weight = "population",
    target_year = 2021L
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
    ags = c("01000001", "01000002"),
    year = 2020L,
    rate = NA_real_
  )

  res <- harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "rate",
    type = "ratio",
    weight = "population",
    target_year = 2021L
  )

  expect_identical(res$rate, NA_real_)
})

test_that("harmonize_regions errors for employment weights before 1997", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000001", 1995L, 1996L),
    crosswalk_row(
      "01000001",
      "01000001",
      1997L,
      1998L,
      share_employment = 1,
      employment_old = 50
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 1995L, rate = 1)

  expect_error(
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "rate",
      type = "ratio",
      weight = "employment",
      target_year = 1998L
    ),
    "only available for transitions from 1997"
  )
})

test_that("harmonize_regions accepts employment weights from 1997 onward", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000001", 1995L, 1996L),
    crosswalk_row(
      "01000001",
      "01000001",
      1997L,
      1998L,
      share_employment = 1,
      employment_old = 50
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 1997L, rate = 2)

  res <- harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "rate",
    type = "ratio",
    weight = "employment",
    target_year = 1998L
  )
  expect_equal(res$rate, 2)
})

test_that("harmonize_regions refuses backcasting without explicit permission", {
  crosswalk <- crosswalk_row("01000001", "01000099", 2020L, 2021L)
  data <- tibble::tibble(ags = "01000099", year = 2021L, population = 100)

  expect_error(
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      type = "absolute",
      weight = "population",
      target_year = 2020L
    ),
    "backcast"
  )
})

test_that("harmonize_regions performs backcasting with a warning when explicitly allowed", {
  crosswalk <- crosswalk_row("01000001", "01000099", 2020L, 2021L)
  data <- tibble::tibble(ags = "01000099", year = 2021L, population = 100)

  expect_warning(
    res <- harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      type = "absolute",
      weight = "population",
      target_year = 2020L,
      allow_backcast = TRUE
    ),
    "experimental"
  )
  expect_equal(res$ags, "01000001")
})

test_that("a backcast over several years warns once", {
  crosswalk <- rbind(
    crosswalk_row("01000001", "01000001", 2020L, 2021L),
    crosswalk_row("01000001", "01000001", 2021L, 2022L)
  )
  data <- tibble::tibble(
    ags = "01000001",
    year = c(2021L, 2022L),
    population = 100
  )

  warnings <- character()
  withCallingHandlers(
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      type = "absolute",
      weight = "population",
      target_year = 2020L,
      allow_backcast = TRUE
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(grep("experimental", warnings), 1)
})

test_that("target_year = 'current' uses the most recent available boundary", {
  crosswalk <- crosswalk_row("01000001", "01000009", 2020L, 2021L)
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 100)

  res <- harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "population",
    type = "absolute",
    weight = "population",
    target_year = "current"
  )
  expect_equal(res$boundary_year, 2021L)
})

test_that("a crosswalk that mixes levels is an error", {
  crosswalk <- dplyr::bind_rows(
    dplyr::mutate(
      crosswalk_row("01000001", "01000001", 2020L, 2021L),
      level = "districts"
    ),
    dplyr::mutate(
      crosswalk_row("01001001", "01001001", 2020L, 2021L),
      level = "municipalities"
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 100)

  expect_error(
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      target_year = 2021L
    ),
    "mixes levels \\(districts, municipalities\\)"
  )
  expect_error(
    check_regions(data, crosswalk, "ags", "year", 2021L),
    "mixes levels"
  )
})

test_that("a crosswalk of one level converts, with or without a level column", {
  plain <- crosswalk_row("01000001", "01000009", 2020L, 2021L)
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 100)
  convert <- function(crosswalk) {
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      target_year = 2021L
    )
  }
  expect_equal(
    convert(dplyr::mutate(plain, level = "municipalities")),
    convert(plain)
  )
})

# Issue 07: BBSR's annual districts crosswalk has self-mapping rows whose
# share_population sums to far less than 1 (07137000 Mayen-Koblenz, 0.017, for
# 2014->2015 and 2015->2016). Without renormalization the chained absolute
# count shrinks to 0.017^2 of the input.
test_that("absolute conversion renormalizes off-1 shares of a self-mapping AGS across a chain", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000001",
      2020L,
      2021L,
      share_population = 0.017
    ),
    crosswalk_row(
      "01000001",
      "01000001",
      2021L,
      2022L,
      share_population = 0.017
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 1000)

  # Expected warning: the crosswalk's shares were renormalized.
  res <- suppressWarnings(harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "population",
    type = "absolute",
    weight = "population",
    target_year = 2022L
  ))
  expect_equal(res$population, 1000)
})

test_that("the single-row share fix leaves the converted values unchanged and ends the renormalization", {
  fixes <- crosswalk_fixes[
    crosswalk_fixes$id == "district-single-row-shares-2014-2015",
  ]
  # All four self-mapping rows, as published (the fix applies as a whole).
  published <- dplyr::bind_rows(lapply(
    list(
      c("07135000", 2014, 0.96166294, 0.98284864, 0.996122263),
      c("07137000", 2014, 0.03833706, 0.01715136, 0.003877737),
      c("07135000", 2015, 0.96166294, 0.98284864, 0.996122263),
      c("07137000", 2015, 0.03833706, 0.01715136, 0.003877737)
    ),
    function(r) {
      crosswalk_row(
        r[[1]],
        r[[1]],
        as.integer(r[[2]]),
        as.integer(r[[2]]) + 1L,
        share_area = as.numeric(r[[3]]),
        share_population = as.numeric(r[[4]]),
        share_employment = as.numeric(r[[5]])
      )
    }
  ))
  published$name_old <- published$name_new <- ifelse(
    published$ags_old == "07135000",
    "Cochem-Zell",
    "Mayen-Koblenz"
  )
  fixed <- suppressMessages(apply_crosswalk_fixes(published, fixes))
  expect_equal(fixed$share_population, rep(1, 4))

  data <- tibble::tibble(
    ags = c("07135000", "07137000"),
    year = 2014L,
    population = c(1000, 500)
  )
  convert <- function(crosswalk) {
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      type = "absolute",
      weight = "population",
      target_year = 2015L
    )
  }
  expect_no_message(expect_no_warning(res_fixed <- convert(fixed)))
  res_published <- suppressWarnings(suppressMessages(convert(published)))
  expect_equal(res_fixed, res_published)
  expect_equal(res_fixed$population, c(1000, 500))
})

test_that("absolute conversion distributes the full count proportionally when split shares sum to 0.9", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000002", 2020L, 2021L, share_population = 0.6),
    crosswalk_row("01000001", "01000003", 2020L, 2021L, share_population = 0.3)
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 900)

  res <- suppressWarnings(harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "population",
    type = "absolute",
    weight = "population",
    target_year = 2021L
  ))
  expect_equal(res$population[res$ags == "01000002"], 600)
  expect_equal(res$population[res$ags == "01000003"], 300)
})

test_that("shares within tolerance of 1 are rescaled to sum to 1 and do not warn", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_population = 0.595
    ),
    crosswalk_row("01000001", "01000003", 2020L, 2021L, share_population = 0.40)
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 1000)

  expect_message(
    res <- expect_no_warning(
      harmonize_regions(
        data,
        crosswalk,
        "ags",
        "year",
        "population",
        type = "absolute",
        weight = "population",
        target_year = 2021L
      )
    ),
    "deviate slightly from 1"
  )
  # Sum 0.995, rescaled: 1000 * 0.595 / 0.995 and 1000 * 0.40 / 0.995.
  expect_equal(res$population[res$ags == "01000002"], 598, tolerance = 1e-3)
  expect_equal(res$population[res$ags == "01000003"], 402, tolerance = 1e-3)
  expect_equal(sum(res$population), 1000)
})

test_that("renormalization warns once, naming the affected AGS, the transition and the crosswalk as cause", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000001",
      2020L,
      2021L,
      share_population = 0.017
    ),
    crosswalk_row(
      "01000001",
      "01000001",
      2021L,
      2022L,
      share_population = 0.017
    )
  )
  data <- tibble::tibble(
    ags = "01000001",
    year = c(2020L, 2021L),
    population = 1000
  )

  warnings <- list()
  withCallingHandlers(
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      type = "absolute",
      weight = "population",
      target_year = 2022L
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

# A unit without inhabitants has share_population 1 on every target row in the
# BBSR crosswalks (e.g. 09671456 Rohrbrunner Forst, 2020: population_old 0,
# share_population 1 / 1 / 1, share_area 0.01 / 0.49 / 0.50): a share of 1 on
# every target row cannot be a split.
zero_population_split <- function() {
  dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_area = 0.25,
      share_population = 1,
      population_old = 0
    ),
    crosswalk_row(
      "01000001",
      "01000003",
      2020L,
      2021L,
      share_area = 0.75,
      share_population = 1,
      population_old = 0
    )
  )
}

test_that("a zero-population source unit is split by area share without a warning", {
  data <- tibble::tibble(ags = "01000001", year = 2020L, value = 100)

  res <- expect_no_warning(harmonize_regions(
    data,
    zero_population_split(),
    "ags",
    "year",
    "value",
    type = "absolute",
    weight = "population",
    target_year = 2021L
  ))
  expect_equal(res$value[res$ags == "01000002"], 25)
  expect_equal(res$value[res$ags == "01000003"], 75)
})

test_that("zero-population units are not named in the warning for other off-1 shares", {
  crosswalk <- dplyr::bind_rows(
    zero_population_split(),
    crosswalk_row("01000009", "01000009", 2020L, 2021L, share_population = 0.5)
  )
  data <- tibble::tibble(
    ags = c("01000001", "01000009"),
    year = 2020L,
    value = c(100, 10)
  )

  warnings <- character()
  res <- withCallingHandlers(
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "value",
      type = "absolute",
      weight = "population",
      target_year = 2021L
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(warnings, 1)
  expect_match(warnings, "01000009", fixed = TRUE)
  expect_no_match(warnings, "01000001", fixed = TRUE)
  expect_equal(res$value[res$ags == "01000009"], 10)
  expect_equal(res$value[res$ags == "01000002"], 25)
})

test_that("a zero-area unit under weight = 'area' is still renormalized with a warning", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_area = 1,
      area_old = 0
    ),
    crosswalk_row(
      "01000001",
      "01000003",
      2020L,
      2021L,
      share_area = 1,
      area_old = 0
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, value = 100)

  # Expected warning: the crosswalk's share_area do not sum to 1 (no area to
  # fall back on, so the shares are renormalized evenly).
  res <- suppressWarnings(harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "value",
    type = "absolute",
    weight = "area",
    target_year = 2021L
  ))
  expect_equal(res$value[res$ags == "01000002"], 50)
  expect_equal(res$value[res$ags == "01000003"], 50)
})

test_that("a zero-employment source unit is split by area share under weight = 'employment'", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_area = 0.25,
      share_employment = 1,
      employment_old = 0
    ),
    crosswalk_row(
      "01000001",
      "01000003",
      2020L,
      2021L,
      share_area = 0.75,
      share_employment = 1,
      employment_old = 0
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, value = 100)

  res <- expect_no_warning(harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "value",
    type = "absolute",
    weight = "employment",
    target_year = 2021L
  ))
  expect_equal(res$value[res$ags == "01000002"], 25)
  expect_equal(res$value[res$ags == "01000003"], 75)
})

# Four municipalities in the 1990-2000 file (e.g. 12039430 Schoenermark, 1992)
# have share_population 1 on every target row although their counts are
# non-zero and differ by row (0.21 / 0.48), read here as the parts going to each
# target (observed in the file, see .scratch/crosswalk-read-municipal issue 05).
test_that("off-1 shares are replaced by count shares when the counts are the parts", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_population = 1,
      population_old = 300
    ),
    crosswalk_row(
      "01000001",
      "01000003",
      2020L,
      2021L,
      share_population = 1,
      population_old = 700
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, value = 100)

  res <- expect_no_warning(harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "value",
    type = "absolute",
    weight = "population",
    target_year = 2021L
  ))
  expect_equal(res$value[res$ags == "01000002"], 30)
  expect_equal(res$value[res$ags == "01000003"], 70)
})

test_that("off-1 shares are renormalized, with a warning, when the count is the unit's total on every row", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_population = 1,
      population_old = 1000
    ),
    crosswalk_row(
      "01000001",
      "01000003",
      2020L,
      2021L,
      share_population = 1,
      population_old = 1000
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, value = 100)

  # Expected warning: the crosswalk's share_population do not sum to 1.
  res <- suppressWarnings(harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "value",
    type = "absolute",
    weight = "population",
    target_year = 2021L
  ))
  expect_equal(res$value[res$ags == "01000002"], 50)
  expect_equal(res$value[res$ags == "01000003"], 50)
})

test_that("count shares also apply under weight = 'area'", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_area = 1,
      area_old = 25
    ),
    crosswalk_row(
      "01000001",
      "01000003",
      2020L,
      2021L,
      share_area = 1,
      area_old = 75
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, value = 100)

  res <- expect_no_warning(harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "value",
    type = "absolute",
    weight = "area",
    target_year = 2021L
  ))
  expect_equal(res$value[res$ags == "01000002"], 25)
  expect_equal(res$value[res$ags == "01000003"], 75)
})

test_that("equal counts are not read as parts: they may be the unit's total repeated", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_population = 1,
      population_old = 500
    ),
    crosswalk_row(
      "01000001",
      "01000003",
      2020L,
      2021L,
      share_population = 1,
      population_old = 500
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, value = 100)

  # Expected warning: the crosswalk's share_population do not sum to 1.
  res <- suppressWarnings(harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "value",
    type = "absolute",
    weight = "population",
    target_year = 2021L
  ))
  expect_equal(res$value[res$ags == "01000002"], 50)
  expect_equal(res$value[res$ags == "01000003"], 50)
})

test_that("a partly missing population count is not read as parts", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_population = 1,
      population_old = 300
    ),
    crosswalk_row(
      "01000001",
      "01000003",
      2020L,
      2021L,
      share_population = 1,
      population_old = NA
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, value = 100)

  # Expected warning: the crosswalk's share_population do not sum to 1.
  res <- suppressWarnings(harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "value",
    type = "absolute",
    weight = "population",
    target_year = 2021L
  ))
  expect_equal(res$value[res$ags == "01000002"], 50)
  expect_equal(res$value[res$ags == "01000003"], 50)
})

test_that("a missing population count is not treated as zero population", {
  crosswalk <- zero_population_split()
  crosswalk$population_old <- NA_real_
  data <- tibble::tibble(ags = "01000001", year = 2020L, value = 100)

  # Expected warning: the crosswalk's share_population do not sum to 1.
  res <- suppressWarnings(harmonize_regions(
    data,
    crosswalk,
    "ags",
    "year",
    "value",
    type = "absolute",
    weight = "population",
    target_year = 2021L
  ))
  expect_equal(res$value[res$ags == "01000002"], 50)
  expect_equal(res$value[res$ags == "01000003"], 50)
})

test_that("type = 'ratio' ignores off-1 shares and does not warn about them", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000001",
      2020L,
      2021L,
      share_population = 0.017
    ),
    crosswalk_row(
      "01000001",
      "01000001",
      2021L,
      2022L,
      share_population = 0.017
    )
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, rate = 4.2)

  expect_no_warning(
    res <- harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "rate",
      type = "ratio",
      weight = "population",
      target_year = 2022L
    )
  )
  expect_equal(res$rate, 4.2)
})

test_that("harmonize_regions drops and warns about an unmapped AGS in the target year", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000001", 2020L, 2021L),
    crosswalk_row("01000002", "01000002", 2020L, 2021L)
  )
  data <- tibble::tibble(
    ags = c("01000001", "01000002", "01000009", "01000001", "01000009"),
    year = c(2020L, 2020L, 2020L, 2021L, 2021L),
    population = c(10, 20, 30, 11, 33)
  )

  # 01000009 is unknown to the crosswalk: it is dropped in 2020 and, under the
  # same rule, in the target year 2021 - reported in one warning.
  warnings <- testthat::capture_warnings(
    res <- harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      target_year = 2021L
    )
  )
  expect_length(warnings, 1)
  expect_match(warnings, "2 area unit/year combination.*01000009")
  expect_match(warnings, "check_regions\\(\\).*complete list")
  expect_equal(attr(res, "unmapped")$ags, c("01000009", "01000009"))
  expect_equal(attr(res, "unmapped")$year, c(2020L, 2021L))

  expect_false("01000009" %in% res$ags)
  expect_equal(res$population[res$ags == "01000001" & res$year == 2021L], 11)
})

test_that("harmonize_regions passes mapped target-year rows through unchanged", {
  crosswalk <- crosswalk_row("01000001", "01000001", 2020L, 2021L)
  data <- tibble::tibble(
    ags = "01000001",
    year = 2021L,
    population = 42
  )

  expect_no_warning(
    res <- harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      target_year = 2021L
    )
  )
  expect_equal(res$population, 42)
})

test_that("harmonize_regions leaves target-year rows alone when no transition leads into the target year", {
  crosswalk <- crosswalk_row("01000001", "01000001", 2020L, 2021L)
  data <- tibble::tibble(ags = "01000009", year = 2020L, population = 5)

  expect_no_warning(
    res <- harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      target_year = 2020L
    )
  )
  expect_equal(res$ags, "01000009")
})

test_that("a share sum within the tolerance is renormalized, with a message and no warning", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row(
      "01000001",
      "01000002",
      2020L,
      2021L,
      share_population = 0.66
    ),
    crosswalk_row("01000001", "01000003", 2020L, 2021L, share_population = 0.33)
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 990)

  expect_message(
    res <- expect_no_warning(harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      type = "absolute",
      target_year = 2021L
    )),
    "01000001 \\(2020 -> 2021, sum 0.9900\\)"
  )
  expect_equal(sum(res$population), 990)
  expect_equal(sort(res$population), c(330, 660))
})

test_that("renormalize = FALSE uses the shares as given and reports the deviation", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000002", 2020L, 2021L, share_population = 0.6),
    crosswalk_row("01000001", "01000003", 2020L, 2021L, share_population = 0.3)
  )
  data <- tibble::tibble(ags = "01000001", year = 2020L, population = 1000)

  expect_message(
    res <- expect_no_warning(harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      type = "absolute",
      target_year = 2021L,
      renormalize = FALSE
    )),
    "used as given.*01000001 \\(2020 -> 2021, sum 0.9000\\)"
  )
  expect_equal(sort(res$population), c(300, 600))
})

test_that("the unmapped warning names several cases, capped", {
  crosswalk <- crosswalk_row("01000001", "01000001", 2020L, 2021L)
  ags <- sprintf("010001%02d", 10:17)
  data <- tibble::tibble(ags = ags, year = 2020L, population = 1)

  warning <- testthat::capture_warnings(
    harmonize_regions(
      data,
      crosswalk,
      "ags",
      "year",
      "population",
      target_year = 2021L
    )
  )
  expect_match(warning, "8 area unit/year combination")
  expect_equal(
    lengths(regmatches(warning, gregexpr("01000[0-9]+ in", warning))),
    5
  )
})

test_that("a step refuses shares from rows that do not match the plan", {
  crosswalk <- dplyr::bind_rows(
    crosswalk_row("01000001", "01000001", 2020L, 2021L),
    crosswalk_row("01000002", "01000002", 2020L, 2021L)
  )
  plan <- plan_conversion(c("01000001", "01000002"), 2020L, crosswalk, 2021L)
  group <- tibble::tibble(
    ..ags = c("01000001", "01000002"),
    ..year = 2020L,
    population = 1
  )
  step <- plan$steps[["2020"]][[1]]
  expect_no_error(
    harmonize_step(
      group,
      step,
      crosswalk,
      "population",
      "absolute",
      "population"
    )
  )
  expect_error(
    harmonize_step(
      group,
      step,
      crosswalk[2:1, ],
      "population",
      "absolute",
      "population"
    )
  )
})
