#' BBSR-Umstiegsschluessel einlesen
#'
#' Liest eine oder mehrere lokale Umstiegsschluessel-xlsx-Dateien (siehe
#' [bbsr_umstieg_download()]) ein und normalisiert sie zu einem einheitlichen
#' "long"-Tibble.
#'
#' Jede Datei enthaelt ein Tabellenblatt je Jahresuebergang (bei
#' `"jaehrlich"`-Dateien, Blattname z. B. `"2010-2011"` oder `"2010"`) bzw. je
#' Ausgangsjahr (bei `"umrechnung_*"`-Dateien, Blattname = Ausgangsjahr, festes
#' Zieljahr aus dem Dateinamen). `ebene` und `art` werden dazu aus dem
#' Dateinamen abgeleitet (siehe [bbsr_umstieg_verfuegbar()] fuer die
#' Namenskonventionen). Bei Gebietsreformen (Gemeindezusammenschluessen,
#' Kreisneugliederungen) gibt es mehrere Zeilen je `ags_alt`, deren
#' Anteilswerte sich jeweils zu 1 aufsummieren.
#'
#' @param pfad Pfad oder Vektor von Pfaden zu lokalen xlsx-Dateien (siehe
#'   [bbsr_umstieg_download()]).
#'
#' @return Ein Tibble mit den Spalten `ags_alt`, `name_alt`, `ags_neu`,
#'   `name_neu`, `jahr_von`, `jahr_bis`, `anteil_flaeche`,
#'   `anteil_bevoelkerung`, `anteil_beschaeftigte` (vor 1997 `NA`, da das BBSR
#'   Beschaeftigtendaten erst ab 1997 als Gewichtungsbasis anbietet) sowie den
#'   zugehoerigen Absolutwerten `flaeche_alt`, `bevoelkerung_alt` und
#'   `beschaeftigte_alt` der jeweiligen alten Einheit (Basis fuer eine
#'   gewichtete Mittelwertbildung bei Verhaeltniszahlen, siehe
#'   [regio_konsistent()]).
#' @export
bbsr_umstieg_read <- function(pfad) {
  daten <- purrr::map_dfr(pfad, bbsrgeo_read_datei)
  bbsrgeo_pruefe_anteilsummen(daten)
  daten
}

#' Anteilssummen je ags_alt/jahr_von auf Plausibilitaet pruefen
#'
#' Die flaechenproportionalen Anteile aller Zielgebiete eines `ags_alt` sollten
#' sich je Jahresuebergang zu 1 aufsummieren (siehe Details in
#' [bbsr_umstieg_read()]). In den BBSR-Quelldateien kommen jedoch vereinzelt
#' Kombinationen vor, bei denen das nicht der Fall ist (z. B. bei kleinen
#' Grenzkorrekturen ohne dokumentiertes Gegenstueck) - das ist keine
#' Unstimmigkeit dieses Pakets, sondern der Ausgangsdaten, wird hier aber als
#' Warnung sichtbar gemacht.
#'
#' @param daten Von [bbsr_umstieg_read()] eingelesenes Tibble.
#' @return `daten` unveraendert, unsichtbar.
#' @noRd
bbsrgeo_pruefe_anteilsummen <- function(daten) {
  summen <- dplyr::summarise(
    dplyr::group_by(daten, .data$ags_alt, .data$jahr_von, .data$jahr_bis),
    summe_flaeche = sum(.data$anteil_flaeche, na.rm = TRUE),
    .groups = "drop"
  )
  abweichend <- summen[abs(summen$summe_flaeche - 1) > 0.01, , drop = FALSE]
  if (nrow(abweichend) > 0) {
    rlang::warn(sprintf(
      paste(
        "%d Kombination(en) aus ags_alt/jahr_von haben eine Summe der",
        "flaechenproportionalen Anteile, die um mehr als 1%% von 1 abweicht",
        "(z. B. ags_alt = '%s', jahr_von = %d: Summe = %.3f). Das kann an",
        "Rundung liegen, haeufiger jedoch an Unstimmigkeiten in der",
        "BBSR-Quelldatei selbst (z. B. fehlende Gegenstuecke bei kleinen",
        "Grenzkorrekturen) - bitte im Zweifel die Originaldatei pruefen."
      ),
      nrow(abweichend), abweichend$ags_alt[1], abweichend$jahr_von[1], abweichend$summe_flaeche[1]
    ))
  }
  invisible(daten)
}

bbsrgeo_read_datei <- function(pfad) {
  if (!file.exists(pfad)) {
    rlang::abort(sprintf("Datei nicht gefunden: %s", pfad))
  }
  meta <- bbsrgeo_datei_meta(pfad)
  sheets <- readxl::excel_sheets(pfad)
  purrr::map_dfr(sheets, function(sheet) bbsrgeo_read_sheet(pfad, sheet, meta))
}

bbsrgeo_datei_meta <- function(pfad) {
  dateiname <- basename(pfad)

  ebene <- dplyr::case_when(
    grepl("gemeinden", dateiname, ignore.case = TRUE) ~ "Gemeinden",
    grepl("kreise", dateiname, ignore.case = TRUE) ~ "Kreise",
    TRUE ~ NA_character_
  )
  if (is.na(ebene)) {
    rlang::warn(sprintf(
      "Konnte 'ebene' (Gemeinden/Kreise) nicht aus dem Dateinamen '%s' ableiten.",
      dateiname
    ))
  }

  zieljahr_match <- regmatches(dateiname, regexpr("umrech-(\\d{4})", dateiname))
  if (length(zieljahr_match) > 0 && nzchar(zieljahr_match)) {
    zieljahr <- as.integer(sub("umrech-", "", zieljahr_match))
    art <- paste0("umrechnung_", zieljahr)
  } else {
    zieljahr <- NA_integer_
    art <- "jaehrlich"
  }

  list(ebene = ebene, art = art, zieljahr = zieljahr, dateiname = dateiname)
}

bbsrgeo_sheet_jahre <- function(sheet, meta) {
  if (meta$art == "jaehrlich") {
    m <- regmatches(sheet, regexec("^(\\d{4})-(\\d{4})$", sheet))[[1]]
    if (length(m) == 3) {
      return(list(von = as.integer(m[2]), bis = as.integer(m[3])))
    }
    m2 <- regmatches(sheet, regexec("^(\\d{4})$", sheet))[[1]]
    if (length(m2) == 2) {
      jahr <- as.integer(m2[2])
      return(list(von = jahr, bis = jahr + 1L))
    }
    rlang::abort(sprintf(
      "Unerwarteter Blattname '%s' in einer 'jaehrlich'-Datei (%s) - erwartet wird 'JJJJ-JJJJ' oder 'JJJJ'.",
      sheet, meta$dateiname
    ))
  }

  m <- regmatches(sheet, regexec("^(\\d{4})$", sheet))[[1]]
  if (length(m) != 2) {
    rlang::abort(sprintf(
      "Unerwarteter Blattname '%s' in einer 'umrechnung'-Datei (%s) - erwartet wird 'JJJJ'.",
      sheet, meta$dateiname
    ))
  }
  list(von = as.integer(m[2]), bis = meta$zieljahr)
}

bbsrgeo_read_sheet <- function(pfad, sheet, meta) {
  roh <- suppressMessages(
    readxl::read_excel(pfad, sheet = sheet, col_names = FALSE, skip = 1, col_types = "text")
  )
  n <- ncol(roh)

  if (n == 8) {
    spalten <- c(
      "ags_alt", "name_alt", "anteil_flaeche", "anteil_bevoelkerung",
      "flaeche_alt", "bevoelkerung_alt", "ags_neu", "name_neu"
    )
    hat_beschaeftigte <- FALSE
  } else if (n == 10) {
    spalten <- c(
      "ags_alt", "name_alt", "anteil_flaeche", "anteil_bevoelkerung", "anteil_beschaeftigte",
      "flaeche_alt", "bevoelkerung_alt", "beschaeftigte_alt", "ags_neu", "name_neu"
    )
    hat_beschaeftigte <- TRUE
  } else {
    rlang::abort(sprintf(
      paste(
        "Unerwartete Spaltenzahl (%d) in Blatt '%s' von %s.",
        "Die Tabellenstruktur weicht von der erwarteten Struktur (8 oder 10 Spalten) ab -",
        "bitte Datei manuell pruefen, moeglicherweise hat das BBSR das Format geaendert."
      ),
      n, sheet, basename(pfad)
    ))
  }
  names(roh) <- spalten
  if (!hat_beschaeftigte) {
    roh$anteil_beschaeftigte <- NA_character_
    roh$beschaeftigte_alt <- NA_character_
  }

  jahre <- bbsrgeo_sheet_jahre(sheet, meta)

  tibble::tibble(
    ags_alt = normalisiere_ags(roh$ags_alt),
    name_alt = trimws(roh$name_alt),
    ags_neu = normalisiere_ags(roh$ags_neu),
    name_neu = trimws(roh$name_neu),
    jahr_von = jahre$von,
    jahr_bis = jahre$bis,
    anteil_flaeche = as.numeric(roh$anteil_flaeche),
    anteil_bevoelkerung = as.numeric(roh$anteil_bevoelkerung),
    anteil_beschaeftigte = as.numeric(roh$anteil_beschaeftigte),
    flaeche_alt = as.numeric(roh$flaeche_alt),
    bevoelkerung_alt = as.numeric(roh$bevoelkerung_alt),
    beschaeftigte_alt = as.numeric(roh$beschaeftigte_alt)
  )
}
