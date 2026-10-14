# MotoGP 2025 qualifying, grids and lap timing

This is an additive SQL Server extension for the MotoGP project. It builds on scripts 14-19 and the successfully loaded `16_history_2025_results.sql`. It does not change race results, points, riders, or the accepted race/restart selections.

## Start here — no Python download needed

The package contains the generated 2025 data import, ready to execute.

1. Extract the **entire ZIP** into `C:\Users\sgate\Documents\motogp-project`. Keep the new `motogp_timing` folder together alongside `motogp_races`.
2. Read `SCOPE_AND_VALIDATION.md` for actual recovered coverage and exceptions.
3. In VS Code's **SQL editor**, connected to your SQL Server, open and execute each entire file in this order:

| Script | Action |
|---|---|
| `21_create_timing_tables.sql` | Creates the timing tables and integrity constraints |
| `22_import_timing_2025.sql` | Loads the bundled 2025 data |
| `23_create_timing_views.sql` | Creates reporting views |
| `24_check_timing_2025.sql` | Runs coverage checks and worked examples |

Each script begins with `USE MotoGP;`. Use Ctrl+A followed by **MS SQL: Execute Query**. Do not run SQL files in PowerShell. Check the Messages panel after each file; if there is an error, stop and retain the exact message.

Existing identical imports are skipped. Scripts 21 and 22 are transactional. A changed timing revision is deliberately blocked rather than silently replacing an accepted dataset. `*_in_seed` counts report the supplied data, not necessarily newly inserted rows.

These scripts were generated and checked against the supplied project schema, but were **not executed against a live SQL Server** in this environment. There is no need to rerun earlier calendar, results or standings imports.

## Tables and grain

| Table | One row represents |
|---|---|
| `timing_sessions` | An official Q1, Q2, Sprint or race session, linked to an existing event/class |
| `session_entries` | A source rider identity observed in a session classification, timing sheet or reference record; may include a historical record holder who did not participate |
| `timing_revisions` | An immutable accepted collection of source documents and parsed facts for one session |
| `timing_quality_issues` | A source gap, discrepancy or excluded unfinished fragment, retained for review |
| `timing_documents` | One source document type per revision, with URL, hash, retrieval time and parse status |
| `session_results` | One rider's Q1 or Q2 classification, position and best time |
| `session_lap_records` | One source-reported record type, such as `fastestLap`, `poleLap`, `recordLap` or `bestLap` |
| `race_fastest_laps` | A rider's fastest lap as published on that race session's FastLapRider sheet |
| `race_grids` | A published starting-grid slot for a particular race session |
| `lap_times` | A numbered lap with a published duration, sectors, cancellation flags and pit-lane flag |

The source session UUID is the stable `sid`. Race views link it to `motogp_source.race_sessions`, and use only sessions already selected for statistics and races marked HELD. This avoids treating restart parts as extra scoring races.

Source rider keys follow the earlier import's `MGP_<legacy_id>` convention, with UUID fallback. Riders are matched by source IDs; names are never used as global identity keys. Within an event/class, uniquely mapped rider numbers link printed PDF rows to those source IDs. Conflicting number mappings are rejected.

Durations use `DECIMAL(...,3)` seconds. SQL `TIME` would represent a time of day rather than a duration. Original time text or PDF row text is retained. No missing time is converted into a zero.

## Reporting views

- `v_qualifying_results`: Q1 and Q2 separately; `session_position` is the position within that session.
- `v_race_fastest_laps`: each rider's published fastest lap, including its lap number.
- `v_race_overall_fastest_laps`: the rider ranked first on each race's published fastest-lap sheet. If investigating tied times, inspect all riders with the minimum time in `v_race_fastest_laps`.
- `v_race_grids`: published grid slots, with `OFFICIAL`, `PROVISIONAL` or `PUBLISHED` document status.
- `v_race_lap_times`: numbered, timed laps and sectors for imported scoring sessions.
- `v_timing_quality_issues`: documented source gaps, conflicts and unfinished fragments.
- `v_timing_document_coverage`: parsed rows, missing/withheld documents and source references.

**Do not obtain the overall qualifying order by sorting everybody's minimum Q1/Q2 time.** Riders who advance to Q2 are classified within Q2. Some may be slower there than their Q1 time; a Q1/Q2 aggregation loses that structure. Published grids are stored independently and may reflect penalties.

**Published grid position is not a verified physical start position.** A late withdrawal, pit-lane start or race-start incident may not be reflected in that PDF. This package does not infer those events. Grid penalty reasons and post-publication changes require their own source evidence.

**Do not confuse a circuit record with the fastest lap of this race.** Reference records keep their original type and year. Fastest-lap reporting uses the race-specific FastLapRider document. The API conflict documented in the audit is preserved separately.

**Lap cancellation is not the same as deleting a completed race lap.** Keep cancelled-time laps for distance/count analysis; exclude them when calculating legal best lap times. Standing-start laps, pit laps, outlaps and interrupted laps also distort pace. A false cancellation flag is only the absence of a printed cancellation mark, not a blanket assertion that the lap is suitable for pace analysis. The parser does not infer a comprehensive validity or tyre-stint model.

Unnumbered or `unfinished` fragments do not supply a complete duration and are not inserted as timed laps. They are logged in the audit with source row text. Race result lap counts remain authoritative for classification purposes.

## Optional refresh / reproducible rebuild

**Skip this section to load the bundled SQL.** Python is only needed to re-download or rebuild timing data.

In a terminal opened in `motogp_timing`:

```powershell
py -m pip install -r .\requirements.txt
py .\fetch_timing.py --year 2025
```

The downloader uses four workers by default, caches requests atomically, retries failures, and never connects to SQL Server. Rerun the same command to resume cached downloads. It downloads session lists, Q1/Q2 and race classifications, and the race-specific grid, fastest-lap and analysis PDFs. This version is deliberately limited to 2025 and uses the bundled 73 event/class request list.

After a successful download, rebuilding locally without further network requests is:

```powershell
py .\fetch_timing.py --year 2025 --build-cached
```

Use `--refresh` explicitly to fetch current source bytes instead of cached responses. A refreshed source can change a content hash even when the visible data looks similar. Read the resulting audit before running generated SQL. If script 22 rejects a changed revision, preserve both versions and review them; do not remove the guard or delete prior rows to bypass it.

`PyMuPDF==1.26.6` is the tested PDF extraction dependency. Python 3.10+ is recommended; the included SQL files require no Python installation. This ZIP excludes downloaded PDF cache files to keep delivery compact. It includes the source manifest and hashes, extracted facts, audit and scripts; running the downloader recreates the cache.

## Current scope limits

- 2025 only; all four solo classes present in this archive snapshot.
- Q1 and Q2, races and MotoGP Sprints; no practice, warm-up, pre-2025 qualifying formats or live telemetry.
- Race lap timing only. Qualifying individual laps are not imported; qualifying classification best times are.
- Source-specific missingness and exceptions are explicit in the audit.
- This improves the timing data foundation; it does not supply GPS coordinates, throttle, braking or other telemetry.
