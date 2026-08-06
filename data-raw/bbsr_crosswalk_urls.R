## code to prepare `bbsr_crosswalk_urls` dataset goes here
##
## This table was filled in by hand on 2026-08-06 from the overview page
##   https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/umstiegsschluessel/umsteigeschluessel.html
## (file sizes as shown there). The BBSR updates that page (in German only)
## whenever a new vintage/target boundary is published - this table then
## needs to be updated by hand (add rows). As an alternative,
## bbsr_crosswalk_available_live() live-parses the overview page, in case
## this static table has gone stale.

base_url <- "https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/umstiegsschluessel/"

bbsr_crosswalk_urls <- tibble::tribble(
  ~level,          ~kind,             ~year_from, ~year_to, ~file_name,                                   ~file_size,
  "municipalities", "annual",          1990L,      2000L,     "ref-gemeinden-1990-2000.xlsx",               "8 MB",
  "municipalities", "annual",          2000L,      2010L,     "ref-gemeinden-2000-2010.xlsx",               "8 MB",
  "municipalities", "annual",          2010L,      2020L,     "ref-gemeinden-2010-2020.xlsx",               "7 MB",
  "municipalities", "annual",          2020L,      2024L,     "ref-gemeinden-2020-2024.xlsx",               "3 MB",
  "municipalities", "conversion_2019", 1990L,      1999L,     "ref-gemeinden-umrech-2019-1990-1999.xlsx",   "8 MB",
  "municipalities", "conversion_2019", 2000L,      2010L,     "ref-gemeinden-umrech-2019-2000-2010.xlsx",   "8 MB",
  "municipalities", "conversion_2019", 2011L,      2018L,     "ref-gemeinden-umrech-2019-2011-2018.xlsx",   "5 MB",
  "municipalities", "conversion_2020", 1990L,      1999L,     "ref-gemeinden-umrech-2020-1990-1999.xlsx",   "8 MB",
  "municipalities", "conversion_2020", 2000L,      2010L,     "ref-gemeinden-umrech-2020-2000-2010.xlsx",   "8 MB",
  "municipalities", "conversion_2020", 2011L,      2019L,     "ref-gemeinden-umrech-2020-2011-2019.xlsx",   "6 MB",
  "municipalities", "conversion_2021", 1990L,      1999L,     "ref-gemeinden-umrech-2021-1990-1999.xlsx",   "8 MB",
  "municipalities", "conversion_2021", 2000L,      2010L,     "ref-gemeinden-umrech-2021-2000-2010.xlsx",   "8 MB",
  "municipalities", "conversion_2021", 2011L,      2020L,     "ref-gemeinden-umrech-2021-2011-2020.xlsx",   "6 MB",
  "districts",      "annual",          1990L,      2024L,     "ref-kreise-1990-2024.xlsx",                  "949 KB",
  "districts",      "conversion_2019", 1990L,      2018L,     "ref-kreise-umrech-2019-1990-2018.xlsx",      "888 KB",
  "districts",      "conversion_2020", 1990L,      2019L,     "ref-kreise-umrech-2020-1990-2019.xlsx",      "916 KB",
  "districts",      "conversion_2021", 1990L,      2020L,     "ref-kreise-umrech-2021-1990-2020.xlsx",      "933 KB",
)

bbsr_crosswalk_urls$url <- paste0(
  base_url,
  bbsr_crosswalk_urls$file_name,
  "?__blob=publicationFile&v=2"
)
bbsr_crosswalk_urls <- bbsr_crosswalk_urls[, c("level", "kind", "year_from", "year_to", "url", "file_size")]

usethis::use_data(bbsr_crosswalk_urls, internal = TRUE, overwrite = TRUE)
