test_that("normalisiere_ags polstert fehlende fuehrende Nullen", {
  expect_equal(normalisiere_ags("1001000"), "01001000")
  expect_equal(normalisiere_ags("13001000"), "13001000")
  expect_equal(normalisiere_ags(1001000), "01001000")
})

test_that("normalisiere_ags ist idempotent bei bereits 8-stelligen Werten", {
  expect_equal(normalisiere_ags("01001000"), "01001000")
})

test_that("normalisiere_ags behandelt leere/fehlende Werte als NA", {
  expect_equal(normalisiere_ags(""), NA_character_)
  expect_equal(normalisiere_ags(NA), NA_character_)
  expect_equal(normalisiere_ags("  "), NA_character_)
})

test_that("normalisiere_ags warnt bei nicht-numerischen Werten und setzt NA", {
  expect_warning(res <- normalisiere_ags("abc"), "konnten nicht als Zahl")
  expect_equal(res, NA_character_)
})
