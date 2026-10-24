# Report ags_old groups whose name_old is not constant

Status: needs-triage
Category: enhancement

Raised while triaging shares-from-counts issue 02: the miscoded row
07235000 (2011 -> 2012, `name_old` Bernkastel-Wittlich, which is 07231000) was
found by the maintainer by reading the sheets. Its `name_old` disagrees with
the other rows of the same `ags_old`.

## Observation

In every cached file (downloads of 2026-10-24) the rows of one
`ags_old`/`year_from`/`year_to` group were checked for more than one distinct
`name_old`:

| File | Groups | Groups with more than one `name_old` |
| --- | --- | --- |
| municipal 1990-2000 | 151002 | 0 |
| municipal 2000-2010 | 127333 | 0 |
| municipal 2010-2020 | 112120 | 0 |
| municipal 2020-2024 | 54919 | 0 |
| districts | 14743 | 1 (07235000, 2011 -> 2012) |

So on these files the check has no false positives and finds the known case.
It would not find a miscoded row that is the only row of its group, nor a
miscoded `ags_new` (not checked here), nor a code coded consistently wrong.

## To establish

1. Where it reports: a message or warning in `bbsr_crosswalk_read()` next to
   the share-sum warning (shares-from-counts issue 02 uses a message), and
   whether it names both codes and names.
2. Whether the same check applies to `name_new` against `ags_new` (not
   measured).
3. How it relates to the correction function (issue 02): the check only
   detects; recoding is decided there.

## Out of scope

Correcting the BBSR data (issue 02). Deriving the right code from the name.

## Comments
