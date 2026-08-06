test_that("bbsr_umstieg_verfuegbar liefert die erwarteten Spalten", {
  d <- bbsr_umstieg_verfuegbar()
  expect_s3_class(d, "tbl_df")
  expect_named(d, c("ebene", "art", "von_jahr", "bis_jahr", "url", "dateigroesse"))
  expect_true(all(c("Gemeinden", "Kreise") %in% d$ebene))
})

test_that("bbsr_umstieg_verfuegbar filtert nach ebene", {
  d <- bbsr_umstieg_verfuegbar("Kreise")
  expect_true(all(d$ebene == "Kreise"))
  expect_true(nrow(d) > 0)
})

test_that("bbsr_umstieg_verfuegbar validiert ebene", {
  expect_error(bbsr_umstieg_verfuegbar("Bundeslaender"))
})

test_that("jede art/ebene-Kombination hat mindestens eine Zeile", {
  d <- bbsr_umstieg_verfuegbar()
  erwartete_arten <- c("jaehrlich", "umrechnung_2019", "umrechnung_2020", "umrechnung_2021")
  expect_true(all(erwartete_arten %in% d$art))
  expect_true(all(grepl("^https://www\\.bbsr\\.bund\\.de/.*\\.xlsx\\?", d$url)))
})
