# Generates small synthetic xlsx fixtures that mimic the real BBSR
# structure (verified against real downloads, see data-raw/). Not part of
# the build/test run - only re-run manually if needed (requires the
# Suggests package 'writexl').
#
# Structure per sheet: row 1 = header placeholder (skipped by
# bbsrgeo:::bbsrgeo_read_sheet() via skip = 1), from row 2 onward real
# data, NO column names (col_names = FALSE when writing).
# Column order without employment (8 columns):
#   ags_old, name_old, share_area, share_population,
#   area_old, population_old, ags_new, name_new
# with employment (10 columns): additionally share_employment (pos. 5)
# and employment_old (pos. 8).

raw <- function(...) {
  rbind(
    c("HEAD1", "HEAD2", "HEAD3", "HEAD4", "HEAD5", "HEAD6", "HEAD7", "HEAD8"),
    ...
  )
}

# --- File 1: "annual" (no 'umrech' in the name) -------------------------
# Sheet "1999-2000": 8 columns, one unchanged district + one split
sheet_1999_2000 <- raw(
  c(
    "01000001",
    "District A",
    "1",
    "1",
    "100",
    "1000",
    "01000001",
    "District A"
  ),
  c(
    "01000002",
    "District B",
    "0.4",
    "0.3",
    "40",
    "300",
    "01000009",
    "District N"
  ),
  c(
    "01000002",
    "District B",
    "0.6",
    "0.7",
    "60",
    "700",
    "01000010",
    "District M"
  )
)

# Sheet "2000-2001": 10 columns (with employment), unchanged units
head10 <- c(
  "HEAD1",
  "HEAD2",
  "HEAD3",
  "HEAD4",
  "HEAD5",
  "HEAD6",
  "HEAD7",
  "HEAD8",
  "HEAD9",
  "HEAD10"
)
sheet_2000_2001 <- rbind(
  head10,
  c(
    "01000001",
    "District A",
    "1",
    "1",
    "1",
    "100",
    "1000",
    "10",
    "01000001",
    "District A"
  ),
  c(
    "01000009",
    "District N",
    "1",
    "1",
    "1",
    "40",
    "300",
    "5",
    "01000009",
    "District N"
  )
)

# Sheet "2001" (single-year sheet name as used in municipality files -> 2001-2002), 8 columns
sheet_2001 <- raw(
  c("01000001", "District A", "1", "1", "100", "1000", "01000001", "District A")
)

writexl::write_xlsx(
  list(
    "1999-2000" = as.data.frame(sheet_1999_2000),
    "2000-2001" = as.data.frame(sheet_2000_2001),
    "2001" = as.data.frame(sheet_2001)
  ),
  path = "tests/testthat/fixtures/ref-kreise-testfixture-jaehrlich.xlsx",
  col_names = FALSE
)

# --- File 2: "conversion to 2021" (file name with 'umrech-2021') --------
# Sheets are source years (single year number), fixed target year = 2021 (from file name)
sheet_1999 <- raw(
  c("01000001", "District A", "1", "1", "100", "1000", "01000001", "District A")
)
sheet_2000 <- raw(
  c("01000001", "District A", "1", "1", "100", "1000", "01000001", "District A")
)

writexl::write_xlsx(
  list("1999" = as.data.frame(sheet_1999), "2000" = as.data.frame(sheet_2000)),
  path = "tests/testthat/fixtures/ref-kreise-umrech-2021-testfixture.xlsx",
  col_names = FALSE
)

message("Fixtures written to tests/testthat/fixtures/")
