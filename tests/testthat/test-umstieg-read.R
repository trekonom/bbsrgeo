test_that("bbsr_umstieg_read parst eine 'jaehrlich'-Datei korrekt", {
  d <- bbsr_umstieg_read(test_path("fixtures", "ref-kreise-testfixture-jaehrlich.xlsx"))

  expect_named(d, c(
    "ags_alt", "name_alt", "ags_neu", "name_neu", "jahr_von", "jahr_bis",
    "anteil_flaeche", "anteil_bevoelkerung", "anteil_beschaeftigte",
    "flaeche_alt", "bevoelkerung_alt", "beschaeftigte_alt"
  ))
  expect_equal(nrow(d), 6)

  # Sheet "1999-2000": hyphenierter Blattname -> jahr_von/jahr_bis direkt daraus
  unveraendert <- d[d$jahr_von == 1999 & d$ags_alt == "01000001", ]
  expect_equal(unveraendert$jahr_bis, 2000)
  expect_equal(unveraendert$anteil_flaeche, 1)

  # Split von Kreis B in zwei Zeilen, Anteile summieren sich zu 1
  split <- d[d$jahr_von == 1999 & d$ags_alt == "01000002", ]
  expect_equal(nrow(split), 2)
  expect_equal(sum(split$anteil_flaeche), 1)
  expect_equal(sum(split$anteil_bevoelkerung), 1)

  # Sheet "2000-2001": 10-Spalten-Variante mit Beschaeftigtendaten
  mit_besch <- d[d$jahr_von == 2000, ]
  expect_true(all(!is.na(mit_besch$anteil_beschaeftigte)))
  expect_true(all(!is.na(mit_besch$beschaeftigte_alt)))

  # Sheet "2001": einjaehriger Blattname -> jahr_bis wird als jahr_von + 1 abgeleitet
  einjaehrig <- d[d$jahr_von == 2001, ]
  expect_equal(einjaehrig$jahr_bis, 2002)
})

test_that("bbsr_umstieg_read parst eine 'umrechnung_*'-Datei korrekt (festes Zieljahr)", {
  d <- bbsr_umstieg_read(test_path("fixtures", "ref-kreise-umrech-2021-testfixture.xlsx"))

  expect_equal(nrow(d), 2)
  # Zieljahr kommt aus dem Dateinamen (umrech-2021), nicht aus dem Blattnamen
  expect_true(all(d$jahr_bis == 2021))
  expect_equal(sort(d$jahr_von), c(1999, 2000))
})

test_that("bbsr_umstieg_read normalisiert AGS auf 8 Stellen", {
  d <- bbsr_umstieg_read(test_path("fixtures", "ref-kreise-testfixture-jaehrlich.xlsx"))
  expect_true(all(nchar(d$ags_alt) == 8))
  expect_true(all(nchar(d$ags_neu) == 8))
})

test_that("bbsr_umstieg_read kann mehrere Dateien auf einmal einlesen", {
  d <- bbsr_umstieg_read(c(
    test_path("fixtures", "ref-kreise-testfixture-jaehrlich.xlsx"),
    test_path("fixtures", "ref-kreise-umrech-2021-testfixture.xlsx")
  ))
  expect_equal(nrow(d), 6 + 2)
})

test_that("bbsr_umstieg_read bricht bei fehlender Datei mit klarer Meldung ab", {
  expect_error(bbsr_umstieg_read("does-not-exist.xlsx"), "nicht gefunden")
})
