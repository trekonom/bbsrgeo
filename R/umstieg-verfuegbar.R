#' Verfuegbare BBSR-Umstiegsschluessel auflisten
#'
#' Gibt die im Paket hinterlegte Uebersicht der vom BBSR
#' (Bundesinstitut fuer Bau-, Stadt- und Raumforschung) veroeffentlichten
#' Umstiegsschluessel-Dateien zurueck: jaehrliche (verkettbare) Schluessel
#' sowie direkte Umrechnungen historischer Jahre auf einen festen
#' Gebietsstand (2019/2020/2021).
#'
#' Die Liste ist statisch im Paket hinterlegt (siehe
#' `data-raw/bbsr_umstieg_urls.R`) und kann veralten, sobald das BBSR neue
#' Jahrgaenge oder Gebietsstaende veroeffentlicht. Mit
#' [bbsr_umstieg_verfuegbar_live()] steht eine Alternative zur Verfuegung,
#' die die BBSR-Uebersichtsseite live abfragt.
#'
#' @param ebene Character-Vektor: `"Gemeinden"`, `"Kreise"` oder beides
#'   (Standard).
#'
#' @return Ein Tibble mit den Spalten `ebene`, `art` (`"jaehrlich"`,
#'   `"umrechnung_2019"`, `"umrechnung_2020"` oder `"umrechnung_2021"`),
#'   `von_jahr`, `bis_jahr`, `url` und `dateigroesse`.
#' @export
#'
#' @examples
#' bbsr_umstieg_verfuegbar("Kreise")
bbsr_umstieg_verfuegbar <- function(ebene = c("Gemeinden", "Kreise")) {
  ebene <- match.arg(ebene, several.ok = TRUE)
  dplyr::filter(bbsr_umstieg_urls, .data$ebene %in% .env$ebene)
}
