import json,pathlib
OUT=pathlib.Path(__file__).resolve().parent
riders=json.loads((OUT/'riders.json').read_text());seasons=json.loads((OUT/'rider_season_records.json').read_text())
def lit(v):
 if v is None:return 'NULL'
 if isinstance(v,bool):return '1' if v else '0'
 if isinstance(v,int):return str(v)
 return "N'"+v.replace("'","''")+"'"
def seed(table,rows,columns,keys):
 chunks=[]
 for i in range(0,len(rows),400):
  values=',\n'.join('('+', '.join(lit(r[k]) for k in columns)+')' for r in rows[i:i+400])
  names=', '.join(columns)
  chunks.append(f'INSERT INTO {table} ({names})\nSELECT {", ".join("v."+c for c in columns)}\nFROM (VALUES\n{values}\n) AS v ({names})\nWHERE NOT EXISTS (SELECT 1 FROM {table} AS existing WHERE '+ ' AND '.join(f'existing.{k}=v.{k}' for k in keys)+');\n')
 return '\n'.join(chunks)
header='''/* MotoGP riders: official public archive snapshot, retrieved 2026-10-11.
Read README.md before running. Solo classes, 1949-2026; includes MotoE.
Coverage is not certified exhaustive. Sidecars and pre-1949 racing excluded.
Run the ENTIRE file in a SQL editor connected to SQL Server, not PowerShell.
Requires your existing dbo.countries(country_id, country_name, country_code).
Creates dbo.riders if absent, using the schema previously discussed.
Existing riders with no source mapping stop the import for reconciliation.
Rerunning inserts only missing source IDs; it preserves existing rider edits.
Source nationality is a profile label, not a verified historical race nationality.
Numbers are season roster observations, not guaranteed for every race.
*/
USE MotoGP;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.countries', N'U') IS NULL
    THROW 50001, 'Create and seed dbo.countries first.', 1;
IF SCHEMA_ID(N'motogp_source') IS NULL EXEC(N'CREATE SCHEMA motogp_source');
IF OBJECT_ID(N'dbo.riders', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.riders (
    rider_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    display_name NVARCHAR(150) NOT NULL,
    first_name NVARCHAR(100) NULL,
    last_name NVARCHAR(100) NULL,
    date_of_birth DATE NULL,
    birth_place NVARCHAR(150) NULL,
    birth_country_id INT NULL,
    CONSTRAINT FK_riders_birth_country FOREIGN KEY (birth_country_id)
        REFERENCES dbo.countries(country_id)
 );
END;
IF OBJECT_ID(N'motogp_source.riders',N'U') IS NULL
BEGIN
 CREATE TABLE motogp_source.riders (
    source_rider_uuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    motogp_legacy_id INT NOT NULL UNIQUE,
    display_name NVARCHAR(150) NOT NULL,
    first_name NVARCHAR(100) NULL,
    last_name NVARCHAR(100) NULL,
    date_of_birth DATE NULL,
    birth_place NVARCHAR(150) NULL,
    birth_country_name NVARCHAR(100) NULL,
    birth_country_code CHAR(3) NULL,
    profile_country_name NVARCHAR(100) NULL,
    profile_country_iso2 VARCHAR(10) NULL,
    profile_country_code CHAR(3) NULL,
    source_url NVARCHAR(500) NOT NULL,
    retrieved_at DATE NOT NULL,
    identity_review_required BIT NOT NULL,
    participation_review_required BIT NOT NULL,
    rider_id INT NULL,
    CONSTRAINT FK_motogp_source_riders FOREIGN KEY (rider_id)
        REFERENCES dbo.riders(rider_id)
 );
END;
IF OBJECT_ID(N'motogp_source.rider_seasons',N'U') IS NULL
BEGIN
 CREATE TABLE motogp_source.rider_seasons (
    source_rider_uuid UNIQUEIDENTIFIER NOT NULL,
    season SMALLINT NOT NULL,
    class_name NVARCHAR(20) NOT NULL,
    listed_in_roster BIT NOT NULL,
    listed_in_standings BIT NOT NULL,
    rider_number INT NULL,
    sponsored_team_name NVARCHAR(200) NULL,
    roster_url NVARCHAR(500) NULL,
    standings_url NVARCHAR(500) NULL,
    listed_in_statistics BIT NOT NULL,
    statistics_url NVARCHAR(500) NULL,
    CONSTRAINT PK_motogp_source_rider_seasons PRIMARY KEY
        (source_rider_uuid,season,class_name),
    CONSTRAINT FK_motogp_source_rider_seasons FOREIGN KEY (source_rider_uuid)
        REFERENCES motogp_source.riders(source_rider_uuid)
 );
END;
IF EXISTS (
 SELECT 1 FROM dbo.riders AS r
 WHERE NOT EXISTS (SELECT 1 FROM motogp_source.riders AS s WHERE s.rider_id=r.rider_id)
)
 THROW 50003, 'Existing riders lack source mappings. Reconcile them before importing to avoid duplicates.', 1;
'''
cols=[k for k in riders[0] if k!='name_variants']
sql=header+seed('motogp_source.riders',riders,cols,['source_rider_uuid'])
sql+='''
-- Fail rather than silently lose a country relationship.
IF EXISTS (
 SELECT 1 FROM motogp_source.riders AS s
 LEFT JOIN dbo.countries AS c ON c.country_code=s.birth_country_code
 WHERE s.birth_country_code IS NOT NULL AND c.country_id IS NULL
) OR EXISTS (
 SELECT 1 FROM motogp_source.riders AS s
 LEFT JOIN dbo.countries AS c ON c.country_code=s.profile_country_code
 WHERE s.profile_country_code IS NOT NULL AND c.country_id IS NULL
)
 THROW 50002, 'A source country code is absent from dbo.countries. Apply the country seed first.', 1;

-- Map newly generated internal IDs back to the stable source UUID.
DECLARE @new_riders TABLE (source_rider_uuid UNIQUEIDENTIFIER, rider_id INT);
MERGE dbo.riders AS target
USING (
 SELECT s.source_rider_uuid,s.display_name,s.first_name,s.last_name,
        s.date_of_birth,s.birth_place,c.country_id AS birth_country_id
 FROM motogp_source.riders AS s
 LEFT JOIN dbo.countries AS c ON c.country_code=s.birth_country_code
 WHERE s.rider_id IS NULL
   AND s.identity_review_required=0 AND s.participation_review_required=0
) AS incoming ON 1=0
WHEN NOT MATCHED THEN
 INSERT (display_name,first_name,last_name,date_of_birth,birth_place,birth_country_id)
 VALUES (incoming.display_name,incoming.first_name,incoming.last_name,
         incoming.date_of_birth,incoming.birth_place,incoming.birth_country_id)
OUTPUT incoming.source_rider_uuid,inserted.rider_id
INTO @new_riders (source_rider_uuid,rider_id);

UPDATE s SET rider_id=n.rider_id
FROM motogp_source.riders AS s
JOIN @new_riders AS n ON n.source_rider_uuid=s.source_rider_uuid;

'''
sql+=seed('motogp_source.rider_seasons',seasons,list(seasons[0]),['source_rider_uuid','season','class_name'])
sql+='''
COMMIT TRANSACTION;
SELECT COUNT(*) AS new_riders_added FROM @new_riders;
SELECT COUNT(*) AS source_riders,
       COUNT(date_of_birth) AS with_date_of_birth,
       COUNT(birth_place) AS with_birth_place
FROM motogp_source.riders;
SELECT COUNT(*) AS source_season_class_records FROM motogp_source.rider_seasons;
SELECT display_name,motogp_legacy_id,identity_review_required,participation_review_required
FROM motogp_source.riders WHERE rider_id IS NULL ORDER BY display_name;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
'''
(OUT/'08_import_riders.sql').write_text(sql,encoding='utf-8-sig')
(OUT/'09_explore_riders.sql').write_text('''USE MotoGP;
GO
-- Rider details plus the nationality label currently reported by the archive.
SELECT r.rider_id,r.display_name,r.first_name,r.last_name,r.date_of_birth,
       r.birth_place,b.country_name AS source_reported_birth_country,
       n.country_name AS source_reported_nationality,s.motogp_legacy_id
FROM dbo.riders AS r
JOIN motogp_source.riders AS s ON s.rider_id=r.rider_id
LEFT JOIN dbo.countries AS b ON b.country_id=r.birth_country_id
LEFT JOIN dbo.countries AS n ON n.country_code=s.profile_country_code
ORDER BY r.last_name,r.first_name;

-- Classes in which the source lists each rider (not a count of race starts).
SELECT DISTINCT r.display_name,s.class_name
FROM motogp_source.rider_seasons AS s
JOIN motogp_source.riders AS p ON p.source_rider_uuid=s.source_rider_uuid
JOIN dbo.riders AS r ON r.rider_id=p.rider_id
ORDER BY r.display_name,s.class_name;

-- Season number observations; these do not prove the number at every race.
SELECT r.display_name,s.season,s.class_name,s.rider_number,s.sponsored_team_name
FROM motogp_source.rider_seasons AS s
JOIN motogp_source.riders AS p ON p.source_rider_uuid=s.source_rider_uuid
JOIN dbo.riders AS r ON r.rider_id=p.rider_id
WHERE s.rider_number IS NOT NULL
ORDER BY r.display_name,s.season,s.class_name;

-- A practical data-quality exercise: find missing biographical information.
SELECT rider_id,display_name,date_of_birth,birth_place
FROM dbo.riders
WHERE date_of_birth IS NULL OR birth_place IS NULL
ORDER BY display_name;
''',encoding='utf-8-sig')
print('SQL bytes',len(sql.encode('utf-8')))
