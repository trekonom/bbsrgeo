bbsrgeo_user_agent <- function() {
  paste0(
    "bbsrgeo/", as.character(utils::packageVersion("bbsrgeo")),
    " (R-Paket fuer BBSR-Umstiegsschluessel; Kontakt: stefan.moog@prognos.com)"
  )
}

bbsrgeo_cache_dir <- function(cache_dir = NULL) {
  cache_dir <- cache_dir %||% tools::R_user_dir("bbsrgeo", which = "cache")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  cache_dir
}

#' AGS-Werte auf ein einheitliches 8-stelliges Format normalisieren
#'
#' Kreis- und Gemeindeschluessel werden vom BBSR in den xlsx-Dateien teils als
#' Zahl, teils als Text abgelegt. Bei Bundeslaendern mit Laendercode "01" bis
#' "09" geht dabei die fuehrende Null verloren, sobald eine Zelle als Zahl
#' interpretiert wird. Diese Funktion erzwingt einheitlich ein 8-stelliges,
#' nullgepolstertes Text-Format.
#'
#' @param x Character- oder numerischer Vektor mit AGS-Werten.
#' @return Character-Vektor mit 8-stelligen AGS (oder `NA`).
#' @noRd
normalisiere_ags <- function(x) {
  x <- trimws(as.character(x))
  x[!nzchar(x)] <- NA_character_

  ags_num <- suppressWarnings(as.numeric(x))
  ungueltig <- is.na(ags_num) & !is.na(x)
  if (any(ungueltig)) {
    rlang::warn(sprintf(
      "%d AGS-Wert(e) konnten nicht als Zahl interpretiert werden und wurden auf NA gesetzt (z. B. '%s').",
      sum(ungueltig), x[which(ungueltig)[1]]
    ))
  }

  ifelse(is.na(ags_num), NA_character_, sprintf("%08.0f", ags_num))
}
