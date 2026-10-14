/* Run after 13_create_season_classes.sql. SQL Server, database MotoGP.
   One event can visit a venue already used that year; one event/class can
   have several scoring races. Restart sessions are NOT extra scoring races.
   Source keys make imports repeatable without guessing local identity IDs.
*/
USE MotoGP;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.season_classes',N'U') IS NULL
 THROW 50001,'Run scripts 07, 08, 10, 11 and 13 before this package.',1;

IF OBJECT_ID(N'dbo.events',N'U') IS NULL
CREATE TABLE dbo.events(
 event_id INT IDENTITY PRIMARY KEY,
 source_event_uuid UNIQUEIDENTIFIER NOT NULL UNIQUE,
 season_year SMALLINT NOT NULL REFERENCES dbo.seasons(season_year),
 event_name NVARCHAR(250) NOT NULL,
 short_name NVARCHAR(20) NOT NULL,
 circuit_id INT NULL REFERENCES dbo.circuits(circuit_id),
 date_start DATE NOT NULL,date_end DATE NOT NULL,
 event_status VARCHAR(25) NOT NULL CHECK(event_status IN('CONCLUDED','SCHEDULED','RACES_CANCELLED','UNKNOWN')),
 source_status NVARCHAR(50) NULL,
 source_country_code NVARCHAR(20) NULL,
 source_url NVARCHAR(1000) NOT NULL,
 venue_evidence_url NVARCHAR(1000) NOT NULL,
 CONSTRAINT UQ_events_season UNIQUE(event_id,season_year),
 CHECK(date_end>=date_start)
);
IF OBJECT_ID(N'dbo.event_classes',N'U') IS NULL
CREATE TABLE dbo.event_classes(
 event_class_id INT IDENTITY PRIMARY KEY,
 event_id INT NOT NULL,season_year SMALLINT NOT NULL,class_id INT NOT NULL,
 circuit_id INT NOT NULL REFERENCES dbo.circuits(circuit_id),
 source_url NVARCHAR(1000) NOT NULL,
 venue_evidence_url NVARCHAR(1000) NOT NULL,
 CONSTRAINT UQ_event_classes UNIQUE(event_id,class_id),
 FOREIGN KEY(event_id,season_year) REFERENCES dbo.events(event_id,season_year),
 FOREIGN KEY(season_year,class_id) REFERENCES dbo.season_classes(season_year,class_id)
);
IF OBJECT_ID(N'dbo.result_statuses',N'U') IS NULL
CREATE TABLE dbo.result_statuses(
 result_status_code VARCHAR(20) PRIMARY KEY,
 status_description NVARCHAR(200) NOT NULL
);
INSERT INTO dbo.result_statuses(result_status_code,status_description)
SELECT v.code,v.description FROM (VALUES
 ('CLASSIFIED',N'Officially classified; position stored separately'),
 ('DNF',N'Did not finish, including explicit retirement or failure to finish first lap'),
 ('NC',N'Not classified; does not by itself establish cause or retirement'),
 ('DNS',N'Did not start this session; a rider may have started an earlier race part'),
 ('DSQ',N'Disqualified'),('EXCLUDED',N'Explicit source exclusion'),
 ('NO_RESTART',N'Not on restart grid; do not infer that the rider never started the race'),
 ('UNKNOWN',N'Unresolved source outcome')) v(code,description)
WHERE NOT EXISTS(SELECT 1 FROM dbo.result_statuses s WHERE s.result_status_code=v.code);

IF OBJECT_ID(N'dbo.races',N'U') IS NULL
CREATE TABLE dbo.races(
 race_id INT IDENTITY PRIMARY KEY,race_key VARCHAR(100) NOT NULL UNIQUE,
 event_class_id INT NOT NULL REFERENCES dbo.event_classes(event_class_id),
 race_type VARCHAR(10) NOT NULL CHECK(race_type IN('GP','SPRINT','RACE')),
 race_number SMALLINT NOT NULL CHECK(race_number>0),
 race_date DATE NULL,
 race_status VARCHAR(20) NOT NULL CHECK(race_status IN('HELD','CANCELLED','SCHEDULED','REVIEW')),
 selection_note NVARCHAR(500) NOT NULL,
 selection_evidence_url NVARCHAR(1000) NULL,
 CONSTRAINT UQ_races_event_class UNIQUE(event_class_id,race_type,race_number)
);
IF OBJECT_ID(N'motogp_source.race_sessions',N'U') IS NULL
CREATE TABLE motogp_source.race_sessions(
 source_session_uuid UNIQUEIDENTIFIER PRIMARY KEY,
 race_id INT NOT NULL REFERENCES dbo.races(race_id),
 source_type NVARCHAR(20) NOT NULL,source_number SMALLINT NULL,
 source_date NVARCHAR(50) NULL,source_status NVARCHAR(50) NULL,
 selected_for_statistics BIT NOT NULL,
 source_url NVARCHAR(1000) NOT NULL,pdf_url NVARCHAR(1000) NULL,
 CONSTRAINT UQ_race_sessions_race UNIQUE(source_session_uuid,race_id)
);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'motogp_source.race_sessions') AND name=N'UX_selected_race_session')
CREATE UNIQUE INDEX UX_selected_race_session ON motogp_source.race_sessions(race_id) WHERE selected_for_statistics=1;

IF OBJECT_ID(N'dbo.race_entries',N'U') IS NULL
CREATE TABLE dbo.race_entries(
 race_entry_id INT IDENTITY PRIMARY KEY,
 race_id INT NOT NULL REFERENCES dbo.races(race_id),
 source_rider_key VARCHAR(60) NOT NULL,
 rider_id INT NULL REFERENCES dbo.riders(rider_id),
 source_rider_legacy_id INT NULL,source_rider_uuid UNIQUEIDENTIFIER NULL,
 source_rider_name NVARCHAR(200) NOT NULL,
 rider_number SMALLINT NULL,
 team_season_id INT NULL REFERENCES dbo.team_seasons(team_season_id),
 constructor_id INT NULL REFERENCES dbo.constructors(constructor_id),
 source_team_name NVARCHAR(250) NULL,source_constructor_name NVARCHAR(150) NULL,
 source_country_code NVARCHAR(20) NULL,
 entry_status VARCHAR(20) NOT NULL DEFAULT 'OBSERVED' CHECK(entry_status IN('OBSERVED','ENTERED','DNQ','WITHDRAWN','UNKNOWN')),
 source_url NVARCHAR(1000) NOT NULL,
 CONSTRAINT UQ_race_entries_rider UNIQUE(race_id,source_rider_key),
 CONSTRAINT UQ_race_entries_race UNIQUE(race_entry_id,race_id)
);
IF OBJECT_ID(N'dbo.race_result_sets',N'U') IS NULL
CREATE TABLE dbo.race_result_sets(
 result_set_key CHAR(64) PRIMARY KEY,
 race_id INT NOT NULL,
 source_session_uuid UNIQUEIDENTIFIER NOT NULL,
 retrieved_at DATE NOT NULL,
 is_current BIT NOT NULL,
 source_url NVARCHAR(1000) NOT NULL,
 points_state VARCHAR(30) NOT NULL CHECK(points_state IN('SOURCE_REPORTED','VERIFIED_PDF','UNRESOLVED')),
 completeness_note NVARCHAR(500) NOT NULL,
 FOREIGN KEY(source_session_uuid,race_id) REFERENCES motogp_source.race_sessions(source_session_uuid,race_id),
 CONSTRAINT UQ_race_result_sets_race UNIQUE(result_set_key,race_id)
);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.race_result_sets') AND name=N'UX_current_result_set')
CREATE UNIQUE INDEX UX_current_result_set ON dbo.race_result_sets(source_session_uuid) WHERE is_current=1;

IF OBJECT_ID(N'dbo.race_results',N'U') IS NULL
CREATE TABLE dbo.race_results(
 result_set_key CHAR(64) NOT NULL,race_entry_id INT NOT NULL,race_id INT NOT NULL,
 classified_position SMALLINT NULL CHECK(classified_position>0),
 result_status_code VARCHAR(20) NOT NULL REFERENCES dbo.result_statuses(result_status_code),
 source_status NVARCHAR(50) NULL,
 started_session BIT NULL,
 laps_completed SMALLINT NULL CHECK(laps_completed>=0),
 elapsed_seconds DECIMAL(14,3) NULL CHECK(elapsed_seconds>=0),
 source_time NVARCHAR(100) NULL,source_gap NVARCHAR(100) NULL,
 source_points DECIMAL(10,3) NULL,
 official_points_awarded DECIMAL(10,3) NULL CHECK(official_points_awarded>=0),
 result_reason NVARCHAR(250) NULL,
 PRIMARY KEY(result_set_key,race_entry_id),
 FOREIGN KEY(result_set_key,race_id) REFERENCES dbo.race_result_sets(result_set_key,race_id),
 FOREIGN KEY(race_entry_id,race_id) REFERENCES dbo.race_entries(race_entry_id,race_id),
 CHECK((result_status_code='CLASSIFIED' AND classified_position IS NOT NULL)
    OR (result_status_code<>'CLASSIFIED' AND classified_position IS NULL))
);

-- Championship participants are separate from race entries. Team championship
-- entrants must not be inferred by adding all squads of one team organisation.
IF OBJECT_ID(N'dbo.championships',N'U') IS NULL
CREATE TABLE dbo.championships(
 championship_id INT IDENTITY PRIMARY KEY,
 championship_key VARCHAR(80) NOT NULL UNIQUE,
 season_year SMALLINT NOT NULL,class_id INT NOT NULL,
 championship_type VARCHAR(15) NOT NULL CHECK(championship_type IN('RIDER','TEAM','CONSTRUCTOR')),
 UNIQUE(season_year,class_id,championship_type),
 FOREIGN KEY(season_year,class_id) REFERENCES dbo.season_classes(season_year,class_id)
);
IF OBJECT_ID(N'dbo.championship_entries',N'U') IS NULL
CREATE TABLE dbo.championship_entries(
 championship_entry_id INT IDENTITY PRIMARY KEY,
 championship_id INT NOT NULL REFERENCES dbo.championships(championship_id),
 source_competitor_key VARCHAR(100) NOT NULL,
 source_competitor_name NVARCHAR(250) NOT NULL,
 rider_id INT NULL REFERENCES dbo.riders(rider_id),
 constructor_id INT NULL REFERENCES dbo.constructors(constructor_id),
 team_id INT NULL REFERENCES dbo.teams(team_id),
 CHECK((CASE WHEN rider_id IS NULL THEN 0 ELSE 1 END
       +CASE WHEN constructor_id IS NULL THEN 0 ELSE 1 END
       +CASE WHEN team_id IS NULL THEN 0 ELSE 1 END)<=1),
 UNIQUE(championship_id,source_competitor_key),
 CONSTRAINT UQ_championship_entries_champ UNIQUE(championship_entry_id,championship_id)
);
IF OBJECT_ID(N'dbo.championship_standing_snapshots',N'U') IS NULL
CREATE TABLE dbo.championship_standing_snapshots(
 snapshot_key CHAR(64) PRIMARY KEY,
 championship_id INT NOT NULL REFERENCES dbo.championships(championship_id),
 retrieved_at DATE NOT NULL,
 through_race_id INT NULL REFERENCES dbo.races(race_id),
 is_current BIT NOT NULL,
 source_url NVARCHAR(1000) NOT NULL,
 coverage_note NVARCHAR(500) NOT NULL,
 CONSTRAINT UQ_standing_snapshots_champ UNIQUE(snapshot_key,championship_id)
);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.championship_standing_snapshots') AND name=N'UX_current_standings')
CREATE UNIQUE INDEX UX_current_standings ON dbo.championship_standing_snapshots(championship_id) WHERE is_current=1;
IF OBJECT_ID(N'dbo.championship_standings',N'U') IS NULL
CREATE TABLE dbo.championship_standings(
 snapshot_key CHAR(64) NOT NULL,championship_id INT NOT NULL,championship_entry_id INT NOT NULL,
 official_position SMALLINT NULL CHECK(official_position>0),official_points DECIMAL(10,3) NULL,
 PRIMARY KEY(snapshot_key,championship_entry_id),
 FOREIGN KEY(snapshot_key,championship_id) REFERENCES dbo.championship_standing_snapshots(snapshot_key,championship_id),
 FOREIGN KEY(championship_entry_id,championship_id) REFERENCES dbo.championship_entries(championship_entry_id,championship_id)
);
IF OBJECT_ID(N'dbo.penalties',N'U') IS NULL
CREATE TABLE dbo.penalties(
 penalty_id INT IDENTITY PRIMARY KEY,penalty_key VARCHAR(100) NOT NULL UNIQUE,
 championship_entry_id INT NOT NULL REFERENCES dbo.championship_entries(championship_entry_id),
 race_id INT NULL REFERENCES dbo.races(race_id),
 decision_date DATE NOT NULL,penalty_type VARCHAR(30) NOT NULL,
 decision_status VARCHAR(20) NOT NULL CHECK(decision_status IN('APPLIED','UNDER_APPEAL','OVERTURNED','SUPERSEDED')),
 decision_summary NVARCHAR(1000) NOT NULL,source_url NVARCHAR(1000) NOT NULL,
 CONSTRAINT UQ_penalties_recipient UNIQUE(penalty_id,championship_entry_id)
);
IF OBJECT_ID(N'dbo.championship_points_adjustments',N'U') IS NULL
CREATE TABLE dbo.championship_points_adjustments(
 adjustment_id INT IDENTITY PRIMARY KEY,adjustment_key VARCHAR(100) NOT NULL UNIQUE,
 championship_entry_id INT NOT NULL,
 penalty_id INT NULL,
 points_delta DECIMAL(10,3) NOT NULL CHECK(points_delta<>0),
 effective_date DATE NOT NULL,
 adjustment_status VARCHAR(20) NOT NULL CHECK(adjustment_status IN('APPLIED','REVERSED')),
 reflected_in_race_points BIT NOT NULL,
 reason NVARCHAR(1000) NOT NULL,source_url NVARCHAR(1000) NOT NULL,
 FOREIGN KEY(championship_entry_id) REFERENCES dbo.championship_entries(championship_entry_id),
 FOREIGN KEY(penalty_id,championship_entry_id) REFERENCES dbo.penalties(penalty_id,championship_entry_id)
);
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
-- Cross-table checks that ordinary single-column foreign keys cannot express.
CREATE OR ALTER TRIGGER dbo.TR_race_entries_team_context
ON dbo.race_entries AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN dbo.races r ON r.race_id=i.race_id
 JOIN dbo.event_classes ec ON ec.event_class_id=r.event_class_id
 JOIN dbo.team_seasons ts ON ts.team_season_id=i.team_season_id
 WHERE ts.season_year<>ec.season_year OR ts.class_id<>ec.class_id)
 THROW 50020,'Team-season must match the race season and class.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_championship_entries_type
ON dbo.championship_entries AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN dbo.championships ch ON ch.championship_id=i.championship_id
 WHERE (i.rider_id IS NOT NULL AND ch.championship_type<>'RIDER')
 OR (i.constructor_id IS NOT NULL AND ch.championship_type<>'CONSTRUCTOR')
 OR (i.team_id IS NOT NULL AND ch.championship_type<>'TEAM'))
 THROW 50021,'Competitor identity type does not match its championship.',1;
END;
GO
