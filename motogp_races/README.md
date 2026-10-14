# MotoGP calendar, race results and championship points

SQL Server package for Stephen's existing MotoGP database. Snapshot cutoff:
12 October 2026. Use the Windows VS Code MSSQL extension as before.

## What this delivery contains

| Area | Included |
|---|---:|
| Non-test events in the archive calendar, 1949–2026 | 1,079 |
| Event/class combinations | 3,563 |
| Logical races in the results pilot | 26 |
| Source race sessions, including one restart part | 27 |
| Classification rows retained | 502 |
| Rows in the selected current-result reporting view | 475 |
| Rider standings rows after duplicate removal | 8,701 |
| Documented championship deductions | 3 |

**The historical calendar is seeded; the race results are a pilot, not the full
1949–2026 results database.** The included Python importer can fetch further
seasons and generate SQL. It was exercised on the supplied pilot, a live MotoE
doubleheader request and a partial-cache build; a complete historical run has
not been completed. A successful full download still cannot certify that the
source includes every historical finisher, non-finisher or entrant.

## Run these SQL files in order

Earlier prerequisite scripts: circuits (07), riders (08), manufacturers/teams
(10 and 11), season/classes (13). The earlier 09 and 12 exploration scripts
were optional. This package does not need them.

1. `14_create_calendar_and_results.sql` — tables, status lookup and integrity checks.
2. `15_import_calendar.sql` — events and the classes/circuits for each event.
3. `16_import_pilot_results.sql` — reviewed pilot scope and source classifications.
4. `17_import_rider_standings.sql` — published archive standings snapshots.
5. `18_import_documented_adjustments.sql` — three actual 2020 deductions.
6. `19_create_reporting_views.sql` — queryable views for results, wins and standings.
7. `20_explore_and_check.sql` — optional read-only examples and review queries.

Open each complete SQL file in the VS Code **editor**, connect to your SQL
Server and execute it there. SQL does not go in the PowerShell terminal.
Scripts use the `MotoGP` database and require SQL Server 2016 SP1 or newer
for `CREATE OR ALTER VIEW/TRIGGER`.

Seeds use stable source keys and skip existing rows. They do not delete your
earlier data. Each import is transactional. If a classification or standings
snapshot differs from an existing current snapshot, the import stops for
review rather than silently replacing it. Schema/view scripts contain `GO`
batch separators; inspect the Messages panel for errors before continuing.

This package has passed offline data and SQL-literal checks. It has **not**
been executed on a SQL Server instance or on your computer. `validation.json`
states exactly what was checked.

## Understand the model

`events` is the Grand Prix meeting in a particular year. There is no unique
constraint on season/circuit: repeated visits are valid. Dates are dates,
and source session timestamps remain raw strings because historical time-zone
accuracy has not been established. Calendar order can be queried by date;
official round numbers are deliberately not invented from row order.

`event_classes` links the meeting to `season_classes` and to its class-specific
circuit. In the mixed-course TT years, `events.circuit_id` is NULL and the
event/class rows identify the Mountain Course or Clypse correctly. Circuit
configuration history remains a future extension; no lap lengths are assigned
to permanent circuit records here.

`races` is a logical scoring race: GP, Sprint, or a numbered MotoE race.
`motogp_source.race_sessions` retains the source timing sessions belonging to
it. Only one session per logical race can be selected for statistics. Multiple
parts outside the explicitly reviewed Thailand case are held for review.

`race_entries` stores the number, team name, constructor and rider identity as
observed in the race classification. This is not yet a complete entry list or
qualifying import. DNQ/withdrawal statuses are supported but never inferred
from a rider's absence. Race-level team-season links are deliberately NULL;
the source team label remains available. A season roster alone does not prove
the exact entrant for that race.

`race_result_sets` identifies a source classification snapshot by content hash.
`race_results` holds its rider rows. This gives us room for revised results
without overwriting evidence. Current views select the accepted session and
current result set; raw restart parts remain queryable separately.

`championships`, `championship_entries`, `championship_standing_snapshots` and
`championship_standings` retain published championship scores separately from
race results. Rider, team and constructor competitions have different scopes.
An organisation can run multiple squads: do not sum all organisation results
and call that an official team championship score.

`penalties` documents the decision. `championship_points_adjustments` records
its points effect. A reversal or superseding decision must be recorded rather
than deleting the original evidence. The effective-adjustment view excludes
overturned/superseded decisions and adjustments already reflected in race
points. **Never subtract these deductions again from published official
standings, which can already include them.**

## The validated pilot

| Meeting | Why it is included |
|---|---|
| 1949 Tourist Trophy | Old archive coverage and missing points/timing data |
| 1999 Malaysian GP | Historical zero-point placeholders and missing class data |
| 2013 Australian GP | Disqualification records, including Marc Marquez |
| 2018 British GP | Cancellation despite source `FINISHED` flags |
| 2023 Japanese GP | Red-flag-affected meeting and a Sprint |
| 2025 Thailand GP | Normal race/Sprint, first-lap non-finish and DNS labels |
| 2025 French GP, MotoE | Two separate scoring races in one event/class |
| 2026 Thailand GP | Restart sessions and revised half-points |

Of the 26 logical races, 21 have selected classifications, three are cancelled
and two are unresolved empty classifications (1949 TT 250cc and 1999 Malaysia
250cc). Those empty responses are not treated as cancelled races. The source
calendar can be incomplete for cancelled events absent from its feeds.

## Points and status policy

- No points-per-position calculation is used to populate actual points.
- Points are `DECIMAL(10,3)`, allowing 12.5, 6.5 and similar awards.
- An all-zero/absent points field across an otherwise populated classification
  is quarantined as unresolved. The original source value is retained, but
  `official_points_awarded` is NULL. This affects 90 source rows in the pilot,
  including an unselected early part of the restarted Thailand race; 63 of
  those rows appear in the current-result reporting view.
- `SOURCE_REPORTED` points were supplied by the API and are not individually
  independently verified. `VERIFIED_PDF` in this pilot identifies the revised
  2026 Thailand Moto2 classification checked against the official PDF.
- `NC` is not automatically DNF. `OUTSTND` remains NC; explicit retirement or
  failure to finish the first lap can map to DNF.
- `NO_RESTART` preserves “not on restart grid”. `started_session` refers to
  that timing session, not necessarily the rider's participation in an earlier
  race part. Do not use it alone to calculate career race starts.
- A crash followed by rejoining is not automatically a DNF. Reasons are NULL
  unless specifically documented; no mechanical/crash causes are guessed.
- Raw status, gap and time are preserved. Old zero-lap placeholders become
  NULL; pre-2000 durations are not parsed because archive formatting needs
  further checking. Missing fields must not be converted to zero for charts.
- Historical dropped-score rules are not implemented. Published standings
  remain the reference; imported race-score sums are explicitly incomplete.

## Identity and coverage issues

The pilot has six race entries whose riders are absent from the earlier master
import: Direk Archewong, Bernhard Absmeier, M. Meganathan, Luca Amato, Lachlan
Kavney and Luca Scassa. Their classifications are retained with source IDs and
names; `rider_id` stays NULL. No speculative rider merges or biographies are
created. The exploration SQL lists these for later resolution.

Eight duplicate standings rows had identical competitor/position/points
facts. They were collapsed into one row each; the originals are recorded in
`standings.json`. Nineteen season/class standings responses were empty and
are listed there. Standings are archive snapshots, not certified final tables;
their endpoint does not establish a reliable through-race boundary. This
matters especially for 2026, and old endpoint snapshots can also be incomplete.

The three penalty examples are Yamaha constructor −50, Monster Energy Yamaha
MotoGP team −20 and Petronas Yamaha SRT team −37, decided 5 November 2020.
They are not a full historical penalty register. Petronas has a championship
entrant record, but its master team link remains NULL until that organisation
identity is researched. No deduction is assigned to the rider championship.

## Extend with Python on Windows

Python is optional for running the supplied SQL. To expand the results,
install/use Python 3.9 or newer and open a PowerShell terminal **inside this
extracted package folder**. No additional Python packages are required.

```powershell
py .\fetch_history.py --year 2025
```

The script downloads public session/classification data, saves resumable
checkpoints and generates `16_history_2025_results.sql` plus a matching audit
JSON. It does not connect to or change your database. Review the audit, then
execute the generated SQL in the VS Code SQL editor. Existing pilot rows are
skipped when their content agrees.

```powershell
py .\fetch_history.py --full
```

This requests the remaining history represented in the supplied calendar
through 12 October 2026. It can take substantial time and depends on the
availability of the public endpoints. Rerun the same command after interruption
to reuse completed downloads. Failed requests are written to a coverage report
and prevent automatic SQL generation until retried successfully.

To deliberately build a partial import from completed checkpoints:

```powershell
py .\fetch_history.py --year 2025 --build-cached
```

The filename and coverage report explicitly mark partial scope. Review every
`REVIEW` race and unresolved points issue before using aggregate results.
The importer uses cached snapshots; it is not an automatic latest-results
refresh service. Updating an existing source result requires explicit revision
review. A new season also needs new calendar/season-class records first.

Offline rebuild and checks:

```powershell
py .\build_imports.py
py .\validate_package.py
```

Power BI can later read `v_race_results_current` and
`v_official_rider_standings`. Keep their different coverage and purposes clear.
`v_imported_rider_wins` reports wins in imported data, not certified career totals.

## Source references

- Official MotoGP results API: `https://api.motogp.pulselive.com/motogp/v1/results/`.
  Exact per-event and classification URLs are retained in the JSON and SQL.
- Revised 2026 Thailand Moto2 PDF:
  https://resources.motogp.com/files/results/2026/THA/Moto2/RAC2/Classification.pdf
- Explanation of the corrected points:
  https://www.motogp.com/en/news/2026/02/18/grand-prix-thailand-2026-perubahan-hasil-moto2/1002527
- 2025 Thailand classification and incident log:
  https://resources.motogp.com/files/results/2025/THA/MotoGP/RAC/Classification.pdf
- British GP cancellation:
  https://www.motogp.com/en/news/2018/08/28/gopro-british-gp-cancellation-a-message-for-fans/147970
- FIM/Dorna's 2020 sanctions notice, reproduced by Roadracing World:
  https://www.roadracingworld.com/news/motogp-yamaha-and-its-teams-penalized/
- Historical dropped scores:
  https://www.motogp.com/pt/news/2022/11/01/swinging-sixties-not-always-that-simple/182568

Circuit corrections reuse the evidence in script 07 and `calendar.json`,
including historical Belfast, Brno, Geneva, Zolder, Reims and Clypse mappings.
