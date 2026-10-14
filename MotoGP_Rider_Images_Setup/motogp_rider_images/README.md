# Season-specific rider photos

Prepared for the existing MotoGP SQL Server project. Initial image import: **2025**, across MotoGP, Moto2, Moto3 and MotoE. No changes are made to your race results or timing data.

## What to do now

1. Extract this ZIP into your main `motogp-project` folder. Keep its `motogp_rider_images` folder intact.
2. Open the SQL files in VS Code, connect to `localhost\SQLEXPRESS` / **MotoGP**, and run each whole file in this order:
   - **25_create_rider_image_tables.sql**
   - **26_import_rider_images_2025.sql**
   - **27_create_rider_image_views.sql**
   - **28_check_rider_images.sql**
3. Compare the returned counts with **image_audit_2025.json**, or send a screenshot of script 28's results.
4. When building the report, follow **POWER_BI_SETUP.md** for relationships, selectors, image display and missing-photo messages.

No Python execution is needed for this initial import. SQL can be rerun: it updates these source-managed image rows and inserts missing ones; it does not duplicate rows. Do not hand-edit the source-managed table expecting those edits to survive a later image refresh.

## Included data

Expected script 28 totals: **137 rider/season/class rows, 132 displayable photos, 0 unlinked photo rows**. Five catalogue rows have no displayable photo: four missing and one undated. Among the 134 combinations in imported qualifying/grid data, 131 have a usable photo; the three exceptions are Alex Escrig (undated image), Hector Garzo / Moto2 (missing), and Jakob Rosenthaler / Moto3 (missing). The other two missing catalogue associations are Andrea Dovizioso / MotoGP and Joel Esteban / MotoGP; do not interpret roster-only associations as race starts.

The live official 2025 roster has 137 rider/class associations. This is a roster-based image catalogue, not a list of actual starters. Three associations do not occur in the imported qualifying/grid participants. Use race and qualifying facts for participation statistics.

All 134 rider/class combinations in the existing 2025 qualifying and published-grid data are represented. The final audit identifies available, missing and withheld images. Missing does not mean zero, and an image from another year is never silently substituted.

The chosen full-body profile files include team clothing and work well beside statistics. Their background is generally transparent. Season and class must be selected as well as rider to keep the photo contextual.

Images remain hosted by MotoGP. This package contains links, source records and code—not a redistributed photo collection. Public access does not grant reuse rights for public/commercial publishing.

## Automation for another season or a refresh

Open PowerShell inside `motogp_rider_images`:

```powershell
py .\fetch_rider_images.py --year 2024
```

This produces `26_import_rider_images_2024.sql`, a JSON catalogue and an audit. Read the audit, then run that generated SQL against MotoGP. The table and views already support multiple seasons; do not recreate the database. Your Power BI model then needs refreshing.

To recheck the live 2025 roster and image URLs:

```powershell
py .\fetch_rider_images.py --year 2025 --refresh
```

Python standard library only; no pip install needed. Downloads are limited to four workers and cached locally. An interrupted run can be resumed using the same command without `--refresh`. `FETCH_FAILED` images require a refresh to retry.

The bundled source catalogue covers the project's existing 1949–2026 season/class requests. Older archive photos often have no year in their paths. Such images are retained as candidates with `UNDATED_IMAGE_REVIEW` and are not displayed automatically as period-correct photographs. Newly introduced rider identities cause generation to stop for reconciliation instead of guessing a rider link.

## Model design and limitations

- Grain: one source rider / season / class. SQL resolves the existing canonical rider ID through `motogp_source.riders`; no name matching.
- The public BI view exposes only checked, year-linked image URLs. Other candidates remain in the source-managed SQL table and audit for review.
- Year in URL plus matching roster career step is season evidence. It does not certify the exact outfit for every event or represent all mid-season team changes.
- Nested current team colour codes and logos are deliberately not imported as historical team attributes. The source's season-level sponsored team name is retained.
- A single canonical rider mapped from multiple source IDs could create duplicate BI rows. Script 28 explicitly checks this and the report guard hides ambiguous selections.
- Initial validation checks URL responses, image bytes, source identities, SQL seed round-trip and participant coverage. SQL Server execution and Power BI rendering must be checked locally.

## Files

- SQL 25–28: tables, seed import, BI views and verification.
- `POWER_BI_SETUP.md`: complete setup steps and DAX measures.
- `fetch_rider_images.py`: repeatable collection, validation and SQL generation.
- `rider_images_2025.json`, `image_audit_2025.json`: source catalogue and exceptions.
- `rider_index.json`, `expected_season_riders.json`, `season_sources.json`: identity and source lookup inputs from this project.
- `validation.json`: package checks and their limits.

Official roster sources are recorded per row; photos use `https://photos.motogp.com/`.
