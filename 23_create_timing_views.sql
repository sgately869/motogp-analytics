USE MotoGP;
GO
CREATE OR ALTER VIEW dbo.v_qualifying_results AS
SELECT ev.season_year,ev.event_name,ev.short_name,c.class_name,s.sid AS session_uuid,
 s.number AS qualifying_part,s.date AS source_session_date,
 en.rider_id,en.[key] AS source_rider_key,COALESCE(ri.display_name,en.name) AS rider_name,en.number AS rider_number,
 q.position AS session_position,q.source_status,q.best_lap_seconds,q.best_lap_number,q.total_laps,q.top_speed_kmh,
 s.url AS source_url
FROM dbo.session_results q
JOIN dbo.timing_revisions v ON v.revision=q.revision AND v.is_current=1
JOIN dbo.timing_sessions s ON s.sid=q.sid AND s.type='Q'
JOIN dbo.event_classes ec ON ec.event_class_id=s.event_class_id
JOIN dbo.events ev ON ev.event_id=ec.event_id
JOIN dbo.classes c ON c.class_id=ec.class_id
JOIN dbo.session_entries en ON en.sid=q.sid AND en.[key]=q.[key]
LEFT JOIN dbo.riders ri ON ri.rider_id=en.rider_id;
GO
CREATE OR ALTER VIEW dbo.v_race_fastest_laps AS
SELECT ev.season_year,ev.event_name,ev.short_name,c.class_name,r.race_id,r.race_type,r.race_number,r.race_date,
 f.sid AS session_uuid,en.rider_id,en.[key] AS source_rider_key,COALESCE(ri.display_name,en.name) AS rider_name,
 f.rider_number,f.published_rank,f.best_lap_seconds,f.best_lap_number,f.total_laps,
 doc.url AS source_url,f.page AS source_page
FROM dbo.race_fastest_laps f
JOIN dbo.timing_revisions v ON v.revision=f.revision AND v.is_current=1
JOIN motogp_source.race_sessions rs ON rs.source_session_uuid=f.sid AND rs.selected_for_statistics=1
JOIN dbo.races r ON r.race_id=rs.race_id AND r.race_status='HELD'
JOIN dbo.event_classes ec ON ec.event_class_id=r.event_class_id
JOIN dbo.events ev ON ev.event_id=ec.event_id
JOIN dbo.classes c ON c.class_id=ec.class_id
JOIN dbo.session_entries en ON en.sid=f.sid AND en.[key]=f.source_rider_key
LEFT JOIN dbo.riders ri ON ri.rider_id=en.rider_id
JOIN dbo.timing_documents doc ON doc.revision=f.revision AND doc.kind='fast_lap_rider';
GO
CREATE OR ALTER VIEW dbo.v_race_overall_fastest_laps AS
SELECT * FROM dbo.v_race_fastest_laps WHERE published_rank=1;
GO
CREATE OR ALTER VIEW dbo.v_race_grids AS
SELECT ev.season_year,ev.event_name,ev.short_name,c.class_name,r.race_id,r.race_type,r.race_number,r.race_date,
 g.sid AS session_uuid,en.rider_id,en.[key] AS source_rider_key,COALESCE(ri.display_name,en.name) AS rider_name,
 g.rider_number,g.grid_position AS published_grid_position,g.grid_status,g.qualifying_time_seconds,
 doc.url AS source_url,g.page AS source_page
FROM dbo.race_grids g
JOIN dbo.timing_revisions v ON v.revision=g.revision AND v.is_current=1
JOIN motogp_source.race_sessions rs ON rs.source_session_uuid=g.sid AND rs.selected_for_statistics=1
JOIN dbo.races r ON r.race_id=rs.race_id AND r.race_status='HELD'
JOIN dbo.event_classes ec ON ec.event_class_id=r.event_class_id
JOIN dbo.events ev ON ev.event_id=ec.event_id
JOIN dbo.classes c ON c.class_id=ec.class_id
JOIN dbo.session_entries en ON en.sid=g.sid AND en.[key]=g.source_rider_key
LEFT JOIN dbo.riders ri ON ri.rider_id=en.rider_id
JOIN dbo.timing_documents doc ON doc.revision=g.revision AND doc.kind='grid';
GO
CREATE OR ALTER VIEW dbo.v_race_lap_times AS
SELECT ev.season_year,ev.event_name,ev.short_name,c.class_name,r.race_id,r.race_type,r.race_number,r.race_date,
 l.sid AS session_uuid,en.rider_id,en.[key] AS source_rider_key,COALESCE(ri.display_name,en.name) AS rider_name,
 l.rider_number,l.lap_number,l.lap_time_seconds,l.lap_time_cancelled,l.pit_lane_crossing,
 l.sector1_seconds,l.sector2_seconds,l.sector3_seconds,l.sector4_seconds,
 l.sector1_cancelled,l.sector2_cancelled,l.sector3_cancelled,l.sector4_cancelled,l.speed_kmh,
 l.lap_time_seconds-(l.sector1_seconds+l.sector2_seconds+l.sector3_seconds+l.sector4_seconds) AS sector_sum_difference_seconds,
 doc.url AS source_url,l.page AS source_page
FROM dbo.lap_times l
JOIN dbo.timing_revisions v ON v.revision=l.revision AND v.is_current=1
JOIN motogp_source.race_sessions rs ON rs.source_session_uuid=l.sid AND rs.selected_for_statistics=1
JOIN dbo.races r ON r.race_id=rs.race_id AND r.race_status='HELD'
JOIN dbo.event_classes ec ON ec.event_class_id=r.event_class_id
JOIN dbo.events ev ON ev.event_id=ec.event_id
JOIN dbo.classes c ON c.class_id=ec.class_id
JOIN dbo.session_entries en ON en.sid=l.sid AND en.[key]=l.source_rider_key
LEFT JOIN dbo.riders ri ON ri.rider_id=en.rider_id
JOIN dbo.timing_documents doc ON doc.revision=l.revision AND doc.kind='analysis';
GO
CREATE OR ALTER VIEW dbo.v_timing_document_coverage AS
SELECT ev.season_year,ev.event_name,ev.short_name,c.class_name,s.type AS session_type,s.number AS session_number,
 s.sid AS session_uuid,d.kind AS document_type,d.parse_status,d.row_count,d.note,d.url AS source_url,d.sha256,d.retrieved_at
FROM dbo.timing_documents d
JOIN dbo.timing_revisions v ON v.revision=d.revision AND v.is_current=1
JOIN dbo.timing_sessions s ON s.sid=d.sid
JOIN dbo.event_classes ec ON ec.event_class_id=s.event_class_id
JOIN dbo.events ev ON ev.event_id=ec.event_id
JOIN dbo.classes c ON c.class_id=ec.class_id;
GO
CREATE OR ALTER VIEW dbo.v_timing_quality_issues AS
SELECT ev.season_year,ev.event_name,ev.short_name,c.class_name,s.type AS session_type,s.number AS session_number,
 s.sid AS session_uuid,i.component,i.reason
FROM dbo.timing_quality_issues i
JOIN dbo.timing_revisions v ON v.revision=i.revision AND v.is_current=1
JOIN dbo.timing_sessions s ON s.sid=i.sid
JOIN dbo.event_classes ec ON ec.event_class_id=s.event_class_id
JOIN dbo.events ev ON ev.event_id=ec.event_id
JOIN dbo.classes c ON c.class_id=ec.class_id;
GO
