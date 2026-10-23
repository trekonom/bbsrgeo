# INKAR indicator 280 (Pflegebedürftige je 100 Einwohner): numerator, denominator, Gebietsstand

Researched 2026-10-23, primary sources only. Related: `../issues/02-reproduce-cochem-zell-residual.md`.

**Headline: the INKAR indicator-level description for indicator 280 (the page with "Berechnungsalgorithmus" and "statistische Grundlagen") was NOT found.** It is rendered inside the INKAR web app (inkar.de), which could not be fetched (TLS error "unable to get local issuer certificate"). Everything below is general INKAR/BBSR methodology plus Destatis Pflegestatistik metadata. None of it addresses indicator 280 specifically.

## (a) Documented facts

### A1. INKAR puts all indicators on one current Gebietsstand
- Source (BBSR): https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/interaktive-anwendungen/inkar/inkar-online.html
- "Die Indikatoren sind weitgehend als Zeitreihe bis zum Jahr 1995 berechnet" and they are based "auf dem gleichen aktuellen Gebietsstand".
- Gloss: indicators are largely computed as time series back to 1995, all on the same current boundary.
- Same page: "Die Indikatoren beruhen weitgehend auf den Daten der amtlichen Statistik des Bundes und der Länder." (Indicators are largely based on official federal and state statistics.)
- Same page: users can "den Berechnungsalgorithmus und die statistischen Grundlagen nachvollziehen" in each indicator's detail view. Further docs are said to be under "Dokumentation und Hilfe" on www.inkar.de.
- Gloss: this is where indicator 280's algorithm would be documented. That page was not retrievable (see Not found).
- Caveat: the page says "weitgehend" (largely). It does not say that every indicator, or both parts of a ratio, are converted.

### A2. BBSR's Laufende Raumbeobachtung converts all regional data to the latest Gebietsstand using Umstiegsschlüssel
- Source (BBSR): https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/umstiegsschluessel/umsteigeschluessel.html (no date on page; footer 2020-2026)
- "werden in der Laufenden Raumbeobachtung des BBSR alle regionalen Daten auf den letztgültigen Gebietsstand umgerechnet"
  - Gloss: in BBSR's ongoing spatial monitoring, all regional data are converted to the latest valid boundary.
- "Die Gebietsstände beziehen sich immer auf den 31. Dezember." (Boundary states always refer to 31 December.)
- The page does not mention INKAR by name (checked via fetch). That INKAR is the product of the Laufende Raumbeobachtung is an inference, although A1 supports the same-current-Gebietsstand claim.

### A3. Conversion keys: area, population, employment
- Same BBSR page: "flächen-, bevölkerungs- und ab 1997 beschäftigtenproportionale Umrechnungsschlüssel".
- "die meisten sozioökonomischen Daten sehr gut mit dem bevölkerungsproportionalen Gewichtungsfaktor umgeschätzt" (most socioeconomic data are estimated very well with the population-proportional key).
- "Die Umrechnungsschlüssel stellen Anteilswerte dar und dienen der Umrechnung von Basisdaten bzw. Absolutwerten." (The keys are share values for converting base data / absolute values.)
- For ratio-type indicators, the page says the keys serve "als Gewichte für eine Mittelwertbildung auf dem neuen Gebietszuschnitt" (as weights for averaging on the new boundary). The exact wording around this phrase was summarised by the fetch tool, so check it on the page before quoting in published docs.
- Small boundary adjustments (not whole municipalities) are ignored, per the page summary.

### A4. Pflegestatistik numerator: source, Stichtag, regional coverage
- Source (Destatis/Statistische Ämter; Qualitätsbericht, here the Berlin-Brandenburg copy): https://download.statistik-berlin-brandenburg.de/9b7549456588c45e/fcf5bf8d1d87/MD_22412_2025.pdf (Statistic 22412, Erhebung bei Pflegeeinrichtungen)
  - "Räumliche Abdeckung: Deutschland, Bundesländer, Regierungsbezirke, Kreise und kreisfreie Städte." (Spatial coverage: Germany, states, Regierungsbezirke, Kreise.)
  - "Berichtszeitraum/-zeitpunkt: Stichtagserhebung zum 15. Dezember." (Reference: snapshot survey on 15 Dec.)
  - "Periodizität: Zweijährlich." (Every two years.) Another passage: "Der Stichtag der Erhebung ist der 15. Dezember in ungeraden Kalenderjahren."
  - "Vollerhebung mit Auskunftspflicht" (full census with mandatory reporting).
- The BIFG page found via search says the Pflegegeld-recipient count has a different Stichtag (31.12.); that page was not fetched, so treat it as unverified. URL: https://www.bifg.de/publikationen/reporte/pflegereport/pflegebeduerftige-nach-pflegeleistungen
- The Statistisches Bundesamt data are published on whatever Kreis boundary applies in the reporting year (inferred from the table structure). I found no explicit Gebietsstand statement in the Qualitätsbericht I read.

### A5. BBSR's own description of the Pflegequote map (2023)
- Source (BBSR): https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/aktuelles/km-pflegebeduerftige.html
- Caption: "Pflegebedürftige je 100 Einwohner/-innen für das Jahr 2023 auf Kreisbasis in %"; text: "Aus den aktuellen Zahlen der Pflegestatistik geht hervor".
- Gloss: the figure is care recipients per 100 inhabitants, by Kreis, 2023, from the Pflegestatistik.
- The page does not define the denominator source, Stichtag or Gebietsstand (fetch result: "not stated").

### A6. Population basis in older Pflegestatistik Kreisvergleich (2011 edition) was the pre-Zensus Fortschreibung
- Source (Statistische Ämter des Bundes und der Länder, "Pflegestatistik 2011 - Pflege im Rahmen der Pflegeversicherung: Kreisvergleich"): https://www.statistischebibliothek.de/mir/servlets/MCRFileNodeServlet/DEHeft_derivate_00011253/Pflegestatistik_2011.pdf
- Footnote 3, reconstructed from badly garbled PDF text extraction (letter spacing broken, so the wording is approximate): "Genutzt werden in diesem Bericht generell die Daten der Bevölkerungsfortschreibung auf Grundlage früherer Zählungen. Nicht verwendet werden entsprechend die Daten des Zensus zum Mai 2011 - eine anhand dieser Daten aktualisierte Fortschreibung zum Jahresende 2011 liegt noch nicht vollständig vor."
  - Gloss: this report uses the population update based on earlier censuses and does not use the May 2011 census data.
- This concerns Destatis's own Pflegequote in the 2011 Kreisvergleich, not INKAR. It shows only that official Kreis rates at the time used a pre-Zensus population series.

## (b) Not documented / not found
1. **INKAR indicator 280's own description** (Berechnungsalgorithmus, Statistische Grundlagen, Quelle, Stichtag). Not found. Not retrievable from the INKAR app (TLS error), and the web searches did not surface the INKAR download documentation or Indikatorenübersicht.
2. **Whether INKAR converts numerator and denominator of a ratio separately, converts the ratio by weighted mean, or leaves the numerator on historical boundaries.** Not found. The BBSR Umstiegsschlüssel page speaks of keys for absolute values and weights for averaging ratios (A3). It does not say how INKAR indicators are built from counts and populations. It does not say whether the numerator of 280 is converted.
3. **Which population series is the denominator** (Fortschreibung vs Zensus 2011 basis; Stichtag 31.12. vs mid-year). Not found for INKAR 280. The BBSR Umstiegsschlüssel page gives no Stichtag for population data and does not mention the Zensus (per fetch result). The BBSR Pflegebedürftige page gives none either.
4. **Which Pflegestatistik reference date feeds the INKAR value for a year** (15.12. facility survey vs 31.12. Pflegegeld count; INKAR's year label). Not found.
5. **Whether INKAR reran historical years after Zensus 2011** (i.e. whether the 2009 and 2013 INKAR denominators are the then-official Fortschreibung or a revised series). Not found. No INKAR source on re-computation of back-years was located.
6. **GENESIS table 22411 metadata** (Gebietsstand and Stichtag of the Kreis tables). Not retrieved. The Qualitätsbericht above (statistic 22412) was read instead, and it has no explicit Gebietsstand statement.
7. **Destatis Qualitätsbericht for statistic 22411 (Empfänger von Pflegegeldleistungen).** Not found. The BIFG claim in A4 about Pflegegeld timing is a secondary source.
8. Version and date of the INKAR Gebietsstand: two BBSR pages reportedly differ (31.12.2023 on inkar.de, 31.12.2022 on a BBSR 2025 page, per a search summary). Not verified directly.

## (c) Relation to the hypothesis (unadjusted numerator with adjusted denominator for some districts)
- **Supported by sources:** none. No source states or implies that INKAR leaves the 280 numerator on historical boundaries or adjusts only the denominator.
- **Contradicted by sources:** none directly. A1 and A2 state a general intent that INKAR time series use one current Gebietsstand (qualified by "weitgehend"). That is consistent with INKAR adjusting both numerator and denominator, but it does not establish how 280 is built.
- **Silent:** the sources are silent on the numerator conversion method, the denominator series, and the Stichtag. They are also silent on Zensus 2011 handling in INKAR, and on the specific Rhein-Hunsrück and Wartburgkreis (Eisenach) observations.
- **Limited relevance of A6:** the 2011 Pflegestatistik Kreisvergleich used a pre-Zensus Fortschreibung. That documents a pre-/post-Zensus population-series break in official Kreis rates. It says nothing about which series INKAR used for its 2009/2013 values.
- **Suggested way to close the gap (not done here):** obtain the INKAR indicator 280 detail text (INKAR web app or the downloadable Indikatorenübersicht / "Dokumentation und Hilfe" at inkar.de), or ask BBSR (Referat Raumbeobachtung) directly.
