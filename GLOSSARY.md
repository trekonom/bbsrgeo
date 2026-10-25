# bbsrgeo

Re-expresses German regional statistics time series on one consistent set of area boundaries, using BBSR crosswalks, despite municipality mergers and district reorganizations.

## Language

### Areas and boundaries

**Area unit**:
Any territorial unit identified by an 8-digit AGS (Amtlicher Gemeindeschluessel).
_Avoid_: region, geography, entity

**Level**:
Whether an area unit is a **District** or a **Municipality**. A property of the crosswalk, carried in its `level` column; the data must match it. A crosswalk that mixes levels is an error.
_Avoid_: scale, granularity

**District**:
A Kreis (Landkreis or kreisfreie Stadt). Its 5-digit Kreisschluessel is another representation of the same unit as the 8-digit AGS (key + `000`), not a different unit.
_Avoid_: county

**Municipality**:
A Gemeinde, the lowest-level area unit.
_Avoid_: city, town, community

**Boundary year**:
The year whose territorial layout (the set of area units, as of 31 Dec of that year) a dataset is expressed in.
_Avoid_: vintage, reference year, Gebietsstand year

**Target year**:
The boundary year a dataset is converted to; `"current"` means the latest one in the crosswalk.
_Avoid_: goal year, end year

### Crosswalks

**Crosswalk**:
A BBSR table mapping area units of one boundary year onto those of another, with a share for each pairing. Either annual or conversion. German: Umstiegsschluessel.
_Avoid_: lookup, mapping table, concordance

**Annual crosswalk**:
A crosswalk holding one transition per year step; chained when the target year is several steps away.

**Conversion crosswalk**:
A crosswalk converting every earlier boundary year directly to one fixed target year, in a single step. The target year is set by the file, so a requested target year must match it.

**Transition**:
One step of a crosswalk from a source boundary year (`year_from`) to a destination boundary year (`year_to`).
_Avoid_: change, step, reform

**Transition group**:
The rows of one old area unit in one transition (`ags_old`, `year_from`, `year_to`), whose shares and counts the checks and the renormalization compare.
_Avoid_: group, bucket

**Share**:
The fraction of an old area unit's weight allocated to one new area unit; sums to 1 over the new units of one old unit and one transition.
_Avoid_: proportion, weight, factor

**Weight basis**:
The quantity the shares are measured in: population, area, or employment.
_Avoid_: weight (alone), allocation key

**Share deviation**:
A transition where an old unit's shares do not sum to 1 by more than 1% (a sum exactly at the tolerance, such as three shares of 0.33, is rounding and not a deviation). Not introduced by the package. `bbsr_crosswalk_read()` names the pattern observed in the rows, without stating a cause: (a) a share of 1 on every target row of a multi-row group, with counts that differ between rows; (b) a single target row with a share below 1; (c) any other. `harmonize_regions()` handles these by renormalization.
_Avoid_: share error, bad shares

**Treatment**:
The correction applied to the shares of one transition group in a share deviation, chosen once by `classify_share_deviations()` for both the read-time checks and the conversion: _rounding_ (sum within the tolerance, rescaled to 1), _zero basis_ (a unit without population or employment, split by area share), _parts_ (counts that differ between rows read as the parts going to each target) or _renormalize_ (anything else, rescaled to 1). A group that sums to 1 needs none.
_Avoid_: fix, correction method

**Source-data fix**:
A documented correction to rows of a BBSR crosswalk file (set a cell, or drop a row), made when the file is read and only where the correct value is verified. A fix applies as a whole or not at all. Listed with the evidence for it. Differs from a **Treatment**, which rescales shares during conversion from the shares alone and changes no row of the crosswalk.
_Avoid_: correction, patch, recode (a recode is one kind of fix)

**Count gap**:
How far `count / total` of a row lies from its share in a transition group whose counts read as parts and whose shares sum to 1. A gap larger than the counts' resolution is reported by `bbsr_crosswalk_read()`; the conversion still uses the shares as given.
_Avoid_: count error, mismatch

**Conversion plan**:
The transitions a conversion of a panel passes through, per start year, and the **Unmapped units** it would drop with the transition each is lost at. Holds structure only, no values or shares. Built once by `plan_conversion()` (`R/conversion-path.R`) and read by both `harmonize_regions()` and `check_regions()`, so the two cannot disagree.
_Avoid_: path, route

**Unmapped unit**:
An area unit in the data with no crosswalk entry for a transition. Always dropped with a warning, never passed through. The **Conversion plan** lists them; `harmonize_regions()` warns once about them and `check_regions()` reports the rows they would drop.
_Avoid_: missing unit, orphan

### Variables

**Panel**:
A long-format dataset with one row per area unit and year. Each year is converted to the target year independently; units need not appear in every year.
_Avoid_: time series table, wide data

**Absolute variable**:
A quantity that adds up across area units (e.g. population); converted by summing shares of the old values.
_Avoid_: count, extensive variable

**Ratio variable**:
A quantity that does not add up across area units (e.g. a rate); converted by a weighted mean over the old values, weighted by share and weight basis.
_Avoid_: rate, intensive variable, indicator

### Conversion

**Harmonization**:
Converting a panel dataset to one target year's boundary year using crosswalk shares.
_Avoid_: normalization, reprojection, remapping

**Forward conversion**:
Harmonization from an older to a newer boundary year; the direction crosswalks are designed for.
_Avoid_: upcasting

**Backcast**:
Harmonization from a newer to an older boundary year, done by applying the forward shares in reverse. A known approximation, not a true disaggregation.
_Avoid_: reverse conversion, downscaling

**Renormalization**:
Rescaling the shares of a transition whose shares do not sum to 1 so they sum to 1, so no part of an absolute value is lost. The default of `harmonize_regions()`; `renormalize = FALSE` uses the shares as given. Deviations beyond the tolerance warn, smaller ones only produce a message. Only the _renormalize_ and _rounding_ treatments are reported; _zero basis_ and _parts_ are silent.
_Avoid_: correction, fixing
