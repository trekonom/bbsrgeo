# Hilfsfunktion fuer synthetische Umstiegsschluessel in Tests
schluessel_zeile <- function(ags_alt, ags_neu, jahr_von, jahr_bis,
                              anteil_flaeche = 1, anteil_bevoelkerung = 1, anteil_beschaeftigte = NA,
                              flaeche_alt = 100, bevoelkerung_alt = 1000, beschaeftigte_alt = NA) {
  tibble::tibble(
    ags_alt = ags_alt, name_alt = ags_alt, ags_neu = ags_neu, name_neu = ags_neu,
    jahr_von = jahr_von, jahr_bis = jahr_bis,
    anteil_flaeche = anteil_flaeche, anteil_bevoelkerung = anteil_bevoelkerung,
    anteil_beschaeftigte = anteil_beschaeftigte,
    flaeche_alt = flaeche_alt, bevoelkerung_alt = bevoelkerung_alt, beschaeftigte_alt = beschaeftigte_alt
  )
}

test_that("regio_konsistent aggregiert absolute Werte bei vollstaendiger Fusion", {
  # Kreis A und B fusionieren vollstaendig (je anteil = 1) zu Kreis C; Kreis D unveraendert
  schluessel <- dplyr::bind_rows(
    schluessel_zeile("01000001", "01000099", 2020L, 2021L, bevoelkerung_alt = 1000),
    schluessel_zeile("01000002", "01000099", 2020L, 2021L, bevoelkerung_alt = 2000),
    schluessel_zeile("01000003", "01000003", 2020L, 2021L, bevoelkerung_alt = 500)
  )
  daten <- tibble::tibble(
    ags = c("01000001", "01000002", "01000003"), jahr = 2020L,
    einwohner = c(1000, 2000, 500)
  )

  res <- regio_konsistent(
    daten, schluessel, "ags", "jahr", "einwohner",
    typ = "absolut", gewicht = "bevoelkerung", ziel_gebietsstand = 2021L, ebene = "Kreise"
  )

  c_wert <- res$einwohner[res$ags == "01000099"]
  d_wert <- res$einwohner[res$ags == "01000003"]
  expect_equal(c_wert, 3000)
  expect_equal(d_wert, 500)
  expect_true(all(res$gebietsstand == 2021L))
})

test_that("regio_konsistent bildet bei Verhaeltniszahlen den gewichteten Mittelwert", {
  schluessel <- dplyr::bind_rows(
    schluessel_zeile("01000001", "01000099", 2020L, 2021L, bevoelkerung_alt = 1000),
    schluessel_zeile("01000002", "01000099", 2020L, 2021L, bevoelkerung_alt = 2000)
  )
  daten <- tibble::tibble(ags = c("01000001", "01000002"), jahr = 2020L, quote = c(5, 8))

  res <- regio_konsistent(
    daten, schluessel, "ags", "jahr", "quote",
    typ = "verhaeltnis", gewicht = "bevoelkerung", ziel_gebietsstand = 2021L, ebene = "Kreise"
  )

  erwartet <- (5 * 1000 + 8 * 2000) / 3000
  expect_equal(res$quote, erwartet)
})

test_that("regio_konsistent verteilt bei einem Split korrekt auf mehrere Zieleinheiten", {
  # Kreis A spaltet sich: 40 % (Flaeche) / 30 % (Bevoelkerung) zu B, Rest zu C
  schluessel <- dplyr::bind_rows(
    schluessel_zeile("01000001", "01000002", 2020L, 2021L, anteil_flaeche = 0.4, anteil_bevoelkerung = 0.3),
    schluessel_zeile("01000001", "01000003", 2020L, 2021L, anteil_flaeche = 0.6, anteil_bevoelkerung = 0.7),
    schluessel_zeile("01000002", "01000002", 2020L, 2021L),
    schluessel_zeile("01000003", "01000003", 2020L, 2021L)
  )
  daten <- tibble::tibble(
    ags = c("01000001", "01000002", "01000003"), jahr = 2020L,
    einwohner = c(1000, 500, 500)
  )

  res <- regio_konsistent(
    daten, schluessel, "ags", "jahr", "einwohner",
    typ = "absolut", gewicht = "bevoelkerung", ziel_gebietsstand = 2021L, ebene = "Kreise"
  )

  expect_equal(res$einwohner[res$ags == "01000002"], 500 + 1000 * 0.3)
  expect_equal(res$einwohner[res$ags == "01000003"], 500 + 1000 * 0.7)
})

test_that("regio_konsistent verkettet jaehrliche Schluessel ueber mehrere Jahre", {
  schluessel <- dplyr::bind_rows(
    schluessel_zeile("01000001", "01000001", 2018L, 2019L),
    schluessel_zeile("01000001", "01000001", 2019L, 2020L),
    schluessel_zeile("01000001", "01000009", 2020L, 2021L)
  )
  daten <- tibble::tibble(ags = "01000001", jahr = 2018L, einwohner = 100)

  res <- regio_konsistent(
    daten, schluessel, "ags", "jahr", "einwohner",
    typ = "absolut", gewicht = "bevoelkerung", ziel_gebietsstand = 2021L, ebene = "Kreise"
  )

  expect_equal(res$ags, "01000009")
  expect_equal(res$einwohner, 100)
  expect_equal(res$jahr, 2018L)
})

test_that("regio_konsistent nutzt einen direkten Umrechnungsschluessel ohne Verkettung", {
  # 'umrechnung_2021'-Stil: jahr_bis ist bereits das feste Zieljahr
  schluessel <- schluessel_zeile("01000001", "01000009", 1999L, 2021L)
  daten <- tibble::tibble(ags = "01000001", jahr = 1999L, einwohner = 100)

  res <- regio_konsistent(
    daten, schluessel, "ags", "jahr", "einwohner",
    typ = "absolut", gewicht = "bevoelkerung", ziel_gebietsstand = 2021L, ebene = "Kreise"
  )
  expect_equal(res$ags, "01000009")
  expect_equal(res$einwohner, 100)
})

test_that("regio_konsistent bricht bei fehlendem Hop in der Verkettung ab", {
  schluessel <- schluessel_zeile("01000001", "01000001", 2018L, 2019L)
  daten <- tibble::tibble(ags = "01000001", jahr = 2018L, einwohner = 100)

  expect_error(
    regio_konsistent(
      daten, schluessel, "ags", "jahr", "einwohner",
      typ = "absolut", gewicht = "bevoelkerung", ziel_gebietsstand = 2021L, ebene = "Kreise"
    ),
    "Kein Umstiegsschluessel"
  )
})

test_that("regio_konsistent verweigert Rueckrechnung ohne explizite Erlaubnis", {
  schluessel <- schluessel_zeile("01000001", "01000099", 2020L, 2021L)
  daten <- tibble::tibble(ags = "01000099", jahr = 2021L, einwohner = 100)

  expect_error(
    regio_konsistent(
      daten, schluessel, "ags", "jahr", "einwohner",
      typ = "absolut", gewicht = "bevoelkerung", ziel_gebietsstand = 2020L, ebene = "Kreise"
    ),
    "Rueckrechnung"
  )
})

test_that("regio_konsistent fuehrt Rueckrechnung mit Warnung durch, wenn explizit erlaubt", {
  schluessel <- schluessel_zeile("01000001", "01000099", 2020L, 2021L)
  daten <- tibble::tibble(ags = "01000099", jahr = 2021L, einwohner = 100)

  expect_warning(
    res <- regio_konsistent(
      daten, schluessel, "ags", "jahr", "einwohner",
      typ = "absolut", gewicht = "bevoelkerung", ziel_gebietsstand = 2020L, ebene = "Kreise",
      erlaube_rueckrechnung = TRUE
    ),
    "experimentell"
  )
  expect_equal(res$ags, "01000001")
})

test_that("ziel_gebietsstand = 'aktuell' verwendet den juengsten verfuegbaren Stand", {
  schluessel <- schluessel_zeile("01000001", "01000009", 2020L, 2021L)
  daten <- tibble::tibble(ags = "01000001", jahr = 2020L, einwohner = 100)

  res <- regio_konsistent(
    daten, schluessel, "ags", "jahr", "einwohner",
    typ = "absolut", gewicht = "bevoelkerung", ziel_gebietsstand = "aktuell", ebene = "Kreise"
  )
  expect_equal(res$gebietsstand, 2021L)
})

test_that("regio_konsistent_kreise und regio_konsistent_gemeinden liefern identische Ergebnisse", {
  schluessel <- schluessel_zeile("01000001", "01000001", 2020L, 2021L)
  daten <- tibble::tibble(ags = "01000001", jahr = 2020L, einwohner = 100)

  a <- regio_konsistent_kreise(
    daten, schluessel, "ags", "jahr", "einwohner",
    typ = "absolut", gewicht = "bevoelkerung", ziel_gebietsstand = 2021L
  )
  b <- regio_konsistent_gemeinden(
    daten, schluessel, "ags", "jahr", "einwohner",
    typ = "absolut", gewicht = "bevoelkerung", ziel_gebietsstand = 2021L
  )
  expect_equal(a, b)
})
