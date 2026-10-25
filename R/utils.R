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

  # "NAs introduced by coercion"; the unparsable values are reported below.
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

# Examples a check names per finding item before cutting the list off.
MAX_FINDING_EXAMPLES <- 5

# A finding is what a check reports, as data: a `header`, `items` (see
# finding_item()), an optional closing `hint` and a `severity` ("warning" or
# "message"). A check returns NULL when it finds nothing; report_finding()
# signals one.
finding <- function(header, items, hint = NULL, severity = "warning") {
  severity <- rlang::arg_match0(severity, c("warning", "message"))
  list(header = header, items = items, hint = hint, severity = severity)
}

# One bullet of a finding: `n` cases described by `label`, with `examples`
# (strings the check formatted and capped). `scope` prefixes the bullet
# ("<scope>: ").
finding_item <- function(label, n, examples, scope = NULL) {
  list(label = label, n = n, examples = examples, scope = scope)
}

# Signals a finding once, as a warning or a message according to its severity:
# the header, one bullet "<scope>: <n> <label>, e.g. <examples>" per item, the
# hint. Does not cap or reformat the examples. NULL signals nothing.
report_finding <- function(finding) {
  if (is.null(finding)) {
    return(invisible())
  }
  bullets <- purrr::map_chr(finding$items, function(item) {
    sprintf(
      "%s%d %s, e.g. %s",
      if (is.null(item$scope)) "" else paste0(item$scope, ": "),
      item$n,
      item$label,
      paste(item$examples, collapse = "; ")
    )
  })
  body <- c(
    finding$header,
    stats::setNames(bullets, rep("*", length(bullets))),
    if (!is.null(finding$hint)) c(i = finding$hint)
  )
  signal <- if (finding$severity == "warning") rlang::warn else rlang::inform
  signal(body)
  invisible()
}
