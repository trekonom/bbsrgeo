#' Read a BBSR area crosswalk
#'
#' Reads one or more local crosswalk xlsx files (see
#' [bbsr_crosswalk_download()]) and normalizes them into a single "long"
#' tibble.
#'
#' Each file contains one sheet per year transition (for `"annual"` files,
#' sheet name e.g. `"2010-2011"` or `"2010"`) or per source year (for
#' `"conversion_*"` files, sheet name = source year, fixed target year taken
#' from the file name). `level` and `kind` are derived from the file name
#' (see [bbsr_crosswalk_available()] for the naming conventions - these file
#' names are set by the BBSR and remain in German). In case of boundary
#' reforms (municipality mergers, district reorganizations), there are
#' multiple rows per `ags_old`, whose shares sum to 1.
#'
#' Transitions to a year after 2024 are ignored, with a message: bbsrgeo
#' supports boundaries up to the last year of its example datasets.
#'
#' @param path Path or vector of paths to local xlsx files (see
#'   [bbsr_crosswalk_download()]).
#' @param fix Apply the documented corrections of [bbsr_crosswalk_fix()].
#'   Default `TRUE`; `FALSE` returns the files as published.
#'
#' @return A tibble with columns `ags_old`, `name_old`, `ags_new`,
#'   `name_new`, `year_from`, `year_to`, `level` (`"districts"` or
#'   `"municipalities"`, from the file name), `share_area`, `share_population`,
#'   `share_employment` (`NA` before 1997, since the BBSR only offers
#'   employment data as a weighting basis from 1997 onward), and the
#'   corresponding absolute values `area_old`, `population_old`, and
#'   `employment_old` of the respective old unit (basis for a weighted
#'   average when converting ratios, see [harmonize_regions()]).
#' @export
bbsr_crosswalk_read <- function(path, fix = TRUE) {
  stopifnot(is.logical(fix), length(fix) == 1, !is.na(fix))
  data <- purrr::map_dfr(path, bbsrgeo_read_file)
  data <- drop_newer_transitions(data)
  if (fix) {
    data <- bbsr_crosswalk_fix(data)
  }
  report_finding(bbsrgeo_check_names(data))
  analysis <- share_deviation_analysis(data)
  report_finding(bbsrgeo_check_share_sums(data, analysis))
  report_finding(bbsrgeo_check_count_shares(data, analysis))
  data
}

# The last boundary year the package supports: the example datasets end in
# 2024, and BBSR republished its files with a 2024 -> 2025 transition under
# unchanged file names. Raise it together with the URL table in R/sysdata.rda
# and the row counts in test-crosswalk-read.R.
crosswalk_last_year <- 2024L

drop_newer_transitions <- function(data) {
  newer <- data$year_to > crosswalk_last_year
  if (any(newer)) {
    rlang::inform(sprintf(
      paste(
        "Ignored %d row(s) of transitions to a year after %d,",
        "the last boundary year bbsrgeo supports."
      ),
      sum(newer),
      crosswalk_last_year
    ))
    data <- data[!newer, ]
  }
  data
}

bbsrgeo_read_file <- function(path) {
  if (!file.exists(path)) {
    rlang::abort(sprintf("File not found: %s", path))
  }
  meta <- bbsrgeo_file_meta(path)
  sheets <- readxl::excel_sheets(path)
  purrr::map_dfr(sheets, function(sheet) bbsrgeo_read_sheet(path, sheet, meta))
}

bbsrgeo_file_meta <- function(path) {
  file_name <- basename(path)

  # BBSR file names are in German and outside this package's control
  # ("gemeinden" = municipalities, "kreise" = districts).
  level <- dplyr::case_when(
    grepl("gemeinden", file_name, ignore.case = TRUE) ~ "municipalities",
    grepl("kreise", file_name, ignore.case = TRUE) ~ "districts",
    TRUE ~ NA_character_
  )
  if (is.na(level)) {
    rlang::warn(sprintf(
      "Could not derive 'level' (municipalities/districts) from file name '%s'.",
      file_name
    ))
  }

  target_year_match <- regmatches(
    file_name,
    regexpr("umrech-(\\d{4})", file_name)
  )
  if (length(target_year_match) > 0 && nzchar(target_year_match)) {
    target_year <- as.integer(sub("umrech-", "", target_year_match))
    kind <- paste0("conversion_", target_year)
  } else {
    target_year <- NA_integer_
    kind <- "annual"
  }

  list(
    level = level,
    kind = kind,
    target_year = target_year,
    file_name = file_name
  )
}

bbsrgeo_sheet_years <- function(sheet, meta) {
  if (meta$kind == "annual") {
    m <- regmatches(sheet, regexec("^(\\d{4})-(\\d{4})$", sheet))[[1]]
    if (length(m) == 3) {
      return(list(from = as.integer(m[2]), to = as.integer(m[3])))
    }
    # The municipal 1990-2000 file abbreviates the end year in its sheet
    # names ("1990-91" to "1996-97", checked with readxl::excel_sheets());
    # "1999-00" would work too. The end year must be the year after the
    # start year.
    m_short <- regmatches(sheet, regexec("^(\\d{4})-(\\d{2})$", sheet))[[1]]
    if (length(m_short) == 3) {
      from <- as.integer(m_short[2])
      if ((from + 1L) %% 100L == as.integer(m_short[3])) {
        return(list(from = from, to = from + 1L))
      }
    }
    m2 <- regmatches(sheet, regexec("^(\\d{4})$", sheet))[[1]]
    if (length(m2) == 2) {
      year <- as.integer(m2[2])
      return(list(from = year, to = year + 1L))
    }
    rlang::abort(sprintf(
      "Unexpected sheet name '%s' in an 'annual' file (%s) - expected 'YYYY-YYYY', 'YYYY-YY' or 'YYYY'.",
      sheet,
      meta$file_name
    ))
  }

  m <- regmatches(sheet, regexec("^(\\d{4})$", sheet))[[1]]
  if (length(m) != 2) {
    rlang::abort(sprintf(
      "Unexpected sheet name '%s' in a 'conversion' file (%s) - expected 'YYYY'.",
      sheet,
      meta$file_name
    ))
  }
  list(from = as.integer(m[2]), to = meta$target_year)
}

bbsrgeo_read_sheet <- function(path, sheet, meta) {
  raw <- suppressMessages(
    readxl::read_excel(
      path,
      sheet = sheet,
      col_names = FALSE,
      col_types = "text"
    )
  )
  bbsrgeo_parse_sheet(raw, sheet, meta)
}

# Parses one sheet as read by readxl (all text, no column names, the header row
# included) into the crosswalk tibble. Separate from the reading so the layouts
# can be tested with a constructed table.
bbsrgeo_parse_sheet <- function(raw, sheet, meta) {
  # Row 1 is the header; its text tells the 10-column layouts apart.
  header <- unlist(raw[1, ], use.names = FALSE)
  raw <- raw[-1, ]
  # Most municipal sheets (all of 1990-2000 and 2000-2010, those up to
  # 2015-2016 of 2010-2020) have a second header row of column labels
  # ("Kennziffer" = AGS, "Name"); the later sheets do not (municipal issue 04).
  # Drop it by content, before the AGS is normalized. The label is exact in
  # all 26 affected sheets.
  raw <- raw[is.na(raw[[1]]) | raw[[1]] != "Kennziffer", ]
  n <- ncol(raw)

  # Since the 2022 sheet of ref-gemeinden-2020-2024.xlsx a 12-digit
  # Regionalschluessel follows each AGS and the employment columns are gone:
  # also 10 columns, but not the employment layout below.
  has_regional_key <- n == 10 &&
    grepl("Regionalschl", header[2], ignore.case = TRUE)

  if (has_regional_key) {
    cols <- c(
      "ags_old",
      "regional_key_old",
      "name_old",
      "share_area",
      "share_population",
      "area_old",
      "population_old",
      "ags_new",
      "regional_key_new",
      "name_new"
    )
    has_employment <- FALSE
  } else if (n == 8) {
    cols <- c(
      "ags_old",
      "name_old",
      "share_area",
      "share_population",
      "area_old",
      "population_old",
      "ags_new",
      "name_new"
    )
    has_employment <- FALSE
  } else if (n == 10) {
    cols <- c(
      "ags_old",
      "name_old",
      "share_area",
      "share_population",
      "share_employment",
      "area_old",
      "population_old",
      "employment_old",
      "ags_new",
      "name_new"
    )
    has_employment <- TRUE
  } else {
    rlang::abort(sprintf(
      paste(
        "Unexpected number of columns (%d) in sheet '%s' of %s.",
        "The table structure deviates from the expected structure (8 or 10 columns) -",
        "please inspect the file manually, the BBSR may have changed the format."
      ),
      n,
      sheet,
      meta$file_name
    ))
  }
  names(raw) <- cols
  if (!has_employment) {
    raw$share_employment <- NA_character_
    raw$employment_old <- NA_character_
  }

  years <- bbsrgeo_sheet_years(sheet, meta)

  tibble::tibble(
    ags_old = normalize_ags(raw$ags_old),
    name_old = trimws(raw$name_old),
    ags_new = normalize_ags(raw$ags_new),
    name_new = trimws(raw$name_new),
    year_from = years$from,
    year_to = years$to,
    level = meta$level,
    share_area = as.numeric(raw$share_area),
    share_population = as.numeric(raw$share_population),
    share_employment = as.numeric(raw$share_employment),
    area_old = as.numeric(raw$area_old),
    population_old = as.numeric(raw$population_old),
    employment_old = as.numeric(raw$employment_old)
  )
}
