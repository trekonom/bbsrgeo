# Run one test file with the network-guarded tests enabled.
# test_file() does not set NOT_CRAN, so without it skip_on_cran() skips the
# test-validate-*.R and test-crosswalk-download.R tests and the run is "green"
# having checked nothing.
# Usage: Rscript dev/test-file.R tests/testthat/test-validate-ltc.R
path <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(path)) stop("Usage: Rscript dev/test-file.R <path to test file>")

Sys.setenv(NOT_CRAN = "true")
testthat::test_file(path, package = "bbsrgeo", load_package = "source")
