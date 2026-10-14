USE MotoGP;
GO
CREATE OR ALTER VIEW dbo.v_race_results_current AS
SELECT e.season_year,e.event_id,e.event_name,e.short_name,c.class_name,ci.circuit_name,
 r.race_id,r.race_key,r.race_type,r.race_number,r.race_date,
 en.race_entry_id,en.rider_id,en.source_rider_key,
 COALESCE(ri.display_name,en.source_rider_name) AS rider_name,
 en.rider_number,en.source_team_name,en.source_constructor_name,
 rr.classified_position,rr.result_status_code,rr.source_status,rr.started_session,
 rr.laps_completed,rr.elapsed_seconds,rr.source_time,rr.source_gap,
 rr.official_points_awarded,rs.points_state,rs.retrieved_at,rs.source_url,
 rs.completeness_note
FROM dbo.race_results rr
JOIN dbo.race_result_sets rs ON rs.result_set_key=rr.result_set_key AND rs.is_current=1
JOIN motogp_source.race_sessions s ON s.source_session_uuid=rs.source_session_uuid AND s.selected_for_statistics=1
JOIN dbo.races r ON r.race_id=rr.race_id AND r.race_status='HELD'
JOIN dbo.event_classes ec ON ec.event_class_id=r.event_class_id
JOIN dbo.events e ON e.event_id=ec.event_id
JOIN dbo.classes c ON c.class_id=ec.class_id
JOIN dbo.circuits ci ON ci.circuit_id=ec.circuit_id
JOIN dbo.race_entries en ON en.race_entry_id=rr.race_entry_id
LEFT JOIN dbo.riders ri ON ri.rider_id=en.rider_id;
GO
CREATE OR ALTER VIEW dbo.v_imported_rider_wins AS
SELECT rider_id,source_rider_key,rider_name,class_name,race_type,COUNT_BIG(*) AS wins_in_imported_results
FROM dbo.v_race_results_current
WHERE classified_position=1 AND result_status_code='CLASSIFIED'
GROUP BY rider_id,source_rider_key,rider_name,class_name,race_type;
GO
CREATE OR ALTER VIEW dbo.v_official_rider_standings AS
SELECT ch.season_year,c.class_name,ce.rider_id,ce.source_competitor_key,
 COALESCE(r.display_name,ce.source_competitor_name) AS rider_name,
 st.official_position,st.official_points,s.retrieved_at,s.coverage_note,s.source_url
FROM dbo.championship_standings st
JOIN dbo.championship_standing_snapshots s ON s.snapshot_key=st.snapshot_key AND s.is_current=1
JOIN dbo.championships ch ON ch.championship_id=st.championship_id AND ch.championship_type='RIDER'
JOIN dbo.classes c ON c.class_id=ch.class_id
JOIN dbo.championship_entries ce ON ce.championship_entry_id=st.championship_entry_id
LEFT JOIN dbo.riders r ON r.rider_id=ce.rider_id;
GO
CREATE OR ALTER VIEW dbo.v_effective_points_adjustments AS
SELECT ch.season_year,c.class_name,ch.championship_type,ce.championship_entry_id,
 ce.source_competitor_name,a.adjustment_key,a.points_delta,a.effective_date,a.source_url
FROM dbo.championship_points_adjustments a
JOIN dbo.championship_entries ce ON ce.championship_entry_id=a.championship_entry_id
JOIN dbo.championships ch ON ch.championship_id=ce.championship_id
JOIN dbo.classes c ON c.class_id=ch.class_id
LEFT JOIN dbo.penalties p ON p.penalty_id=a.penalty_id
WHERE a.adjustment_status='APPLIED' AND a.reflected_in_race_points=0
 AND (a.penalty_id IS NULL OR p.decision_status IN('APPLIED','UNDER_APPEAL'));
GO
