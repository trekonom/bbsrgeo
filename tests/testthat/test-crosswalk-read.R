test_that("bbsr_crosswalk_read parses an 'annual' file correctly", {
  d <- bbsr_crosswalk_read(test_path(
    "fixtures",
    "ref-kreise-testfixture-jaehrlich.xlsx"
  ))

  expect_named(
    d,
    c(
      "ags_old",
      "name_old",
      "ags_new",
      "name_new",
      "year_from",
      "year_to",
      "level",
      "share_area",
      "share_population",
      "share_employment",
      "area_old",
      "population_old",
      "employment_old"
    )
  )
  expect_equal(nrow(d), 6)
  expect_true(all(d$level == "districts"))

  # Sheet "1999-2000": hyphenated sheet name -> year_from/year_to taken directly from it
  unchanged <- d[d$year_from == 1999 & d$ags_old == "01000001", ]
  expect_equal(unchanged$year_to, 2000)
  expect_equal(unchanged$share_area, 1)

  # Split of district B into two rows, shares sum to 1
  split <- d[d$year_from == 1999 & d$ags_old == "01000002", ]
  expect_equal(nrow(split), 2)
  expect_equal(sum(split$share_area), 1)
  expect_equal(sum(split$share_population), 1)

  # Sheet "2000-2001": 10-column variant with employment data
  with_employment <- d[d$year_from == 2000, ]
  expect_true(all(!is.na(with_employment$share_employment)))
  expect_true(all(!is.na(with_employment$employment_old)))

  # Sheet "2001": single-year sheet name -> year_to derived as year_from + 1
  single_year <- d[d$year_from == 2001, ]
  expect_equal(single_year$year_to, 2002)
})

test_that("bbsr_crosswalk_read parses a 'conversion_*' file correctly (fixed target year)", {
  d <- bbsr_crosswalk_read(test_path(
    "fixtures",
    "ref-kreise-umrech-2021-testfixture.xlsx"
  ))

  expect_equal(nrow(d), 2)
  # Target year comes from the file name (umrech-2021), not the sheet name
  expect_true(all(d$year_to == 2021))
  expect_equal(sort(d$year_from), c(1999, 2000))
})

test_that("bbsr_crosswalk_read normalizes AGS to 8 digits", {
  d <- bbsr_crosswalk_read(test_path(
    "fixtures",
    "ref-kreise-testfixture-jaehrlich.xlsx"
  ))
  expect_true(all(nchar(d$ags_old) == 8))
  expect_true(all(nchar(d$ags_new) == 8))
})

test_that("bbsr_crosswalk_read can read multiple files at once", {
  d <- bbsr_crosswalk_read(c(
    test_path("fixtures", "ref-kreise-testfixture-jaehrlich.xlsx"),
    test_path("fixtures", "ref-kreise-umrech-2021-testfixture.xlsx")
  ))
  expect_equal(nrow(d), 6 + 2)
})

test_that("bbsr_crosswalk_read aborts with a clear message for a missing file", {
  expect_error(bbsr_crosswalk_read("does-not-exist.xlsx"), "not found")
})

test_that("bbsrgeo_sheet_years parses two-digit end years in annual sheet names", {
  meta <- list(kind = "annual", file_name = "ref-gemeinden-1990-2000.xlsx")

  expect_equal(
    bbsrgeo_sheet_years("1990-91", meta),
    list(from = 1990L, to = 1991L)
  )
  expect_equal(
    bbsrgeo_sheet_years("1996-97", meta),
    list(from = 1996L, to = 1997L)
  )
  # Century rollover: the end year is the next year, not 1900.
  expect_equal(
    bbsrgeo_sheet_years("1999-00", meta),
    list(from = 1999L, to = 2000L)
  )
  # The existing patterns are unchanged.
  expect_equal(
    bbsrgeo_sheet_years("1997-1998", meta),
    list(from = 1997L, to = 1998L)
  )
  expect_equal(
    bbsrgeo_sheet_years("2005", meta),
    list(from = 2005L, to = 2006L)
  )
})

test_that("bbsrgeo_sheet_years rejects a two-digit end year that is not the next year", {
  meta <- list(kind = "annual", file_name = "ref-gemeinden-1990-2000.xlsx")
  expect_error(bbsrgeo_sheet_years("1990-93", meta), "Unexpected sheet name")
})

test_that("bbsr_crosswalk_read parses the municipal Regionalschluessel layout", {
  # Reading must not warn: the 12-digit Regionalschluessel is not an AGS.
  d <- expect_no_warning(bbsr_crosswalk_read(test_path(
    "fixtures",
    "ref-gemeinden-testfixture-regionalschluessel.xlsx"
  )))

  expect_equal(nrow(d), 4)
  expect_true(all(d$level == "municipalities"))
  # The 12-digit Regionalschluessel columns are not read as AGS, and the
  # 10 columns are not mistaken for the employment layout.
  expect_equal(
    sort(unique(c(d$ags_old, d$ags_new))),
    c("01001000", "01002000", "01009000", "01010000")
  )
  expect_equal(
    d$name_old[d$year_from == 2022 & d$ags_old == "01001000"],
    "Town A"
  )
  expect_true(all(is.na(d$share_employment)))
  expect_true(all(is.na(d$employment_old)))

  split <- d[d$year_from == 2022 & d$ags_old == "01002000", ]
  expect_equal(sort(split$share_area), c(0.4, 0.6))
  expect_equal(sort(split$share_population), c(0.3, 0.7))
  expect_equal(sum(split$population_old), 1000)
  expect_equal(d$population_old[d$year_from == 2023], 92667)
})

test_that("bbsr_crosswalk_read drops the second header row of municipal sheets", {
  # Fixture sheet names, see make-fixtures.R: "2000-2001" has two header rows
  # (title, then "Kennziffer"/"Name" labels), "2016-2017" one.
  two_row_year <- 2000
  one_row_year <- 2016
  d <- bbsr_crosswalk_read(test_path(
    "fixtures",
    "ref-gemeinden-testfixture-kopfzeilen.xlsx"
  ))

  expect_false(anyNA(d$ags_old))
  expect_false(anyNA(d$ags_new))
  expect_equal(nrow(d), 3)
  # The first data row is the first municipality, not the label row.
  expect_equal(d$ags_old[1], "01001000")
  expect_equal(d$name_old[1], "Town A")
  expect_equal(
    d$ags_old[d$year_from == two_row_year],
    c("01001000", "01002000")
  )
  expect_equal(d$ags_old[d$year_from == one_row_year], "01001000")
})

test_that("the real BBSR files have no header rows among their data rows", {
  skip_on_cran()
  skip_if_offline()

  # Row counts and warnings measured on the downloads of 2026-10-24. Before
  # the fix the municipal files had 10, 10 and 6 more rows (the label row of
  # each sheet with a second header row); the 2020-2024 and district files
  # are unchanged. A changed upstream file will need these updated.
  # Exact counts on purpose: a mismatch usually means BBSR republished the file
  # under the same name (districts gained the 2024 -> 2025 transition), not a
  # header-row bug.
  expected_rows <- c(
    municipalities_1990 = 151093,
    municipalities_2000 = 127337,
    municipalities_2010 = 112275,
    municipalities_2020 = 43991,
    districts = 14908
  )
  files <- list(
    municipalities_1990 = list("municipalities", 1990),
    municipalities_2000 = list("municipalities", 2000),
    municipalities_2010 = list("municipalities", 2010),
    municipalities_2020 = list("municipalities", 2020),
    districts = list("districts", NULL)
  )

  for (name in names(files)) {
    path <- tryCatch(
      bbsr_crosswalk_download(
        level = files[[name]][[1]],
        kind = "annual",
        year_from = files[[name]][[2]]
      ),
      error = function(e) skip("Could not download the BBSR area crosswalk.")
    )
    # Collect, do not suppress: some files warn about share deviations
    # (bbsrgeo_check_share_sums()), which are not header rows.
    warnings <- character()
    messages <- character()
    d <- withCallingHandlers(
      bbsr_crosswalk_read(path),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        messages <<- c(messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    # No file has shares that disagree with their counts beyond the counts'
    # resolution (bbsrgeo_check_count_shares(), measured 2026-10-24; the
    # municipal 2000-2010 population deviation of 0.0072 is inside the bound).
    expect_false(
      any(grepl("disagree with their counts", messages)),
      label = name
    )
    # Only the district file has a documented fix (bbsr_crosswalk_fix()).
    expect_equal(
      any(grepl("Documented fixes", messages)),
      name == "districts",
      label = name
    )

    expect_false(anyNA(d$ags_old), label = paste("ags_old in", name))
    expect_false(anyNA(d$ags_new), label = paste("ags_new in", name))
    expect_equal(nrow(d), expected_rows[[name]], label = paste("rows in", name))
    # The label rows formed an ags_old = NA group that warned.
    expect_false(any(grepl("ags_old = 'NA'", warnings)), label = name)

    # Share deviations measured on the same downloads: the 1990-2000 file has
    # 4 groups with a share of 1 on every row; 09377444 (2016, sum 0.99) is
    # rounding and does not warn. The district file's 4 single-row groups below
    # 1 are fixed (district-single-row-shares-2014-2015).
    expected_pattern <- c(
      municipalities_1990 = "4 combination.*share of 1 on every target row"
    )[name]
    if (is.na(expected_pattern)) {
      expect_length(warnings, 0)
    } else {
      expect_length(warnings, 1)
      expect_match(warnings, expected_pattern, label = name)
    }
  }
})

test_that("the real files: only the unfixed district row has inconsistent names", {
  skip_on_cran()
  skip_if_offline()
  path <- tryCatch(
    bbsr_crosswalk_download(level = "districts", kind = "annual"),
    error = function(e) skip("Could not download the BBSR area crosswalk.")
  )
  name_warnings <- function(...) {
    out <- character()
    withCallingHandlers(
      suppressMessages(bbsr_crosswalk_read(path, ...)),
      warning = function(w) {
        out <<- c(out, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    out[grepl("names of one code differ", out)]
  }
  # Exactly one group, and only on the ags_old side. The municipal files are
  # covered by the loop in the "no header rows" test, which expects no warning
  # besides the share deviations.
  unfixed <- name_warnings(fix = FALSE)
  expect_match(unfixed, "1 ags_old group.*07235000.*2011 -> 2012")
  expect_false(grepl("ags_new group", unfixed))
  expect_length(name_warnings(), 0)
})

test_that("the real files: the unfixed district row disagrees with its counts", {
  skip_on_cran()
  skip_if_offline()
  path <- tryCatch(
    bbsr_crosswalk_download(level = "districts", kind = "annual"),
    error = function(e) skip("Could not download the BBSR area crosswalk.")
  )
  count_messages <- function(...) {
    out <- character()
    withCallingHandlers(
      suppressWarnings(bbsr_crosswalk_read(path, ...)),
      message = function(m) {
        out <<- c(out, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    out[grepl("disagree with their counts", out)]
  }
  # Exactly this group, for area and population (unfixed sums 1.009 / 1.007).
  unfixed <- count_messages(fix = FALSE)
  expect_match(unfixed, "area: 1 group.*07235000.*year_from = 2011")
  expect_match(unfixed, "population: 1 group.*07235000.*year_from = 2011")
  expect_length(count_messages(), 0)
})

test_that("transitions to a year after the last supported one are dropped, with a message", {
  d <- tibble::tibble(
    ags_old = c("01001000", "01001000"),
    year_from = c(2023L, 2024L),
    year_to = c(2024L, 2025L)
  )
  expect_message(res <- drop_newer_transitions(d), "Ignored 1 row")
  expect_equal(res$year_to, 2024L)
  expect_no_message(drop_newer_transitions(d[1, ]))
})
