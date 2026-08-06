#' BBSR-Umstiegsschluessel herunterladen
#'
#' Laedt eine zu `ebene`/`art` (und optional `von_jahr`/`bis_jahr`) passende
#' Umstiegsschluessel-Datei (xlsx) vom BBSR herunter und legt sie in einem
#' lokalen Cache-Verzeichnis ab. Bereits gecachte Dateien werden per Default
#' nicht erneut heruntergeladen.
#'
#' @param ebene `"Gemeinden"` oder `"Kreise"`.
#' @param art Art der Tabelle: `"jaehrlich"` (Jahr-zu-Jahr-Umstiegsschluessel,
#'   verkettbar) oder `"umrechnung_2019"`/`"umrechnung_2020"`/
#'   `"umrechnung_2021"` (direkte Umrechnung historischer Jahre auf den
#'   jeweiligen festen Zieljahr-Gebietsstand).
#' @param von_jahr,bis_jahr Optionale Filter auf die in
#'   [bbsr_umstieg_verfuegbar()] gelisteten Jahresspannen. `NULL` (Standard)
#'   liefert alle zu `ebene`/`art` passenden Dateien (i. d. R. genau eine).
#' @param cache_dir Zielverzeichnis fuer den Cache. Standard:
#'   `tools::R_user_dir("bbsrgeo", "cache")`.
#' @param overwrite Bereits gecachte Dateien erneut herunterladen?
#'
#' @return Character-Vektor mit den lokalen Pfaden der (heruntergeladenen
#'   oder bereits gecachten) Dateien.
#' @export
bbsr_umstieg_download <- function(ebene = c("Gemeinden", "Kreise"),
                                   art = c("jaehrlich", "umrechnung_2019", "umrechnung_2020", "umrechnung_2021"),
                                   von_jahr = NULL,
                                   bis_jahr = NULL,
                                   cache_dir = NULL,
                                   overwrite = FALSE) {
  ebene <- match.arg(ebene)
  art <- match.arg(art)
  cache_dir <- bbsrgeo_cache_dir(cache_dir)

  treffer <- bbsr_umstieg_verfuegbar(ebene)
  treffer <- treffer[treffer$art == art, , drop = FALSE]
  if (!is.null(von_jahr)) treffer <- treffer[treffer$von_jahr == von_jahr, , drop = FALSE]
  if (!is.null(bis_jahr)) treffer <- treffer[treffer$bis_jahr == bis_jahr, , drop = FALSE]

  if (nrow(treffer) == 0) {
    rlang::abort(sprintf(
      "Keine passende Umstiegsschluessel-Datei gefunden (ebene = '%s', art = '%s', von_jahr = %s, bis_jahr = %s). Siehe bbsr_umstieg_verfuegbar() fuer verfuegbare Kombinationen.",
      ebene, art,
      if (is.null(von_jahr)) "NULL" else von_jahr,
      if (is.null(bis_jahr)) "NULL" else bis_jahr
    ))
  }

  vapply(
    treffer$url, bbsrgeo_download_datei,
    FUN.VALUE = character(1), cache_dir = cache_dir, overwrite = overwrite,
    USE.NAMES = FALSE
  )
}

bbsrgeo_download_datei <- function(url, cache_dir, overwrite) {
  dateiname <- basename(sub("\\?.*$", "", url))
  ziel <- file.path(cache_dir, dateiname)

  if (file.exists(ziel) && !overwrite) {
    return(ziel)
  }

  resp <- tryCatch(
    {
      httr2::request(url) |>
        httr2::req_user_agent(bbsrgeo_user_agent()) |>
        httr2::req_timeout(120) |>
        httr2::req_perform()
    },
    error = function(e) {
      rlang::abort(sprintf("Download von %s fehlgeschlagen: %s", url, conditionMessage(e)), parent = e)
    }
  )
  writeBin(httr2::resp_body_raw(resp), ziel)

  ziel
}
