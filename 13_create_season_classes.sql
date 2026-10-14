/* MotoGP: valid championship season/class combinations.
   Run this entire file in the VS Code SQL editor, connected to MotoGP.
   Prerequisites: scripts 10 and 11 from the manufacturer/team package.
   Source: cached official MotoGP results categories for each season,
   https://api.motogp.pulselive.com/motogp/v1/results/categories?seasonUuid=...
   Snapshot: 2026-10-12. All 303 observed pairs are represented by the
   ten continuous ranges below; no missing years within those ranges.
   2026 is the snapshot cutoff, not an end date for the current classes.
   MotoE's 2025 endpoint describes this snapshot, not permanent closure.
   Scope follows earlier imports: solo GP classes plus MotoE; no sidecars.
   Safe to rerun: inserts missing pairs only. No existing data is deleted.
*/
USE MotoGP;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.seasons', N'U') IS NULL
       OR OBJECT_ID(N'dbo.classes', N'U') IS NULL
       OR OBJECT_ID(N'dbo.team_seasons', N'U') IS NULL
       OR OBJECT_ID(N'dbo.class_season_suppliers', N'U') IS NULL
        THROW 50001, 'Run manufacturer/team scripts 10 and 11 first.', 1;

    DECLARE @class_ranges TABLE (
        class_name NVARCHAR(50) NOT NULL PRIMARY KEY,
        first_year SMALLINT NOT NULL,
        last_year SMALLINT NOT NULL
    );

    INSERT INTO @class_ranges (class_name, first_year, last_year)
    VALUES
        (N'500cc',  1949, 2001),
        (N'MotoGP', 2002, 2026),
        (N'350cc',  1949, 1982),
        (N'250cc',  1949, 2009),
        (N'Moto2',  2010, 2026),
        (N'125cc',  1949, 2011),
        (N'Moto3',  2012, 2026),
        (N'50cc',   1962, 1983),
        (N'80cc',   1984, 1989),
        (N'MotoE',  2019, 2025);

    IF EXISTS (
        SELECT 1 FROM @class_ranges r
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.classes c WHERE c.class_name = r.class_name
        )
    )
        THROW 50002, 'A required class is missing. Check script 10 and your class names.', 1;

    IF (SELECT COUNT(*) FROM dbo.seasons WHERE season_year BETWEEN 1949 AND 2026) <> 78
        THROW 50003, 'Seasons 1949 through 2026 are required. Run script 11 first.', 1;

    IF OBJECT_ID(N'dbo.season_classes', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.season_classes (
            season_year SMALLINT NOT NULL,
            class_id INT NOT NULL,
            CONSTRAINT PK_season_classes PRIMARY KEY (season_year, class_id),
            CONSTRAINT FK_season_classes_seasons FOREIGN KEY (season_year)
                REFERENCES dbo.seasons (season_year),
            CONSTRAINT FK_season_classes_classes FOREIGN KEY (class_id)
                REFERENCES dbo.classes (class_id)
        );
    END;

    INSERT INTO dbo.season_classes (season_year, class_id)
    SELECT s.season_year, c.class_id
    FROM @class_ranges r
    JOIN dbo.classes c ON c.class_name = r.class_name
    JOIN dbo.seasons s ON s.season_year BETWEEN r.first_year AND r.last_year
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.season_classes sc
        WHERE sc.season_year = s.season_year AND sc.class_id = c.class_id
    );

    DECLARE @rows_inserted INT = @@ROWCOUNT;

    -- Check earlier imports before adding stricter relationships.
    IF EXISTS (
        SELECT 1 FROM dbo.team_seasons ts
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.season_classes sc
            WHERE sc.season_year = ts.season_year AND sc.class_id = ts.class_id
        )
    )
        THROW 50004, 'A team-season has no matching season/class. No changes committed.', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.class_season_suppliers css
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.season_classes sc
            WHERE sc.season_year = css.season_year AND sc.class_id = css.class_id
        )
    )
        THROW 50005, 'A supplier has no matching season/class. No changes committed.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.team_seasons')
          AND name = N'FK_team_seasons_season_classes'
    )
        ALTER TABLE dbo.team_seasons WITH CHECK
        ADD CONSTRAINT FK_team_seasons_season_classes
            FOREIGN KEY (season_year, class_id)
            REFERENCES dbo.season_classes (season_year, class_id);

    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.class_season_suppliers')
          AND name = N'FK_class_season_suppliers_season_classes'
    )
        ALTER TABLE dbo.class_season_suppliers WITH CHECK
        ADD CONSTRAINT FK_class_season_suppliers_season_classes
            FOREIGN KEY (season_year, class_id)
            REFERENCES dbo.season_classes (season_year, class_id);

    ALTER TABLE dbo.team_seasons WITH CHECK
        CHECK CONSTRAINT FK_team_seasons_season_classes;
    ALTER TABLE dbo.class_season_suppliers WITH CHECK
        CHECK CONSTRAINT FK_class_season_suppliers_season_classes;

    COMMIT TRANSACTION;

    SELECT @rows_inserted AS rows_inserted_this_run;
    -- Expected: 303 rows for this snapshot (including on a rerun).
    SELECT COUNT(*) AS season_class_count_1949_to_2026
    FROM dbo.season_classes
    WHERE season_year BETWEEN 1949 AND 2026;

    -- Check class coverage. These dates describe the imported data only.
    SELECT c.class_name, MIN(sc.season_year) AS first_imported_season,
           MAX(sc.season_year) AS last_imported_season,
           COUNT(*) AS seasons_in_snapshot
    FROM dbo.season_classes sc
    JOIN dbo.classes c ON c.class_id = sc.class_id
    WHERE sc.season_year BETWEEN 1949 AND 2026
    GROUP BY c.class_id, c.class_name
    ORDER BY MIN(sc.season_year), c.class_name;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Future seasons: confirm the actual championship classes, then add the
-- season to dbo.seasons and its pairs to dbo.season_classes BEFORE importing
-- teams or suppliers. This script deliberately does not guess future classes.
