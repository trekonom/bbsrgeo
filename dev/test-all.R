# Run the whole test suite, list anything that skipped, and fail on warnings.
# test_local() enables the network-guarded validation tests itself (it sets
# NOT_CRAN=true); a skipped test here means the network or BBSR was
# unreachable, and the run proves nothing for that test.
# Usage: Rscript dev/test-all.R
res <- as.data.frame(testthat::test_local(".", stop_on_failure = TRUE))

skipped <- res[res$skipped, c("file", "test")]
if (nrow(skipped) > 0) {
  message("\nSkipped tests (these did not run):")
  print(skipped, row.names = FALSE)
}

if (any(res$warning > 0)) {
  print(res[res$warning > 0, c("file", "test", "warning")], row.names = FALSE)
  stop("Tests emitted warnings; suppress the known ones or fix the cause.")
}
