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
  expect_message(res <- bbsr_crosswalk_fix(d), "07235000.*07231000.*2011")
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

  # The 2014 and 2015 district rows still warn (not fixed); only the corrected
  # groups must not.
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
  expect_length(read$messages, 1)
  expect_match(read$messages, "07231000", fixed = TRUE)
  fixed <- read$value
  expect_false(any(grepl("07231000|07235000", read$warnings)))

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
    target_year = 2012L,
    level = "districts"
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
    target_year = 2012L,
    level = "districts"
  ) |>
    suppressMessages()
  expect_equal(unfixed$population[unfixed$ags == "07231000"], 10000)
})
