/* MotoGP country/territory reference seed -- researched 2026-10-11.
Run in a SQL file connected to SQL Server, not in PowerShell.
Assumes dbo.countries(country_id IDENTITY, country_name, country_code).

Scope: solo GP championship classes 1949-2026, including historical
50cc/80cc/125cc/250cc/350cc/500cc and MotoGP/Moto2/Moto3/MotoE.
Sidecar participation was not audited.

THIS IS A RESEARCHED LOOKUP SEED, NOT A CERTIFIED EXHAUSTIVE PARTICIPATION LIST.
Lookup membership is not itself evidence that a country was represented.

Audit of MotoGP's public results API: 303 season/class standings queried;
8709 rider-season rows; 51 nonempty country codes; 316 rows missing country;
19 standings responses empty. Older standings omit zero-point riders.
Some historic nationalities are normalized to modern countries in this API.
Supplementary sources identify further countries and historical labels.
Hong Kong is retained for rider origin/birthplace coverage: race sources may
record a Hong Kong rider under China. Verify race nationality separately.

Current codes follow ISO alpha-3 convention. The six historical codes below
are explicit PROJECT KEYS; do not interpret the whole column as current ISO.
FRG and RHO in particular are project conventions. Source racing codes such
as GER, SPA, NED and SUI need a mapping to DEU, ESP, NLD and CHE when importing.

The insert preserves existing IDs and inserts only absent codes.
A conflicting existing country name/code causes a constraint error rather
than overwriting data. Check such conflicts before changing existing rows.
*/
USE MotoGP;
GO

INSERT INTO dbo.countries (country_name, country_code)
SELECT seed.country_name, seed.country_code
FROM (VALUES
    (N'Algeria', 'DZA'),
    (N'Andorra', 'AND'),
    (N'Argentina', 'ARG'),
    (N'Australia', 'AUS'),
    (N'Austria', 'AUT'),
    (N'Belgium', 'BEL'),
    (N'Brazil', 'BRA'),
    (N'Bulgaria', 'BGR'),
    (N'Canada', 'CAN'),
    (N'Chile', 'CHL'),
    (N'China', 'CHN'),
    (N'Colombia', 'COL'),
    (N'Croatia', 'HRV'),
    (N'Cuba', 'CUB'),
    (N'Czechia', 'CZE'),
    (N'Denmark', 'DNK'),
    (N'Finland', 'FIN'),
    (N'France', 'FRA'),
    (N'Germany', 'DEU'),
    (N'Gibraltar', 'GIB'),
    (N'Guatemala', 'GTM'),
    (N'Hong Kong', 'HKG'),
    (N'Hungary', 'HUN'),
    (N'India', 'IND'),
    (N'Indonesia', 'IDN'),
    (N'Ireland', 'IRL'),
    (N'Italy', 'ITA'),
    (N'Japan', 'JPN'),
    (N'Kazakhstan', 'KAZ'),
    (N'Luxembourg', 'LUX'),
    (N'Malaysia', 'MYS'),
    (N'Mexico', 'MEX'),
    (N'Monaco', 'MCO'),
    (N'Netherlands', 'NLD'),
    (N'New Zealand', 'NZL'),
    (N'Norway', 'NOR'),
    (N'Poland', 'POL'),
    (N'Portugal', 'PRT'),
    (N'Qatar', 'QAT'),
    (N'Romania', 'ROU'),
    (N'Russia', 'RUS'),
    (N'San Marino', 'SMR'),
    (N'Slovakia', 'SVK'),
    (N'Slovenia', 'SVN'),
    (N'South Africa', 'ZAF'),
    (N'Spain', 'ESP'),
    (N'Sweden', 'SWE'),
    (N'Switzerland', 'CHE'),
    (N'Thailand', 'THA'),
    (N'Turkey', 'TUR'),
    (N'Ukraine', 'UKR'),
    (N'United Kingdom', 'GBR'),
    (N'United States', 'USA'),
    (N'Uruguay', 'URY'),
    (N'Venezuela', 'VEN'),
    (N'Zimbabwe', 'ZWE'),
    -- Historical entities: project-defined keys, not current ISO codes.
    (N'Czechoslovakia', 'CSK'),
    (N'East Germany', 'DDR'),
    (N'West Germany', 'FRG'),
    (N'Rhodesia', 'RHO'),
    (N'Soviet Union', 'SUN'),
    (N'Yugoslavia', 'YUG')
) AS seed(country_name, country_code)
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.countries AS existing
    WHERE existing.country_code = seed.country_code
);

SELECT @@ROWCOUNT AS countries_added;

SELECT country_id, country_name, country_code
FROM dbo.countries
ORDER BY country_name;
GO

/* Research provenance (read-only reference URLs):
API season catalogue:
https://api.motogp.pulselive.com/motogp/v1/results/seasons
Supplementary sources:
India:
https://www.motogp.com/id/news/2023/09/19/un-pas-de-geant-du-motogp-dans-le-nouveau-monde-par-nick-harris/478366
China (race nationality CHN for Cheung Wai On):
https://www.roadracingworld.com/news/rossi-wins-motogp-world-championship-at-sepang/
Hong Kong (origin, not independently certified as race nationality):
https://www.scmp.com/article/499010/local-hero-hopes-ride-will-attract-sponsors
Croatia and Slovakia (zero-point riders):
https://www.motoplanete.us/sport/detailed-ranking/4-125cc/2009/0/page.html
Slovenia (Luka Nedog wildcard entry):
https://www.crash.net/motogp/news/72879/1/hofmann-heads-brno-wild-cards
Historical labels:
https://en.wikipedia.org/wiki/1968_Grand_Prix_motorcycle_racing_season
https://www.motogp.com/en/legends
https://en.wikipedia.org/wiki/1963_Grand_Prix_motorcycle_racing_season

One example per nonempty API country code follows. These are SOURCE LABELS,
not verified historical nationality assignments. Do not copy them directly
onto historical race entries without checking the event source.
AD: Andorra | Xavi Cardelus | 2024 | Moto2™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=dd12382e-1d9f-46ee-a5f7-c5104db28e43&categoryUuid=549640b8-fd9c-4245-acfd-60e4bc38b25c
AR: Argentina | Marco Morelli | 2026 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
AT: Austria | Leo Rammerstorfer | 2026 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
AU: Australia | Jack Miller | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
BE: Belgium | Barry Baltus | 2026 | Moto2™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=549640b8-fd9c-4245-acfd-60e4bc38b25c
BG: Bulgaria | Bogdan Nikolov | 1989 | 80cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e6dac447-28af-4394-a570-93d33d138cc9&categoryUuid=9169fbb9-6ca5-402a-8388-788a9288c560
BR: Brazil | Diogo Moreira | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
CA: Canada | Miguel Duhamel | 1992 | 500cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=7163a8f0-30a6-4265-99af-d0f8d8002265&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
CH: Switzerland | Noah Dettwiler | 2025 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=ae6c6f0d-c652-44f8-94aa-420fc5b3dab4&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
CL: Chile | Vincenzo Cascino | 1981 | 350cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=8a939600-760d-440f-8e45-0c18d73631e1&categoryUuid=211afccf-202f-4643-beb2-471646cfd0d3
CO: Colombia | David Alonso | 2026 | Moto2™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=549640b8-fd9c-4245-acfd-60e4bc38b25c
CU: Cuba | J. Lazo | 1979 | 250cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=6339eb76-3390-4312-8c83-43a9512c8c25&categoryUuid=008a50a7-e302-44ba-b468-7e9999324c64
CZ: Czechia | Filip Salac | 2026 | Moto2™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=549640b8-fd9c-4245-acfd-60e4bc38b25c
DE: Germany | Jonas Folger | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
DK: Denmark | Robbin Harms | 2003 | 125cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=632718a6-f1fe-4f5a-b95d-03b8e7635d70&categoryUuid=2391edcb-13be-4389-8627-5a5c3f967e85
DZ: Algeria | Bady Hassaine | 1989 | 125cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e6dac447-28af-4394-a570-93d33d138cc9&categoryUuid=2391edcb-13be-4389-8627-5a5c3f967e85
ES: Spain | Jorge Martin | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
FI: Finland | Rico Salmela | 2026 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
FR: France | Fabio Quartararo | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
GB: United Kingdom of Great Britain and Northern Ireland | Cal Crutchlow | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
GI: Gibraltar | Johnny Grace | 1963 | 125cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=473191ae-cd39-443c-bf30-920403670c07&categoryUuid=2391edcb-13be-4389-8627-5a5c3f967e85
GT: Guatemala | Ivan Schuman | 1963 | 250cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=473191ae-cd39-443c-bf30-920403670c07&categoryUuid=008a50a7-e302-44ba-b468-7e9999324c64
HU: Hungary | Tibor Varga | 2025 | MotoE™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=ae6c6f0d-c652-44f8-94aa-420fc5b3dab4&categoryUuid=3bda82ba-0445-440c-9375-cd48d777bd95
ID: Indonesia | Veda Pratama | 2026 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
IE: Ireland | Casey O'gorman | 2026 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
IT: Italy | Marco Bezzecchi | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
JP: Japan | Ai Ogura | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
KZ: Kazakhstan | Makar Yurchenko | 2019 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=cbc5dc8d-3aae-4327-bd88-d1cdeea9b654&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
LU: Luxembourg | Andy Leuthe | 1991 | 500cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=af5f5823-349b-40ba-b3a5-4ecd9f7f167e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
MC: Monaco | Jean Louis Pasquier | 1970 | 125cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=fea3cb28-5c7c-4888-8dae-6e851259775a&categoryUuid=2391edcb-13be-4389-8627-5a5c3f967e85
MX: Mexico | Gabriel Martinez-abrego | 2017 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e24e8a8c-4673-498d-86e0-731581d7c586&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
MY: Malaysia | Hakim Danish | 2026 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
NL: Netherlands | Collin Veijer | 2026 | Moto2™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=549640b8-fd9c-4245-acfd-60e4bc38b25c
NO: Norway | Sturla Fagerhaug | 2011 | 125cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=b6cf5327-3c57-41d6-874c-bf330fcfc0fc&categoryUuid=2391edcb-13be-4389-8627-5a5c3f967e85
NZ: New Zealand | Cormac Buchanan | 2026 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
PL: Poland | Milan Pawelec | 2026 | Moto2™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=549640b8-fd9c-4245-acfd-60e4bc38b25c
PT: Portugal | Miguel Oliveira | 2025 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=ae6c6f0d-c652-44f8-94aa-420fc5b3dab4&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
QA: Qatar | Hamad Al Sahouti | 2024 | Moto3™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=dd12382e-1d9f-46ee-a5f7-c5104db28e43&categoryUuid=954f7e65-2ef2-4423-b949-4961cc603e45
RO: Romania | Jacopo Hosciuc | 2025 | MotoE™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=ae6c6f0d-c652-44f8-94aa-420fc5b3dab4&categoryUuid=3bda82ba-0445-440c-9375-cd48d777bd95
RU: Russian Federation | Vladimir Leonov | 2009 | 250cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=6487b826-eaaa-43e6-a2d2-4c5cafa948ae&categoryUuid=008a50a7-e302-44ba-b468-7e9999324c64
SE: Sweden | Johan Stigefelt | 2003 | 250cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=632718a6-f1fe-4f5a-b95d-03b8e7635d70&categoryUuid=008a50a7-e302-44ba-b468-7e9999324c64
SM: San Marino | Luca Bernardi | 2025 | MotoE™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=ae6c6f0d-c652-44f8-94aa-420fc5b3dab4&categoryUuid=3bda82ba-0445-440c-9375-cd48d777bd95
TH: Thailand | Somkiat Chantra | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
TR: Türkiye | Toprak Razgatlioglu | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
UA: Ukraine | Vladimir Ivanov | 2010 | Moto2™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=d5bd3042-f4dc-4fdc-897a-e284d07592e6&categoryUuid=549640b8-fd9c-4245-acfd-60e4bc38b25c
US: United States of America | Joe Roberts | 2026 | Moto2™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=549640b8-fd9c-4245-acfd-60e4bc38b25c
UY: Uruguay | J. Acosta | 1963 | 500cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=473191ae-cd39-443c-bf30-920403670c07&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
VE: Venezuela (Bolivarian Republic of) | Robertino Pietri | 2010 | Moto2™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=d5bd3042-f4dc-4fdc-897a-e284d07592e6&categoryUuid=549640b8-fd9c-4245-acfd-60e4bc38b25c
YU: None | Zdravko Matulja | 1989 | 80cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e6dac447-28af-4394-a570-93d33d138cc9&categoryUuid=9169fbb9-6ca5-402a-8388-788a9288c560
ZA: South Africa | Brad Binder | 2026 | MotoGP™
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=e88b4e43-2209-47aa-8e83-0e0b1cedde6e&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
ZW: Zimbabwe | Dave Petersen | 1986 | 500cc
https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=8dd7d599-ac03-4486-8d46-edf2edc3146d&categoryUuid=e8c110ad-64aa-4e8e-8a86-f2f152f6a942
*/
