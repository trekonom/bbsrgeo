
<!-- README.md is generated from README.Rmd. Please edit that file -->

# bbsrgeo

<!-- badges: start -->

<!-- badges: end -->

`bbsrgeo` laedt die vom BBSR (Bundesinstitut fuer Bau-, Stadt- und
Raumforschung) veroeffentlichten **Umstiegsschluessel** fuer Gemeinden
und Kreise herunter und rechnet damit Regionalstatistik-Zeitreihen (z.
B. aus der Regionaldatenbank Deutschland / GENESIS-Regio) auf einen
konsistenten, frei waehlbaren Gebietsstand um - trotz Gemeindefusionen
und Kreisgebietsreformen.

Mehr Hintergrund und ein durchgerechnetes Beispiel:
`vignette("bbsrgeo")`.

## Installation

`bbsrgeo` ist (noch) nicht auf CRAN. Aus dem lokalen Quellverzeichnis
installieren:

``` r
# install.packages("pak")
pak::pak("local::.")
```

## Beispiel

``` r
library(bbsrgeo)

# Welche Umstiegsschluessel bietet das BBSR fuer Kreise an?
bbsr_umstieg_verfuegbar("Kreise")
#> # A tibble: 4 × 6
#>   ebene  art             von_jahr bis_jahr url                      dateigroesse
#>   <chr>  <chr>              <int>    <int> <chr>                    <chr>       
#> 1 Kreise jaehrlich           1990     2024 https://www.bbsr.bund.d… 949 KB      
#> 2 Kreise umrechnung_2019     1990     2018 https://www.bbsr.bund.d… 888 KB      
#> 3 Kreise umrechnung_2020     1990     2019 https://www.bbsr.bund.d… 916 KB      
#> 4 Kreise umrechnung_2021     1990     2020 https://www.bbsr.bund.d… 933 KB
```

``` r
# Umstiegsschluessel herunterladen (wird lokal gecacht) und einlesen
pfad <- bbsr_umstieg_download(ebene = "Kreise", art = "jaehrlich")
umstieg <- bbsr_umstieg_read(pfad)

# Regionaldaten (AGS + Jahr + Wertespalte) auf den Gebietsstand 2024 umrechnen
regio_konsistent(
  regionaldaten,
  umstiegsschluessel = umstieg,
  ags_spalte = "ags",
  jahr_spalte = "jahr",
  wert_spalten = "einwohner",
  typ = "absolut",
  gewicht = "bevoelkerung",
  ziel_gebietsstand = 2024L,
  ebene = "Kreise"
)
```
