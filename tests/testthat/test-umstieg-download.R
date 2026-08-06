test_that("bbsr_umstieg_download laedt in den Cache und liest ihn beim naechsten Mal", {
  cache_dir <- withr::local_tempdir()

  mock <- function(req) httr2::response(status_code = 200, body = charToRaw("fake-xlsx-inhalt"))

  pfad <- httr2::with_mocked_responses(mock, {
    bbsr_umstieg_download(
      ebene = "Kreise", art = "jaehrlich", cache_dir = cache_dir
    )
  })

  expect_true(file.exists(pfad))
  expect_equal(readLines(pfad, warn = FALSE), "fake-xlsx-inhalt")

  # Zweiter Aufruf ohne overwrite darf nicht erneut "herunterladen" (kein Mock noetig)
  pfad2 <- bbsr_umstieg_download(
    ebene = "Kreise", art = "jaehrlich", cache_dir = cache_dir
  )
  expect_equal(pfad, pfad2)
})

test_that("bbsr_umstieg_download validiert ebene/art und Jahresfilter", {
  cache_dir <- withr::local_tempdir()
  expect_error(
    bbsr_umstieg_download(ebene = "Kreise", art = "jaehrlich", von_jahr = 1800, cache_dir = cache_dir),
    "Keine passende"
  )
})

test_that("bbsr_umstieg_download gibt bei HTTP-Fehlern eine klare Meldung", {
  cache_dir <- withr::local_tempdir()
  mock <- function(req) httr2::response(status_code = 404)

  expect_error(
    httr2::with_mocked_responses(mock, {
      bbsr_umstieg_download(ebene = "Kreise", art = "jaehrlich", cache_dir = cache_dir)
    }),
    "fehlgeschlagen"
  )
})
