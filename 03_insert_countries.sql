USE MotoGP;
GO

INSERT INTO dbo.countries (country_name, country_code)
VALUES
    (N'Italy', 'ITA'),
    (N'Spain', 'ESP'),
    (N'France', 'FRA'),
    (N'Australia', 'AUS'),
    (N'Japan', 'JPN'),
    (N'United Kingdom', 'GBR'),
    (N'United States', 'USA');

GO

SELECT country_id, country_name, country_code
FROM dbo.countries
ORDER BY country_name;