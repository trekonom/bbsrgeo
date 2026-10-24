groups_crosswalk <- function(...) {
  tibble::tibble(...)
}

test_that("groups differing in year_to are separate transition groups", {
  cw <- groups_crosswalk(
    ags_old = "01001000",
    year_from = 2000,
    year_to = c(2001, 2001, 2002),
    share_area = c(0.4, 0.6, 1),
    area_old = c(40, 60, 100)
  )
  facts <- transition_group_facts(cw, "area")
  expect_equal(facts$n_rows, c(2, 2, 1))
  expect_equal(facts$share_sum, c(1, 1, 1))
  expect_equal(facts$count_total, c(100, 100, 100))
})

test_that("a missing count makes counts neither observed nor differing", {
  cw <- groups_crosswalk(
    ags_old = "01001000",
    year_from = 2000,
    year_to = 2001,
    share_population = c(0.4, 0.6),
    population_old = c(40, NA)
  )
  facts <- transition_group_facts(cw, "population")
  expect_false(any(facts$counts_observed))
  expect_false(any(facts$counts_differ))
})

test_that("equal counts do not differ, unequal counts do", {
  cw <- groups_crosswalk(
    ags_old = c("a", "a", "b", "b"),
    year_from = 2000,
    year_to = 2001,
    share_area = c(0.5, 0.5, 0.3, 0.7),
    area_old = c(10, 10, 30, 70)
  )
  facts <- transition_group_facts(cw, "area")
  expect_equal(facts$counts_differ, c(FALSE, FALSE, TRUE, TRUE))
  expect_true(all(facts$counts_observed))
})

test_that("a negative count makes the group not non-negative", {
  cw <- groups_crosswalk(
    ags_old = c("a", "a", "b", "b"),
    year_from = 2000,
    year_to = 2001,
    share_area = 0.5,
    area_old = c(-1, 5, 3, 5)
  )
  facts <- transition_group_facts(cw, "area")
  expect_equal(facts$counts_non_negative, c(FALSE, FALSE, TRUE, TRUE))
})

test_that("the share sum ignores a missing share", {
  cw <- groups_crosswalk(
    ags_old = "a",
    year_from = 2000,
    year_to = 2001,
    share_area = c(0.4, NA),
    area_old = c(4, 6)
  )
  expect_equal(transition_group_facts(cw, "area")$share_sum, c(0.4, 0.4))
})

test_that("an absent count or share column does not error", {
  cw <- groups_crosswalk(
    ags_old = "a",
    year_from = 2000,
    year_to = 2001,
    share_area = c(0.4, 0.6)
  )
  facts <- transition_group_facts(cw, "employment")
  expect_equal(nrow(facts), 2)
  expect_true(all(is.na(facts$share_sum)))
  expect_true(all(is.na(facts$count_total)))
  expect_false(any(facts$counts_observed))
  expect_false(any(facts$counts_differ))
  expect_equal(facts$n_rows, c(2, 2))
})
