# Constructed crosswalk rows for bbsrgeo_check_share_sums(): `ags` is the old
# unit, one target row per element of `share`.
share_rows <- function(ags, share, area_old = rep(10, length(share))) {
  tibble::tibble(
    ags_old = ags,
    ags_new = sprintf("%s%d", substr(ags, 1, 7), seq_along(share)),
    year_from = 2000L,
    year_to = 2001L,
    share_area = share,
    share_population = share,
    area_old = area_old,
    population_old = area_old
  )
}

test_that("a share sum exactly at the tolerance is not reported", {
  d <- share_rows("01001000", rep(0.33, 3))
  expect_null(bbsrgeo_check_share_sums(d))
})

test_that("a clean group is not reported", {
  d <- share_rows("01001000", c(0.4, 0.6))
  expect_null(bbsrgeo_check_share_sums(d))
})

test_that("a share of 1 on every row with differing counts is named as such", {
  d <- rbind(
    share_rows("12039430", c(1, 1), area_old = c(15.099, 6.471)),
    share_rows("12043470", c(1, 1), area_old = c(3, 4))
  )
  f <- bbsrgeo_check_share_sums(d)
  expect_equal(f$severity, "warning")
  expect_length(f$items, 1)
  expect_match(f$items[[1]]$label, "share of 1 on every target row.*differ")
  expect_equal(f$items[[1]]$n, 2)
  expect_equal(
    f$items[[1]]$examples,
    "ags_old = '12039430', year_from = 2000: sum = 2.000"
  )
})

test_that("a single row with a share below 1 is named as such", {
  f <- bbsrgeo_check_share_sums(share_rows("07135000", 0.962))
  expect_match(f$items[[1]]$label, "single target row")
  expect_equal(f$items[[1]]$n, 1)
  expect_match(f$items[[1]]$examples, "ags_old = '07135000'")
})

test_that("any other deviation is named as such", {
  f <- bbsrgeo_check_share_sums(share_rows("01001000", c(0.5, 0.3)))
  expect_match(f$items[[1]]$label, "other")
  expect_match(f$items[[1]]$examples, "ags_old = '01001000'")
})

test_that("a share of 1 on every row with equal counts is 'other'", {
  f <- bbsrgeo_check_share_sums(share_rows("01001000", c(1, 1)))
  expect_match(f$items[[1]]$label, "other")
})

test_that("the finding does not name a cause and asks to check the file", {
  f <- bbsrgeo_check_share_sums(share_rows("07135000", 0.962))
  expect_false(grepl("caused by", f$header))
  expect_match(f$hint, "check the original file")
})

test_that("each pattern present is counted and exemplified once", {
  d <- rbind(
    share_rows("12039430", c(1, 1), area_old = c(15, 6)),
    share_rows("07135000", 0.962),
    share_rows("01001000", c(0.5, 0.3))
  )
  f <- bbsrgeo_check_share_sums(d)
  expect_length(f$items, 3)
  expect_match(f$header, "^3 ags_old/year_from combination")
  examples <- vapply(f$items, function(i) i$examples, character(1))
  expect_match(examples[[1]], "12039430")
  expect_match(examples[[2]], "07135000")
  expect_match(examples[[3]], "01001000")
})

# Constructed rows for bbsrgeo_check_names(): one row per element of `name_old`
# (and `name_new`), all in one transition.
name_rows <- function(
  ags_old,
  name_old,
  ags_new = "01001001",
  name_new = "Neu"
) {
  tibble::tibble(
    ags_old = ags_old,
    name_old = name_old,
    ags_new = ags_new,
    name_new = name_new,
    year_from = 2011L,
    year_to = 2012L
  )
}

test_that("consistent names are not reported", {
  d <- name_rows(c("01001000", "01001000"), c("Alt", "Alt"))
  expect_null(bbsrgeo_check_names(d))
})

test_that("two names under one ags_old are reported with codes, transition and names", {
  d <- name_rows(
    c("07235000", "07235000"),
    c("Bernkastel-Wittlich", "Trier-Saarburg")
  )
  f <- bbsrgeo_check_names(d)
  expect_equal(f$severity, "warning")
  expect_length(f$items, 1)
  expect_match(f$items[[1]]$label, "^ags_old group")
  expect_equal(f$items[[1]]$n, 1)
  expect_equal(
    f$items[[1]]$examples,
    "ags_old '07235000' (2011 -> 2012): 'Bernkastel-Wittlich', 'Trier-Saarburg'"
  )
})

test_that("two names under one ags_new are reported", {
  d <- name_rows(
    c("01001000", "01002000"),
    c("A", "B"),
    ags_new = c("01001001", "01001001"),
    name_new = c("Neu", "Anders")
  )
  f <- bbsrgeo_check_names(d)
  expect_match(f$items[[1]]$label, "^ags_new group")
  expect_equal(
    f$items[[1]]$examples,
    "ags_new '01001001' (2011 -> 2012): 'Neu', 'Anders'"
  )
})

test_that("missing names are ignored", {
  d <- name_rows(c("01001000", "01001000", "01001000"), c("Alt", NA, "Alt"))
  expect_null(bbsrgeo_check_names(d))
  d <- name_rows(c("01001000", "01001000"), c(NA_character_, NA_character_))
  expect_null(bbsrgeo_check_names(d))
})

test_that("a crosswalk without name columns does not error", {
  d <- name_rows("01001000", "Alt")[c(
    "ags_old",
    "ags_new",
    "year_from",
    "year_to"
  )]
  expect_null(bbsrgeo_check_names(d))
})

# Constructed rows for bbsrgeo_check_count_shares(): the area shares and counts
# of one old unit (`share` and `area_old` per target row).
count_rows <- function(ags, share, area_old) {
  tibble::tibble(
    ags_old = ags,
    year_from = 2000L,
    year_to = 2001L,
    share_area = share,
    area_old = area_old
  )
}

test_that("shares that agree with their counts are not reported", {
  d <- count_rows("01001000", c(0.25, 0.75), c(25, 75))
  expect_null(bbsrgeo_check_count_shares(d))
})

test_that("shares that disagree with their counts are reported with an example", {
  d <- count_rows("01001000", c(0.5, 0.5), c(25, 75))
  f <- bbsrgeo_check_count_shares(d)
  expect_equal(f$severity, "message")
  expect_length(f$items, 1)
  expect_equal(f$items[[1]]$scope, "area")
  expect_equal(f$items[[1]]$n, 1)
  expect_equal(
    f$items[[1]]$examples,
    "ags_old = '01001000', year_from = 2000, largest deviation 0.2500"
  )
  expect_match(f$hint, "as given")
})

test_that("a deviation within the counts' resolution is not reported", {
  # Counts rounded to 0.1 on a total of 1: count / total is off by up to
  # 0.05 * (1 + 2) / 1 = 0.15 (COUNT_RESOLUTION, bound per row).
  d <- count_rows("01001000", c(0.3, 0.7), c(0.4, 0.6))
  expect_null(bbsrgeo_check_count_shares(d))
})

test_that("equal counts are skipped", {
  d <- count_rows("01001000", c(0.2, 0.8), c(50, 50))
  expect_null(bbsrgeo_check_count_shares(d))
})

test_that("a group whose shares sum off 1 is skipped", {
  d <- count_rows("01001000", c(1, 1), c(25, 75))
  expect_null(bbsrgeo_check_count_shares(d))
})

test_that("a missing count column does not error", {
  d <- count_rows("01001000", c(0.5, 0.5), c(25, 75))
  expect_null(bbsrgeo_check_count_shares(d[names(d) != "area_old"]))
})

test_that("the shares of one basis are reported per basis, in order", {
  d <- count_rows("01001000", c(0.5, 0.5), c(25, 75))
  d$share_population <- d$share_area
  d$population_old <- d$area_old
  f <- bbsrgeo_check_count_shares(d)
  expect_equal(
    vapply(f$items, function(i) i$scope, character(1)),
    c("area", "population")
  )
})
