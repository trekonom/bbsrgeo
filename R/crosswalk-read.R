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
#' @param path Path or vector of paths to local xlsx files (see
#'   [bbsr_crosswalk_download()]).
#'
#' @return A tibble with columns `ags_old`, `name_old`, `ags_new`,
#'   `name_new`, `year_from`, `year_to`, `share_area`, `share_population`,
#'   `share_employment` (`NA` before 1997, since the BBSR only offers
#'   employment data as a weighting basis from 1997 onward), and the
#'   corresponding absolute values `area_old`, `population_old`, and
#'   `employment_old` of the respective old unit (basis for a weighted
#'   average when converting ratios, see [harmonize_regions()]).
#' @export
bbsr_crosswalk_read <- function(path) {
  data <- purrr::map_dfr(path, bbsrgeo_read_file)
  bbsrgeo_check_share_sums(data)
  data
}

#' Sanity-check share sums per ags_old/year_from
#'
#' The area-proportional shares of all target areas of an `ags_old` should
#' sum to 1 per year transition (see Details in [bbsr_crosswalk_read()]). The
#' BBSR source files, however, occasionally contain combinations where this
#' is not the case (e.g. minor boundary corrections without a documented
#' counterpart) - this is not an inconsistency introduced by this package
#' but by the source data, and is surfaced here as a warning.
#'
#' @param data Tibble read by [bbsr_crosswalk_read()].
#' @return `data`, unchanged, invisibly.
#' @noRd
bbsrgeo_check_share_sums <- function(data) {
  sums <- dplyr::summarise(
    dplyr::group_by(data, .data$ags_old, .data$year_from, .data$year_to),
    area_sum = sum(.data$share_area, na.rm = TRUE),
    .groups = "drop"
  )
  off <- sums[abs(sums$area_sum - 1) > SHARE_SUM_TOLERANCE, , drop = FALSE]
  if (nrow(off) > 0) {
    rlang::warn(sprintf(
      paste(
        "%d ags_old/year_from combination(s) have a sum of area shares",
        "that deviates from 1 by more than 1%% (e.g. ags_old = '%s',",
        "year_from = %d: sum = %.3f). This can be due to rounding, but is",
        "more often caused by inconsistencies in the BBSR source file",
        "itself (e.g. missing counterparts for minor boundary corrections)",
        "- please check the original file if in doubt."
      ),
      nrow(off), off$ags_old[1], off$year_from[1], off$area_sum[1]
    ))
  }
  invisible(data)
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

  target_year_match <- regmatches(file_name, regexpr("umrech-(\\d{4})", file_name))
  if (length(target_year_match) > 0 && nzchar(target_year_match)) {
    target_year <- as.integer(sub("umrech-", "", target_year_match))
    kind <- paste0("conversion_", target_year)
  } else {
    target_year <- NA_integer_
    kind <- "annual"
  }

  list(level = level, kind = kind, target_year = target_year, file_name = file_name)
}

bbsrgeo_sheet_years <- function(sheet, meta) {
  if (meta$kind == "annual") {
    m <- regmatches(sheet, regexec("^(\\d{4})-(\\d{4})$", sheet))[[1]]
    if (length(m) == 3) {
      return(list(from = as.integer(m[2]), to = as.integer(m[3])))
    }
    m2 <- regmatches(sheet, regexec("^(\\d{4})$", sheet))[[1]]
    if (length(m2) == 2) {
      year <- as.integer(m2[2])
      return(list(from = year, to = year + 1L))
    }
    rlang::abort(sprintf(
      "Unexpected sheet name '%s' in an 'annual' file (%s) - expected 'YYYY-YYYY' or 'YYYY'.",
      sheet, meta$file_name
    ))
  }

  m <- regmatches(sheet, regexec("^(\\d{4})$", sheet))[[1]]
  if (length(m) != 2) {
    rlang::abort(sprintf(
      "Unexpected sheet name '%s' in a 'conversion' file (%s) - expected 'YYYY'.",
      sheet, meta$file_name
    ))
  }
  list(from = as.integer(m[2]), to = meta$target_year)
}

bbsrgeo_read_sheet <- function(path, sheet, meta) {
  raw <- suppressMessages(
    readxl::read_excel(path, sheet = sheet, col_names = FALSE, skip = 1, col_types = "text")
  )
  n <- ncol(raw)

  if (n == 8) {
    cols <- c(
      "ags_old", "name_old", "share_area", "share_population",
      "area_old", "population_old", "ags_new", "name_new"
    )
    has_employment <- FALSE
  } else if (n == 10) {
    cols <- c(
      "ags_old", "name_old", "share_area", "share_population", "share_employment",
      "area_old", "population_old", "employment_old", "ags_new", "name_new"
    )
    has_employment <- TRUE
  } else {
    rlang::abort(sprintf(
      paste(
        "Unexpected number of columns (%d) in sheet '%s' of %s.",
        "The table structure deviates from the expected structure (8 or 10 columns) -",
        "please inspect the file manually, the BBSR may have changed the format."
      ),
      n, sheet, basename(path)
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
    share_area = as.numeric(raw$share_area),
    share_population = as.numeric(raw$share_population),
    share_employment = as.numeric(raw$share_employment),
    area_old = as.numeric(raw$area_old),
    population_old = as.numeric(raw$population_old),
    employment_old = as.numeric(raw$employment_old)
  )
}
