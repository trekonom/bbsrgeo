test_that("regio_pruefen erkennt vollstaendig zuordenbare Daten", {
  schluessel <- tibble::tibble(
    ags_alt = "01000001", ags_neu = "01000001", jahr_von = 2020L, jahr_bis = 2021L
  )
  daten <- tibble::tibble(ags = "01000001", jahr = 2020L, einwohner = 100)

  expect_message(res <- regio_pruefen(daten, schluessel, "ags"), "Alle 1 Zeilen")
  expect_equal(nrow(res), 0)
})

test_that("regio_pruefen findet unbekannte AGS", {
  schluessel <- tibble::tibble(
    ags_alt = "01000001", ags_neu = "01000001", jahr_von = 2020L, jahr_bis = 2021L
  )
  daten <- tibble::tibble(ags = c("01000001", "99999999"), jahr = 2020L, einwohner = c(100, 50))

  expect_message(res <- regio_pruefen(daten, schluessel, "ags"), "1 von 2 Zeilen")
  expect_equal(nrow(res), 1)
  expect_equal(res$ags, "99999999")
})

test_that("regio_pruefen warnt zusaetzlich bei nicht abgedeckten Jahren", {
  schluessel <- tibble::tibble(
    ags_alt = "01000001", ags_neu = "01000001", jahr_von = 2020L, jahr_bis = 2021L
  )
  daten <- tibble::tibble(ags = "01000001", jahr = 1950L, einwohner = 100)

  expect_message(
    regio_pruefen(daten, schluessel, "ags", jahr_spalte = "jahr"),
    "nicht abgedeckt"
  )
})
