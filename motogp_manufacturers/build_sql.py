import pathlib,json
OUT=pathlib.Path(__file__).resolve().parent
def load(n):return json.loads((OUT/(n+'.json')).read_text())
def val(v):
 if v is None:return 'NULL'
 if isinstance(v,bool):return str(int(v))
 if isinstance(v,int):return str(v)
 return "N'"+v.replace("'","''")+"'"
def stage(table,rows,cols):
 out=[]
 for i in range(0,len(rows),300):
  out.append('INSERT INTO '+table+' ('+', '.join(cols)+') VALUES\n'+',\n'.join('('+', '.join(val(r.get(c)) for c in cols)+')' for r in rows[i:i+300])+';\n')
 return '\n'.join(out)
schema='''/* MotoGP manufacturer/team model. Compiled 2026-10-12.
Run this entire file in VS Code's SQL editor connected to SQL Server.
09_explore_riders.sql was optional; it is not a prerequisite.
Read README.md: archive coverage and team identity mappings are incomplete.
*/
USE MotoGP;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.countries',N'U') IS NULL OR OBJECT_ID(N'dbo.classes',N'U') IS NULL
 OR OBJECT_ID(N'dbo.class_groups',N'U') IS NULL
 THROW 50001,'Existing countries, classes and class_groups tables are required.',1;
IF SCHEMA_ID(N'motogp_source') IS NULL EXEC(N'CREATE SCHEMA motogp_source');

-- Append missing historical classes; existing class IDs and groups are preserved.
INSERT INTO dbo.class_groups(group_name)
SELECT v.group_name FROM (VALUES(N'Historic 350cc'),(N'50cc / 80cc'),(N'Electric')) v(group_name)
WHERE NOT EXISTS(SELECT 1 FROM dbo.class_groups g WHERE g.group_name=v.group_name);
INSERT INTO dbo.classes(class_name,class_group_id,first_season,last_season)
SELECT v.class_name,g.class_group_id,v.first_season,v.last_season
FROM (VALUES(N'350cc',N'Historic 350cc',1949,1982),
 (N'50cc',N'50cc / 80cc',1962,1983),(N'80cc',N'50cc / 80cc',1984,1989),
 (N'MotoE',N'Electric',2019,2025)) v(class_name,group_name,first_season,last_season)
JOIN dbo.class_groups g ON g.group_name=v.group_name
WHERE NOT EXISTS(SELECT 1 FROM dbo.classes c WHERE c.class_name=v.class_name);

IF OBJECT_ID(N'dbo.seasons',N'U') IS NULL
CREATE TABLE dbo.seasons(season_year SMALLINT NOT NULL PRIMARY KEY,
 CONSTRAINT CK_seasons_year CHECK(season_year>=1949));
IF OBJECT_ID(N'dbo.manufacturers',N'U') IS NULL
CREATE TABLE dbo.manufacturers(
 manufacturer_id INT IDENTITY PRIMARY KEY,
 manufacturer_key VARCHAR(80) NOT NULL UNIQUE,
 manufacturer_name NVARCHAR(150) NOT NULL,
 country_id INT NULL REFERENCES dbo.countries(country_id),
 source_url NVARCHAR(1000) NOT NULL);
IF OBJECT_ID(N'dbo.constructors',N'U') IS NULL
CREATE TABLE dbo.constructors(
 constructor_id INT IDENTITY PRIMARY KEY,
 constructor_key VARCHAR(40) NOT NULL UNIQUE,
 constructor_name NVARCHAR(150) NOT NULL,
 manufacturer_id INT NULL REFERENCES dbo.manufacturers(manufacturer_id));
IF OBJECT_ID(N'dbo.teams',N'U') IS NULL
CREATE TABLE dbo.teams(
 team_id INT IDENTITY PRIMARY KEY,team_key VARCHAR(80) NOT NULL UNIQUE,
 team_name NVARCHAR(150) NOT NULL,country_id INT NULL REFERENCES dbo.countries(country_id));
IF OBJECT_ID(N'dbo.team_seasons',N'U') IS NULL
CREATE TABLE dbo.team_seasons(
 team_season_id INT IDENTITY PRIMARY KEY,
 team_season_key VARCHAR(120) NOT NULL UNIQUE,
 team_id INT NOT NULL REFERENCES dbo.teams(team_id),
 season_year SMALLINT NOT NULL REFERENCES dbo.seasons(season_year),
 class_id INT NOT NULL REFERENCES dbo.classes(class_id),
 entry_status VARCHAR(20) NOT NULL,
 status_source_url NVARCHAR(1000) NULL,
 CONSTRAINT UQ_team_seasons UNIQUE(team_id,season_year,class_id),
 CONSTRAINT CK_team_seasons_status CHECK(entry_status IN ('FACTORY','INDEPENDENT','UNKNOWN')));
IF OBJECT_ID(N'dbo.team_season_names',N'U') IS NULL
CREATE TABLE dbo.team_season_names(
 name_key CHAR(64) NOT NULL PRIMARY KEY,
 team_season_id INT NOT NULL REFERENCES dbo.team_seasons(team_season_id),
 entry_name NVARCHAR(250) NOT NULL,source_url NVARCHAR(1000) NOT NULL);
IF OBJECT_ID(N'dbo.team_season_constructors',N'U') IS NULL
CREATE TABLE dbo.team_season_constructors(
 team_season_id INT NOT NULL REFERENCES dbo.team_seasons(team_season_id),
 constructor_id INT NOT NULL REFERENCES dbo.constructors(constructor_id),
 support_level VARCHAR(30) NOT NULL,
 support_source_url NVARCHAR(1000) NULL,
 source_url NVARCHAR(1000) NOT NULL,
 CONSTRAINT PK_team_season_constructors PRIMARY KEY(team_season_id,constructor_id),
 CONSTRAINT CK_team_constructor_support CHECK(support_level IN ('FACTORY_SUPPORTED','CUSTOMER','UNKNOWN')));
IF OBJECT_ID(N'dbo.class_season_suppliers',N'U') IS NULL
CREATE TABLE dbo.class_season_suppliers(
 season_year SMALLINT NOT NULL REFERENCES dbo.seasons(season_year),
 class_id INT NOT NULL REFERENCES dbo.classes(class_id),
 supply_role VARCHAR(30) NOT NULL,
 manufacturer_id INT NOT NULL REFERENCES dbo.manufacturers(manufacturer_id),
 source_url NVARCHAR(1000) NOT NULL,
 CONSTRAINT PK_class_season_suppliers PRIMARY KEY(season_year,class_id,supply_role),
 CONSTRAINT CK_class_supplier_role CHECK(supply_role IN ('ENGINE','COMPLETE_MOTORCYCLE')));

-- Source layer preserves original names, placeholders and unresolved mappings.
IF OBJECT_ID(N'motogp_source.constructor_labels',N'U') IS NULL
CREATE TABLE motogp_source.constructor_labels(
 constructor_key VARCHAR(40) NOT NULL PRIMARY KEY,
 source_name NVARCHAR(150) NOT NULL,source_legacy_id INT NULL,
 source_uuid UNIQUEIDENTIFIER NULL,review_required BIT NOT NULL,
 first_observed_season SMALLINT NOT NULL,last_observed_season SMALLINT NOT NULL,
 constructor_id INT NULL REFERENCES dbo.constructors(constructor_id),
 source_url NVARCHAR(1000) NOT NULL);
IF OBJECT_ID(N'motogp_source.team_labels',N'U') IS NULL
CREATE TABLE motogp_source.team_labels(label_key CHAR(64) NOT NULL PRIMARY KEY,
 source_name NVARCHAR(250) NOT NULL);
IF OBJECT_ID(N'motogp_source.team_mappings',N'U') IS NULL
CREATE TABLE motogp_source.team_mappings(
 label_key CHAR(64) NOT NULL REFERENCES motogp_source.team_labels(label_key),
 season_year SMALLINT NOT NULL REFERENCES dbo.seasons(season_year),
 class_id INT NOT NULL REFERENCES dbo.classes(class_id),
 team_id INT NULL REFERENCES dbo.teams(team_id),mapping_status VARCHAR(30) NOT NULL,
 evidence_url NVARCHAR(1000) NOT NULL,
 CONSTRAINT PK_source_team_mappings PRIMARY KEY(label_key,season_year,class_id));
IF OBJECT_ID(N'motogp_source.team_constructor_observations',N'U') IS NULL
CREATE TABLE motogp_source.team_constructor_observations(
 observation_key CHAR(64) NOT NULL PRIMARY KEY,
 season_year SMALLINT NOT NULL REFERENCES dbo.seasons(season_year),
 class_id INT NOT NULL REFERENCES dbo.classes(class_id),
 evidence_type VARCHAR(20) NOT NULL,rider_legacy_id INT NULL,
 source_team_uuid UNIQUEIDENTIFIER NULL,
 team_label_key CHAR(64) NULL REFERENCES motogp_source.team_labels(label_key),
 constructor_key VARCHAR(40) NULL REFERENCES motogp_source.constructor_labels(constructor_key),
 source_url NVARCHAR(1000) NOT NULL,retrieved_at DATE NOT NULL);
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
'''
(OUT/'10_create_manufacturer_team_tables.sql').write_text(schema,encoding='utf-8-sig')
sql='''/* Fixed research snapshot. Run after 10_create_manufacturer_team_tables.sql.
Inserts absent keys; preserves existing IDs, mappings and manual edits.
Run a single copy at a time. All changes roll back on failure. */
USE MotoGP;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DROP TABLE IF EXISTS #manufacturers,#constructors,#teams,#team_seasons,#names,#links,#suppliers,#labels,#mappings,#observations;
BEGIN TRY
BEGIN TRANSACTION;
CREATE TABLE #manufacturers(manufacturer_key VARCHAR(80) PRIMARY KEY,manufacturer_name NVARCHAR(150),country_code CHAR(3),source_url NVARCHAR(1000));
CREATE TABLE #constructors(constructor_key VARCHAR(40) PRIMARY KEY,constructor_name NVARCHAR(150),source_legacy_id INT,source_uuid UNIQUEIDENTIFIER,manufacturer_key VARCHAR(80),review_required BIT,first_observed_season SMALLINT,last_observed_season SMALLINT,source_url NVARCHAR(1000));
CREATE TABLE #teams(team_key VARCHAR(80) PRIMARY KEY,team_name NVARCHAR(150),country_code CHAR(3));
CREATE TABLE #team_seasons(team_season_key VARCHAR(120) PRIMARY KEY,team_key VARCHAR(80),season_year SMALLINT,class_name NVARCHAR(50),entry_status VARCHAR(20),status_source_url NVARCHAR(1000));
CREATE TABLE #names(name_key CHAR(64) PRIMARY KEY,team_season_key VARCHAR(120),entry_name NVARCHAR(250),source_url NVARCHAR(1000));
CREATE TABLE #links(team_season_key VARCHAR(120),constructor_key VARCHAR(40),support_level VARCHAR(30),support_source_url NVARCHAR(1000),source_url NVARCHAR(1000),PRIMARY KEY(team_season_key,constructor_key));
CREATE TABLE #suppliers(season_year SMALLINT,class_name NVARCHAR(50),supply_role VARCHAR(30),manufacturer_key VARCHAR(80),source_url NVARCHAR(1000),PRIMARY KEY(season_year,class_name,supply_role));
CREATE TABLE #labels(label_key CHAR(64) PRIMARY KEY,source_name NVARCHAR(250));
CREATE TABLE #mappings(label_key CHAR(64),season_year SMALLINT,class_name NVARCHAR(50),team_key VARCHAR(80),mapping_status VARCHAR(30),evidence_url NVARCHAR(1000),PRIMARY KEY(label_key,season_year,class_name));
CREATE TABLE #observations(observation_key CHAR(64) PRIMARY KEY,season_year SMALLINT,class_name NVARCHAR(50),evidence_type VARCHAR(20),rider_legacy_id INT,source_team_uuid UNIQUEIDENTIFIER,team_label_key CHAR(64),constructor_key VARCHAR(40),source_url NVARCHAR(1000),retrieved_at DATE);
'''
specs=[('manufacturers','#manufacturers',['manufacturer_key','manufacturer_name','country_code','source_url']),('constructors','#constructors',['constructor_key','constructor_name','source_legacy_id','source_uuid','manufacturer_key','review_required','first_observed_season','last_observed_season','source_url']),('teams','#teams',['team_key','team_name','country_code']),('team_seasons','#team_seasons',['team_season_key','team_key','season_year','class_name','entry_status','status_source_url']),('team_season_names','#names',['name_key','team_season_key','entry_name','source_url']),('team_season_constructors','#links',['team_season_key','constructor_key','support_level','support_source_url','source_url']),('class_season_suppliers','#suppliers',['season_year','class_name','supply_role','manufacturer_key','source_url']),('team_labels','#labels',['label_key','source_name']),('team_mappings','#mappings',['label_key','season_year','class_name','team_key','mapping_status','evidence_url']),('observations','#observations',['observation_key','season_year','class_name','evidence_type','rider_legacy_id','source_team_uuid','team_label_key','constructor_key','source_url','retrieved_at'])]
for name,table,cols in specs:
 rows=load(name)
 if name=='constructors':rows=[dict(r,source_url=r['source_urls'][0]) for r in rows]
 sql+=stage(table,rows,cols)
sql+='''
IF EXISTS(SELECT class_name FROM #observations EXCEPT SELECT class_name FROM dbo.classes)
 THROW 50002,'A source class is missing. Run script 10 and check existing class names.',1;
IF EXISTS(SELECT 1 FROM #manufacturers m LEFT JOIN dbo.countries c ON c.country_code=m.country_code WHERE m.country_code IS NOT NULL AND c.country_id IS NULL)
 THROW 50003,'A manufacturer country code is missing.',1;
IF EXISTS(SELECT 1 FROM #teams t LEFT JOIN dbo.countries c ON c.country_code=t.country_code WHERE t.country_code IS NOT NULL AND c.country_id IS NULL)
 THROW 50004,'A team country code is missing.',1;

DECLARE @yr SMALLINT=1949;
WHILE @yr<=2026
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.seasons WHERE season_year=@yr)
 INSERT INTO dbo.seasons(season_year) VALUES(@yr);
 SET @yr=@yr+1;
END;
INSERT INTO dbo.manufacturers(manufacturer_key,manufacturer_name,country_id,source_url)
SELECT s.manufacturer_key,s.manufacturer_name,c.country_id,s.source_url FROM #manufacturers s
LEFT JOIN dbo.countries c ON c.country_code=s.country_code
WHERE NOT EXISTS(SELECT 1 FROM dbo.manufacturers d WHERE d.manufacturer_key=s.manufacturer_key);
INSERT INTO dbo.constructors(constructor_key,constructor_name,manufacturer_id)
SELECT s.constructor_key,s.constructor_name,m.manufacturer_id FROM #constructors s
LEFT JOIN dbo.manufacturers m ON m.manufacturer_key=s.manufacturer_key
WHERE s.review_required=0 AND NOT EXISTS(SELECT 1 FROM dbo.constructors d WHERE d.constructor_key=s.constructor_key);
INSERT INTO dbo.teams(team_key,team_name,country_id)
SELECT s.team_key,s.team_name,c.country_id FROM #teams s
LEFT JOIN dbo.countries c ON c.country_code=s.country_code
WHERE NOT EXISTS(SELECT 1 FROM dbo.teams d WHERE d.team_key=s.team_key);
INSERT INTO dbo.team_seasons(team_season_key,team_id,season_year,class_id,entry_status,status_source_url)
SELECT s.team_season_key,t.team_id,s.season_year,c.class_id,s.entry_status,s.status_source_url
FROM #team_seasons s JOIN dbo.teams t ON t.team_key=s.team_key JOIN dbo.classes c ON c.class_name=s.class_name
WHERE NOT EXISTS(SELECT 1 FROM dbo.team_seasons d WHERE d.team_id=t.team_id AND d.season_year=s.season_year AND d.class_id=c.class_id);
-- Existing natural keys must use the package's stable import keys.
IF EXISTS(SELECT 1 FROM #team_seasons s LEFT JOIN dbo.team_seasons t ON t.team_season_key=s.team_season_key WHERE t.team_season_id IS NULL)
 THROW 50005,'An existing team/season/class row uses a different import key. Reconcile it before importing.',1;
INSERT INTO dbo.team_season_names(name_key,team_season_id,entry_name,source_url)
SELECT s.name_key,t.team_season_id,s.entry_name,s.source_url FROM #names s
JOIN dbo.team_seasons t ON t.team_season_key=s.team_season_key
WHERE NOT EXISTS(SELECT 1 FROM dbo.team_season_names d WHERE d.name_key=s.name_key);
INSERT INTO dbo.team_season_constructors(team_season_id,constructor_id,support_level,support_source_url,source_url)
SELECT t.team_season_id,c.constructor_id,s.support_level,s.support_source_url,s.source_url FROM #links s
JOIN dbo.team_seasons t ON t.team_season_key=s.team_season_key JOIN dbo.constructors c ON c.constructor_key=s.constructor_key
WHERE NOT EXISTS(SELECT 1 FROM dbo.team_season_constructors d WHERE d.team_season_id=t.team_season_id AND d.constructor_id=c.constructor_id);
INSERT INTO dbo.class_season_suppliers(season_year,class_id,supply_role,manufacturer_id,source_url)
SELECT s.season_year,c.class_id,s.supply_role,m.manufacturer_id,s.source_url FROM #suppliers s
JOIN dbo.classes c ON c.class_name=s.class_name JOIN dbo.manufacturers m ON m.manufacturer_key=s.manufacturer_key
WHERE NOT EXISTS(SELECT 1 FROM dbo.class_season_suppliers d WHERE d.season_year=s.season_year AND d.class_id=c.class_id AND d.supply_role=s.supply_role);
INSERT INTO motogp_source.constructor_labels(constructor_key,source_name,source_legacy_id,source_uuid,review_required,first_observed_season,last_observed_season,constructor_id,source_url)
SELECT s.constructor_key,s.constructor_name,s.source_legacy_id,s.source_uuid,s.review_required,s.first_observed_season,s.last_observed_season,c.constructor_id,s.source_url
FROM #constructors s LEFT JOIN dbo.constructors c ON c.constructor_key=s.constructor_key
WHERE NOT EXISTS(SELECT 1 FROM motogp_source.constructor_labels d WHERE d.constructor_key=s.constructor_key);
INSERT INTO motogp_source.team_labels(label_key,source_name)
SELECT s.label_key,s.source_name FROM #labels s WHERE NOT EXISTS(SELECT 1 FROM motogp_source.team_labels d WHERE d.label_key=s.label_key);
INSERT INTO motogp_source.team_mappings(label_key,season_year,class_id,team_id,mapping_status,evidence_url)
SELECT s.label_key,s.season_year,c.class_id,t.team_id,s.mapping_status,s.evidence_url
FROM #mappings s JOIN dbo.classes c ON c.class_name=s.class_name LEFT JOIN dbo.teams t ON t.team_key=s.team_key
WHERE NOT EXISTS(SELECT 1 FROM motogp_source.team_mappings d WHERE d.label_key=s.label_key AND d.season_year=s.season_year AND d.class_id=c.class_id);
INSERT INTO motogp_source.team_constructor_observations(observation_key,season_year,class_id,evidence_type,rider_legacy_id,source_team_uuid,team_label_key,constructor_key,source_url,retrieved_at)
SELECT s.observation_key,s.season_year,c.class_id,s.evidence_type,s.rider_legacy_id,s.source_team_uuid,s.team_label_key,s.constructor_key,s.source_url,s.retrieved_at
FROM #observations s JOIN dbo.classes c ON c.class_name=s.class_name
WHERE NOT EXISTS(SELECT 1 FROM motogp_source.team_constructor_observations d WHERE d.observation_key=s.observation_key);
COMMIT TRANSACTION;
SELECT 'manufacturers' AS table_name,COUNT(*) AS row_count FROM dbo.manufacturers
UNION ALL SELECT 'constructors',COUNT(*) FROM dbo.constructors
UNION ALL SELECT 'teams',COUNT(*) FROM dbo.teams
UNION ALL SELECT 'team_seasons',COUNT(*) FROM dbo.team_seasons
UNION ALL SELECT 'team_season_constructors',COUNT(*) FROM dbo.team_season_constructors
UNION ALL SELECT 'source_observations',COUNT(*) FROM motogp_source.team_constructor_observations;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
DROP TABLE IF EXISTS #manufacturers,#constructors,#teams,#team_seasons,#names,#links,#suppliers,#labels,#mappings,#observations;
GO
'''
(OUT/'11_import_manufacturers_and_teams.sql').write_text(sql,encoding='utf-8-sig')
print('Wrote schema and seed',len(sql.encode()),'bytes')
