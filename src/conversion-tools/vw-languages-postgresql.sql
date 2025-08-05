-- Converted from SQL Server view: vwDimLanguages.sql
-- Original SQL Server view converted to PostgreSQL
-- 
CREATE OR REPLACE VIEW rds.dim_languages AS
SELECT
		  DimLanguageId
		, rsy.SchoolYear
		, Iso6392LanguageCodeCode
		, sssrd.InputCode AS Iso6392LanguageMap
	FROM rds.dim_languages rdl
	CROSS JOIN (SELECT DISTINCT SchoolYear FROM staging.source_system_reference_data) rsy
	LEFT JOIN staging.source_system_reference_data sssrd
		ON rdl.Iso6392LanguageCodeCode = sssrd.OutputCode
		AND sssrd.TableName = 'refLanguage'
		AND rsy.SchoolYear = sssrd.SchoolYear;