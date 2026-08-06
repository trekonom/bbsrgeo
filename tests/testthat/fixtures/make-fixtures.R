# Erzeugt kleine synthetische xlsx-Fixtures, die die reale BBSR-Struktur
# nachbilden (verifiziert an echten Downloads, siehe data-raw/). Nicht Teil
# des Build-/Testlaufs - nur bei Bedarf manuell neu ausfuehren
# (benoetigt das Suggests-Paket 'writexl').
#
# Struktur je Sheet: Zeile 1 = Kopfzeilen-Platzhalter (wird von
# bbsrgeo:::bbsrgeo_read_sheet() per skip = 1 uebersprungen), ab Zeile 2
# echte Daten, KEINE Spaltennamen (col_names = FALSE beim Schreiben).
# Spaltenreihenfolge ohne Beschaeftigte (8 Spalten):
#   ags_alt, name_alt, anteil_flaeche, anteil_bevoelkerung,
#   flaeche_alt, bevoelkerung_alt, ags_neu, name_neu
# mit Beschaeftigte (10 Spalten): zusaetzlich anteil_beschaeftigte (Pos. 5)
# und beschaeftigte_alt (Pos. 8).

roh <- function(...) {
  rbind(
    c("KOPF1", "KOPF2", "KOPF3", "KOPF4", "KOPF5", "KOPF6", "KOPF7", "KOPF8"),
    ...
  )
}

# --- Datei 1: "jaehrlich" (kein 'umrech' im Namen) ---------------------
# Sheet "1999-2000": 8 Spalten, ein unveraenderter Kreis + ein Split
sheet_1999_2000 <- roh(
  c("01000001", "Kreis A", "1", "1", "100", "1000", "01000001", "Kreis A"),
  c("01000002", "Kreis B", "0.4", "0.3", "40", "300", "01000009", "Kreis N"),
  c("01000002", "Kreis B", "0.6", "0.7", "60", "700", "01000010", "Kreis M")
)

# Sheet "2000-2001": 10 Spalten (mit Beschaeftigte), unveraenderte Einheiten
kopf10 <- c("KOPF1", "KOPF2", "KOPF3", "KOPF4", "KOPF5", "KOPF6", "KOPF7", "KOPF8", "KOPF9", "KOPF10")
sheet_2000_2001 <- rbind(
  kopf10,
  c("01000001", "Kreis A", "1", "1", "1", "100", "1000", "10", "01000001", "Kreis A"),
  c("01000009", "Kreis N", "1", "1", "1", "40", "300", "5", "01000009", "Kreis N")
)

# Sheet "2001" (einjaehriger Blattname wie bei Gemeinden-Dateien -> 2001-2002), 8 Spalten
sheet_2001 <- roh(
  c("01000001", "Kreis A", "1", "1", "100", "1000", "01000001", "Kreis A")
)

writexl::write_xlsx(
  list(
    "1999-2000" = as.data.frame(sheet_1999_2000),
    "2000-2001" = as.data.frame(sheet_2000_2001),
    "2001" = as.data.frame(sheet_2001)
  ),
  path = "tests/testthat/fixtures/ref-kreise-testfixture-jaehrlich.xlsx",
  col_names = FALSE
)

# --- Datei 2: "umrechnung auf 2021" (Dateiname mit 'umrech-2021') ------
# Sheets sind Ausgangsjahre (einzelne Jahreszahl), Zieljahr fest = 2021 (aus Dateiname)
sheet_1999 <- roh(
  c("01000001", "Kreis A", "1", "1", "100", "1000", "01000001", "Kreis A")
)
sheet_2000 <- roh(
  c("01000001", "Kreis A", "1", "1", "100", "1000", "01000001", "Kreis A")
)

writexl::write_xlsx(
  list("1999" = as.data.frame(sheet_1999), "2000" = as.data.frame(sheet_2000)),
  path = "tests/testthat/fixtures/ref-kreise-umrech-2021-testfixture.xlsx",
  col_names = FALSE
)

message("Fixtures geschrieben nach tests/testthat/fixtures/")
