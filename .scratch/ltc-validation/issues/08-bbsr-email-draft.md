# Draft: email to BBSR about INKAR indicator 280 (issue 08)

Not sent. To: contact listed on the BBSR INKAR page (look it up there; not
verified here). Written in German because BBSR is the recipient. Fill in the
sender line before sending.

---

**Betreff:** INKAR, Indikator 280 (Pflegebedürftige je 100 Einwohner): Methodik der Gebietsstandsumrechnung

Sehr geehrte Damen und Herren,

ich arbeite mit einem R-Paket (`bbsrgeo`), das Regionalstatistiken mithilfe
der BBSR-Umstiegsschlüssel auf einen einheitlichen Gebietsstand umrechnet. Zur
Validierung vergleiche ich die Umrechnung von Pflegestatistik-Daten
(GENESIS-Regio, Tabelle 22411-02-02-4, Stichtag 15. Dezember, Kreisebene,
2009 bis 2023) mit INKAR-Indikator 280 (Pflegebedürftige je 100 Einwohner,
Kreise, aktueller Gebietsstand). Dazu habe ich drei Fragen zur Methodik, die
ich der Indikatorbeschreibung in der INKAR-Anwendung nicht entnehmen konnte:

1. Welche Bevölkerungsreihe bildet den Nenner (Quelle, Stichtag, Basis
   Zensus 2011 oder nicht)?
2. Werden die Pflegebedürftigen (Zähler) wie die Bevölkerung über die
   BBSR-Umstiegsschlüssel auf den aktuellen Gebietsstand umgerechnet, oder
   bleiben sie auf dem jeweiligen historischen Gebietsstand?
3. Falls die Umrechnung zwischen Kreisen unterschiedlich erfolgt: Wovon hängt
   das ab?

Hintergrund: Für die meisten Kreise stimmt meine umgerechnete Rate mit INKAR
auf 0,5 % genau überein. Eine Ausnahme ist der Rhein-Hunsrück-Kreis (07140)
in den Jahren 2009, 2011 und 2013: Die umgerechnete Bevölkerung weicht dort
nur um rund 0,2 % von der INKAR-Bevölkerung ab, meine Rate liegt aber 1,2 bis
1,4 % über dem INKAR-Wert. Eine Ursache kann ich nicht belegen und möchte
sie nicht vermuten.

Über eine kurze Auskunft oder einen Hinweis auf eine Methodendokumentation
würde ich mich sehr freuen. Die Antwort würde ich in der Paketdokumentation
mit Quellenangabe festhalten.

Vielen Dank und freundliche Grüße

Stefan Moog
moogs@gmx.de
