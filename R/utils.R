bbsrgeo_user_agent <- function() {
  paste0(
    "bbsrgeo/",
    as.character(utils::packageVersion("bbsrgeo")),
    " (R package for BBSR area crosswalks; contact: stefan.moog@prognos.com)"
  )
}

bbsrgeo_cache_dir <- function(cache_dir = NULL) {
  cache_dir <- cache_dir %||% tools::R_user_dir("bbsrgeo", which = "cache")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  cache_dir
}

#' Normalize AGS values to a consistent 8-digit format
#'
#' The BBSR stores district/municipality keys (AGS) in its xlsx files partly
#' as numbers, partly as text. For federal states with country code "01" to
#' "09", the leading zero is lost as soon as a cell is interpreted as a
#' number. This function enforces a consistent, zero-padded 8-digit text
#' format.
#'
#' @param x Character or numeric vector of AGS values.
#' @return Character vector of 8-digit AGS values (or `NA`).
#' @noRd
normalize_ags <- function(x) {
  x <- trimws(as.character(x))
  x[!nzchar(x)] <- NA_character_

  ags_num <- suppressWarnings(as.numeric(x))
  invalid <- is.na(ags_num) & !is.na(x)
  if (any(invalid)) {
    rlang::warn(sprintf(
      "%d AGS value(s) could not be parsed as a number and were set to NA (e.g. '%s').",
      sum(invalid),
      x[which(invalid)[1]]
    ))
  }

  ifelse(is.na(ags_num), NA_character_, sprintf("%08.0f", ags_num))
}

# Largest deviation of a crosswalk's shares per ags_old/transition from a sum of
# 1 that is treated as rounding (see bbsrgeo_check_share_sums() and
# renormalize_forward_shares()).
SHARE_SUM_TOLERANCE <- 0.01
