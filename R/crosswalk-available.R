#' List available BBSR area crosswalks
#'
#' Returns the overview of area crosswalk files ("Umstiegsschluessel")
#' published by the BBSR (Bundesinstitut fuer Bau-, Stadt- und
#' Raumforschung, Germany's Federal Institute for Research on Building,
#' Urban Affairs and Spatial Development) that ships with this package:
#' annual (chainable) crosswalks as well as direct conversions of historical
#' years onto a fixed target boundary (2019/2020/2021).
#'
#' This list is stored statically in the package (see
#' `data-raw/bbsr_crosswalk_urls.R`) and can go stale once the BBSR
#' publishes a new vintage or target boundary. [bbsr_crosswalk_available_live()]
#' offers an alternative that queries the BBSR overview page live.
#'
#' @param level Character vector: `"municipalities"`, `"districts"`, or both
#'   (default).
#'
#' @return A tibble with columns `level`, `kind` (`"annual"`,
#'   `"conversion_2019"`, `"conversion_2020"`, or `"conversion_2021"`),
#'   `year_from`, `year_to`, `url`, and `file_size`.
#' @export
#'
#' @examples
#' bbsr_crosswalk_available("districts")
bbsr_crosswalk_available <- function(level = c("municipalities", "districts")) {
  level <- match.arg(level, several.ok = TRUE)
  dplyr::filter(bbsr_crosswalk_urls, .data$level %in% .env$level)
}
