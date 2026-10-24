test_that("normalize_ags pads missing leading zeros", {
  expect_equal(normalize_ags("1001000"), "01001000")
  expect_equal(normalize_ags("13001000"), "13001000")
  expect_equal(normalize_ags(1001000), "01001000")
})

test_that("normalize_ags is idempotent for already 8-digit values", {
  expect_equal(normalize_ags("01001000"), "01001000")
})

test_that("normalize_ags treats empty/missing values as NA", {
  expect_equal(normalize_ags(""), NA_character_)
  expect_equal(normalize_ags(NA), NA_character_)
  expect_equal(normalize_ags("  "), NA_character_)
})

test_that("normalize_ags warns on non-numeric values and sets NA", {
  expect_warning(res <- normalize_ags("abc"), "could not be parsed")
  expect_equal(res, NA_character_)
})

# Collects every condition a reporter call signals, as list(class, message).
signalled <- function(expr) {
  out <- list()
  withCallingHandlers(
    expr,
    warning = function(w) {
      out[[length(out) + 1]] <<- list("warning", conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      out[[length(out) + 1]] <<- list("message", conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  out
}

example_finding <- function(severity = "warning", hint = "Check the file.") {
  finding(
    header = "Something is off:",
    items = list(
      finding_item("first label", 2, c("ex a", "ex b")),
      finding_item("second label", 1, "ex c", scope = "area")
    ),
    hint = hint,
    severity = severity
  )
}

test_that("a warning finding warns once", {
  s <- signalled(report_finding(example_finding("warning")))
  expect_length(s, 1)
  expect_equal(s[[1]][[1]], "warning")
})

test_that("a message finding informs once", {
  s <- signalled(report_finding(example_finding("message")))
  expect_length(s, 1)
  expect_equal(s[[1]][[1]], "message")
})

test_that("NULL signals nothing", {
  expect_length(signalled(report_finding(NULL)), 0)
})

test_that("header, items in order with count and examples, then the hint", {
  msg <- signalled(report_finding(example_finding()))[[1]][[2]]
  expect_match(msg, "Something is off:")
  expect_match(msg, "2 first label, e.g. ex a; ex b", fixed = TRUE)
  expect_match(msg, "area: 1 second label, e.g. ex c", fixed = TRUE)
  pos <- vapply(
    c("Something is off", "first label", "second label", "Check the file."),
    function(p) regexpr(p, msg, fixed = TRUE)[[1]],
    numeric(1)
  )
  expect_false(is.unsorted(pos, strictly = TRUE))
})

test_that("a finding without a hint ends after its items", {
  msg <- signalled(report_finding(example_finding(hint = NULL)))[[1]][[2]]
  expect_false(grepl("Check the file", msg))
})

test_that("a finding rejects an unknown severity", {
  expect_error(example_finding("error"))
})
