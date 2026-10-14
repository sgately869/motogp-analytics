# MotoGP rider research and SQL import

Snapshot: 11 October 2026. This is a researched starting dataset, NOT a certified complete list of every rider in GP history.

## What is included

- 2,175 source identity records; source IDs are not necessarily distinct people.
- 2,162 records eligible for automatic insertion into `dbo.riders`.
- 13 records held in the source tables for review: eight identities in four same-name groups, and five roster-only records needing participation checks.
- 1,008 records with a source-reported date of birth; 698 with a birthplace; 2,014 with a mapped source nationality label. These counts include review records.
- 9,374 source rider/season/class observations, not race starts.
- Coverage: 1949–2026, across 50cc, 80cc, 125cc, 250cc, 350cc, 500cc, MotoGP, Moto2, Moto3 and MotoE. No sidecars, pre-1949 racing, or separate junior/national series. The 2026 season is unfinished.

All 303 season/class roster requests returned records. This establishes retrieval coverage, not historical completeness. The source roster and standings feeds omit known riders; nine independently located official profiles with GP statistics were added. More omissions may remain, especially zero-point riders, non-qualifiers and early entrants. Race-by-race entry lists and classifications still need auditing before anyone can call this complete.

## Open the list

`rider_list.md` is the human-readable alphabetical list. In VS Code, open it and press Ctrl+Shift+V for a table preview. `riders.json` contains the same identities with more fields and source references; it is suitable for later Python/R practice. Null means missing or withheld, not zero.

## Load the SQL Server database

1. Extract this ZIP into your Windows `motogp-project` folder.
2. In VS Code, open `08_import_riders.sql` in the editor and connect the MSSQL extension to your existing SQL Server Express instance.
3. Run the entire file using the MSSQL Execute Query command. Do not paste SQL into the PowerShell terminal. No Python or JSON import step is needed.
4. With an initially empty riders table, expect 2,162 new rider rows, 2,175 source identities, 9,374 source season/class observations, and 13 pending-review records.
5. Open `09_explore_riders.sql` and run individual queries to explore names, birth information, class observations and recorded numbers.

The import uses `MotoGP` and your existing `dbo.countries(country_id, country_name, country_code)` table, including the expanded three-character codes. It does not alter your countries, circuits, classes or class groups.

The expected rider schema is `dbo.riders(rider_id INT IDENTITY PRIMARY KEY, display_name NVARCHAR(150) NOT NULL, first_name NVARCHAR(100) NULL, last_name NVARCHAR(100) NULL, date_of_birth DATE NULL, birth_place NVARCHAR(150) NULL, birth_country_id INT NULL)` with the birth-country foreign key. It creates this table if absent. If you created a different rider schema, adapt the import to that schema before running it.

If you already entered riders manually without source mappings, the script stops and rolls back to avoid creating duplicates. Those rows need reconciliation to the supplied source IDs; names alone are not a safe matching key. A missing country code also stops the import and rolls it back.

The script is designed to be rerunnable: it inserts absent source UUIDs, retains their generated rider IDs, and preserves existing rider edits. It is a fixed snapshot loader, not a live synchronisation service. Run one copy at a time. Pending-review records stay in the source tables; they are not automatically promoted on a rerun.

## Why there are source tables

- `dbo.riders`: the person records used by your database.
- `motogp_source.riders`: the original source identities, biography facts, country labels, review flags, retrieval date and mapping to your internal rider IDs.
- `motogp_source.rider_seasons`: the evidence linking a source identity to a season and class, with available roster numbers and sponsored team names.

Keeping the original source layer is a useful first data-engineering exercise: it makes corrections and identity matching traceable. Class names here are source text rather than foreign keys to your six currently seeded classes. This preserves the historical 50cc/80cc/350cc and MotoE observations until the full competition model is built.

## Data definitions and limitations

- **Identity:** UUIDs and legacy IDs identify source records. The four same-name groups are Cees van Dongen, Miguel Duhamel, Manuel Hernandez and Josh Hook. They may represent duplicated profiles or different people. All eight source records are retained and held for review. No merge was made by name or date of birth.
- **Participation review:** Bob Keeler, S. Ferretti, C. Stormont and Kadai Yaseen Ahamed appear in rosters but have no first-GP record in the checked statistics feed. That does not prove they never entered or raced. Mike Trimby's honorary roster entry uses the placeholder legacy ID 2147483647; it must not establish MotoGP competition in 2023. These five are withheld from automatic rider insertion.
- **Names:** source-provided first and last names are preserved, including initials. No initial has been expanded by guessing. Source spelling and name order may need historical correction.
- **Biographies:** DOB, birthplace and birth-country labels are source-reported and have not all been independently corroborated. Source country labels can reflect modern geography. Missing birth country is never filled from nationality or inferred from a city.
- **Nationality:** `profile_country_*` records the label supplied by the profile/archive at retrieval. It is not citizenship history or guaranteed nationality at each race. Historical labels such as Czechoslovakia and Rhodesia are retained where supplied; other source records already use modern countries. Original labels are kept alongside mapped project country codes.
- **Numbers:** a positive number is a season roster observation. Source zero is treated as unknown and becomes NULL. A number can change during a season; future race-entry records should be authoritative. Missing number does not mean the rider had no number.
- **Teams:** the supplied sponsored team text is preserved where present. The API's nested team name can be its modern name, so that nested field was deliberately not imported as a historical team name.
- **Classes and seasons:** flags distinguish roster evidence, standings evidence and first-GP statistics evidence. Supplementary statistics establish a first-GP season/class only, not a full career timeline. Source rosters may include entrants who did not start. These observations must not be used as race counts, career start/end dates, or proof of participation in every event that season.
- **Wins:** not stored on `dbo.riders`. Calculate GP wins by joining riders to race entries/results, counting official first-place finishes, and grouping by class. Keep Sprint wins separate. This package has no complete race-results dataset, so it supplies no career win totals.

## Files

- `08_import_riders.sql`: self-contained database import; no external data files required at execution.
- `09_explore_riders.sql`: example queries.
- `rider_list.md`: alphabetical human-readable list, with review status.
- `riders.json`: biography/source identity data.
- `rider_season_records.json`: season/class/number/team observations with source URLs.
- `coverage.json`: retrieval coverage, counts and source URLs for every season/class.
- `identity_review.json`: same-name identity groups requiring review.
- `data_issues.json`: participation/placeholder issues.
- `supplementary_participation.json`: official first-GP evidence for the nine added profiles.
- `build_sql.py`: optional standard-library Python script; rebuilds both SQL files from the supplied JSON files. Run `python build_sql.py` inside this extracted folder. It performs no database writes or network requests.
- `manifest.json`: file hashes for this fixed snapshot.

## Sources and method

Primary sources were MotoGP's public results and rider feeds:

- Season/category catalogue and standings: https://api.motogp.pulselive.com/motogp/v1/results/seasons and per-season category/standings URLs retained in the data.
- Historical rosters: `https://riders.motogp.com/api/riders/getRiders?season=YEAR&category=CATEGORY_UUID` (303 responses).
- Rider profiles: `https://api.motogp.pulselive.com/motogp/v1/riders/RIDER_UUID`.
- Supplementary profile search: `https://riders.motogp.com/api/riders/searchRider?search=NAME`.
- Targeted GP participation checks: `https://api.motogp.pulselive.com/motogp/v1/riders/LEGACY_ID/stats` (all roster-only candidates plus supplementary profiles).

For example, the official Mashel Al Naimi profile confirms his birth date/place and Moto2 career: https://www.motogp.com/en/riders/mashel-al-naimi-mashel-al-naimi/5f5310f7-f3c1-48a6-8adf-9ba8ac447463 . The official article identifying Sarath Kumar's GP participation is https://www.motogp.com/en/news/2023/09/19/un-pas-de-geant-du-motogp-dans-le-nouveau-monde-par-nick-harris/478366 . These examples demonstrate why the season roster alone was insufficient.

The record union uses source UUIDs, not names. Four standings identities absent from the roster union were filled from their direct profiles. Nine additional identities with first-GP evidence were added by targeted searches. Missing biography fields remain NULL. Names with multiple UUIDs and records with unresolved participation evidence are quarantined in the source layer.

## Validation performed

Source UUID and legacy-ID uniqueness, season/class key uniqueness, reference integrity, country-code mappings, field lengths, date formats, review counts and generated SQL literal round-trips were checked. All 303 roster requests completed without an empty response. These are data/export checks, not proof that the historical archive is complete.

The SQL has not been executed against your local SQL Server: that server is on your Windows computer and is not accessible here. The script uses a transaction and rolls back on execution errors.
