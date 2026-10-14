"""Developer helper: regenerate the additive SQL schema from the import specification."""
from pathlib import Path
from build_timing import SPECS
ROOT=Path(__file__).resolve().parent
s='''/* Additive extension: does not alter results, points, or the existing race session selection. */
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
'''
required={'issues':['revision','sid','issue_number','component','reason'],'documents':['revision','sid','kind','parse_status','row_count'], 'qualifying':['revision','sid','key'], 'records':['revision','sid','key','record_type'], 'fastest':['revision','sid','source_rider_key','published_rank','best_lap_seconds','best_lap_number','total_laps','page'], 'grids':['revision','sid','source_rider_key','grid_position','grid_status','page'], 'laps':['revision','sid','source_rider_key','lap_number','lap_time_seconds','lap_time_cancelled','pit_lane_crossing','sector1_cancelled','sector2_cancelled','sector3_cancelled','sector4_cancelled','page']}
keys={'issues':['revision','issue_number'],'documents':['revision','kind'],'qualifying':['revision','key'],'records':['revision','record_type'],'fastest':['revision','source_rider_key'],'grids':['revision','source_rider_key'],'laps':['revision','source_rider_key','lap_number']}
for kind in required:
 table,cols=SPECS[kind];lines=[]
 for name,typ in cols:
  lines.append(f' [{name}] {typ.upper()} '+('NOT NULL' if name in required[kind] else 'NULL'))
 lines.append(' PRIMARY KEY('+','.join('['+k+']' for k in keys[kind])+')')
 lines.append(' FOREIGN KEY(revision,sid) REFERENCES dbo.timing_revisions(revision,sid)')
 if kind not in ('documents','issues'):lines.append(' FOREIGN KEY(sid,'+('[key]' if kind in ['qualifying','records'] else 'source_rider_key')+') REFERENCES dbo.session_entries(sid,[key])')
 for name,typ in cols:
  if name.endswith('_seconds') or name in ['lap_number','best_lap_number','grid_position','published_rank','page','position']:
   lines.append(f' CHECK([{name}]>0)')
 if kind=='grids':lines+=[' UNIQUE(revision,grid_position)'," CHECK(grid_status IN('OFFICIAL','PROVISIONAL','PUBLISHED'))"]
 if kind=='fastest':lines+=[' UNIQUE(revision,published_rank)',' CHECK(best_lap_number<=total_laps)']
 if kind=='documents':lines+=[' CHECK(row_count>=0)'," CHECK(parse_status IN('PARSED','REVIEW','NOT_ADVERTISED','DOWNLOAD_FAILED'))"]
 s+=f"IF OBJECT_ID(N'dbo.{table}',N'U') IS NULL\nCREATE TABLE dbo.{table}(\n"+',\n'.join(lines)+'\n);\n'
s+='COMMIT TRANSACTION;\nEND TRY\nBEGIN CATCH\n IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;\n THROW;\nEND CATCH;\nGO\n'
(ROOT/'21_create_timing_tables.sql').write_text(s,encoding='utf-8-sig')
