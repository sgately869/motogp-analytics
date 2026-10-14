# MotoGP manufacturers, constructors and teams

Compiled 12 October 2026, using the official archive snapshot collected 11 October 2026 plus supplementary research. Scope is solo GP classes from 1949 through 2026, including MotoE. Sidecars, Formula 750, pre-1949 GP racing and separate national/junior series are excluded. 2026 is still in progress.

This package is a broad historical research/import baseline, NOT a certified exhaustive list of every manufacturer, one-off special, private entrant or team. The schema is designed to accept those missing records later without overwriting history.

## Run these files in VS Code

You do not need to run the earlier `09_explore_riders.sql`; it only contained example queries.

1. Extract the ZIP into your Windows `motogp-project` folder.
2. Connect the VS Code MSSQL extension to your existing SQL Server and run the entire `10_create_manufacturer_team_tables.sql` file.
3. Run the entire `11_import_manufacturers_and_teams.sql` file.
4. `12_explore_manufacturers_and_teams.sql` contains optional read-only queries, including Pramac's constructor change and Moto2's engine supply.

Run SQL in the SQL editor, not PowerShell. The import is self-contained: no JSON loading, Python installation or file-path configuration is needed. Scripts use SQL Server 2016+ syntax. They are transaction protected and insert missing stable keys, preserving existing IDs and edits. Run one copy at a time. They are fixed snapshot loaders, not live refresh/upsert scripts.

The scripts assume the existing `MotoGP` database and the schemas already discussed: `countries(country_id,country_name,country_code)`, `classes(class_id,class_name,class_group_id,first_season,last_season)` and `class_groups(class_group_id,group_name)`. Newly named tables must be absent or match the definitions in script 10. No rider, race-result or circuit rows are changed.

Script 10 appends 350cc, 50cc, 80cc and MotoE if missing, preserving existing class IDs/group assignments. It creates three project-defined groups where absent: Historic 350cc, 50cc / 80cc, Electric. These are organisational groupings, not a claim that 350cc was the direct predecessor of Moto2. MotoE's last held season is recorded as 2025 because the championship went on hiatus thereafter; this is not a prediction that it can never return. Missing seasons 1949–2026 are seeded by script 11.

## Expected counts in an otherwise empty new model

| Dataset/table | Rows |
|---|---:|
| dbo.manufacturers | 105 |
| dbo.constructors | 289 |
| dbo.teams | 39 |
| dbo.team_seasons | 722 |
| dbo.team_season_names | 854 |
| dbo.team_season_constructors | 650 |
| dbo.class_season_suppliers | 24 |
| dbo.seasons | 78 |
| motogp_source.constructor_labels | 292 |
| motogp_source.team_labels | 877 |
| motogp_source.team_mappings | 1,666 |
| motogp_source.team_constructor_observations | 11,235 |

736 name/season/class mappings are unresolved. They remain in the source layer with a NULL team_id. This is not a count of 736 additional teams. The placeholder constructor labels P, Unknown and XX are retained as source records and excluded from dbo.constructors.

## The modelling decision

A satellite/independent team is not automatically a subsidiary of its motorcycle manufacturer. Ownership, sporting entry status and technical support are different facts. There is deliberately no permanent parent_manufacturer_id on teams.

| Table | One row represents |
|---|---|
| manufacturers | An identified marque or builder, not necessarily one continuous legal company |
| constructors | A constructor identity credited by the results source; may be a composite label |
| teams | A curated racing organisation/lineage independent of sponsorship name or motorcycle supply |
| seasons | One calendar championship season |
| team_seasons | A team organisation operating in one class in one season |
| team_season_names | One observed sponsored/entry name for that organisation/class/season |
| team_season_constructors | One observed constructor association for that organisation/class/season |
| class_season_suppliers | A class-wide exclusive engine or complete-motorcycle supplier in one season |

An organisation can run more than one squad or sponsored identity in the same class. The organisation-level team_seasons grain must not be treated as a championship scoring team or summed blindly to calculate team titles. Future race entries should retain their exact official entrant/team identity, constructor and rider; that is where race-level allocation and any mid-season changes become authoritative.

The source tables preserve original constructor/team labels, IDs, evidence URLs, season/class context and unresolved mappings. This avoids erasing information simply because it cannot yet be normalised confidently. Stable text import keys identify our records; SQL generates internal integer IDs. Relationships are resolved by those keys, never by guessed identity numbers.

## How the model handles the awkward cases

- **Pramac:** its 2024 MotoGP constructor observation is Ducati; 2025 is Yamaha. The same Pramac organisation is retained. For 2025/2026 it is independent in the sporting classification, with factory-supported Yamaha supply recorded separately. Yamaha explicitly described the independently owned team as its second Factory Team.
- **Moto2:** team sponsorship is not constructor identity. A KTM- or Honda-branded team can race a Kalex or Boscoscuro chassis using a Triumph engine. Class-wide ENGINE supply is seeded as Honda for 2010–2018 and Triumph for 2019–2026. It does not overwrite the constructors credited in results.
- **MotoE:** COMPLETE_MOTORCYCLE supply is Energica for 2019–2022 and Ducati for 2023–2025. No MotoE season is invented for 2026.
- **FTR Honda, Kalex KTM and similar labels:** retain the credited composite constructor. The manufacturer link is NULL until its meaning is researched; do not split a hyphen/space and assume corporate ownership or component provenance.
- **Speed Up and Boscoscuro:** Speed Up remains a team identity; Boscoscuro is a marque/builder and credited constructor. Historic Speed Up constructor credit remains visible. Corporate ownership/continuity between brands is not inferred from the team name.
- **LCR:** the historic LCR constructor and modern LCR racing team are separate records in different tables. Matching names do not establish that they are the same organisation.
- **MV Agusta:** the source has two constructor legacy IDs using this name. Both source identities are retained and linked to one marque. Group by manufacturer_id for marque-level queries; do not assume constructor_name is unique.
- **Multiple constructors:** eight curated organisation/class/seasons have more than one observed constructor. All links are retained. This can reflect different squads, riders, mid-season changes or a source error; it does not establish the chronology or an exclusive supply contract. No fabricated effective dates are supplied.
- **Factory/independent status:** only selected 2025/2026 MotoGP entries receive a classification. Other periods/classes remain UNKNOWN. The word Factory in a sponsored name is not used as proof of status. Pramac's known technical support is sourced explicitly; other support levels remain UNKNOWN.

## Scope and source quality

303 official season/class standings responses were reviewed; 19 were empty. Their union contains 289 constructor source IDs carrying 288 distinct labels. These include established manufacturers, specialist builders, composites, model/sponsor labels and placeholders. It would be incorrect to label all 288 as manufacturers.

The curated manufacturer table contains 101 clearly identified marques/builders from that union, Ilmor mapped from the Ilmor X3 entry, plus BSA, Vincent and BSL from supplementary historical entry records. The supplementary evidence includes zero-point entrants and a non-qualifier; presence in the constructor catalogue is not proof of a race start. For those three, the observed year means the year of the supplied supplementary evidence, not their first ever GP year.

Unlinked historical constructor identities remain available in dbo.constructors and the catalogue. More can be mapped to manufacturer records after research. Known candidate names such as Nougier require championship-entry verification before being added; a machine described as a Grand Prix prototype is not sufficient by itself.

Team names were collected from standings and the matched season/class sponsored_team fields of all 303 historical rosters. The nested team/constructor objects in the rider profiles were deliberately not used to infer historical motorcycle supply: sampled older responses contain modern team/manufacturer details. After rejecting a mismatched career-step record, the union contains 877 distinct original team-name strings. Names are sparse before 2002; the standings themselves only supply non-null team data from 2006 in this snapshot. This is a major limitation on historic team completeness.

Thirty-nine recognisable organisation/name families have inspectable mappings in team_mappings.json. These are research mappings based on source labels and reviewed family rules, not an independently certified legal-entity registry. All raw spellings/encoding errors are retained; whitespace/case/trademark variations are collapsed only for canonical season names. Ambiguous joint labels such as Camel Pramac Pons remain unresolved. Partner/owner transitions may require finer identities when legal ownership or championship-team accounting is added.

Country fields are intentionally NULL in this release: manufacturer/team country-of-origin and historical domicile have not been independently sourced. No country is inferred from sponsor names. First/last observed constructor seasons are evidence bounds, not founding/closure dates. Wins, starts and championships are not stored in these master tables.

## Data files and learning use

- manufacturer_list.md: the 105 curated marques/builders with evidence links.
- constructor_catalogue.md: all 292 source constructor identities, classifications and observed ranges.
- team_name_catalogue.md: all 877 source strings, observed years and mapping status.
- The JSON files preserve the relational datasets and evidence for Python/R practice.
- source_coverage.json records every standings query and row count.
- build_sql.py rebuilds scripts 10 and 11 from the supplied JSON, using Python's standard library only. Run `python build_sql.py` inside the extracted folder. It does not connect to a database or access the network.
- schema.md contains a compact relationship diagram and notes.
- validation.json and manifest.json record the export checks and file hashes.

For Power BI later, use a separate reporting model with fact_race_results at one rider/race grain and dimensions for rider, constructor, team entry, circuit and date. Do not count source observations as races or let multiple sponsored names multiply rows in a reporting join. For SQL learning, querying the separate tables now is a good way to practise keys, joins, bridge tables, NULLs and source reconciliation.

## Sources

Most row-level evidence is MotoGP's public results/rider archive; exact URLs are retained in the JSON/source tables. The snapshot was collected 2026-10-11 and reused rather than silently presented as a fresh 2026-10-12 extraction.

- Official definitions of factory and independent teams: https://www.motogp.com/en/glossary
- Pramac's independent ownership and Yamaha supply: https://global.yamaha-motor.com/race/release/2024/011/
- Speed Up distinguishes its team from the Boscoscuro motorcycle identity: https://www.teamspeedup.it/en/boscoscuro-starts-the-engines/
- Honda's Moto2 supply from inception through 2018: https://global.honda/en/newsroom/news/2015/c150213eng.html
- Triumph's Moto2 supply since 2019: https://www.triumphmotorcycles.co.uk/discover/racing/moto2
- Energica's 2019–2022 MotoE supply: https://energicamotor.com/racing
- Ducati's 2023–2025 MotoE supply: https://www.ducati.com/ww/en/company/innovation/moto-e
- MotoE hiatus after 2025: https://www.fim-moto.com/en/news/news-detail/article/motoetm%EF%B8%8Fto-go-on-hiatus-following-2025-season
- Ilmor X3 manufacturer identification: https://en.wikipedia.org/wiki/Ilmor_X3
- Supplementary BSA/Vincent entry evidence: https://en.wikipedia.org/wiki/1951_Grand_Prix_motorcycle_racing_season
- Supplementary BSL entry/DNQ evidence: https://en.wikipedia.org/wiki/1999_French_motorcycle_Grand_Prix

The supplementary sources are secondary and are labelled as such; the primary official feed does not provide those missing records in the checked standings. Continued race-entry/classification research is required for a complete register.

## Validation limits

Keys, cross-file references, field lengths, date/class ranges, row counts and SQL literal export round-trips were checked. The Pramac and Moto2 example joins were checked against the generated data. SQL regeneration is deterministic. Scripts have not been executed against your Windows SQL Server, which is not accessible from this workspace; execute them there and inspect the returned counts/errors.
