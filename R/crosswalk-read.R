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
#' @param fix Apply the documented corrections of [bbsr_crosswalk_fix()].
#'   Default `TRUE`; `FALSE` returns the files as published.
#'
#' @return A tibble with columns `ags_old`, `name_old`, `ags_new`,
#'   `name_new`, `year_from`, `year_to`, `share_area`, `share_population`,
#'   `share_employment` (`NA` before 1997, since the BBSR only offers
#'   employment data as a weighting basis from 1997 onward), and the
#'   corresponding absolute values `area_old`, `population_old`, and
#'   `employment_old` of the respective old unit (basis for a weighted
#'   average when converting ratios, see [harmonize_regions()]).
#' @export
bbsr_crosswalk_read <- function(path, fix = TRUE) {
  stopifnot(is.logical(fix), length(fix) == 1, !is.na(fix))
  data <- purrr::map_dfr(path, bbsrgeo_read_file)
  if (fix) {
    data <- bbsr_crosswalk_fix(data)
  }
  bbsrgeo_check_names(data)
  bbsrgeo_check_share_sums(data)
  bbsrgeo_check_count_shares(data)
  data
}

#' Check that the names of one code are constant within a transition
#'
#' Within one `ags_old`/`year_from`/`year_to` group `name_old` should be one
#' name, and likewise `name_new` within an `ags_new` group. More than one
#' distinct name means a row carries the code of another unit (e.g. 07235000 in
#' 2011 -> 2012 with the name Bernkastel-Wittlich). Missing names are ignored.
#' Reported as one warning, without a cause.
#'
#' @param data Tibble read by [bbsr_crosswalk_read()].
#' @return `data`, unchanged, invisibly.
#' @noRd
bbsrgeo_check_names <- function(data) {
  inconsistent <- function(code_col, name_col) {
    if (!all(c(code_col, name_col) %in% names(data))) {
      return(NULL)
    }
    d <- data.frame(
      code = data[[code_col]],
      name = data[[name_col]],
      year_from = data$year_from,
      year_to = data$year_to
    )
    d <- unique(d[!is.na(d$name), , drop = FALSE])
    key <- paste(d$code, d$year_from, d$year_to)
    n_names <- stats::ave(seq_len(nrow(d)), key, FUN = length)
    d <- d[n_names > 1, , drop = FALSE]
    if (nrow(d) == 0) {
      return(NULL)
    }
    d <- d[order(d$code, d$year_from), , drop = FALSE]
    groups <- split(d, paste(d$code, d$year_from, d$year_to), drop = TRUE)
    list(
      code_col = code_col,
      n = length(groups),
      examples = purrr::map_chr(utils::head(groups, 5), function(g) {
        sprintf(
          "%s '%s' (%d -> %d): %s",
          code_col,
          g$code[1],
          g$year_from[1],
          g$year_to[1],
          paste0("'", g$name, "'", collapse = ", ")
        )
      })
    )
  }

  found <- purrr::compact(list(
    inconsistent("ags_old", "name_old"),
    inconsistent("ags_new", "name_new")
  ))
  if (length(found) == 0) {
    return(invisible(data))
  }
  lines <- purrr::map_chr(found, function(f) {
    sprintf(
      "%d %s group(s) with more than one name, e.g. %s",
      f$n,
      f$code_col,
      paste(f$examples, collapse = "; ")
    )
  })
  rlang::warn(c(
    "The names of one code differ within a transition:",
    stats::setNames(lines, rep("*", length(lines))),
    i = "Please check the original file if in doubt."
  ))
  invisible(data)
}

#' Check that shares agree with their own counts
#'
#' For each weight basis, in an `ags_old`/transition group with several target
#' rows, counts that are all observed, non-negative and differ between rows
#' (as in [harmonize_regions()]), a positive total and shares summing to 1
#' within `SHARE_SUM_TOLERANCE`, `count / total` should equal the share. A
#' row deviates by more than the counts' resolution allows when
#' `|count / total - share| > COUNT_RESOLUTION * (1 + n_rows) / total`. Groups
#' with equal counts or shares summing off 1 are skipped. Reported as one
#' message; the conversion uses the shares as given (ADR 0001).
#'
#' @param data Tibble read by [bbsr_crosswalk_read()].
#' @return `data`, unchanged, invisibly.
#' @noRd
bbsrgeo_check_count_shares <- function(data) {
  lines <- character()
  for (basis in c("area", "population", "employment")) {
    share_col <- paste0("share_", basis)
    count_col <- paste0(basis, "_old")
    if (!all(c(share_col, count_col) %in% names(data))) {
      next
    }
    d <- data.frame(
      ags_old = data$ags_old,
      year_from = data$year_from,
      year_to = data$year_to,
      share = data[[share_col]],
      count = data[[count_col]]
    )
    key <- paste(d$ags_old, d$year_from, d$year_to)
    group_sum <- function(x) stats::ave(x, key, FUN = sum)
    group_n <- stats::ave(d$share, key, FUN = length)
    total <- group_sum(d$count)
    varies <- stats::ave(d$count, key, FUN = function(v) {
      !anyNA(v) &&
        diff(range(v)) > COUNT_DIFFERENCE_TOLERANCE * max(abs(v))
    }) ==
      1
    non_negative <- stats::ave(d$count, key, FUN = function(v) {
      all(v >= 0)
    }) ==
      1
    share_sum <- group_sum(d$share)
    eligible <- group_n > 1 &
      varies &
      non_negative &
      !is.na(total) &
      total > 0 &
      !is.na(share_sum) &
      !share_sum_deviates(share_sum)
    excess <- abs(d$count / total - d$share) -
      COUNT_RESOLUTION * (1 + group_n) / total
    disagree <- eligible & !is.na(excess) & excess > 0
    if (!any(disagree)) {
      next
    }
    groups <- unique(d[disagree, c("ags_old", "year_from", "year_to")])
    groups <- groups[order(groups$ags_old, groups$year_from), , drop = FALSE]
    shown <- utils::head(groups, 5)
    lines <- c(
      lines,
      sprintf(
        "%s: %d group(s), e.g. %s",
        basis,
        nrow(groups),
        paste(
          sprintf(
            "ags_old = '%s', year_from = %d",
            shown$ags_old,
            shown$year_from
          ),
          collapse = "; "
        )
      )
    )
  }
  if (length(lines) > 0) {
    rlang::inform(c(
      paste(
        "Some shares disagree with their counts by more than the counts'",
        "resolution allows (count / total differs from the share):"
      ),
      stats::setNames(lines, rep("*", length(lines))),
      i = paste(
        "The conversion uses the shares as given. Please check the original",
        "file if in doubt."
      )
    ))
  }
  invisible(data)
}

#' Sanity-check share sums per ags_old/year_from
#'
#' The area-proportional shares of all target areas of an `ags_old` should
#' sum to 1 per year transition (see Details in [bbsr_crosswalk_read()]). The
#' BBSR source files, however, contain combinations where this is not the
#' case. They are surfaced here as one warning that counts them by the pattern
#' observed in the rows (see "Share deviation" in `GLOSSARY.md`), without
#' stating a cause.
#'
#' @param data Tibble read by [bbsr_crosswalk_read()].
#' @return `data`, unchanged, invisibly.
#' @noRd
bbsrgeo_check_share_sums <- function(data) {
  count_cols <- intersect(
    c("area_old", "population_old", "employment_old"),
    names(data)
  )
  differs <- function(v) {
    !anyNA(v) && diff(range(v)) > COUNT_DIFFERENCE_TOLERANCE * max(abs(v))
  }
  summary <- dplyr::summarise(
    dplyr::group_by(data, .data$ags_old, .data$year_from, .data$year_to),
    n_rows = dplyr::n(),
    area_sum = sum(.data$share_area, na.rm = TRUE),
    all_one = all(abs(.data$share_area - 1) <= SHARE_SUM_TOLERANCE),
    dplyr::across(
      dplyr::all_of(count_cols),
      differs,
      .names = "differs_{.col}"
    ),
    .groups = "drop"
  )
  summary$counts_differ <- Reduce(
    `|`,
    summary[paste0("differs_", count_cols)],
    FALSE
  )
  off <- summary[share_sum_deviates(summary$area_sum), , drop = FALSE]
  if (nrow(off) == 0) {
    return(invisible(data))
  }

  # Patterns are named from what the rows look like, not from a cause.
  off$pattern <- dplyr::case_when(
    off$n_rows > 1 & off$all_one & off$counts_differ ~ "a",
    off$n_rows == 1 & off$area_sum < 1 ~ "b",
    TRUE ~ "c"
  )
  labels <- c(
    a = paste(
      "a share of 1 on every target row of a multi-row group, with counts",
      "that differ between rows"
    ),
    b = "a single target row with a share below 1",
    c = "other"
  )
  lines <- purrr::map_chr(
    intersect(names(labels), off$pattern),
    function(p) {
      rows <- off[off$pattern == p, , drop = FALSE]
      sprintf(
        "%d combination(s): %s (e.g. ags_old = '%s', year_from = %d: sum = %.3f)",
        nrow(rows),
        labels[[p]],
        rows$ags_old[1],
        rows$year_from[1],
        rows$area_sum[1]
      )
    }
  )
  rlang::warn(c(
    sprintf(
      paste(
        "%d ags_old/year_from combination(s) have a sum of area shares that",
        "deviates from 1 by more than 1%%. By pattern:"
      ),
      nrow(off)
    ),
    stats::setNames(lines, rep("*", length(lines))),
    i = "Please check the original file if in doubt."
  ))
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
      basename(path)
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
