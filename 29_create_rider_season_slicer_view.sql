/* MotoGP: Season -> Class -> Rider dropdown support.
   Run this whole file against MotoGP. It creates one read-only reporting view.
   Source: imported rider-season associations, including roster and standings
   evidence. This is not proof of a race start and is independent of photo
   availability or the narrower set of race results imported so far.
   No existing relationship, table, result or measure is changed.
*/
USE MotoGP;
GO
CREATE OR ALTER VIEW dbo.v_bi_rider_season_membership AS
SELECT DISTINCT r.rider_id,CONVERT(INT,s.season) AS season_year,s.class_name
FROM motogp_source.rider_seasons AS s
JOIN motogp_source.riders AS r ON r.source_rider_uuid=s.source_rider_uuid
WHERE r.rider_id IS NOT NULL;
GO
SELECT season_year,class_name,COUNT(*) AS available_riders
FROM dbo.v_bi_rider_season_membership
WHERE season_year=2025
GROUP BY season_year,class_name
ORDER BY class_name;
GO
/* POWER BI SETUP
1. Import dbo.v_bi_rider_season_membership and rename it RiderSeasons.
2. Create/verify these active relationships, all single-direction, one-to-many:
   Riders[rider_id] -> RiderSeasons[rider_id]
   Seasons[season_year] -> RiderSeasons[season_year]
   Classes[class_name] -> RiderSeasons[class_name]
   Do not link RiderSeasons directly to RaceResults, QualifyingResults or
   RiderPhotos. Keep the existing nine relationships unchanged.
3. Create the following measures individually in Power BI (not SQL):

Class Available =
VAR MatchingRows =
    CALCULATE ( COUNTROWS ( RiderSeasons ), REMOVEFILTERS ( Riders ) )
RETURN IF ( MatchingRows > 0, 1, 0 )

Rider Available =
IF ( COUNTROWS ( RiderSeasons ) > 0, 1, 0 )

Selection Status =
SWITCH (
    TRUE (),
    NOT HASONEVALUE ( Seasons[season_year] ), "Select a season",
    NOT HASONEVALUE ( Classes[class_name] ), "Select a class",
    [Class Available] = 0, "Select a class available in this season",
    NOT HASONEVALUE ( Riders[rider_id] ), "Select a rider",
    [Rider Available] = 0, "Select a rider available in this season and class",
    BLANK ()
)

4. Select the Classes[class_name] slicer. Drag Class Available to
   Filters on this visual and set it to is 1. Select the Riders[display_name]
   slicer and filter it by Rider Available is 1. Do not put these measures
   in the slicer Field box or in page/report filters. No availability filter
   is needed on the Seasons slicer.
5. Configure Format > Edit interactions among the three slicers:
   Season -> Class: Filter; Season -> Rider: Filter
   Class -> Rider: Filter; Class -> Season: None
   Rider -> Class: None; Rider -> Season: None
   Keep all three filtering the photo and statistics visuals.
6. Put Selection Status in a Card. Changing a parent can retain the previous
   child selection; these filters do not programmatically clear/reselect it.
   If the message appears, choose the class and rider again, in that order.
   Turn off Show items with no data if it is enabled for either child slicer.
7. Verify 2025 offers MotoGP, Moto2, Moto3, MotoE. Changing class changes the
   rider choices. Changing rider must not narrow the class or season choices.
   Check 1990 does not offer Moto2, Moto3 or MotoE. Historical roster coverage
   is not certified complete, and this view does not imply results/photos are
   loaded for every available season/rider.

To stop existing win/podium cards showing zero for an invalid retained
selection, create display wrappers (leave the original measures intact):

GP Wins Display =
IF ( ISBLANK ( [Selection Status] ), [GP Wins], BLANK () )

GP Podiums Display =
IF ( ISBLANK ( [Selection Status] ), [GP Podiums], BLANK () )

Use the Display measures on the cards. Missing historical race coverage is
separate from invalid selection; a valid roster entry alone does not establish
that its full race history was loaded.

Validation: view columns checked against the existing import schema; DISTINCT
prevents duplicate canonical rider/season/class rows. Not executed on live SQL
Server or in Power BI here.
Microsoft guidance on measure-based slicer filtering:
https://learn.microsoft.com/power-bi/guidance/relationships-bidirectional-filtering
*/
