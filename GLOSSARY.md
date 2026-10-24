# bbsrgeo

Re-expresses German regional statistics time series on one consistent set of area boundaries, using BBSR crosswalks, despite municipality mergers and district reorganizations.

## Language

### Areas and boundaries

**Area unit**:
Any territorial unit identified by an 8-digit AGS (Amtlicher Gemeindeschluessel).
_Avoid_: region, geography, entity

**Level**:
Whether an area unit is a **District** or a **Municipality**. A property of the crosswalk; the data must match it.
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

**Unmapped unit**:
An area unit in the data with no crosswalk entry for a transition. Always dropped with a warning, never passed through.
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
Rescaling the shares of a transition whose shares do not sum to 1 so they sum to 1, so no part of an absolute value is lost. The default of `harmonize_regions()`; `renormalize = FALSE` uses the shares as given. Deviations beyond the tolerance warn, smaller ones only produce a message.
_Avoid_: correction, fixing
