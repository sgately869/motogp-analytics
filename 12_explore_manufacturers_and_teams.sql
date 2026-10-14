USE MotoGP;
GO

-- 1. The curated manufacturer/marque list.
SELECT manufacturer_id,manufacturer_name FROM dbo.manufacturers ORDER BY manufacturer_name;

-- 2. Pramac: the same team identity, different constructors in 2024 and 2025.
SELECT t.team_name,ts.season_year,c.class_name,k.constructor_name,
       ts.entry_status,x.support_level
FROM dbo.teams t
JOIN dbo.team_seasons ts ON ts.team_id=t.team_id
JOIN dbo.classes c ON c.class_id=ts.class_id
JOIN dbo.team_season_constructors x ON x.team_season_id=ts.team_season_id
JOIN dbo.constructors k ON k.constructor_id=x.constructor_id
WHERE t.team_key='PRAMAC_RACING' AND c.class_name=N'MotoGP'
  AND ts.season_year IN (2024,2025)
ORDER BY ts.season_year;

-- 3. Moto2: team branding, constructor credit and engine supplier are separate.
SELECT t.team_name,ts.season_year,k.constructor_name,m.manufacturer_name AS engine_supplier
FROM dbo.team_seasons ts
JOIN dbo.teams t ON t.team_id=ts.team_id
JOIN dbo.classes c ON c.class_id=ts.class_id
JOIN dbo.team_season_constructors x ON x.team_season_id=ts.team_season_id
JOIN dbo.constructors k ON k.constructor_id=x.constructor_id
LEFT JOIN dbo.class_season_suppliers s ON s.class_id=ts.class_id
 AND s.season_year=ts.season_year AND s.supply_role='ENGINE'
LEFT JOIN dbo.manufacturers m ON m.manufacturer_id=s.manufacturer_id
WHERE c.class_name=N'Moto2' AND ts.season_year=2025
ORDER BY t.team_name,k.constructor_name;

-- 4. Sponsors/names associated with one team organisation in a season.
SELECT t.team_name,ts.season_year,c.class_name,n.entry_name
FROM dbo.team_season_names n
JOIN dbo.team_seasons ts ON ts.team_season_id=n.team_season_id
JOIN dbo.teams t ON t.team_id=ts.team_id
JOIN dbo.classes c ON c.class_id=ts.class_id
WHERE t.team_key='LCR_RACING_TEAM' AND ts.season_year=2025
ORDER BY c.class_name,n.entry_name;

-- 5. Original constructor labels still awaiting interpretation.
SELECT source_name,source_legacy_id,first_observed_season,last_observed_season,source_url
FROM motogp_source.constructor_labels WHERE review_required=1;

-- 6. Unresolved historical team names: source records remain queryable.
SELECT n.source_name,m.season_year,c.class_name,m.evidence_url
FROM motogp_source.team_mappings m
JOIN motogp_source.team_labels n ON n.label_key=m.label_key
JOIN dbo.classes c ON c.class_id=m.class_id
WHERE m.team_id IS NULL
ORDER BY m.season_year,c.class_name,n.source_name;

-- 7. Constructors appearing under each class in the observed source records.
-- This is archive presence, not proof of race starts, wins or complete careers.
SELECT DISTINCT c.class_name,k.source_name AS constructor_label
FROM motogp_source.team_constructor_observations o
JOIN motogp_source.constructor_labels k ON k.constructor_key=o.constructor_key
JOIN dbo.classes c ON c.class_id=o.class_id
WHERE k.review_required=0
ORDER BY c.class_name,k.source_name;
