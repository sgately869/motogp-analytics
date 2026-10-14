/* Read-only. Use after 14 through 19. Counts can grow after later imports. */
USE MotoGP;
GO
-- The calendar: one row per event/class, including scheduled future events.
SELECT e.season_year,e.event_name,e.date_start,e.event_status,c.class_name,ci.circuit_name
FROM dbo.events e JOIN dbo.event_classes ec ON ec.event_id=e.event_id
JOIN dbo.classes c ON c.class_id=ec.class_id
JOIN dbo.circuits ci ON ci.circuit_id=ec.circuit_id
WHERE e.season_year=2025
ORDER BY e.date_start,c.class_name;

-- The corrected Moto2 Thailand result: Gonzalez 12.5 points, not 25.
SELECT rider_name,classified_position,result_status_code,official_points_awarded
FROM dbo.v_race_results_current
WHERE season_year=2026 AND short_name='THA' AND class_name='Moto2'
ORDER BY CASE WHEN classified_position IS NULL THEN 1 ELSE 0 END,classified_position,rider_name;

-- Imported wins only; Sprint and GP wins remain separate.
SELECT * FROM dbo.v_imported_rider_wins ORDER BY rider_name,class_name,race_type;

-- These totals are source standings, NOT sums calculated from the pilot races.
SELECT * FROM dbo.v_official_rider_standings
WHERE season_year=1967 AND class_name='500cc' ORDER BY official_position;
SELECT * FROM dbo.v_effective_points_adjustments ORDER BY season_year,championship_type;

-- Review queue: do not manufacture results for these races.
SELECT e.season_year,e.event_name,c.class_name,r.race_type,r.race_status,r.selection_note
FROM dbo.races r JOIN dbo.event_classes ec ON ec.event_class_id=r.event_class_id
JOIN dbo.events e ON e.event_id=ec.event_id JOIN dbo.classes c ON c.class_id=ec.class_id
WHERE r.race_status IN('REVIEW','CANCELLED') ORDER BY e.season_year,e.date_start;

-- Source identities without a confirmed link to your master riders.
SELECT DISTINCT source_rider_key,source_rider_legacy_id,source_rider_name
FROM dbo.race_entries WHERE rider_id IS NULL ORDER BY source_rider_name;

-- Missing points remain visible; SUM alone would silently ignore NULLs.
SELECT season_year,class_name,COUNT(*) AS imported_result_rows,
 SUM(CASE WHEN official_points_awarded IS NULL THEN 1 ELSE 0 END) AS unresolved_points_rows,
 SUM(official_points_awarded) AS known_points_in_imported_races
FROM dbo.v_race_results_current GROUP BY season_year,class_name ORDER BY season_year,class_name;

-- A deliberately incomplete reconciliation, useful while loading more races.
-- Differences are NOT automatically penalties: missing races, dropped scores,
-- revisions and differing snapshot coverage can all explain them.
WITH imported AS (
 SELECT season_year,class_name,source_rider_key,
 COUNT(*) AS imported_results,
 SUM(official_points_awarded) AS known_imported_points,
 SUM(CASE WHEN official_points_awarded IS NULL THEN 1 ELSE 0 END) AS unknown_points_rows
 FROM dbo.v_race_results_current GROUP BY season_year,class_name,source_rider_key
)
SELECT s.season_year,s.class_name,s.rider_name,s.official_points,
 i.imported_results,i.known_imported_points,i.unknown_points_rows,
 N'Coverage not established: do not interpret the difference as a deduction' AS reconciliation_status
FROM dbo.v_official_rider_standings s LEFT JOIN imported i
 ON i.season_year=s.season_year AND i.class_name=s.class_name AND i.source_rider_key=s.source_competitor_key
WHERE s.season_year IN(1967,2025,2026) AND s.official_position<=3
ORDER BY s.season_year,s.class_name,s.official_position;

-- Integrity diagnostics: all three queries below should return NO rows.
SELECT r.race_id,COUNT(*) AS selected_sessions FROM dbo.races r
JOIN motogp_source.race_sessions s ON s.race_id=r.race_id AND s.selected_for_statistics=1
GROUP BY r.race_id HAVING COUNT(*)>1;
SELECT * FROM dbo.v_race_results_current WHERE season_year=2018 AND short_name='GBR';
SELECT en.race_entry_id FROM dbo.race_entries en
JOIN dbo.races r ON r.race_id=en.race_id
JOIN dbo.event_classes ec ON ec.event_class_id=r.event_class_id
JOIN dbo.team_seasons ts ON ts.team_season_id=en.team_season_id
WHERE ts.season_year<>ec.season_year OR ts.class_id<>ec.class_id;
GO
