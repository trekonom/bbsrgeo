#' Verfuegbare BBSR-Umstiegsschluessel live von der BBSR-Webseite abfragen
#'
#' Alternative zu [bbsr_umstieg_verfuegbar()]: fragt die
#' BBSR-Uebersichtsseite live ab und parst die dort verlinkten xlsx-Dateien.
#' Nuetzlich, wenn die im Paket statisch hinterlegte Tabelle veraltet ist
#' (z. B. weil das BBSR einen neuen Jahrgang oder ein neues Zieljahr fuer die
#' Umrechnungstabellen veroeffentlicht hat). Benoetigt das Paket \pkg{rvest}.
#'
#' @param url Adresse der BBSR-Uebersichtsseite. Standard (`NULL`): die
#'   aktuelle Umstiegsschluessel-Uebersichtsseite des BBSR.
#'
#' @return Ein Tibble mit denselben Spalten wie [bbsr_umstieg_verfuegbar()]
#'   (`ebene`, `art`, `von_jahr`, `bis_jahr`, `url`, `dateigroesse`).
#' @export
bbsr_umstieg_verfuegbar_live <- function(url = NULL) {
  url <- url %||% paste0(
    "https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/",
    "Raumabgrenzungen/umstiegsschluessel/umsteigeschluessel.html"
  )
  rlang::check_installed("rvest", reason = "um die BBSR-Seite live zu parsen.")

  resp <- httr2::request(url) |>
    httr2::req_user_agent(bbsrgeo_user_agent()) |>
    httr2::req_timeout(30) |>
    httr2::req_perform()

  seite <- rvest::read_html(httr2::resp_body_string(resp))
  tabelle <- rvest::html_element(seite, "table")
  if (inherits(tabelle, "xml_missing")) {
    rlang::abort("Konnte auf der BBSR-Seite keine Tabelle mit Umstiegsschluesseln finden - die Seitenstruktur hat sich vermutlich geaendert.")
  }

  zeilen <- rvest::html_table(tabelle, fill = TRUE)
  names(zeilen) <- c("ebene", "art", "jahresspanne", "referenztabelle")

  links <- rvest::html_elements(tabelle, "a")
  hrefs <- rvest::html_attr(links, "href")
  linktexte <- rvest::html_text2(links)
  xlsx <- grepl("\\.xlsx", hrefs)
  hrefs <- hrefs[xlsx]
  linktexte <- linktexte[xlsx]

  if (nrow(zeilen) != length(hrefs)) {
    rlang::warn(paste(
      "Anzahl Tabellenzeilen und gefundener xlsx-Links auf der BBSR-Seite",
      "stimmt nicht ueberein - die live geparste Tabelle koennte unvollstaendig",
      "oder falsch zugeordnet sein. Bitte Ergebnis pruefen oder",
      "bbsr_umstieg_verfuegbar() (statische Tabelle) verwenden."
    ))
  }

  n <- min(nrow(zeilen), length(hrefs))
  zeilen <- zeilen[seq_len(n), ]
  hrefs <- hrefs[seq_len(n)]
  linktexte <- linktexte[seq_len(n)]

  jahre <- regmatches(zeilen$jahresspanne, regexec("(\\d{4}).*?(\\d{4})", zeilen$jahresspanne))
  von_jahr <- vapply(jahre, function(m) if (length(m) == 3) as.integer(m[2]) else NA_integer_, integer(1))
  bis_jahr <- vapply(jahre, function(m) if (length(m) == 3) as.integer(m[3]) else NA_integer_, integer(1))

  hat_zieljahr <- grepl("\\d{4}", zeilen$art)
  zieljahr <- rep(NA_character_, length(zeilen$art))
  zieljahr[hat_zieljahr] <- regmatches(zeilen$art[hat_zieljahr], regexpr("\\d{4}", zeilen$art[hat_zieljahr]))
  art <- ifelse(!is.na(zieljahr), paste0("umrechnung_", zieljahr), "jaehrlich")

  dateigroesse <- sub(".*XLSX,\\s*", "", linktexte)
  dateigroesse <- sub(",.*$", "", dateigroesse)

  basis_url <- sub("(https?://[^/]+).*", "\\1", url)
  vollstaendige_url <- ifelse(
    grepl("^https?://", hrefs),
    hrefs,
    paste0(basis_url, hrefs)
  )

  tibble::tibble(
    ebene = zeilen$ebene,
    art = art,
    von_jahr = von_jahr,
    bis_jahr = bis_jahr,
    url = vollstaendige_url,
    dateigroesse = dateigroesse
  )
}
