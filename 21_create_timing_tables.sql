/* Additive extension: does not alter results, points, or the existing race session selection. */
USE MotoGP;
GO
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.event_classes',N'U') IS NULL OR OBJECT_ID(N'motogp_source.race_sessions',N'U') IS NULL
 THROW 50110,'Run calendar/results scripts 14-19 first.',1;
IF OBJECT_ID(N'dbo.timing_sessions',N'U') IS NULL
CREATE TABLE dbo.timing_sessions(
 sid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
 event_class_id INT NOT NULL REFERENCES dbo.event_classes(event_class_id),
 type VARCHAR(10) NOT NULL CHECK(type IN('Q','RAC','SPR')),
 number SMALLINT NULL CHECK(number>0),
 date NVARCHAR(50) NULL,
 status NVARCHAR(50) NULL,
 url NVARCHAR(1000) NOT NULL
);
IF OBJECT_ID(N'dbo.session_entries',N'U') IS NULL
CREATE TABLE dbo.session_entries(
 sid UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.timing_sessions(sid),
 [key] VARCHAR(60) NOT NULL,
 legacy_id INT NULL,uuid UNIQUEIDENTIFIER NULL,
 name NVARCHAR(200) NOT NULL,number SMALLINT NULL,
 rider_id INT NULL REFERENCES dbo.riders(rider_id),
 PRIMARY KEY(sid,[key])
);
IF OBJECT_ID(N'dbo.timing_revisions',N'U') IS NULL
CREATE TABLE dbo.timing_revisions(
 revision CHAR(64) NOT NULL PRIMARY KEY,
 sid UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.timing_sessions(sid),
 created_at NVARCHAR(50) NOT NULL,parser_version VARCHAR(20) NOT NULL,
 is_current BIT NOT NULL,
 UNIQUE(revision,sid)
);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.timing_revisions') AND name=N'UX_timing_current')
CREATE UNIQUE INDEX UX_timing_current ON dbo.timing_revisions(sid) WHERE is_current=1;
IF OBJECT_ID(N'dbo.timing_quality_issues',N'U') IS NULL
CREATE TABLE dbo.timing_quality_issues(
 [revision] CHAR(64) NOT NULL,
 [sid] UNIQUEIDENTIFIER NOT NULL,
 [issue_number] INT NOT NULL,
 [component] VARCHAR(40) NOT NULL,
 [reason] NVARCHAR(1000) NOT NULL,
 PRIMARY KEY([revision],[issue_number]),
 FOREIGN KEY(revision,sid) REFERENCES dbo.timing_revisions(revision,sid)
);
IF OBJECT_ID(N'dbo.timing_documents',N'U') IS NULL
CREATE TABLE dbo.timing_documents(
 [revision] CHAR(64) NOT NULL,
 [sid] UNIQUEIDENTIFIER NOT NULL,
 [kind] VARCHAR(30) NOT NULL,
 [url] NVARCHAR(1000) NULL,
 [sha256] CHAR(64) NULL,
 [retrieved_at] NVARCHAR(50) NULL,
 [parse_status] VARCHAR(25) NOT NULL,
 [row_count] INT NOT NULL,
 [note] NVARCHAR(1000) NULL,
 PRIMARY KEY([revision],[kind]),
 FOREIGN KEY(revision,sid) REFERENCES dbo.timing_revisions(revision,sid),
 CHECK(row_count>=0),
 CHECK(parse_status IN('PARSED','REVIEW','NOT_ADVERTISED','DOWNLOAD_FAILED'))
);
IF OBJECT_ID(N'dbo.session_results',N'U') IS NULL
CREATE TABLE dbo.session_results(
 [revision] CHAR(64) NOT NULL,
 [sid] UNIQUEIDENTIFIER NOT NULL,
 [key] VARCHAR(60) NOT NULL,
 [position] SMALLINT NULL,
 [source_status] NVARCHAR(50) NULL,
 [best_lap_seconds] DECIMAL(12,3) NULL,
 [best_lap_number] SMALLINT NULL,
 [total_laps] SMALLINT NULL,
 [top_speed_kmh] DECIMAL(7,3) NULL,
 [source_time] NVARCHAR(50) NULL,
 PRIMARY KEY([revision],[key]),
 FOREIGN KEY(revision,sid) REFERENCES dbo.timing_revisions(revision,sid),
 FOREIGN KEY(sid,[key]) REFERENCES dbo.session_entries(sid,[key]),
 CHECK([position]>0),
 CHECK([best_lap_seconds]>0),
 CHECK([best_lap_number]>0)
);
IF OBJECT_ID(N'dbo.session_lap_records',N'U') IS NULL
CREATE TABLE dbo.session_lap_records(
 [revision] CHAR(64) NOT NULL,
 [sid] UNIQUEIDENTIFIER NOT NULL,
 [key] VARCHAR(60) NOT NULL,
 [record_type] VARCHAR(30) NOT NULL,
 [record_year] SMALLINT NULL,
 [lap_number] SMALLINT NULL,
 [lap_time_seconds] DECIMAL(12,3) NULL,
 [is_new_record] BIT NULL,
 [source_time] NVARCHAR(50) NULL,
 PRIMARY KEY([revision],[record_type]),
 FOREIGN KEY(revision,sid) REFERENCES dbo.timing_revisions(revision,sid),
 FOREIGN KEY(sid,[key]) REFERENCES dbo.session_entries(sid,[key]),
 CHECK([lap_number]>0),
 CHECK([lap_time_seconds]>0)
);
IF OBJECT_ID(N'dbo.race_fastest_laps',N'U') IS NULL
CREATE TABLE dbo.race_fastest_laps(
 [revision] CHAR(64) NOT NULL,
 [sid] UNIQUEIDENTIFIER NOT NULL,
 [source_rider_key] VARCHAR(60) NOT NULL,
 [rider_number] SMALLINT NULL,
 [published_rank] SMALLINT NOT NULL,
 [best_lap_seconds] DECIMAL(12,3) NOT NULL,
 [best_lap_number] SMALLINT NOT NULL,
 [total_laps] SMALLINT NOT NULL,
 [source_text] NVARCHAR(1000) NULL,
 [page] SMALLINT NOT NULL,
 PRIMARY KEY([revision],[source_rider_key]),
 FOREIGN KEY(revision,sid) REFERENCES dbo.timing_revisions(revision,sid),
 FOREIGN KEY(sid,source_rider_key) REFERENCES dbo.session_entries(sid,[key]),
 CHECK([published_rank]>0),
 CHECK([best_lap_seconds]>0),
 CHECK([best_lap_number]>0),
 CHECK([page]>0),
 UNIQUE(revision,published_rank),
 CHECK(best_lap_number<=total_laps)
);
IF OBJECT_ID(N'dbo.race_grids',N'U') IS NULL
CREATE TABLE dbo.race_grids(
 [revision] CHAR(64) NOT NULL,
 [sid] UNIQUEIDENTIFIER NOT NULL,
 [source_rider_key] VARCHAR(60) NOT NULL,
 [rider_number] SMALLINT NULL,
 [grid_position] SMALLINT NOT NULL,
 [qualifying_time_seconds] DECIMAL(12,3) NULL,
 [grid_status] VARCHAR(20) NOT NULL,
 [source_text] NVARCHAR(1000) NULL,
 [page] SMALLINT NOT NULL,
 PRIMARY KEY([revision],[source_rider_key]),
 FOREIGN KEY(revision,sid) REFERENCES dbo.timing_revisions(revision,sid),
 FOREIGN KEY(sid,source_rider_key) REFERENCES dbo.session_entries(sid,[key]),
 CHECK([grid_position]>0),
 CHECK([qualifying_time_seconds]>0),
 CHECK([page]>0),
 UNIQUE(revision,grid_position),
 CHECK(grid_status IN('OFFICIAL','PROVISIONAL','PUBLISHED'))
);
IF OBJECT_ID(N'dbo.lap_times',N'U') IS NULL
CREATE TABLE dbo.lap_times(
 [revision] CHAR(64) NOT NULL,
 [sid] UNIQUEIDENTIFIER NOT NULL,
 [source_rider_key] VARCHAR(60) NOT NULL,
 [rider_number] SMALLINT NULL,
 [lap_number] SMALLINT NOT NULL,
 [lap_time_seconds] DECIMAL(12,3) NOT NULL,
 [lap_time_cancelled] BIT NOT NULL,
 [pit_lane_crossing] BIT NOT NULL,
 [sector1_seconds] DECIMAL(10,3) NULL,
 [sector2_seconds] DECIMAL(10,3) NULL,
 [sector3_seconds] DECIMAL(10,3) NULL,
 [sector4_seconds] DECIMAL(10,3) NULL,
 [sector1_cancelled] BIT NOT NULL,
 [sector2_cancelled] BIT NOT NULL,
 [sector3_cancelled] BIT NOT NULL,
 [sector4_cancelled] BIT NOT NULL,
 [speed_kmh] DECIMAL(7,3) NULL,
 [page] SMALLINT NOT NULL,
 [source_text] NVARCHAR(1000) NULL,
 PRIMARY KEY([revision],[source_rider_key],[lap_number]),
 FOREIGN KEY(revision,sid) REFERENCES dbo.timing_revisions(revision,sid),
 FOREIGN KEY(sid,source_rider_key) REFERENCES dbo.session_entries(sid,[key]),
 CHECK([lap_number]>0),
 CHECK([lap_time_seconds]>0),
 CHECK([sector1_seconds]>0),
 CHECK([sector2_seconds]>0),
 CHECK([sector3_seconds]>0),
 CHECK([sector4_seconds]>0),
 CHECK([page]>0)
);
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
