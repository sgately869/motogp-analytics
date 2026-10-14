/* MotoGP manufacturer/team model. Compiled 2026-10-12.
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
