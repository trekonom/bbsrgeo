#' Regionalstatistik-Zeitreihe auf einen konsistenten Gebietsstand umrechnen
#'
#' Rechnet einen Regionalstatistik-Datensatz (AGS/Kreis- bzw. Gemeindeschluessel
#' + Jahr + Wertespalte(n)) mithilfe eines BBSR-Umstiegsschluessels
#' (siehe [bbsr_umstieg_read()]) auf einen einheitlichen Gebietsstand um.
#'
#' `daten` muss im "langen" Panelformat vorliegen: eine Zeile je Kombination
#' aus Gebietseinheit (`ags_spalte`) und Jahr (`jahr_spalte`), mit einer oder
#' mehreren numerischen Wertespalten (`wert_spalten`). Liegen die Daten breit
#' vor (Jahre als Spalten), zuvor mit `tidyr::pivot_longer()` umformen.
#'
#' Je nach `typ` werden die Werte unterschiedlich behandelt:
#' * `"absolut"`: gewichtete Aggregation - der Wert einer alten Einheit wird
#'   mit dem gewaehlten Anteilswert multipliziert und je neuer Zieleinheit
#'   aufsummiert. Passend fuer absolute Groessen wie Einwohnerzahl,
#'   Beschaeftigte, Flaeche.
#' * `"verhaeltnis"`: gewichteter Mittelwert - als Gewichte dienen die mit dem
#'   Anteilswert skalierten Absolutwerte (Flaeche/Bevoelkerung/Beschaeftigte)
#'   der jeweils beitragenden alten Einheiten. Passend fuer Verhaeltniszahlen
#'   und Indikatoren (z. B. Arbeitslosenquote, Einwohner je km²).
#'
#' Ist der Umstiegsschluessel vom Typ `"jaehrlich"` und `ziel_gebietsstand`
#' mehr als einen Jahresschritt entfernt, werden die Jahresschluessel
#' automatisch verkettet (sofern lueckenlos vorhanden). Bei einem
#' `"umrechnung_*"`-Schluessel erfolgt die Umrechnung direkt in einem Schritt.
#'
#' Die Umstiegsschluessel des BBSR sind fuer die **Vorwaertsrechnung** (alter
#' -> neuer/aktueller Gebietsstand) konzipiert. Liegt `ziel_gebietsstand` vor
#' dem Jahr einzelner Datenzeilen (Disaggregation auf einen aelteren
#' Gebietsstand), ist das Ergebnis mit einer hoeheren Unsicherheit behaftet
#' (siehe BBSR-Hinweise) und muss explizit mit `erlaube_rueckrechnung = TRUE`
#' aktiviert werden.
#'
#' @param daten Datensatz im langen Panelformat (siehe Details).
#' @param umstiegsschluessel Ein mit [bbsr_umstieg_read()] eingelesener
#'   Umstiegsschluessel, passend zu `ebene`.
#' @param ags_spalte Name der AGS-Spalte in `daten`.
#' @param jahr_spalte Name der Jahres-Spalte in `daten`.
#' @param wert_spalten Character-Vektor mit den Namen der umzurechnenden
#'   Wertespalten.
#' @param typ `"absolut"` oder `"verhaeltnis"` (siehe Details).
#' @param gewicht Gewichtungsbasis: `"bevoelkerung"`, `"flaeche"` oder
#'   `"beschaeftigte"` (siehe BBSR-Empfehlungen in `vignette("bbsrgeo")`).
#' @param ziel_gebietsstand Zieljahr des Gebietsstands (z. B. `2024L`) oder
#'   `"aktuell"` fuer den juengsten im Umstiegsschluessel verfuegbaren Stand.
#' @param ebene `"Kreise"` oder `"Gemeinden"`.
#' @param erlaube_rueckrechnung Rueckrechnung (Disaggregation auf einen
#'   aelteren Gebietsstand) explizit erlauben. Standard `FALSE`.
#'
#' @return Ein Tibble mit den Spalten `ags_spalte`, `jahr_spalte`,
#'   `wert_spalten` (umgerechnet) sowie `gebietsstand` (= `ziel_gebietsstand`,
#'   aufgeloest zu einer Jahreszahl).
#' @export
regio_konsistent <- function(daten,
                              umstiegsschluessel,
                              ags_spalte,
                              jahr_spalte,
                              wert_spalten,
                              typ = c("absolut", "verhaeltnis"),
                              gewicht = c("bevoelkerung", "flaeche", "beschaeftigte"),
                              ziel_gebietsstand,
                              ebene = c("Kreise", "Gemeinden"),
                              erlaube_rueckrechnung = FALSE) {
  typ <- match.arg(typ)
  gewicht <- match.arg(gewicht)
  ebene <- match.arg(ebene)

  if (ebene == "Kreise") {
    regio_konsistent_kreise(
      daten, umstiegsschluessel, ags_spalte, jahr_spalte, wert_spalten,
      typ, gewicht, ziel_gebietsstand, erlaube_rueckrechnung
    )
  } else {
    regio_konsistent_gemeinden(
      daten, umstiegsschluessel, ags_spalte, jahr_spalte, wert_spalten,
      typ, gewicht, ziel_gebietsstand, erlaube_rueckrechnung
    )
  }
}

#' @rdname regio_konsistent
#' @export
regio_konsistent_kreise <- function(daten, umstiegsschluessel, ags_spalte, jahr_spalte,
                                     wert_spalten, typ = c("absolut", "verhaeltnis"),
                                     gewicht = c("bevoelkerung", "flaeche", "beschaeftigte"),
                                     ziel_gebietsstand, erlaube_rueckrechnung = FALSE) {
  typ <- match.arg(typ)
  gewicht <- match.arg(gewicht)
  regio_konsistent_intern(
    daten, umstiegsschluessel, ags_spalte, jahr_spalte, wert_spalten,
    typ, gewicht, ziel_gebietsstand, erlaube_rueckrechnung
  )
}

#' @rdname regio_konsistent
#' @export
regio_konsistent_gemeinden <- function(daten, umstiegsschluessel, ags_spalte, jahr_spalte,
                                        wert_spalten, typ = c("absolut", "verhaeltnis"),
                                        gewicht = c("bevoelkerung", "flaeche", "beschaeftigte"),
                                        ziel_gebietsstand, erlaube_rueckrechnung = FALSE) {
  typ <- match.arg(typ)
  gewicht <- match.arg(gewicht)
  regio_konsistent_intern(
    daten, umstiegsschluessel, ags_spalte, jahr_spalte, wert_spalten,
    typ, gewicht, ziel_gebietsstand, erlaube_rueckrechnung
  )
}

regio_konsistent_intern <- function(daten, umstiegsschluessel, ags_spalte, jahr_spalte,
                                     wert_spalten, typ, gewicht, ziel_gebietsstand,
                                     erlaube_rueckrechnung) {
  stopifnot(
    ags_spalte %in% names(daten),
    jahr_spalte %in% names(daten),
    all(wert_spalten %in% names(daten))
  )

  ziel_jahr <- if (identical(ziel_gebietsstand, "aktuell")) {
    max(umstiegsschluessel$jahr_bis, na.rm = TRUE)
  } else {
    as.integer(ziel_gebietsstand)
  }

  basis <- tibble::tibble(
    ..ags = normalisiere_ags(daten[[ags_spalte]]),
    ..jahr = as.integer(daten[[jahr_spalte]])
  )
  basis <- dplyr::bind_cols(basis, daten[wert_spalten])

  gruppen <- split(basis, basis$..jahr)
  ergebnis <- purrr::map_dfr(gruppen, function(gruppe) {
    regio_konsistent_pfad(
      gruppe, umstiegsschluessel, wert_spalten, typ, gewicht,
      gruppe$..jahr[[1]], ziel_jahr, erlaube_rueckrechnung
    )
  })

  ergebnis$gebietsstand <- ziel_jahr
  namen <- c(ags_spalte, jahr_spalte, wert_spalten, "gebietsstand")
  names(ergebnis)[names(ergebnis) == "..ags"] <- ags_spalte
  names(ergebnis)[names(ergebnis) == "..jahr"] <- jahr_spalte
  ergebnis[, namen]
}

regio_konsistent_pfad <- function(gruppe, schluessel, wert_spalten, typ, gewicht,
                                   jahr_start, ziel_jahr, erlaube_rueckrechnung) {
  if (jahr_start == ziel_jahr) {
    return(gruppe)
  }

  vorwaerts <- jahr_start < ziel_jahr

  if (!vorwaerts) {
    if (!erlaube_rueckrechnung) {
      rlang::abort(sprintf(
        paste(
          "Jahr %d liegt nach dem Ziel-Gebietsstand %d (das entspraeche einer",
          "Rueckrechnung/Disaggregation auf einen aelteren Gebietsstand).",
          "Die BBSR-Umstiegsschluessel sind fuer die Vorwaertsrechnung konzipiert;",
          "eine Rueckrechnung ist fehleranfaelliger. Mit",
          "erlaube_rueckrechnung = TRUE explizit aktivieren."
        ),
        jahr_start, ziel_jahr
      ))
    }
    rlang::warn(paste(
      "Rueckrechnung (Disaggregation von einem neueren auf einen aelteren",
      "Gebietsstand) ist experimentell und mit einem hoeheren Schaetzfehler",
      "verbunden als die vom BBSR vorgesehene Vorwaertsrechnung."
    ))
  }

  direkt <- schluessel[
    schluessel$jahr_von == (if (vorwaerts) jahr_start else ziel_jahr) &
      schluessel$jahr_bis == (if (vorwaerts) ziel_jahr else jahr_start),
    ,
    drop = FALSE
  ]

  if (nrow(direkt) > 0) {
    return(regio_konsistent_schritt(gruppe, direkt, wert_spalten, typ, gewicht, vorwaerts))
  }

  jahre_hops <- if (vorwaerts) {
    seq(jahr_start, ziel_jahr - 1L)
  } else {
    seq(jahr_start - 1L, ziel_jahr, by = -1L)
  }

  aktuelle <- gruppe
  for (j in jahre_hops) {
    von <- if (vorwaerts) j else j + 1L
    bis <- if (vorwaerts) j + 1L else j
    schritt_schluessel <- schluessel[schluessel$jahr_von == von & schluessel$jahr_bis == bis, , drop = FALSE]
    if (nrow(schritt_schluessel) == 0) {
      rlang::abort(sprintf(
        paste(
          "Kein Umstiegsschluessel fuer den Uebergang %d -> %d gefunden.",
          "Verkettung von %d auf %d nicht moeglich - der uebergebene",
          "Umstiegsschluessel deckt diesen Jahresschritt nicht ab."
        ),
        von, bis, jahr_start, ziel_jahr
      ))
    }
    aktuelle <- regio_konsistent_schritt(aktuelle, schritt_schluessel, wert_spalten, typ, gewicht, vorwaerts)
  }
  aktuelle
}

regio_konsistent_schritt <- function(gruppe, schritt_schluessel, wert_spalten, typ, gewicht, vorwaerts) {
  anteil_spalte <- paste0("anteil_", gewicht)
  basis_spalte <- switch(gewicht,
    flaeche = "flaeche_alt",
    bevoelkerung = "bevoelkerung_alt",
    beschaeftigte = "beschaeftigte_alt"
  )

  if (vorwaerts) {
    von_spalte <- "ags_alt"
    nach_spalte <- "ags_neu"
  } else {
    von_spalte <- "ags_neu"
    nach_spalte <- "ags_alt"
  }

  schluessel_join <- tibble::tibble(
    ..ags = schritt_schluessel[[von_spalte]],
    ..ags_ziel = schritt_schluessel[[nach_spalte]],
    ..anteil = schritt_schluessel[[anteil_spalte]],
    ..basis = schritt_schluessel[[basis_spalte]]
  )

  verbunden <- dplyr::inner_join(gruppe, schluessel_join, by = "..ags")

  fehlend <- setdiff(unique(gruppe$..ags), unique(verbunden$..ags))
  if (length(fehlend) > 0) {
    rlang::warn(sprintf(
      "%d AGS-Wert(e) ohne passenden Eintrag im Umstiegsschluessel fuer diesen Uebergang wurden verworfen: %s",
      length(fehlend), paste(utils::head(fehlend, 5), collapse = ", ")
    ))
  }

  if (typ == "absolut") {
    for (v in wert_spalten) {
      verbunden[[v]] <- verbunden[[v]] * verbunden$..anteil
    }
    ergebnis <- dplyr::group_by(verbunden, .data$..ags_ziel, .data$..jahr)
    ergebnis <- dplyr::summarise(
      ergebnis,
      dplyr::across(dplyr::all_of(wert_spalten), ~ sum(.x, na.rm = TRUE)),
      .groups = "drop"
    )
  } else {
    verbunden$..gewicht <- verbunden$..anteil * verbunden$..basis
    ergebnis <- dplyr::group_by(verbunden, .data$..ags_ziel, .data$..jahr)
    ergebnis <- dplyr::summarise(
      ergebnis,
      dplyr::across(
        dplyr::all_of(wert_spalten),
        ~ stats::weighted.mean(.x, w = .data$..gewicht, na.rm = TRUE)
      ),
      .groups = "drop"
    )
  }

  dplyr::rename(ergebnis, ..ags = "..ags_ziel")
}
