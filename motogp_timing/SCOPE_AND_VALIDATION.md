# Scope and validation — 2025 timing extension

## Recovered source coverage

The collector requested all **73 event/class combinations** in the bundled 2025 archive snapshot. It retrieved **248 session classifications** (146 qualifying sessions and 102 race/Sprint sessions) and **306 race timing PDFs** (102 each of grids, personal fastest laps and lap analysis). All advertised documents in this scope downloaded and parsed. No practice or warm-up sessions were requested.

| Class | Q1/Q2 rider rows | Published grid entries | Personal fastest laps | Numbered timed laps |
|---|---:|---:|---:|---:|
| Moto2 | 705 | 615 | 595 | 11034 |
| Moto3 | 654 | 560 | 543 | 9117 |
| MotoE | 138 | 246 | 227 | 1430 |
| MotoGP | 529 | 954 | 916 | 15468 |
| **Total** | **2,026** | **2,375** | **2,281** | **37,049** |

There is one top-ranked fastest lap for each of the 102 imported races/Sprints. Personal fastest-lap coverage is smaller than entry coverage: some riders have no published fastest lap. Absence is not filled with an estimated lap time.

The grid documents contain 1,896 entries headed OFFICIAL STARTING GRID and 479 Sprint entries headed TISSOT SPRINT - STARTING GRID, labelled PUBLISHED in SQL. These are documentary grid positions, not independently established physical starting positions.

## Documented exceptions: 309 notes, not 309 failed downloads

| Category | Count | Treatment |
|---|---:|---|
| No positive qualifying best time | 24 | Keep the qualifying classification and a NULL best time |
| Completed laps but no personal fastest-lap entry on the published sheet | 38 | Retain absence; do not invent a time or its cause |
| Unfinished analysis fragments | 207 | Keep fragment text in the audit/quality table; exclude from numbered timed-lap facts |
| Sector sum differs from published lap duration | 38 | Preserve printed values; expose the difference for pace-data review |
| API fastest-lap record conflicts with PDFs | 1 | Use the independently cross-checked PDF times for reporting; retain API record separately |
| Classification lap count differs from recovered timed laps | 1 | Preserve both source facts and the missing duration |

These are recorded in `22_timing_2025_audit.json` and loaded into `timing_quality_issues`. A PARSED document status means extraction succeeded; it does not mean the source has no gaps or inconsistencies.

### Australian MotoGP Sprint

The API record gives Alex Marquez, 1:27.782 on lap 10. The race-specific FastLapRider sheet instead ranks Marco Bezzecchi first, 1:27.122 on lap 7; the separate Analysis sheet confirms that lap and every other personal best on the sheet. The reporting view uses that PDF evidence. No API record has been overwritten or silently reinterpreted.

- [Fastest lap of each rider](https://resources.motogp.com/files/results/2025/AUS/MotoGP/SPR/FastLapRider.pdf)
- [Individual lap analysis](https://resources.motogp.com/files/results/2025/AUS/MotoGP/SPR/Analysis.pdf)

### Hungarian MotoGP race

Enea Bastianini's classification records one lap, but the analysis contains unfinished fragments without a complete lap duration. Zero complete timed laps are imported for him in this race. All other race/classification rider lap counts match the number of extracted timed laps. We do not change his result or create a synthetic lap time.

- [Individual lap analysis](https://resources.motogp.com/files/results/2025/HUN/MotoGP/RAC/Analysis.pdf)

## Verification completed

- Compared the extension with the existing project schema and source-ID conventions.
- Checked every new data key, parent/child link, SQL string width, UUID, SMALLINT range and positive-time constraint.
- Checked every one of the 2,281 published personal bests against its matching rider and lap in the separate analysis document.
- Compared per-rider timed-lap counts with source classifications; the one exception is documented above.
- Visually inspected official MotoGP, Moto2 and MotoE timing sheets, including multi-column continuations and the Australian conflict.
- Checked sample Thailand best lap, pole-grid identity and lap count against the official sheets.
- Parsed table declarations and reporting/check SQL using a T-SQL parser.
- Checked Python syntax and offline validation assertions.
- Compared all timing source rider identities with the earlier rider seed; no unmatched identities were found in that comparison. Script 22 still checks actual database links.

**Not performed:** execution against a live SQL Server or the user's Windows database. SQL parsing and data validation do not substitute for a database execution test. The scripts retain transactional rollback and revision guards.

## Source evidence and reproducibility

Each fact is linked to a source session and revision. The manifest records exact API/PDF URLs; the normalised data records hashes and retrieval times for every document. Source PDF page and row text accompany printed timing facts. The downloaded PDF cache is not included in the ZIP; the downloader can recreate it.

- `source_manifest.json`: source requests and advertised document locations.
- `timing_2025_normalised.json`: all accepted facts, ready to inspect without SQL Server.
- `22_timing_2025_audit.json`: coverage and all source notes.
- `validation_report.json`: completed offline checks and explicit limits.
- `sql_parse_checks.json`: limited static SQL parsing scope.

Scope is the supplied 2025 official archive, not certification that every fact is correct or that earlier seasons have equivalent coverage. Lap timing supports pace analysis; it is not GPS or machine telemetry.
