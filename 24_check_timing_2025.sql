USE MotoGP;
GO
-- 1. Coverage: distinguish data absent from data successfully parsed.
SELECT class_name,session_type,document_type,parse_status,
 COUNT(*) AS sessions,SUM(row_count) AS imported_rows
FROM dbo.v_timing_document_coverage WHERE season_year=2025
GROUP BY class_name,session_type,document_type,parse_status
ORDER BY class_name,session_type,document_type,parse_status;
-- 2. Every held scoring race should have both fastest-lap and grid coverage.
SELECT DISTINCT rr.class_name,rr.event_name,rr.race_type,rr.race_number,
 CASE WHEN f.race_id IS NULL THEN 'MISSING' ELSE 'PRESENT' END AS fastest_lap,
 CASE WHEN g.race_id IS NULL THEN 'MISSING' ELSE 'PRESENT' END AS published_grid
FROM dbo.v_race_results_current rr
LEFT JOIN (SELECT DISTINCT race_id FROM dbo.v_race_fastest_laps) f ON f.race_id=rr.race_id
LEFT JOIN (SELECT DISTINCT race_id FROM dbo.v_race_grids) g ON g.race_id=rr.race_id
WHERE rr.season_year=2025 AND (f.race_id IS NULL OR g.race_id IS NULL);
-- 3. Source exceptions remain visible.
SELECT * FROM dbo.v_timing_document_coverage
WHERE season_year=2025 AND parse_status<>'PARSED'
ORDER BY class_name,event_name,session_type,document_type;
-- 4. Unlinked participants, including qualifying-only participants or historical record holders.
SELECT DISTINCT c.class_name,en.[key] AS source_rider_key,en.name AS source_name
FROM dbo.session_entries en JOIN dbo.timing_sessions s ON s.sid=en.sid
JOIN dbo.event_classes ec ON ec.event_class_id=s.event_class_id
JOIN dbo.classes c ON c.class_id=ec.class_id
WHERE ec.season_year=2025 AND en.rider_id IS NULL;
-- 5. Example: Thailand qualifying times (Q1 and Q2 remain separate).
SELECT class_name,qualifying_part,session_position,rider_name,best_lap_seconds
FROM dbo.v_qualifying_results WHERE season_year=2025 AND short_name='THA'
ORDER BY class_name,qualifying_part,session_position;
-- 6. One officially top-ranked fastest lap per imported scoring race.
SELECT class_name,race_type,COUNT(*) AS races_with_fastest_lap
FROM dbo.v_race_overall_fastest_laps WHERE season_year=2025
GROUP BY class_name,race_type ORDER BY class_name,race_type;
-- 7. Compare fastest-lap document against the matching analysis lap. Empty means agreement for available laps.
SELECT f.class_name,f.event_name,f.race_type,f.rider_name,f.best_lap_number,
 f.best_lap_seconds,l.lap_time_seconds,l.lap_time_cancelled
FROM dbo.v_race_fastest_laps f
JOIN dbo.v_race_lap_times l ON l.race_id=f.race_id AND l.source_rider_key=f.source_rider_key AND l.lap_number=f.best_lap_number
WHERE f.season_year=2025 AND (f.best_lap_seconds<>l.lap_time_seconds OR l.lap_time_cancelled=1);
-- 8. Published grid compared with finishing position. Grid is not proof of physical start position.
SELECT r.class_name,r.event_name,r.race_type,r.rider_name,g.published_grid_position,
 r.classified_position,g.published_grid_position-r.classified_position AS net_positions_vs_published_grid,
 g.grid_status
FROM dbo.v_race_results_current r
JOIN dbo.v_race_grids g ON g.race_id=r.race_id AND g.source_rider_key=r.source_rider_key
WHERE r.season_year=2025 AND r.short_name='THA' AND r.classified_position IS NOT NULL
ORDER BY r.class_name,r.race_type,r.classified_position;
-- 9. Count documented exceptions even when all documents parsed successfully.
SELECT component,COUNT(*) AS documented_issues
FROM dbo.v_timing_quality_issues WHERE season_year=2025
GROUP BY component ORDER BY component;
-- 10. Investigate a source API/PDF disagreement and the published resolution.
SELECT * FROM dbo.v_timing_quality_issues
WHERE season_year=2025 AND component IN('api_record_conflict','lap_count_difference');
