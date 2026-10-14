/* Three researched examples, NOT a complete penalty history.
Source: FIM/Dorna sanction notice issued 5 November 2020, reproduced at:
https://www.roadracingworld.com/news/motogp-yamaha-and-its-teams-penalized/
These affect constructor/team championships, not rider race points.
No race_id is guessed because the decision covers championship deductions.
*/
USE MotoGP;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @url NVARCHAR(1000)=N'https://www.roadracingworld.com/news/motogp-yamaha-and-its-teams-penalized/';
DECLARE @seed TABLE(ch_type VARCHAR(15),competitor_key VARCHAR(100),competitor_name NVARCHAR(250),delta DECIMAL(10,3));
INSERT INTO @seed VALUES
 ('CONSTRUCTOR','MGP_3',N'Yamaha',-50),
 ('TEAM','YAMAHA_FACTORY_2020',N'Monster Energy Yamaha MotoGP',-20),
 ('TEAM','PETRONAS_YAMAHA_SRT_2020',N'Petronas Yamaha SRT',-37);
INSERT INTO dbo.championships(championship_key,season_year,class_id,championship_type)
SELECT DISTINCT '2020_MotoGP_'+s.ch_type,2020,c.class_id,s.ch_type FROM @seed s
JOIN dbo.classes c ON c.class_name=N'MotoGP'
WHERE NOT EXISTS(SELECT 1 FROM dbo.championships ch WHERE ch.championship_key='2020_MotoGP_'+s.ch_type);
INSERT INTO dbo.championship_entries(championship_id,source_competitor_key,source_competitor_name,constructor_id,team_id)
SELECT ch.championship_id,s.competitor_key,s.competitor_name,co.constructor_id,t.team_id
FROM @seed s JOIN dbo.championships ch ON ch.championship_key='2020_MotoGP_'+s.ch_type
LEFT JOIN dbo.constructors co ON co.constructor_key=s.competitor_key AND s.ch_type='CONSTRUCTOR'
LEFT JOIN dbo.teams t ON t.team_key='YAMAHA_FACTORY_TEAM' AND s.competitor_key='YAMAHA_FACTORY_2020'
WHERE NOT EXISTS(SELECT 1 FROM dbo.championship_entries ce WHERE ce.championship_id=ch.championship_id AND ce.source_competitor_key=s.competitor_key);
INSERT INTO dbo.penalties(penalty_key,championship_entry_id,decision_date,penalty_type,decision_status,decision_summary,source_url)
SELECT 'FIM_20201105_'+s.competitor_key,ce.championship_entry_id,'2020-11-05','POINTS_DEDUCTION','APPLIED',
 N'Championship points withdrawn for failure to follow the required technical-change approval protocol.',@url
FROM @seed s JOIN dbo.championships ch ON ch.championship_key='2020_MotoGP_'+s.ch_type
JOIN dbo.championship_entries ce ON ce.championship_id=ch.championship_id AND ce.source_competitor_key=s.competitor_key
WHERE NOT EXISTS(SELECT 1 FROM dbo.penalties p WHERE p.penalty_key='FIM_20201105_'+s.competitor_key);
INSERT INTO dbo.championship_points_adjustments(adjustment_key,championship_entry_id,penalty_id,points_delta,effective_date,adjustment_status,reflected_in_race_points,reason,source_url)
SELECT p.penalty_key,ce.championship_entry_id,p.penalty_id,s.delta,'2020-11-05','APPLIED',0,
 N'Separate championship deduction; do not apply again to official standings totals.',@url
FROM @seed s JOIN dbo.championships ch ON ch.championship_key='2020_MotoGP_'+s.ch_type
JOIN dbo.championship_entries ce ON ce.championship_id=ch.championship_id AND ce.source_competitor_key=s.competitor_key
JOIN dbo.penalties p ON p.penalty_key='FIM_20201105_'+s.competitor_key
WHERE NOT EXISTS(SELECT 1 FROM dbo.championship_points_adjustments a WHERE a.adjustment_key=p.penalty_key);
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
