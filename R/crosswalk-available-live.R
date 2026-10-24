#' Query available BBSR area crosswalks live from the BBSR website
#'
#' Alternative to [bbsr_crosswalk_available()]: queries the BBSR overview
#' page (in German) live and parses the xlsx files linked there. Useful when
#' the table shipped statically with the package has gone stale (e.g.
#' because the BBSR has published a new vintage or a new target year for the
#' conversion tables). Requires the \pkg{rvest} package.
#'
#' @param url Address of the BBSR overview page. Default (`NULL`): the
#'   current BBSR area-crosswalk overview page.
#'
#' @return A tibble with the same columns as [bbsr_crosswalk_available()]
#'   (`level`, `kind`, `year_from`, `year_to`, `url`, `file_size`).
#' @export
bbsr_crosswalk_available_live <- function(url = NULL) {
  url <- url %||%
    paste0(
      "https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/",
      "Raumabgrenzungen/umstiegsschluessel/umsteigeschluessel.html"
    )
  rlang::check_installed("rvest", reason = "to parse the BBSR page live.")

  resp <- httr2::request(url) |>
    httr2::req_user_agent(bbsrgeo_user_agent()) |>
    httr2::req_timeout(30) |>
    httr2::req_perform()

  page <- rvest::read_html(httr2::resp_body_string(resp))
  table_node <- rvest::html_element(page, "table")
  if (inherits(table_node, "xml_missing")) {
    rlang::abort(
      "Could not find a crosswalk table on the BBSR page - the page structure has probably changed."
    )
  }

  # The scraped page and its table headers/cell text are in German
  # ("Gemeinden" = municipalities, "Kreise" = districts, "jaehrlich" =
  # annual, "Umrechnung auf <year>" = conversion to <year>) - mapped to
  # English labels below.
  rows <- rvest::html_table(table_node, fill = TRUE)
  names(rows) <- c("level_de", "kind_de", "year_span", "reference_table")

  links <- rvest::html_elements(table_node, "a")
  hrefs <- rvest::html_attr(links, "href")
  link_texts <- rvest::html_text2(links)
  xlsx <- grepl("\\.xlsx", hrefs)
  hrefs <- hrefs[xlsx]
  link_texts <- link_texts[xlsx]

  if (nrow(rows) != length(hrefs)) {
    rlang::warn(paste(
      "Number of table rows and xlsx links found on the BBSR page do not",
      "match - the live-parsed table may be incomplete or misaligned.",
      "Please check the result or use bbsr_crosswalk_available()",
      "(static table) instead."
    ))
  }

  n <- min(nrow(rows), length(hrefs))
  rows <- rows[seq_len(n), ]
  hrefs <- hrefs[seq_len(n)]
  link_texts <- link_texts[seq_len(n)]

  years <- regmatches(
    rows$year_span,
    regexec("(\\d{4}).*?(\\d{4})", rows$year_span)
  )
  year_from <- vapply(
    years,
    function(m) if (length(m) == 3) as.integer(m[2]) else NA_integer_,
    integer(1)
  )
  year_to <- vapply(
    years,
    function(m) if (length(m) == 3) as.integer(m[3]) else NA_integer_,
    integer(1)
  )

  has_target_year <- grepl("\\d{4}", rows$kind_de)
  target_year <- rep(NA_character_, length(rows$kind_de))
  target_year[has_target_year] <- regmatches(
    rows$kind_de[has_target_year],
    regexpr("\\d{4}", rows$kind_de[has_target_year])
  )
  kind <- ifelse(
    !is.na(target_year),
    paste0("conversion_", target_year),
    "annual"
  )

  level <- dplyr::case_when(
    rows$level_de == "Gemeinden" ~ "municipalities",
    rows$level_de == "Kreise" ~ "districts",
    TRUE ~ NA_character_
  )

  file_size <- sub(".*XLSX,\\s*", "", link_texts)
  file_size <- sub(",.*$", "", file_size)

  base_url <- sub("(https?://[^/]+).*", "\\1", url)
  full_url <- ifelse(
    grepl("^https?://", hrefs),
    hrefs,
    paste0(base_url, hrefs)
  )

  tibble::tibble(
    level = level,
    kind = kind,
    year_from = year_from,
    year_to = year_to,
    url = full_url,
    file_size = file_size
  )
}
