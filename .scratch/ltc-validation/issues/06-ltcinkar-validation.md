# data-raw/ltcinkar.R has no input validation

Status: needs-triage
Category: enhancement

Found in review of commit b0e071a (`data-raw/ltcinkar.R`).

No check that `Kennziffer` is a zero-padded 5-character string or that `Zeit` is an integer; the test's nrow check only catches problems indirectly. Add assertions (and route through `normalize_ags()`-style padding if needed).
