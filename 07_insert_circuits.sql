/*
MotoGP project: 07_insert_circuits.sql
Research cutoff: 11 October 2026. SQL Server / dbo schema.

SCOPE: 78 named circuit/course records that hosted at least one solo World
Championship GP race, 1949 through the cutoff, including discontinued classes.
MotoE venues are covered; this is NOT an inventory of standalone sidecar,
WorldSBK, Formula 750, pre-1949 or non-championship racing venues.
Tests, cancelled-only venues and future-only venues are excluded.

GRAIN: one record per named circuit/course family, not per GP title, sponsor
name or every configuration. Brno Road Circuit and the replacement purpose-
built Automotodrom are explicit separate records. Clypse and the Mountain
Course are separate because different classes used them at the same TT.
Other configurations (e.g. old/new Sachsenring, Nurburgring Nordschleife,
Sudschleife and GP course, old/new Kyalami) belong in circuit_layouts later.
78 is THIS CATALOGUE'S row count, not an asserted official circuit statistic.

GEOGRAPHY: country_id is present-day location, including closed venues.
Clady/Dundrod use GBR (Northern Ireland); IOM courses use IMN, not GBR.
Old Yugoslav venues use HRV, Brno uses CZE. Preserve historical event host
countries separately when creating the events table. GP titles are not
geography: the San Marino GP at Misano is in Italy.

DATA QUALITY: audited all 78 season event feeds; 73 distinct source circuit
IDs in 1074 finished non-test event records. API event presence is not proof
that every class raced: e.g. 2018 Silverstone is marked FINISHED although
all races were cancelled. The seed does not import event or race facts.
The public circuit list cross-check has 76 already-used named rows; adding
Clypse (listed in a footnote) and separating the old Brno gives these 78.
The public sources contain discrepancies; see the corrections and evidence
appendix. This is a reconciled venue seed, not a complete layout history.

RUN: open this entire file in VS Code, connect MSSQL to your SQL Server,
and execute it as SQL. Do not paste it into PowerShell.
Assumes countries(country_id, country_name, country_code) already exists.
Creates the simple circuits table if absent, or uses the existing same schema.
Preserves existing IDs and names; exact country/name matches are skipped.
Review alternate names before seeding a database that already has circuits.
The entire change runs in a transaction. IOM is added if missing; any other
missing country is reported and causes rollback instead of silent row loss.
No length, corner count, direction, lap record or race count is stored here.
Those depend on layouts, dates or results and should not be static columns.
*/
USE MotoGP;
GO
SET XACT_ABORT ON;

DECLARE @CircuitSeed TABLE (
    circuit_name NVARCHAR(150) NOT NULL,
    country_code CHAR(3) NOT NULL,
    locality NVARCHAR(100) NOT NULL,
    PRIMARY KEY (country_code, circuit_name)
);

INSERT INTO @CircuitSeed (circuit_name, country_code, locality)
VALUES
    (N'Autódromo Oscar y Juan Gálvez', 'ARG', N'Buenos Aires'),
    (N'Autódromo Termas de Río Hondo', 'ARG', N'Termas de Río Hondo'),
    (N'Phillip Island Grand Prix Circuit', 'AUS', N'Phillip Island, Victoria'),
    (N'Sydney Motorsport Park', 'AUS', N'Eastern Creek, New South Wales'),
    (N'Red Bull Ring', 'AUT', N'Spielberg'),
    (N'Salzburgring', 'AUT', N'Plainfeld'),
    (N'Circuit Zolder', 'BEL', N'Heusden-Zolder'),
    (N'Circuit de Spa-Francorchamps', 'BEL', N'Stavelot'),
    (N'Autódromo Internacional Ayrton Senna', 'BRA', N'Goiânia'),
    (N'Autódromo Internacional Nelson Piquet', 'BRA', N'Jacarepaguá, Rio de Janeiro'),
    (N'Autódromo José Carlos Pace', 'BRA', N'São Paulo'),
    (N'Canadian Tire Motorsport Park', 'CAN', N'Bowmanville, Ontario'),
    (N'Bremgarten Circuit', 'CHE', N'Bern'),
    (N'Circuit des Nations', 'CHE', N'Geneva'),
    (N'Shanghai International Circuit', 'CHN', N'Jiading, Shanghai'),
    (N'Automotodrom Brno', 'CZE', N'Brno'),
    (N'Brno Road Circuit', 'CZE', N'Brno'),
    (N'Hockenheimring', 'DEU', N'Hockenheim'),
    (N'Nürburgring', 'DEU', N'Nürburg'),
    (N'Sachsenring', 'DEU', N'Hohenstein-Ernstthal'),
    (N'Schottenring', 'DEU', N'Schotten'),
    (N'Solitudering', 'DEU', N'Stuttgart'),
    (N'Circuit Ricardo Tormo', 'ESP', N'Cheste'),
    (N'Circuit de Barcelona-Catalunya', 'ESP', N'Montmeló'),
    (N'Circuito de Jerez - Ángel Nieto', 'ESP', N'Jerez de la Frontera'),
    (N'Circuito del Jarama', 'ESP', N'San Sebastián de los Reyes'),
    (N'Montjuïc Circuit', 'ESP', N'Barcelona'),
    (N'MotorLand Aragón', 'ESP', N'Alcañiz'),
    (N'Imatra Circuit', 'FIN', N'Imatra'),
    (N'Pyynikki Circuit', 'FIN', N'Tampere'),
    (N'Bugatti Circuit', 'FRA', N'Le Mans'),
    (N'Circuit Paul Armagnac', 'FRA', N'Nogaro'),
    (N'Circuit Paul Ricard', 'FRA', N'Le Castellet'),
    (N'Circuit de Charade', 'FRA', N'Saint-Genès-Champanelle'),
    (N'Circuit de Nevers Magny-Cours', 'FRA', N'Magny-Cours'),
    (N'Circuit des Planques', 'FRA', N'Albi'),
    (N'Reims-Gueux', 'FRA', N'Gueux'),
    (N'Rouen-les-Essarts', 'FRA', N'Grand-Couronne and Orival'),
    (N'Clady Circuit', 'GBR', N'County Antrim, Northern Ireland'),
    (N'Donington Park', 'GBR', N'Castle Donington, England'),
    (N'Dundrod Circuit', 'GBR', N'County Antrim, Northern Ireland'),
    (N'Silverstone Circuit', 'GBR', N'Silverstone, England'),
    (N'Automotodrom Grobnik', 'HRV', N'Čavle, near Rijeka'),
    (N'Opatija Circuit', 'HRV', N'Preluk, Opatija'),
    (N'Balaton Park Circuit', 'HUN', N'Balatonfőkajár'),
    (N'Hungaroring', 'HUN', N'Mogyoród'),
    (N'Mandalika International Circuit', 'IDN', N'Mandalika, Lombok'),
    (N'Sentul International Circuit', 'IDN', N'Sentul, Bogor'),
    (N'Clypse Course', 'IMN', N'Onchan and Douglas'),
    (N'Snaefell Mountain Course', 'IMN', N'Isle of Man'),
    (N'Buddh International Circuit', 'IND', N'Greater Noida'),
    (N'Autodromo Enzo e Dino Ferrari', 'ITA', N'Imola'),
    (N'Autodromo Nazionale Monza', 'ITA', N'Monza'),
    (N'Misano World Circuit Marco Simoncelli', 'ITA', N'Misano Adriatico'),
    (N'Mugello Circuit', 'ITA', N'Scarperia e San Piero'),
    (N'Fuji Speedway', 'JPN', N'Oyama'),
    (N'Mobility Resort Motegi', 'JPN', N'Motegi'),
    (N'Suzuka International Racing Course', 'JPN', N'Suzuka'),
    (N'Johor Circuit', 'MYS', N'Pasir Gudang'),
    (N'Sepang International Circuit', 'MYS', N'Sepang'),
    (N'Shah Alam Circuit', 'MYS', N'Shah Alam'),
    (N'TT Circuit Assen', 'NLD', N'Assen'),
    (N'Algarve International Circuit', 'PRT', N'Portimão'),
    (N'Circuito do Estoril', 'PRT', N'Estoril'),
    (N'Lusail International Circuit', 'QAT', N'Lusail'),
    (N'Hedemora Circuit', 'SWE', N'Hedemora'),
    (N'Karlskoga Motorstadion', 'SWE', N'Karlskoga'),
    (N'Råbelövsbanan', 'SWE', N'Kristianstad'),
    (N'Scandinavian Raceway', 'SWE', N'Anderstorp'),
    (N'Chang International Circuit', 'THA', N'Buriram'),
    (N'Istanbul Park', 'TUR', N'Tuzla, Istanbul'),
    (N'Circuit of the Americas', 'USA', N'Austin, Texas'),
    (N'Daytona International Speedway', 'USA', N'Daytona Beach, Florida'),
    (N'Indianapolis Motor Speedway', 'USA', N'Speedway, Indiana'),
    (N'Laguna Seca Raceway', 'USA', N'Monterey County, California'),
    (N'San Carlos Circuit', 'VEN', N'San Carlos'),
    (N'Kyalami Grand Prix Circuit', 'ZAF', N'Midrand'),
    (N'Phakisa Freeway', 'ZAF', N'Welkom area, Free State');

BEGIN TRY
    BEGIN TRANSACTION;

    -- Extend the shared country/territory lookup for the two TT courses.
    INSERT INTO dbo.countries (country_name, country_code)
    SELECT N'Isle of Man', 'IMN'
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.countries WHERE country_code = 'IMN'
    );

    -- Check before joining: otherwise an INNER JOIN silently drops missing codes.
    IF EXISTS (
        SELECT 1 FROM @CircuitSeed AS s
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.countries AS c
            WHERE c.country_code = s.country_code
        )
    )
    BEGIN
        SELECT DISTINCT s.country_code AS missing_country_code
        FROM @CircuitSeed AS s
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.countries AS c
            WHERE c.country_code = s.country_code
        );
        THROW 50001, 'Missing countries. Run the country expansion script first.', 1;
    END;

    IF OBJECT_ID(N'dbo.circuits', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.circuits (
            circuit_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            circuit_name NVARCHAR(150) NOT NULL,
            country_id INT NOT NULL,
            locality NVARCHAR(100) NULL,
            CONSTRAINT FK_circuits_countries FOREIGN KEY (country_id)
                REFERENCES dbo.countries(country_id)
        );
    END;

    -- Keep one row per canonical name within a country.
    IF EXISTS (
        SELECT 1 FROM dbo.circuits
        GROUP BY country_id, circuit_name HAVING COUNT(*) > 1
    )
        THROW 50002, 'Existing duplicate circuit names found; reconcile them first.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.circuits')
          AND name = N'UX_circuits_country_name'
    )
        CREATE UNIQUE INDEX UX_circuits_country_name
            ON dbo.circuits(country_id, circuit_name);

    INSERT INTO dbo.circuits (circuit_name, country_id, locality)
    SELECT s.circuit_name, c.country_id, s.locality
    FROM @CircuitSeed AS s
    INNER JOIN dbo.countries AS c ON c.country_code = s.country_code
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.circuits AS existing
        WHERE existing.circuit_name = s.circuit_name
          AND existing.country_id = c.country_id
    );

    DECLARE @CircuitsAdded INT = @@ROWCOUNT;
    COMMIT TRANSACTION;

    SELECT @CircuitsAdded AS circuits_added;

    -- This should return 78, even when the database holds additional circuits.
    SELECT COUNT(*) AS scoped_circuits_present
    FROM @CircuitSeed AS s
    INNER JOIN dbo.countries AS co ON co.country_code = s.country_code
    INNER JOIN dbo.circuits AS ci
        ON ci.country_id = co.country_id AND ci.circuit_name = s.circuit_name;

    SELECT ci.circuit_id, ci.circuit_name, co.country_name, co.country_code,
           ci.locality
    FROM dbo.circuits AS ci
    INNER JOIN dbo.countries AS co ON co.country_id = ci.country_id
    ORDER BY co.country_name, ci.circuit_name;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/* EVIDENCE AND RECONCILIATION
Accessed 11 October 2026. API source labels are NOT safe import keys alone.
Catalogue cross-check (not used for future rows):
https://en.wikipedia.org/wiki/List_of_Grand_Prix_motorcycle_circuits

Corrections to the raw MotoGP API:
1. Belfast -> Clady (1949-1952), Dundrod (1953-1971), GBR rather than IRL.
   https://ulstergrandprix.net/facts-behind-worlds-fastest-road-race/
2. Berne -> Bremgarten, except the 1950 Swiss GP at Geneva/Circuit des Nations.
   https://en.wikipedia.org/wiki/1950_Swiss_motorcycle_Grand_Prix
3. Spa-Francorchamps -> Zolder for the 1980 Belgian GP.
   https://www.motorsportmagazine.com/database/races/1980-belgian-motogp/
4. Brno -> road course through 1982; modern Automotodrom from 1987.
   https://www.motogpczechia.com/en/history
5. Isle of Man: add Clypse, used by 125cc (1954-1959), 250cc (1955-1959).
   https://www.iomtt.com/tt-database/courses?cour_code=CLY&era=&eraH=&eraL=&meet_code=TC55++
   https://www.gov.im/about-the-government/departments/cabinet-office/media-centre/isle-of-man-an-overview/
6. The 1954 French GP was at Reims, not Rouen as shown in the event API.
   https://racingmemo.fr/M%20FRANCE/MOTO%20FRANCE%201954.htm
7. Silverstone 2018: event existed, but no championship races took place.
   https://www.motogp.com/en/videos/2018/08/26/whats-the-situation-at-silverstone/61574
   Do not infer raced years from the event FINISHED flag alone.

Naming notes (aliases to map during future imports, not extra circuits):
Eastern Creek = Sydney Motorsport Park.
Mosport = Canadian Tire Motorsport Park.
Interlagos = Autodromo Jose Carlos Pace.
Jacarepagua = Nelson Piquet circuit in Rio; not Brasilia's similarly named track.
Fisco = Fuji Speedway. Tampere = Pyynikki. Kristianstad = Rabelovsbanan.
Rijeka = Grobnik. Opatija = Preluk. Clermont-Ferrand = Charade.
Nogaro = Paul Armagnac. Le Mans = Bugatti (not Circuit de la Sarthe).
Losail = Lusail. Twin Ring Motegi = Mobility Resort Motegi.
A1-Ring = Red Bull Ring; retain specific configurations in circuit_layouts.
Balaton Park is not the unbuilt Balatonring project.
Sachsenring's road course and modern configurations share a venue-family row.
Nurburgring's distinct named configurations must be separate layout records.

Per-record evidence. The event feed demonstrates a source venue label;
the corrections above resolve merged labels and historical mappings.
Source IDs are provided for provenance, not recommended as database PKs.

Autódromo Oscar y Juan Gálvez | ARG | Buenos Aires
API label: Oscar A. Galvez | ID: a13e1e6b-6643-4d7b-9b41-f372158ab5f6
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=690cd02f-f143-4efd-9198-05bbd64bb86a

Autódromo Termas de Río Hondo | ARG | Termas de Río Hondo
API label: Termas de Río Hondo | ID: 536d88a0-b7b9-4312-a5f1-f196e8228991
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=bf5c15b5-f062-4a88-a304-29892743108d

Phillip Island Grand Prix Circuit | AUS | Phillip Island, Victoria
API label: Phillip Island | ID: d4629be0-3742-4950-af2e-2807562d6cb8
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=e6dac447-28af-4394-a570-93d33d138cc9

Sydney Motorsport Park | AUS | Eastern Creek, New South Wales
API label: Eastern Creek | ID: cae551af-fb5d-49f1-9c31-6a27adcb22e1
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=af5f5823-349b-40ba-b3a5-4ecd9f7f167e

Red Bull Ring | AUT | Spielberg
API label: Red Bull Ring - Spielberg | ID: 8dc64efd-25f8-41cf-aa4f-dfbfa41a762a
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=907eee47-4666-4cd4-b41e-b2278821b8f3

Salzburgring | AUT | Plainfeld
API label: Salzburgring | ID: 8a080d54-7fc9-4033-833b-f9c84b87108f
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=14cd72be-713f-474d-a6af-cc57ca58f252

Circuit Zolder | BEL | Heusden-Zolder
https://www.motorsportmagazine.com/database/races/1980-belgian-motogp/

Circuit de Spa-Francorchamps | BEL | Stavelot
API label: Spa-Francorchamps | ID: 1eedf3e4-d9ab-427e-977f-306d8ccc0f99
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=72de1fab-255c-4b9a-9d4b-79ce47ab61c5

Autódromo Internacional Ayrton Senna | BRA | Goiânia
API label: Autódromo Internacional de Goiânia - Ayrton Senna | ID: dc7c629b-f6e2-410e-860a-1ca0f28beb8f
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=1b77d8dc-001c-40cc-8a71-8ccd5ef96214

Autódromo Internacional Nelson Piquet | BRA | Jacarepaguá, Rio de Janeiro
API label: Nelson Piquet | ID: 87692c07-fcd6-4331-822e-511dc651f40c
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=5518c28f-48db-423f-8241-b2fe0654ee19

Autódromo José Carlos Pace | BRA | São Paulo
API label: Interlagos | ID: f390f718-9484-47d7-834f-3814a335af48
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=7163a8f0-30a6-4265-99af-d0f8d8002265

Canadian Tire Motorsport Park | CAN | Bowmanville, Ontario
API label: Mosport | ID: 7e464769-be25-4dfc-b836-bb35d7f52f0c
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=7b04bc94-fa67-472b-88cf-76563ebd5be6

Bremgarten Circuit | CHE | Bern
API label: Berne | ID: b7b4282a-1020-4eb1-a818-26bc60571cd2
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=72de1fab-255c-4b9a-9d4b-79ce47ab61c5

Circuit des Nations | CHE | Geneva
https://en.wikipedia.org/wiki/1950_Swiss_motorcycle_Grand_Prix

Shanghai International Circuit | CHN | Jiading, Shanghai
API label: Shanghai Circuit | ID: 7cf41263-c38c-4942-ab09-9ac74339c3ec
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=6b581433-8531-4c5b-afca-15c7eb27e809

Automotodrom Brno | CZE | Brno
API label: CREDITAS Autodrom Brno | ID: b8664e71-95a8-4c71-b093-96a23fa839df
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=1b77d8dc-001c-40cc-8a71-8ccd5ef96214

Brno Road Circuit | CZE | Brno
https://www.motogpczechia.com/en/history

Hockenheimring | DEU | Hockenheim
API label: Hockenheim | ID: 8f36dd44-e059-4f26-b2b9-2a54105c914a
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=fdbe09f1-381c-43eb-bdf0-c035068f3f32

Nürburgring | DEU | Nürburg
API label: Nurburgring | ID: 1bec7bcc-4e82-4dab-a21a-dc02029cda22
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=e93dc09a-1035-4c14-bd0e-0ae762aad51b

Sachsenring | DEU | Hohenstein-Ernstthal
API label: Sachsenring | ID: 551f87c7-1940-48b0-bce7-1ad8de7ce548
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=690cd02f-f143-4efd-9198-05bbd64bb86a

Schottenring | DEU | Schotten
API label: Schotten | ID: 5f9e2ac9-89a3-4404-b113-7933bbba756c
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=f3cd4e65-3deb-4fac-9755-3360324b2bed

Solitudering | DEU | Stuttgart
API label: Solitude | ID: 2312f6e1-a391-4540-8824-d70b8cd5cabf
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=fbfa8959-79b0-4ec1-8ae1-d9082d0233da

Circuit Ricardo Tormo | ESP | Cheste
API label: Circuit Ricardo Tormo | ID: 664c40ff-8deb-4613-91cd-62c945f95e1e
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=2fd3e95f-5aca-46ba-a8f3-513a36f304b9

Circuit de Barcelona-Catalunya | ESP | Montmeló
API label: Circuit de Barcelona-Catalunya | ID: 2218098d-ab2d-498b-a633-1a4a39119e9e
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=7163a8f0-30a6-4265-99af-d0f8d8002265

Circuito de Jerez - Ángel Nieto | ESP | Jerez de la Frontera
API label: Circuito de Jerez - Ángel Nieto | ID: 763812ea-9435-4c1c-b61b-a0c14ccdfbe4
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=1b77d8dc-001c-40cc-8a71-8ccd5ef96214

Circuito del Jarama | ESP | San Sebastián de los Reyes
API label: Jarama | ID: 9b212708-9bb8-4de1-abe0-9f669d88ba13
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=3826b414-4a3b-4674-90e1-94f7ff3dc9bc

Montjuïc Circuit | ESP | Barcelona
API label: Montjuïc | ID: 64d6fb8c-124f-47c5-8f48-4fe54c07b1b0
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=296ab92c-cd8d-48ba-ace1-aad1455d557f

MotorLand Aragón | ESP | Alcañiz
API label: MotorLand Aragón | ID: 50209e25-6cd8-4d8d-912e-c48a06275a8a
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=d5bd3042-f4dc-4fdc-897a-e284d07592e6

Imatra Circuit | FIN | Imatra
API label: Imatra | ID: 9f1648b1-dd2f-4c12-b77d-da8471ec213a
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=3ff1f0bb-074a-4a8b-94b7-eb536c6589ff

Pyynikki Circuit | FIN | Tampere
API label: Tampere | ID: 52739ea8-bf8f-477f-8ad9-7166ed6eaf30
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=03b2bfac-203c-4b1f-8656-0cbb8c6d7961

Bugatti Circuit | FRA | Le Mans
API label: Le Mans | ID: ebb41e75-8664-4dfd-b0eb-07f24bd5fb92
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=3826b414-4a3b-4674-90e1-94f7ff3dc9bc

Circuit Paul Armagnac | FRA | Nogaro
API label: Nogaro | ID: 8e60a2ef-0e86-4b9b-8811-d0b90a4f0e5a
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=2ab6e465-bc0d-40a5-be66-fe0dbf0e6ab2

Circuit Paul Ricard | FRA | Le Castellet
API label: Paul Ricard | ID: f1bea708-8bf5-4a9e-91dd-99470f243326
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=e39a9e8b-7aa8-4d8d-9372-91091f15d98b

Circuit de Charade | FRA | Saint-Genès-Champanelle
API label: Clermont-Ferrand | ID: 570e8988-3fdc-4448-a8c6-b381ae8730fa
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=438fc379-7133-47fa-9b73-d8d217f42b88

Circuit de Nevers Magny-Cours | FRA | Magny-Cours
API label: Magny Cours | ID: 8310ec39-81b4-4927-98ec-3e2bdcee3fc7
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=7163a8f0-30a6-4265-99af-d0f8d8002265

Circuit des Planques | FRA | Albi
API label: Albi | ID: 688795b3-046a-4bba-ba29-050a4f64a735
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=296ab92c-cd8d-48ba-ace1-aad1455d557f

Reims-Gueux | FRA | Gueux
API label: Reims | ID: 0ed955ff-4426-4fff-8a8a-37539a104dfd
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=c8497a73-5ac9-4e4d-bc69-3e0bd93d7907

Rouen-les-Essarts | FRA | Grand-Couronne and Orival
API label: Rouen | ID: c68101ba-d1cb-4d9b-a21b-f37be44d23e8
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=f3cd4e65-3deb-4fac-9755-3360324b2bed

Clady Circuit | GBR | County Antrim, Northern Ireland
API label: Belfast | ID: 9ae160e2-4b50-4a78-8b2b-db3ddecb36a3
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=72de1fab-255c-4b9a-9d4b-79ce47ab61c5

Donington Park | GBR | Castle Donington, England
API label: Donington Park | ID: 3aa5bcb2-519e-44d7-b3da-bb8f89763a59
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=1b77d8dc-001c-40cc-8a71-8ccd5ef96214

Dundrod Circuit | GBR | County Antrim, Northern Ireland
https://ulstergrandprix.net/facts-behind-worlds-fastest-road-race/

Silverstone Circuit | GBR | Silverstone, England
API label: Silverstone Circuit | ID: 473ee5fa-b4e5-4c00-a0fe-28051700e20d
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=f64bbe89-30bb-461c-acdc-cca30b21fed7

Automotodrom Grobnik | HRV | Čavle, near Rijeka
API label: Rijeka | ID: 9d5f4ae2-f597-4f74-8171-9abd272912e8
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=2ab6e465-bc0d-40a5-be66-fe0dbf0e6ab2

Opatija Circuit | HRV | Preluk, Opatija
API label: Opatija | ID: a8993a35-d28c-4d61-8fa9-58a42131826c
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=3826b414-4a3b-4674-90e1-94f7ff3dc9bc

Balaton Park Circuit | HUN | Balatonfőkajár
API label: Balaton Park Circuit | ID: c2119f01-e758-41a7-a721-d5baec22deb9
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=ae6c6f0d-c652-44f8-94aa-420fc5b3dab4

Hungaroring | HUN | Mogyoród
API label: Hungaroring | ID: 66e50713-edd4-4429-8c5c-573d7cabb9c6
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=79ccac73-5093-489c-9d37-e77a005723f9

Mandalika International Circuit | IDN | Mandalika, Lombok
API label: Pertamina Mandalika Circuit | ID: a1ec6331-c571-418c-92d7-768cf0c83872
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=db8dc197-c7b2-4c1b-b3a4-6dc534c014ef

Sentul International Circuit | IDN | Sentul, Bogor
API label: Sentul | ID: 64179411-7382-4e6c-901f-808388dfee39
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=907eee47-4666-4cd4-b41e-b2278821b8f3

Clypse Course | IMN | Onchan and Douglas
https://www.iomtt.com/tt-database/courses?cour_code=CLY&era=&eraH=&eraL=&meet_code=TC55++

Snaefell Mountain Course | IMN | Isle of Man
API label: Isle of Man | ID: 62cf7a47-b21e-4dd5-8901-fbfb04615619
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=72de1fab-255c-4b9a-9d4b-79ce47ab61c5

Buddh International Circuit | IND | Greater Noida
API label: Buddh International Circuit | ID: ab56759b-8c77-468a-8442-88d712344d30
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=db8dc197-c7b2-4c1b-b3a4-6dc534c023ef

Autodromo Enzo e Dino Ferrari | ITA | Imola
API label: Imola | ID: d6e37cde-40ea-460e-8bec-58378213f858
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=3826b414-4a3b-4674-90e1-94f7ff3dc9bc

Autodromo Nazionale Monza | ITA | Monza
API label: Monza | ID: 05dad63d-0746-4309-a4b4-2527f9cecf36
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=72de1fab-255c-4b9a-9d4b-79ce47ab61c5

Misano World Circuit Marco Simoncelli | ITA | Misano Adriatico
API label: Misano World Circuit Marco Simoncelli | ID: e0d07d48-0b62-40fa-9d36-411b15af406f
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=a6215585-eab4-4100-9b8a-365f4e056805

Mugello Circuit | ITA | Scarperia e San Piero
API label: Autodromo Internazionale del Mugello | ID: 1ab286fc-eb24-4980-85a8-b7b940f46e13
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=357e99b8-cc05-4fcd-b11d-2edfbb019809

Fuji Speedway | JPN | Oyama
API label: Fisco | ID: 6f69c0e3-bb0d-4a7c-a11f-6709a914fc78
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=05f340dd-61dd-4673-b1a9-1ec6d92b93e3

Mobility Resort Motegi | JPN | Motegi
API label: Mobility Resort Motegi | ID: 213eb1ff-9ae5-4aec-862f-44a10637f36d
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=2fd3e95f-5aca-46ba-a8f3-513a36f304b9

Suzuka International Racing Course | JPN | Suzuka
API label: Suzuka | ID: 7afbea7d-97c1-4c75-be49-73a3054625bd
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=473191ae-cd39-443c-bf30-920403670c07

Johor Circuit | MYS | Pasir Gudang
API label: Johor | ID: 67c3d756-1f42-49b1-8f43-8f705e734198
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=a61f83c3-8a0f-446f-b48e-b468fb5c6476

Sepang International Circuit | MYS | Sepang
API label: Petronas Sepang International Circuit | ID: f5a7f3f8-0097-4810-a2da-eee749aedc77
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=2fd3e95f-5aca-46ba-a8f3-513a36f304b9

Shah Alam Circuit | MYS | Shah Alam
API label: Shah Alam | ID: c7272655-3ec7-4d68-8753-eacf45fd151d
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=af5f5823-349b-40ba-b3a5-4ecd9f7f167e

TT Circuit Assen | NLD | Assen
API label: TT Circuit Assen | ID: f4f9b0e8-1319-4d4f-a5ae-6cf193b01fca
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=72de1fab-255c-4b9a-9d4b-79ce47ab61c5

Algarve International Circuit | PRT | Portimão
API label: Autódromo Internacional do Algarve | ID: 912a9d7f-2864-4311-bebb-19851e9c2620
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=fa729c5c-a34a-40b9-8ebf-2578d9433517

Circuito do Estoril | PRT | Estoril
API label: Estoril Circuit | ID: 9450a597-8854-46a6-a6d1-514d4e224915
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=ef1e2970-0ff9-4933-95ac-404845820462

Lusail International Circuit | QAT | Lusail
API label: Lusail International Circuit | ID: e9a71399-cea9-400a-b2ef-48bfdcdf6526
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=6c0e0734-0e32-4c4a-9987-0439449543ab

Hedemora Circuit | SWE | Hedemora
API label: Hedemora | ID: 3d40085a-cb5a-4a69-8595-f96c769e6c15
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=cb64a721-de5b-4fc4-a543-b15c5e5dcf6a

Karlskoga Motorstadion | SWE | Karlskoga
API label: Karlskoga | ID: 73b1ab9d-c48e-4693-b553-f27571b8995f
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=2ab6e465-bc0d-40a5-be66-fe0dbf0e6ab2

Råbelövsbanan | SWE | Kristianstad
API label: Kristianstad | ID: 36cf4aec-3716-4ca8-b164-a83389a93fc2
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=438fc379-7133-47fa-9b73-d8d217f42b88

Scandinavian Raceway | SWE | Anderstorp
API label: Anderstorp | ID: da028e07-b827-4ba9-a1f9-f65370953895
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=14cd72be-713f-474d-a6af-cc57ca58f252

Chang International Circuit | THA | Buriram
API label: Chang International Circuit | ID: a8bd93f8-8e7e-4669-ae1c-1f3f5156b4e7
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=c0844c71-783c-4f86-abce-a9a67adcc1a9

Istanbul Park | TUR | Tuzla, Istanbul
API label: Istanbul Park Circuit | ID: bb0d1bba-a278-46ee-808b-7383b3b36cd8
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=6b581433-8531-4c5b-afca-15c7eb27e809

Circuit of the Americas | USA | Austin, Texas
API label: Circuit Of The Americas | ID: 5b97d826-e527-43e9-b696-09f61cf4559c
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=a0def534-ce1b-492c-bc46-e87e95d28230

Daytona International Speedway | USA | Daytona Beach, Florida
API label: Daytona | ID: 53408041-6360-4860-8009-b799ca10e59c
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=3ff1f0bb-074a-4a8b-94b7-eb536c6589ff

Indianapolis Motor Speedway | USA | Speedway, Indiana
API label: Indianapolis Motor Speedway | ID: d679bc52-d9b4-4385-a480-910f02b90389
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=46e254dc-f6d6-402c-b7c8-8e7c14469678

Laguna Seca Raceway | USA | Monterey County, California
API label: Mazda Raceway | ID: 6ea50617-1b69-4b00-850c-a95ad1776e71
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=b9332591-9e09-441e-938b-9396daf74930

San Carlos Circuit | VEN | San Carlos
API label: San Carlos | ID: 5ff3aec4-4352-45ba-82ed-1bfdbdf8bc15
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=f64bbe89-30bb-461c-acdc-cca30b21fed7

Kyalami Grand Prix Circuit | ZAF | Midrand
API label: Kyalami | ID: 33cc8011-c4b5-419a-81ff-b0140acfedd5
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=17a1aefb-dd07-4fb9-bf03-05e1efd28435

Phakisa Freeway | ZAF | Welkom area, Free State
API label: Phakisa Freeway | ID: 7a575fc7-3c80-49a2-8e5e-90f65a699057
https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=2fd3e95f-5aca-46ba-a8f3-513a36f304b9
*/
