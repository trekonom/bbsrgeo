# data-raw/ltcregio.R drops rows silently, no shape checks

Status: needs-triage
Category: enhancement

Found in review of commit b0e071a (`data-raw/ltcregio.R`).

The valid-AGS filter and the `inner_join` with `popregio` discard unmatched rows without notice; a missing `valid_ags_by_year` entry becomes NULL and `%in%` yields FALSE. The Berlin 399/400 problem was only caught by the test.

Fix: add `stopifnot()` checks on the final shape (400 districts x 8 biennial years, 2009-2023) and report dropped row counts.
