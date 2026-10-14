USE MotoGP;
GO
-- Rider details plus the nationality label currently reported by the archive.
SELECT r.rider_id,r.display_name,r.first_name,r.last_name,r.date_of_birth,
       r.birth_place,b.country_name AS source_reported_birth_country,
       n.country_name AS source_reported_nationality,s.motogp_legacy_id
FROM dbo.riders AS r
JOIN motogp_source.riders AS s ON s.rider_id=r.rider_id
LEFT JOIN dbo.countries AS b ON b.country_id=r.birth_country_id
LEFT JOIN dbo.countries AS n ON n.country_code=s.profile_country_code
ORDER BY r.last_name,r.first_name;

-- Classes in which the source lists each rider (not a count of race starts).
SELECT DISTINCT r.display_name,s.class_name
FROM motogp_source.rider_seasons AS s
JOIN motogp_source.riders AS p ON p.source_rider_uuid=s.source_rider_uuid
JOIN dbo.riders AS r ON r.rider_id=p.rider_id
ORDER BY r.display_name,s.class_name;

-- Season number observations; these do not prove the number at every race.
SELECT r.display_name,s.season,s.class_name,s.rider_number,s.sponsored_team_name
FROM motogp_source.rider_seasons AS s
JOIN motogp_source.riders AS p ON p.source_rider_uuid=s.source_rider_uuid
JOIN dbo.riders AS r ON r.rider_id=p.rider_id
WHERE s.rider_number IS NOT NULL
ORDER BY r.display_name,s.season,s.class_name;

-- A practical data-quality exercise: find missing biographical information.
SELECT rider_id,display_name,date_of_birth,birth_place
FROM dbo.riders
WHERE date_of_birth IS NULL OR birth_place IS NULL
ORDER BY display_name;
