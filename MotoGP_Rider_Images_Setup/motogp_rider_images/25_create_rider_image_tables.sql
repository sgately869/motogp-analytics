USE MotoGP;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'motogp_source.riders',N'U') IS NULL
 THROW 50253, 'Run the existing rider import (script 08) first.', 1;
IF OBJECT_ID(N'dbo.rider_season_images',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.rider_season_images (
  source_rider_uuid UNIQUEIDENTIFIER NOT NULL,
  season_year SMALLINT NOT NULL,
  class_name NVARCHAR(20) NOT NULL,
  source_display_name NVARCHAR(150) NOT NULL,
  source_team_name NVARCHAR(200) NULL,
  rider_number INT NULL,
  candidate_image_url NVARCHAR(2048) NULL,
  image_url NVARCHAR(2048) NULL,
  image_status VARCHAR(40) NOT NULL,
  season_evidence VARCHAR(40) NOT NULL,
  source_url NVARCHAR(2048) NULL,
  retrieved_at VARCHAR(40) NOT NULL,
  checked_at VARCHAR(40) NULL,
  image_sha256 CHAR(64) NULL,
  CONSTRAINT PK_rider_season_images PRIMARY KEY(source_rider_uuid,season_year,class_name),
  CONSTRAINT FK_rider_season_images_source FOREIGN KEY(source_rider_uuid)
   REFERENCES motogp_source.riders(source_rider_uuid),
  CONSTRAINT CK_rider_season_images_year CHECK(season_year BETWEEN 1949 AND 2100),
  CONSTRAINT CK_rider_season_images_display CHECK(image_url IS NULL OR
   (image_status='VERIFIED' AND season_evidence='YEAR_IN_IMAGE_PATH' AND image_url LIKE 'https://%'))
 );
END;
GO
