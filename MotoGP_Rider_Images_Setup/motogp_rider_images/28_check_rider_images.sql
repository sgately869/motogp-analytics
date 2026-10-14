USE MotoGP;
GO
-- Coverage totals; compare with image_audit_2025.json.
SELECT * FROM dbo.v_bi_rider_image_coverage WHERE season_year=2025
ORDER BY class_name,image_status;
-- Ready for Power BI.
SELECT COUNT(*) AS rider_season_class_rows,
 COUNT(display_photo_url) AS displayable_photos
FROM dbo.v_bi_rider_images WHERE season_year=2025;
-- Missing/withheld pictures: expected exceptions, not fabricated portraits.
SELECT display_name,class_name,image_status,season_evidence
FROM dbo.v_bi_rider_images WHERE season_year=2025 AND display_photo_url IS NULL
ORDER BY class_name,display_name;
-- Identity link check: expected 0.
SELECT COUNT(*) AS unlinked_photo_rows
FROM dbo.rider_season_images p
JOIN motogp_source.riders s ON s.source_rider_uuid=p.source_rider_uuid
WHERE p.season_year=2025 AND s.rider_id IS NULL;
-- No duplicate canonical rider/season/class rows: expected no results.
SELECT rider_id,season_year,class_name,COUNT(*) AS row_count
FROM dbo.v_bi_rider_images GROUP BY rider_id,season_year,class_name
HAVING COUNT(*)>1;
-- Example: open this URL in a browser to inspect the official 2025 photo.
SELECT display_name,source_team_name,display_photo_url
FROM dbo.v_bi_rider_images WHERE season_year=2025 AND display_name=N'Marc Marquez';
GO
