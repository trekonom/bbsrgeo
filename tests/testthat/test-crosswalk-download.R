test_that("bbsr_crosswalk_download downloads into the cache and reads from it next time", {
  cache_dir <- withr::local_tempdir()

  mock <- function(req) {
    httr2::response(status_code = 200, body = charToRaw("fake-xlsx-content"))
  }

  path <- httr2::with_mocked_responses(mock, {
    bbsr_crosswalk_download(
      level = "districts",
      kind = "annual",
      cache_dir = cache_dir
    )
  })

  expect_true(file.exists(path))
  expect_equal(readLines(path, warn = FALSE), "fake-xlsx-content")

  # Second call without overwrite must not "download" again (no mock needed)
  path2 <- bbsr_crosswalk_download(
    level = "districts",
    kind = "annual",
    cache_dir = cache_dir
  )
  expect_equal(path, path2)
})

test_that("bbsr_crosswalk_download validates level/kind and year filters", {
  cache_dir <- withr::local_tempdir()
  expect_error(
    bbsr_crosswalk_download(
      level = "districts",
      kind = "annual",
      year_from = 1800,
      cache_dir = cache_dir
    ),
    "No matching"
  )
})

test_that("bbsr_crosswalk_download gives a clear message on HTTP errors", {
  cache_dir <- withr::local_tempdir()
  mock <- function(req) httr2::response(status_code = 404)

  expect_error(
    httr2::with_mocked_responses(mock, {
      bbsr_crosswalk_download(
        level = "districts",
        kind = "annual",
        cache_dir = cache_dir
      )
    }),
    "failed"
  )
})
