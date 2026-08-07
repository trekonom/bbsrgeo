
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
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union

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

`bbsrgeo` ships with a real example dataset, `example_population` -
GENESIS-Regio population figures for every German district, 1995-2024,
each on the area boundary that was actually valid at the time.
Sachsen-Anhalt’s Saalkreis and Landkreis Merseburg-Querfurt, for
example, merged into the new Saalekreis on 2007-07-01:

``` r
example_population |>
  filter(district_name %in% c("Saalkreis", "Merseburg-Querfurt, Kreis", "Saalekreis")) |>
  filter(year %in% 2005:2008) |>
  select(ags, district_name, year, population_total) |>
  arrange(year, ags)
#> # A tibble: 6 × 4
#>   ags      district_name              year population_total
#>   <chr>    <chr>                     <int>            <int>
#> 1 15261000 Merseburg-Querfurt, Kreis  2005           131573
#> 2 15265000 Saalkreis                  2005            76521
#> 3 15261000 Merseburg-Querfurt, Kreis  2006           130434
#> 4 15265000 Saalkreis                  2006            75712
#> 5 15088000 Saalekreis                 2007           203989
#> 6 15088000 Saalekreis                 2008           201273
```

`harmonize_regions()` converts this onto a single, consistent boundary
using the real BBSR crosswalk:

``` r
path <- bbsr_crosswalk_download(level = "districts", kind = "annual")
crosswalk <- bbsr_crosswalk_read(path)
#> Warning: 4 ags_old/year_from combination(s) have a sum of area shares that
#> deviates from 1 by more than 1% (e.g. ags_old = '07135000', year_from = 2014:
#> sum = 0.962). This can be due to rounding, but is more often caused by
#> inconsistencies in the BBSR source file itself (e.g. missing counterparts for
#> minor boundary corrections) - please check the original file if in doubt.

harmonize_regions(
  example_population,
  crosswalk = crosswalk,
  ags_col = "ags",
  year_col = "year",
  value_cols = "population_total",
  type = "absolute",
  weight = "population",
  target_year = "current",
  level = "districts"
) |>
  filter(ags == "15088000", year %in% 2005:2008)
#> # A tibble: 4 × 4
#>   ags       year population_total boundary_year
#>   <chr>    <int>            <dbl>         <int>
#> 1 15088000  2005           208094          2024
#> 2 15088000  2006           206146          2024
#> 3 15088000  2007           203989          2024
#> 4 15088000  2008           201273          2024
```

Saalkreis and Merseburg-Querfurt’s populations are now combined into
Saalekreis for every year, comparable across the boundary reform.
