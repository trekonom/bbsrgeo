# Ask BBSR how INKAR indicator 280 is built (numerator and denominator boundary handling)

Status: done (moved to GitHub issue #1)
Category: enhancement

Follow-up from issue 02 (implemented in 97687ce). Not blocking anything; it would turn a documented unknown into a documented fact.

## Question

How does INKAR build indicator 280 (Pflegebeduerftige je 100 Einwohner)?

1. Which population series is the denominator (source, reference date, Zensus 2011 basis or not)?
2. Is the numerator (Pflegestatistik counts, Stichtag 15 December) converted to the current Gebietsstand the same way as the population, via the BBSR Umstiegsschluessel, or left on the historical boundary?
3. If conversion differs between districts, why? (See below.)

## Why we are asking

Primary-source research found only the general statement that INKAR indicators are time series "auf dem gleichen aktuellen Gebietsstand"; the indicator-280 description sits in the inkar.de web app and could not be fetched. See `.scratch/ltc-validation/research/inkar-280-methodology.md`.

Observed in the bundled data (`ltcregio` harmonized with `harmonize_regions(type = "ratio", weight = "population")` vs `ltcinkar`/`popinkar`):

- Rhein-Hunsrueck-Kreis (07140000), 2009/2011/2013: harmonized population agrees with `popinkar` within 0.2%, yet our rate is 1.2-1.4% above INKAR's. The test names this as a known residual (`tests/testthat/test-validate-ltc.R`).
- Raw (unharmonized) Thuringian districts differ from INKAR in both population and, to a varying degree, rate; after harmonization they agree within 0.3%.
- Everything else outside the BBSR share-sum anomaly (Cochem-Zell, Mayen-Koblenz) agrees within 0.48%.

Do not state any of the above as a mechanism in the package docs until BBSR answers.

## What to do with the answer

- Update the Rhein-Hunsrueck comment in `test-validate-ltc.R` and the "What is not" sentence in `vignettes/bbsrgeo.Rmd` ("A ratio example").
- If the numerator is confirmed unadjusted for some districts, replace the 1-2% tripwire with an assertion tied to that cause.

Where to ask: the contact listed on the BBSR INKAR page (look it up there; not verified here).

## Comments
