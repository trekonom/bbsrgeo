
<!-- README.md is generated from README.Rmd. Please edit that file -->

# bbsrgeo

<!-- badges: start -->

<!-- badges: end -->

`bbsrgeo` downloads the **area crosswalks** (“Umstiegsschluessel”) for
municipalities and districts published by the BBSR (Bundesinstitut fuer
Bau-, Stadt- und Raumforschung, Germany’s Federal Institute for Research
on Building, Urban Affairs and Spatial Development), and uses them to
convert German regional statistics time series (e.g. from the
Regionaldatenbank Deutschland / GENESIS-Regio) onto a consistent, freely
chosen set of area boundaries - despite municipality mergers and
district reorganizations.

More background and a worked example: `vignette("bbsrgeo")`.

## Installation

`bbsrgeo` is not (yet) on CRAN. Install from the local source directory:

``` r
# install.packages("pak")
pak::pak("local::.")
```

## Example

``` r
library(bbsrgeo)

# Which crosswalks does the BBSR offer for districts?
bbsr_crosswalk_available("districts")
#> # A tibble: 4 × 6
#>   level     kind            year_from year_to url                      file_size
#>   <chr>     <chr>               <int>   <int> <chr>                    <chr>    
#> 1 districts annual               1990    2024 https://www.bbsr.bund.d… 949 KB   
#> 2 districts conversion_2019      1990    2018 https://www.bbsr.bund.d… 888 KB   
#> 3 districts conversion_2020      1990    2019 https://www.bbsr.bund.d… 916 KB   
#> 4 districts conversion_2021      1990    2020 https://www.bbsr.bund.d… 933 KB
```

``` r
# Download the crosswalk (cached locally) and read it
path <- bbsr_crosswalk_download(level = "districts", kind = "annual")
crosswalk <- bbsr_crosswalk_read(path)

# Convert regional data (AGS + year + value column) onto the 2024 boundary
harmonize_regions(
  regional_data,
  crosswalk = crosswalk,
  ags_col = "ags",
  year_col = "year",
  value_cols = "population",
  type = "absolute",
  weight = "population",
  target_year = 2024L,
  level = "districts"
)
```
