# Rider portraits in Power BI

This package prepares the data. It does not edit a PBIX file or connect to your SQL Server automatically.

## 1. Import the data

After SQL scripts 25–28 succeed, use Power BI Desktop > Get data > SQL Server:

- Server: `localhost\SQLEXPRESS`
- Database: `MotoGP`
- Import `dbo.riders`; rename it **Riders** in the model.
- Import `dbo.v_bi_photo_seasons`; rename it **Seasons**.
- Import `dbo.v_bi_photo_classes`; rename it **Classes**.
- Import `dbo.v_bi_rider_images`; rename it **RiderPhotos**.

If you already have rider, season and class dimensions, use those existing tables and adapt the measure names below. Do not create duplicate competing dimensions.

## 2. Set the relationships

Create these active one-to-many relationships, with single-direction filtering from the dimension to RiderPhotos:

| One side | Many side |
|---|---|
| Riders[rider_id] | RiderPhotos[rider_id] |
| Seasons[season_year] | RiderPhotos[season_year] |
| Classes[class_name] | RiderPhotos[class_name] |

RiderPhotos has one row per rider, year and class. It is not the rider dimension. Do not merge it directly into every race-result row, and do not create a many-to-many relationship to race results. The same dimensions should filter the statistics fact tables through their appropriate keys when the full model is assembled.

## 3. Add selectors

Add single-select slicers for Riders[display_name], Seasons[season_year] and Classes[class_name]. Turn off Select all. Start with **Marc Marquez / 2025 / MotoGP**. The guard measure below also handles cleared selectors or unsupported combinations.

## 4. Display the portrait

Select RiderPhotos[display_photo_url] in Table view. Under Column tools, set **Data category = Image URL**.

Add a **Table** visual containing only RiderPhotos[display_photo_url]. Hide the column header, gridlines and totals; resize the image and visual for the profile panel. This uses the built-in image-column support and requires no paid custom visual.

Create this measure (Modeling > New measure):

```dax
Show Rider Portrait =
VAR OneSelection =
    HASONEVALUE ( Riders[rider_id] )
        && HASONEVALUE ( Seasons[season_year] )
        && HASONEVALUE ( Classes[class_name] )
VAR MatchingRows =
    CALCULATE (
        COUNTROWS ( RiderPhotos ),
        REMOVEFILTERS ( RiderPhotos[display_photo_url] )
    )
RETURN
    IF ( OneSelection && MatchingRows = 1, 1, 0 )
```

Drag **Show Rider Portrait** into the portrait visual's filters and set it to **is 1**. Also filter display_photo_url to **is not blank**. The guard hides multiple-photo cases instead of picking an arbitrary image. Configure slicer interactions so all three slicers filter the portrait and the statistics.

Create this second measure and place it in a Card alongside or below the portrait:

```dax
Rider Photo Status =
VAR OneSelection =
    HASONEVALUE ( Riders[rider_id] )
        && HASONEVALUE ( Seasons[season_year] )
        && HASONEVALUE ( Classes[class_name] )
VAR MatchingRows = COUNTROWS ( RiderPhotos )
VAR Photo = SELECTEDVALUE ( RiderPhotos[display_photo_url] )
RETURN
    SWITCH (
        TRUE (),
        NOT OneSelection, "Select one rider, season and class",
        MatchingRows = 0, "No photo loaded for this selection",
        MatchingRows > 1, "Multiple photo records: review required",
        ISBLANK ( Photo ), "Season photo unavailable",
        BLANK ()
    )
```

No picture from a different season is substituted. The source team name describes the roster's season association; it is not proof of the rider's team at every individual race. Do not use current nested team colours/logos to describe historic teams.

## 5. Check the behaviour

- Marc Marquez / 2025 / MotoGP should show his season-linked Ducati portrait.
- Change rider: the photo must change together with the rider statistics once those facts are connected.
- Select an unloaded season: the photo disappears and the message explains why.
- Clear a selector or enable multiple selections temporarily: no arbitrary portrait is displayed.
- Select a rider listed as missing in the audit: show the unavailable message.
- Publish a test report and check the links in Power BI Service; public access from Python is not a live Power BI rendering test. SQL Server refresh from your PC also needs the appropriate gateway configuration if scheduled later.

## Image availability and sourcing

URLs point to official MotoGP-hosted files, without sign-in. The package stores URLs and provenance, not copies of the photographs. The host can change or remove an image. A URL containing the selected year and its matching roster record provides season evidence; it is not a visual verification of every sponsor or mid-season change. Older archive images without a year in their path are recorded for review and withheld from automatic display.

Public accessibility does not itself grant a licence to republish the photographs. Review usage rights before a public/commercial release.

Microsoft's image documentation: https://learn.microsoft.com/en-us/power-bi/create-reports/power-bi-images-tables
