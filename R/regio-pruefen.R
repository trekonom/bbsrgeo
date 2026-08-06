#' Regionaldaten auf Kompatibilitaet mit einem Umstiegsschluessel pruefen
#'
#' Prueft, ob alle in `daten` vorkommenden AGS-Werte im Umstiegsschluessel als
#' `ags_alt` vorkommen, und meldet fehlende bzw. nicht zuordenbare Werte (z. B.
#' Tippfehler oder Jahre ausserhalb der abgedeckten Zeitspanne). Sinnvoll als
#' Vorstufe zu [regio_konsistent()], um Datenverluste durch stille
#' `inner_join`-Filterung fruehzeitig sichtbar zu machen.
#'
#' @param daten Ein Datensatz mit einer AGS- und einer Jahres-Spalte.
#' @param umstiegsschluessel Ein mit [bbsr_umstieg_read()] eingelesener
#'   Umstiegsschluessel.
#' @param ags_spalte Name der AGS-Spalte in `daten`.
#' @param jahr_spalte Optionaler Name einer Jahres-Spalte in `daten`. Wenn
#'   angegeben, wird zusaetzlich geprueft, ob fuer das jeweilige Jahr
#'   ueberhaupt ein Uebergang im Umstiegsschluessel existiert.
#'
#' @return Unsichtbar (`invisible`) die Zeilen aus `daten`, deren AGS nicht im
#'   Umstiegsschluessel gefunden wurde (0 Zeilen, wenn alles zuordenbar ist).
#'   Eine Zusammenfassung wird als Nachricht ausgegeben.
#' @export
regio_pruefen <- function(daten, umstiegsschluessel, ags_spalte, jahr_spalte = NULL) {
  stopifnot(ags_spalte %in% names(daten))

  ags_werte <- normalisiere_ags(daten[[ags_spalte]])
  bekannte_ags <- unique(c(umstiegsschluessel$ags_alt, umstiegsschluessel$ags_neu))

  unbekannt <- !(ags_werte %in% bekannte_ags)
  n_unbekannt <- sum(unbekannt)

  if (n_unbekannt == 0) {
    message(sprintf("Alle %d Zeilen haben eine im Umstiegsschluessel bekannte AGS.", nrow(daten)))
  } else {
    message(sprintf(
      "%d von %d Zeilen haben eine AGS, die im Umstiegsschluessel nicht vorkommt (moegliche Ursachen: Tippfehler, AGS ausserhalb der abgedeckten Ebene, oder Jahr ausserhalb der Tabelle).",
      n_unbekannt, nrow(daten)
    ))
  }

  if (!is.null(jahr_spalte)) {
    stopifnot(jahr_spalte %in% names(daten))
    jahr_werte <- daten[[jahr_spalte]]
    bekannte_jahre <- unique(c(umstiegsschluessel$jahr_von, umstiegsschluessel$jahr_bis))
    jahr_unbekannt <- !(jahr_werte %in% bekannte_jahre)
    n_jahr_unbekannt <- sum(jahr_unbekannt)
    if (n_jahr_unbekannt > 0) {
      message(sprintf(
        "%d Zeilen haben ein Jahr, das im Umstiegsschluessel nicht abgedeckt ist.",
        n_jahr_unbekannt
      ))
    }
  }

  invisible(daten[unbekannt, , drop = FALSE])
}
