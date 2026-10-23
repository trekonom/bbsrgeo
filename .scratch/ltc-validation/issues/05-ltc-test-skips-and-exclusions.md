# ltc test turns failures into skips; exclusion list too broad

Status: needs-triage
Category: enhancement

Found in review of commit b0e071a (`tests/testthat/test-validate-ltc.R`).

- `tryCatch(..., error = function(e) NULL)` followed by `skip()` makes a regression in `bbsr_crosswalk_read()` report as a skip. Only guard the download step, or check for network-error classes.
- `affected_kreiskennziffer` is built from all transitions, so it also excludes districts in 2023, where no chaining happens. Restrict the exclusion per `check_year`.
