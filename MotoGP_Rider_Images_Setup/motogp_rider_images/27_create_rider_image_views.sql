USE MotoGP;
GO
CREATE OR ALTER VIEW dbo.v_bi_rider_images AS
SELECT s.rider_id,r.display_name,p.season_year,p.class_name,p.rider_number,
 p.source_team_name,p.image_url AS display_photo_url,p.image_status,p.season_evidence,
 p.source_url,p.checked_at,p.source_rider_uuid
FROM dbo.rider_season_images p
JOIN motogp_source.riders s ON s.source_rider_uuid=p.source_rider_uuid
JOIN dbo.riders r ON r.rider_id=s.rider_id;
GO
CREATE OR ALTER VIEW dbo.v_bi_rider_image_coverage AS
SELECT p.season_year,p.class_name,p.image_status,COUNT(*) AS rider_rows,
 SUM(CASE WHEN p.image_url IS NOT NULL THEN 1 ELSE 0 END) AS displayable_photos,
 SUM(CASE WHEN s.rider_id IS NULL THEN 1 ELSE 0 END) AS unlinked_riders
FROM dbo.rider_season_images p
JOIN motogp_source.riders s ON s.source_rider_uuid=p.source_rider_uuid
GROUP BY p.season_year,p.class_name,p.image_status;
GO
CREATE OR ALTER VIEW dbo.v_bi_photo_seasons AS
SELECT DISTINCT CONVERT(INT,season) AS season_year
FROM motogp_source.rider_seasons;
GO
CREATE OR ALTER VIEW dbo.v_bi_photo_classes AS
SELECT DISTINCT class_name FROM motogp_source.rider_seasons;
GO
