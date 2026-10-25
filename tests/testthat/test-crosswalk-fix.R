# The one documented fix: 07235000 (2011 -> 2012) with name_old
# Bernkastel-Wittlich is a miscoded 07231000 (see R/crosswalk-fixes.R).
fix_rows <- function() {
  tibble::tibble(
    ags_old = c("07231000", "07235000", "07235000"),
    name_old = c(
      "Bernkastel-Wittlich",
      "Bernkastel-Wittlich",
      "Trier-Saarburg"
    ),
    ags_new = c("07231000", "07235000", "07235000"),
    name_new = c("Bernkastel-Wittlich", "Trier-Saarburg", "Trier-Saarburg"),
    year_from = 2011L,
    year_to = 2012L,
    share_area = c(0.99142, 0.00858, 1),
    share_population = c(0.99065, 0.00935, 1)
  )
}

test_that("a fix recodes its one matching row, leaves the rest, and says so", {
  d <- fix_rows()
  expect_message(
    res <- bbsr_crosswalk_fix(d),
    "Applied: district-miscoded-bernkastel-wittlich.*2011 -> 2012"
  )
  expect_equal(res$ags_old, c("07231000", "07231000", "07235000"))
  expect_equal(res[names(res) != "ags_old"], d[names(d) != "ags_old"])
})

test_that("a transition present without the matching row is reported as not applied", {
  d <- fix_rows()[c(1, 3), ]
  expect_message(
    res <- bbsr_crosswalk_fix(d),
    "not applied.*file may have changed"
  )
  expect_equal(res, d)
})

test_that("a fix matching more than one row is not applied", {
  d <- rbind(fix_rows(), fix_rows()[2, ])
  expect_message(res <- bbsr_crosswalk_fix(d), "not applied")
  expect_equal(res, d)
})

test_that("a crosswalk without the transition is untouched and silent", {
  d <- fix_rows()
  d$year_from <- 2013L
  d$year_to <- 2014L
  expect_no_message(res <- bbsr_crosswalk_fix(d))
  expect_equal(res, d)
})

# A constructed fix table: one row per column set or row dropped.
fix_table <- function(...) {
  rows <- list(...)
  tibble::tibble(
    id = vapply(rows, function(r) r$id, ""),
    action = vapply(rows, function(r) r$action %||% "set", ""),
    year_from = 2000L,
    year_to = 2001L,
    ags_old = vapply(rows, function(r) r$ags_old, ""),
    name_old = vapply(rows, function(r) r$name_old %||% "A", ""),
    ags_new = vapply(rows, function(r) r$ags_new %||% r$ags_old, ""),
    column = vapply(rows, function(r) r$column %||% NA_character_, ""),
    value = vapply(rows, function(r) r$value %||% NA_character_, ""),
    n_rows = vapply(rows, function(r) r$n_rows %||% 1L, 1L),
    evidence = "constructed"
  )
}

small_crosswalk <- function() {
  tibble::tibble(
    ags_old = c("01", "01", "02", "03", "03"),
    name_old = "A",
    ags_new = c("01", "01", "02", "03", "03"),
    year_from = 2000L,
    year_to = 2001L,
    share_area = c(0.5, 0.5, 0.9, 0.2, 0.2)
  )
}

test_that("a 'set' fix writes a value of the column's type to its matched row", {
  fixes <- fix_table(
    list(id = "f", ags_old = "02", column = "share_area", value = "1")
  )
  expect_message(
    res <- apply_crosswalk_fixes(small_crosswalk(), fixes),
    "f.*2000 -> 2001.*1 row"
  )
  expect_equal(res$share_area, c(0.5, 0.5, 1, 0.2, 0.2))
})

test_that("a 'set' fix with n_rows = 2 writes to both matched rows", {
  fixes <- fix_table(
    list(
      id = "f",
      ags_old = "03",
      column = "share_area",
      value = "0.5",
      n_rows = 2L
    )
  )
  # The "Documented fixes" message listing the applied fixes.
  res <- suppressMessages(apply_crosswalk_fixes(small_crosswalk(), fixes))
  expect_equal(res$share_area, c(0.5, 0.5, 0.9, 0.5, 0.5))
})

test_that("a 'drop' fix removes exactly the matched rows", {
  fixes <- fix_table(list(id = "f", action = "drop", ags_old = "02"))
  expect_message(
    res <- apply_crosswalk_fixes(small_crosswalk(), fixes),
    "f.*1 row"
  )
  expect_equal(res$ags_old, c("01", "01", "03", "03"))
  expect_equal(res$share_area, c(0.5, 0.5, 0.2, 0.2))
})

test_that("an id with several table rows applies all of them in one message", {
  fixes <- fix_table(
    list(id = "f", ags_old = "02", column = "share_area", value = "1"),
    list(
      id = "f",
      ags_old = "03",
      column = "share_area",
      value = "1",
      n_rows = 2L
    )
  )
  msgs <- character()
  res <- withCallingHandlers(
    apply_crosswalk_fixes(small_crosswalk(), fixes),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_equal(res$share_area, c(0.5, 0.5, 1, 1, 1))
  expect_length(msgs, 1)
  expect_match(msgs, "f.*3 row")
})

test_that("an id with a row matching too few or too many rows is not applied at all", {
  for (bad in list(
    list(id = "f", ags_old = "03", column = "share_area", value = "1"),
    list(
      id = "f",
      ags_old = "01",
      column = "share_area",
      value = "1",
      n_rows = 3L
    )
  )) {
    fixes <- fix_table(
      list(id = "f", ags_old = "02", column = "share_area", value = "1"),
      bad
    )
    expect_message(
      res <- apply_crosswalk_fixes(small_crosswalk(), fixes),
      "not applied.*f.*matched 2 row"
    )
    expect_equal(res, small_crosswalk())
  }
  fixes <- fix_table(
    list(id = "f", ags_old = "02", column = "share_area", value = "1"),
    list(
      id = "f",
      ags_old = "01",
      name_old = "B",
      column = "share_area",
      value = "1"
    )
  )
  expect_message(
    res <- apply_crosswalk_fixes(small_crosswalk(), fixes),
    "not applied.*f.*matched 0 row"
  )
  expect_equal(res, small_crosswalk())
})

test_that("an id whose transition is absent is silent; each id gets one line", {
  fixes <- fix_table(
    list(id = "f", ags_old = "02", column = "share_area", value = "1"),
    list(
      id = "g",
      ags_old = "03",
      column = "share_area",
      value = "0.5",
      n_rows = 2L
    )
  )
  fixes$year_from[2] <- 1990L
  fixes$year_to[2] <- 1991L
  msgs <- character()
  res <- withCallingHandlers(
    apply_crosswalk_fixes(small_crosswalk(), fixes),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_equal(res$share_area, c(0.5, 0.5, 1, 0.2, 0.2))
  expect_match(msgs, "Applied: f ", fixed = TRUE)
  expect_no_match(msgs, "g (", fixed = TRUE)
})

test_that("an id is relevant if any row's transition is present, and then must match fully", {
  fixes <- fix_table(
    list(id = "f", ags_old = "02", column = "share_area", value = "1"),
    list(
      id = "f",
      ags_old = "03",
      column = "share_area",
      value = "0.5",
      n_rows = 2L
    )
  )
  fixes$year_from[2] <- 1990L
  fixes$year_to[2] <- 1991L
  expect_message(
    res <- apply_crosswalk_fixes(small_crosswalk(), fixes),
    "not applied.*f.*matched 0 row"
  )
  expect_equal(res, small_crosswalk())
})

test_that("bbsr_crosswalk_read() applies fixes unless fix = FALSE", {
  path <- test_path("fixtures", "ref-kreise-testfixture-jaehrlich.xlsx")
  # The fixture has no documented row, so the read is unchanged and silent.
  expect_no_message(a <- bbsr_crosswalk_read(path))
  expect_equal(a, bbsr_crosswalk_read(path, fix = FALSE))
})

test_that("the miscoded district row is corrected in the real file", {
  skip_on_cran()
  skip_if_offline()
  path <- tryCatch(
    bbsr_crosswalk_download(level = "districts", kind = "annual"),
    error = function(e) skip("Could not download the BBSR area crosswalk.")
  )

  read_collecting <- function(...) {
    warnings <- character()
    messages <- character()
    value <- withCallingHandlers(
      bbsr_crosswalk_read(path, ...),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        messages <<- c(messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    list(value = value, warnings = warnings, messages = messages)
  }
  as_published <- read_collecting(fix = FALSE)$value
  read <- read_collecting()
  # The 2025 rows of the current file are ignored (crosswalk_last_year).
  expect_match(read$messages, "Ignored 400 row(s)", fixed = TRUE, all = FALSE)
  read$messages <- grep("Documented fixes", read$messages, value = TRUE)
  # One line per fix id, both in the one message.
  expect_length(read$messages, 1)
  expect_match(
    read$messages,
    "district-miscoded-bernkastel-wittlich-2011",
    fixed = TRUE
  )
  expect_match(
    read$messages,
    "district-single-row-shares-2014-2015",
    fixed = TRUE
  )
  fixed <- read$value
  expect_length(read$warnings, 0)

  # The single self-mapping rows of Cochem-Zell and Mayen-Koblenz: shares of 1
  # as fixed, the 2013 split as published.
  single <- function(d) {
    d[
      d$ags_old %in%
        c("07135000", "07137000") &
        d$year_from %in% c(2014, 2015),
    ]
  }
  share_cols <- c("share_area", "share_population", "share_employment")
  expect_equal(nrow(single(fixed)), 4)
  for (col in share_cols) {
    expect_equal(single(fixed)[[col]], rep(1, 4), label = col)
  }
  expect_true(all(single(as_published)$share_area < 1))

  # Measured after the fix: all four sums are 1.000000 (to 6 digits); the
  # unfixed sums are 0.991 and 1.009, so 1e-3 separates the two.
  for (code in c("07231000", "07235000")) {
    rows <- fixed[fixed$ags_old == code & fixed$year_from == 2011, ]
    expect_equal(sum(rows$share_area), 1, tolerance = 1e-3, label = code)
    expect_equal(sum(rows$share_population), 1, tolerance = 1e-3, label = code)
  }
  expect_equal(nrow(fixed), nrow(as_published))
  expect_equal(
    sum(as_published$ags_old == "07235000" & as_published$year_from == 2011),
    2
  )
})

test_that("harmonize_regions() passes 0.86 % of 07231000 on to 07235000 after the fix", {
  # The "Documented fixes" message listing the applied fixes.
  d <- bbsr_crosswalk_fix(fix_rows()) |> suppressMessages()
  data <- tibble::tibble(
    ags = c("07231000", "07235000"),
    year = 2011L,
    population = c(10000, 20000)
  )
  res <- harmonize_regions(
    data,
    d,
    "ags",
    "year",
    "population",
    type = "absolute",
    target_year = 2012L
  )
  expect_equal(res$population[res$ags == "07235000"], 20000 + 10000 * 0.00935)
  expect_equal(res$population[res$ags == "07231000"], 10000 * 0.99065)

  # Unfixed, the miscoded row maps 07235000 to itself and 07231000 keeps all.
  unfixed <- harmonize_regions(
    data,
    fix_rows(),
    "ags",
    "year",
    "population",
    type = "absolute",
    target_year = 2012L
  ) |>
    # The message that the deviating shares were renormalized.
    suppressMessages()
  expect_equal(unfixed$population[unfixed$ags == "07231000"], 10000)
})
