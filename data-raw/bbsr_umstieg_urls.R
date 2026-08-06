## code to prepare `bbsr_umstieg_urls` dataset goes here
##
## Diese Tabelle wurde am 2026-08-06 manuell anhand der Uebersichtsseite
##   https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/umstiegsschluessel/umsteigeschluessel.html
## befuellt (Dateigroessen wie dort angezeigt). Das BBSR aktualisiert diese
## Seite, sobald neue Jahrgaenge/Gebietsstaende erscheinen - die Tabelle muss
## dann von Hand nachgezogen werden (Zeilen ergaenzen). Als Alternative bietet
## das Paket bbsr_umstieg_verfuegbar_live(), das die Uebersichtsseite live
## parst, falls diese statische Tabelle veraltet ist.

basis_url <- "https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/umstiegsschluessel/"

bbsr_umstieg_urls <- tibble::tribble(
  ~ebene,       ~art,               ~von_jahr, ~bis_jahr, ~dateiname,                                   ~dateigroesse,
  "Gemeinden",  "jaehrlich",        1990L,      2000L,     "ref-gemeinden-1990-2000.xlsx",               "8 MB",
  "Gemeinden",  "jaehrlich",        2000L,      2010L,     "ref-gemeinden-2000-2010.xlsx",               "8 MB",
  "Gemeinden",  "jaehrlich",        2010L,      2020L,     "ref-gemeinden-2010-2020.xlsx",               "7 MB",
  "Gemeinden",  "jaehrlich",        2020L,      2024L,     "ref-gemeinden-2020-2024.xlsx",               "3 MB",
  "Gemeinden",  "umrechnung_2019",  1990L,      1999L,     "ref-gemeinden-umrech-2019-1990-1999.xlsx",   "8 MB",
  "Gemeinden",  "umrechnung_2019",  2000L,      2010L,     "ref-gemeinden-umrech-2019-2000-2010.xlsx",   "8 MB",
  "Gemeinden",  "umrechnung_2019",  2011L,      2018L,     "ref-gemeinden-umrech-2019-2011-2018.xlsx",   "5 MB",
  "Gemeinden",  "umrechnung_2020",  1990L,      1999L,     "ref-gemeinden-umrech-2020-1990-1999.xlsx",   "8 MB",
  "Gemeinden",  "umrechnung_2020",  2000L,      2010L,     "ref-gemeinden-umrech-2020-2000-2010.xlsx",   "8 MB",
  "Gemeinden",  "umrechnung_2020",  2011L,      2019L,     "ref-gemeinden-umrech-2020-2011-2019.xlsx",   "6 MB",
  "Gemeinden",  "umrechnung_2021",  1990L,      1999L,     "ref-gemeinden-umrech-2021-1990-1999.xlsx",   "8 MB",
  "Gemeinden",  "umrechnung_2021",  2000L,      2010L,     "ref-gemeinden-umrech-2021-2000-2010.xlsx",   "8 MB",
  "Gemeinden",  "umrechnung_2021",  2011L,      2020L,     "ref-gemeinden-umrech-2021-2011-2020.xlsx",   "6 MB",
  "Kreise",     "jaehrlich",        1990L,      2024L,     "ref-kreise-1990-2024.xlsx",                  "949 KB",
  "Kreise",     "umrechnung_2019",  1990L,      2018L,     "ref-kreise-umrech-2019-1990-2018.xlsx",      "888 KB",
  "Kreise",     "umrechnung_2020",  1990L,      2019L,     "ref-kreise-umrech-2020-1990-2019.xlsx",      "916 KB",
  "Kreise",     "umrechnung_2021",  1990L,      2020L,     "ref-kreise-umrech-2021-1990-2020.xlsx",      "933 KB",
)

bbsr_umstieg_urls$url <- paste0(
  basis_url,
  bbsr_umstieg_urls$dateiname,
  "?__blob=publicationFile&v=2"
)
bbsr_umstieg_urls <- bbsr_umstieg_urls[, c("ebene", "art", "von_jahr", "bis_jahr", "url", "dateigroesse")]

usethis::use_data(bbsr_umstieg_urls, internal = TRUE, overwrite = TRUE)
