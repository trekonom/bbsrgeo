#' Download a BBSR area crosswalk
#'
#' Downloads the crosswalk file (xlsx) matching `level`/`kind` (and
#' optionally `year_from`/`year_to`) from the BBSR and stores it in a local
#' cache directory. Files that are already cached are not downloaded again
#' by default.
#'
#' @param level `"municipalities"` or `"districts"`.
#' @param kind Kind of table: `"annual"` (year-to-year crosswalk, chainable)
#'   or `"conversion_2019"`/`"conversion_2020"`/`"conversion_2021"` (direct
#'   conversion of historical years onto the respective fixed target-year
#'   boundary).
#' @param year_from,year_to Optional filters on the year spans listed in
#'   [bbsr_crosswalk_available()]. `NULL` (default) returns all files
#'   matching `level`/`kind` (usually exactly one).
#' @param cache_dir Target directory for the cache. Default:
#'   `tools::R_user_dir("bbsrgeo", "cache")`.
#' @param overwrite Re-download files that are already cached?
#'
#' @return Character vector with the local paths of the (downloaded or
#'   already cached) files.
#' @export
bbsr_crosswalk_download <- function(
  level = c("municipalities", "districts"),
  kind = c("annual", "conversion_2019", "conversion_2020", "conversion_2021"),
  year_from = NULL,
  year_to = NULL,
  cache_dir = NULL,
  overwrite = FALSE
) {
  level <- match.arg(level)
  kind <- match.arg(kind)
  cache_dir <- bbsrgeo_cache_dir(cache_dir)

  matches <- bbsr_crosswalk_available(level)
  matches <- matches[matches$kind == kind, , drop = FALSE]
  if (!is.null(year_from)) {
    matches <- matches[matches$year_from == year_from, , drop = FALSE]
  }
  if (!is.null(year_to)) {
    matches <- matches[matches$year_to == year_to, , drop = FALSE]
  }

  if (nrow(matches) == 0) {
    rlang::abort(sprintf(
      "No matching crosswalk file found (level = '%s', kind = '%s', year_from = %s, year_to = %s). See bbsr_crosswalk_available() for available combinations.",
      level,
      kind,
      if (is.null(year_from)) "NULL" else year_from,
      if (is.null(year_to)) "NULL" else year_to
    ))
  }

  vapply(
    matches$url,
    bbsrgeo_download_file,
    FUN.VALUE = character(1),
    cache_dir = cache_dir,
    overwrite = overwrite,
    USE.NAMES = FALSE
  )
}

bbsrgeo_download_file <- function(url, cache_dir, overwrite) {
  file_name <- basename(sub("\\?.*$", "", url))
  target <- file.path(cache_dir, file_name)

  if (file.exists(target) && !overwrite) {
    return(target)
  }

  resp <- tryCatch(
    {
      httr2::request(url) |>
        httr2::req_user_agent(bbsrgeo_user_agent()) |>
        httr2::req_timeout(120) |>
        httr2::req_perform()
    },
    error = function(e) {
      rlang::abort(
        sprintf("Download of %s failed: %s", url, conditionMessage(e)),
        parent = e
      )
    }
  )
  writeBin(httr2::resp_body_raw(resp), target)

  target
}
