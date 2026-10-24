deviation_crosswalk <- function(...) {
  tibble::tibble(...)
}

test_that("groups differing in year_to are separate transition groups", {
  cw <- deviation_crosswalk(
    ags_old = "01001000",
    year_from = 2000,
    year_to = c(2001, 2001, 2002),
    share_area = c(0.4, 0.6, 0.5),
    area_old = c(40, 60, 100)
  )
  classified <- classify_share_deviations(cw, "area")
  expect_equal(classified$share_sum, c(1, 1, 0.5))
  expect_equal(classified$treatment, c("ok", "ok", "renormalize"))
  expect_equal(classified$share, c(0.4, 0.6, 1))
})

test_that("a sum of 0 or less is left as it is", {
  cw <- deviation_crosswalk(
    ags_old = c("a", "b"),
    year_from = 2000,
    year_to = 2001,
    share_area = c(0, -0.5),
    area_old = c(1, 2)
  )
  classified <- classify_share_deviations(cw, "area")
  expect_equal(classified$treatment, c("ok", "ok"))
  expect_equal(classified$share, c(0, -0.5))
})

test_that("a sum exactly at the tolerance is rounding, beyond it is not", {
  cw <- deviation_crosswalk(
    ags_old = c("a", "a", "a", "b", "b"),
    year_from = 2000,
    year_to = 2001,
    share_area = c(rep(0.33, 3), 0.5, 0.5),
    area_old = c(rep(10, 3), 10, 10)
  )
  classified <- classify_share_deviations(cw, "area")
  expect_equal(classified$treatment, c(rep("rounding", 3), rep("ok", 2)))
  expect_equal(classified$share[1:3], rep(1 / 3, 3))

  beyond <- classify_share_deviations(
    deviation_crosswalk(
      ags_old = "a",
      year_from = 2000,
      year_to = 2001,
      share_area = c(0.5, 0.48),
      area_old = c(10, 10)
    ),
    "area"
  )
  expect_equal(beyond$treatment, c("renormalize", "renormalize"))
  expect_equal(sum(beyond$share), 1)
})

test_that("counts that differ between rows are read as parts", {
  cw <- deviation_crosswalk(
    ags_old = "12039430",
    year_from = 1992,
    year_to = 1993,
    share_area = c(1, 1),
    area_old = c(30, 70)
  )
  classified <- classify_share_deviations(cw, "area")
  expect_equal(classified$treatment, c("parts", "parts"))
  expect_equal(classified$share, c(0.3, 0.7))
})

test_that("equal counts are renormalized, not read as parts", {
  cw <- deviation_crosswalk(
    ags_old = "a",
    year_from = 2000,
    year_to = 2001,
    share_area = c(1, 1),
    area_old = c(50, 50)
  )
  classified <- classify_share_deviations(cw, "area")
  expect_equal(classified$treatment, c("renormalize", "renormalize"))
  expect_equal(classified$share, c(0.5, 0.5))
})

test_that("a missing count prevents the parts treatment", {
  cw <- deviation_crosswalk(
    ags_old = "a",
    year_from = 2000,
    year_to = 2001,
    share_population = c(1, 1),
    population_old = c(30, NA)
  )
  classified <- classify_share_deviations(cw, "population")
  expect_equal(classified$treatment, c("renormalize", "renormalize"))
})

test_that("a negative count prevents the parts treatment", {
  cw <- deviation_crosswalk(
    ags_old = "a",
    year_from = 2000,
    year_to = 2001,
    share_area = c(1, 1),
    area_old = c(-1, 5)
  )
  expect_equal(
    classify_share_deviations(cw, "area")$treatment,
    c("renormalize", "renormalize")
  )
})

test_that("a zero basis is split by area share, except for the area basis", {
  cw <- deviation_crosswalk(
    ags_old = "09671456",
    year_from = 2019,
    year_to = 2020,
    share_area = c(0.25, 0.75),
    share_population = c(1, 1),
    area_old = c(10, 30),
    population_old = c(0, 0)
  )
  classified <- classify_share_deviations(cw, "population")
  expect_equal(classified$treatment, c("zero_basis", "zero_basis"))
  expect_equal(classified$share, c(0.25, 0.75))
})

test_that("a zero basis without area shares is renormalized", {
  cw <- deviation_crosswalk(
    ags_old = "a",
    year_from = 2000,
    year_to = 2001,
    share_area = c(0, 0),
    share_population = c(1, 1),
    population_old = c(0, 0)
  )
  expect_equal(
    classify_share_deviations(cw, "population")$treatment,
    c("renormalize", "renormalize")
  )
})

test_that("an absent count or share column does not error", {
  cw <- deviation_crosswalk(
    ags_old = "a",
    year_from = 2000,
    year_to = 2001,
    share_area = c(0.4, 0.6)
  )
  classified <- classify_share_deviations(cw, "employment")
  expect_equal(nrow(classified), 2)
  expect_equal(classified$treatment, c("ok", "ok"))
  expect_true(all(is.na(classified$share_sum)))
  expect_false(any(classified$count_gap_exceeds_resolution))

  area_only <- classify_share_deviations(cw, "area")
  expect_equal(area_only$treatment, c("ok", "ok"))
  expect_true(all(is.na(area_only$count_gap)))
})

test_that("the share sum ignores a missing share", {
  cw <- deviation_crosswalk(
    ags_old = "a",
    year_from = 2000,
    year_to = 2001,
    share_area = c(0.4, NA),
    area_old = c(4, 6)
  )
  expect_equal(classify_share_deviations(cw, "area")$share_sum, c(0.4, 0.4))
})

test_that("a count gap is measured only where shares sum to 1 and counts differ", {
  cw <- deviation_crosswalk(
    ags_old = c("agree", "agree", "gap", "gap", "equal", "equal"),
    year_from = 2000,
    year_to = 2001,
    share_area = c(0.3, 0.7, 0.5, 0.5, 0.5, 0.5),
    area_old = c(30, 70, 30, 70, 50, 50)
  )
  classified <- classify_share_deviations(cw, "area")
  expect_equal(classified$count_gap[1:2], c(0, 0))
  expect_equal(classified$count_gap[3:4], c(0.2, 0.2))
  expect_true(all(is.na(classified$count_gap[5:6])))
  expect_equal(
    classified$count_gap_exceeds_resolution,
    c(FALSE, FALSE, TRUE, TRUE, FALSE, FALSE)
  )
})

test_that("share_deviation_patterns names a, b and c", {
  cw <- deviation_crosswalk(
    ags_old = c("a", "a", "b", "c", "c", "d", "d"),
    year_from = 2000,
    year_to = 2001,
    share_area = c(1, 1, 0.9, 0.5, 0.3, 0.4, 0.6),
    area_old = c(15, 6, 10, 10, 10, 4, 6)
  )
  patterns <- share_deviation_patterns(cw)
  expect_equal(
    patterns$pattern,
    c("a", "a", "b", "c", "c", NA, NA)
  )
  expect_equal(patterns$share_sum[1], 2)
})
