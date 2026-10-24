# Run the whole test suite, list anything that skipped, and fail on warnings.
# Every problem is repeated at the very end of the output, so the last lines
# of a failing run name the failing tests and their messages.
# test_local() enables the network-guarded validation tests itself (it sets
# NOT_CRAN=true); a skipped test here means the network or BBSR was
# unreachable, and the run proves nothing for that test.
# Usage: Rscript dev/test-all.R
results <- testthat::test_local(".", stop_on_failure = FALSE)
res <- as.data.frame(results)

# A test file that gets much slower is a performance regression the tests do
# not catch: a grouped dplyr::mutate() once took test-crosswalk-read.R from
# about 50 s to 230 s. The slowest file measures about 50 s.
MAX_FILE_SECONDS <- 120
elapsed <- tapply(res$real, res$file, sum)
slowest <- utils::head(sort(elapsed, decreasing = TRUE), 3)
message(
  "\nSlowest test files: ",
  paste(sprintf("%s %.0f s", names(slowest), slowest), collapse = ", ")
)
problems <- character()
if (any(elapsed > MAX_FILE_SECONDS)) {
  problems <- c(
    problems,
    paste0(
      "A test file took longer than ",
      MAX_FILE_SECONDS,
      " s: ",
      paste(names(elapsed)[elapsed > MAX_FILE_SECONDS], collapse = ", "),
      ". Check for per-group evaluation over the ~150k crosswalk groups."
    )
  )
}

skipped <- res[res$skipped, c("file", "test")]
if (nrow(skipped) > 0) {
  message("\nSkipped tests (these did not run):")
  print(skipped, row.names = FALSE)
}

if (any(res$warning > 0)) {
  print(res[res$warning > 0, c("file", "test", "warning")], row.names = FALSE)
  problems <- c(
    problems,
    "Tests emitted warnings; suppress the known ones or fix the cause."
  )
}

for (test in results) {
  for (result in test$results) {
    if (inherits(result, c("expectation_failure", "expectation_error"))) {
      problems <- c(
        problems,
        sprintf(
          "%s, %s:\n%s",
          test$file,
          test$test,
          conditionMessage(result)
        )
      )
    }
  }
}

if (length(problems) > 0) {
  message("\n==== Problems ====\n", paste(problems, collapse = "\n\n"))
  quit(status = 1)
}
