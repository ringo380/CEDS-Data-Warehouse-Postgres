-- Converted from SQL Server view: vwDimK12Demographics.sql
-- Original SQL Server view converted to PostgreSQL
-- 
CREATE OR REPLACE VIEW rds.dim_k12_demographics AS
SELECT
		  DimK12DemographicId
		, rsy.SchoolYear
		, SexCode
		, COALESCE(sssrd1.InputCode, 'MISSING') AS SexMap
	FROM rds.dim_k12_demographics rdkd
	CROSS JOIN (SELECT DISTINCT SchoolYear FROM staging.source_system_reference_data) rsy
	LEFT JOIN staging.source_system_reference_data sssrd1
		ON rdkd.SexCode = sssrd1.OutputCode
		AND rsy.SchoolYear = sssrd1.SchoolYear
		AND sssrd1.TableName = 'RefSex';