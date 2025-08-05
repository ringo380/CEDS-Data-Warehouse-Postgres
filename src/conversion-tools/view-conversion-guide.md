# SQL Server Views to PostgreSQL Views Conversion Guide

## Overview

SQL Server views in the CEDS Data Warehouse provide abstracted access to dimension tables with source system reference data mappings. There are **37 views** in the RDS schema that need conversion to PostgreSQL.

## View Inventory

All views are in the `[RDS]` schema and follow the naming pattern `vw*`:

### Dimension Status Views (Most Common Pattern)
1. `vwDimAcademicTermDesignators`
2. `vwDimChildOutcomeSummaries`
3. `vwDimComprehensiveAndTargetedSupports`
4. `vwDimCteStatuses`
5. `vwDimDisabilityStatuses`
6. `vwDimDisciplineStatuses`
7. `vwDimEconomicallyDisadvantagedStatuses`
8. `vwDimEnglishLearnerStatuses`
9. `vwDimFirearmDisciplineStatuses`
10. `vwDimFirearms`
11. `vwDimFosterCareStatuses`
12. `vwDimGradeLevels`
13. `vwDimHomelessnessStatuses`
14. `vwDimIdeaDisabilityTypes`
15. `vwDimIdeaStatuses`
16. `vwDimImmigrantStatuses`
17. `vwDimIndividualizedProgramStatuses`
18. `vwDimK12AcademicAwardStatuses`
19. `vwDimK12CourseStatuses`
20. `vwDimK12Demographics`
21. `vwDimK12EnrollmentStatuses`
22. `vwDimK12OrganizationStatuses`
23. `vwDimK12ProgramTypes`
24. `vwDimK12SchoolStatuses`
25. `vwDimK12StaffCategories`
26. `vwDimK12StaffStatuses`
27. `vwDimLanguages`
28. `vwDimMigrantStatuses`
29. `vwDimMilitaryStatuses`
30. `vwDimNOrDStatuses`
31. `vwDimPsAcademicAwardStatuses`
32. `vwDimPsDemographics`
33. `vwDimPsEnrollmentStatuses`
34. `vwDimPsInstitutionStatuses`
35. `vwDimRaces`
36. `vwDimSubgroups`
37. `vwDimTitleIIIStatuses`
38. `vwDimTitleIStatuses`

### Special Purpose Views
1. `vwUnduplicatedRaceMap` - Complex aggregation logic
2. `vwCEDS_DataWarehouse_Extended_Properties` - Metadata view using SQL Server extended properties

## Key Differences

### SQL Server Views
- Schema notation: `[RDS].[vwViewName]`
- Square bracket column names: `[ColumnName]`
- Function calls: `ISNULL()`, `CAST()`, `LEN()`
- Extended properties: `fn_listextendedproperty()`
- Information schema: `INFORMATION_SCHEMA.*`
- Outer apply joins: `OUTER APPLY`

### PostgreSQL Views
- Schema notation: `rds.view_name`
- Snake case column names: `column_name`
- Function calls: `COALESCE()`, `::type`, `LENGTH()`
- Comments: `COMMENT ON` statements
- Information schema: `information_schema.*`
- Lateral joins: `LEFT JOIN LATERAL`

## Common View Patterns

### Pattern 1: Simple Dimension Mapping View

**SQL Server:**
```sql
CREATE VIEW [RDS].[vwDimLanguages]
AS
	SELECT
		  DimLanguageId
		, rsy.SchoolYear
		, Iso6392LanguageCodeCode
		, sssrd.InputCode AS Iso6392LanguageMap
	FROM rds.DimLanguages rdl
	CROSS JOIN (SELECT DISTINCT SchoolYear FROM staging.SourceSystemReferenceData) rsy
	LEFT JOIN staging.SourceSystemReferenceData sssrd
		ON rdl.Iso6392LanguageCodeCode = sssrd.OutputCode
		AND sssrd.TableName = 'refLanguage'
		AND rsy.SchoolYear = sssrd.SchoolYear
```

**PostgreSQL:**
```sql
CREATE OR REPLACE VIEW rds.vw_dim_languages AS
SELECT
    dim_language_id,
    rsy.school_year,
    iso6392_language_code_code,
    sssrd.input_code AS iso6392_language_map
FROM rds.dim_languages rdl
CROSS JOIN (SELECT DISTINCT school_year FROM staging.source_system_reference_data) rsy
LEFT JOIN staging.source_system_reference_data sssrd
    ON rdl.iso6392_language_code_code = sssrd.output_code
    AND sssrd.table_name = 'refLanguage'
    AND rsy.school_year = sssrd.school_year;
```

### Pattern 2: View with ISNULL Function

**SQL Server:**
```sql
CREATE VIEW RDS.vwDimK12Demographics 
AS
	SELECT
		  DimK12DemographicId
		, rsy.SchoolYear
		, SexCode
		, ISNULL(sssrd1.InputCode, 'MISSING') AS SexMap
	FROM rds.DimK12Demographics rdkd
	CROSS JOIN (SELECT DISTINCT SchoolYear FROM staging.SourceSystemReferenceData) rsy
	LEFT JOIN staging.SourceSystemReferenceData sssrd1
		ON rdkd.SexCode = sssrd1.OutputCode
		AND rsy.SchoolYear = sssrd1.SchoolYear
		AND sssrd1.TableName = 'RefSex'
```

**PostgreSQL:**
```sql
CREATE OR REPLACE VIEW rds.vw_dim_k12_demographics AS
SELECT
    dim_k12_demographic_id,
    rsy.school_year,
    sex_code,
    COALESCE(sssrd1.input_code, 'MISSING') AS sex_map
FROM rds.dim_k12_demographics rdkd
CROSS JOIN (SELECT DISTINCT school_year FROM staging.source_system_reference_data) rsy
LEFT JOIN staging.source_system_reference_data sssrd1
    ON rdkd.sex_code = sssrd1.output_code
    AND rsy.school_year = sssrd1.school_year
    AND sssrd1.table_name = 'RefSex';
```

### Pattern 3: Complex Aggregation View

**SQL Server:**
```sql
CREATE VIEW [RDS].[vwUnduplicatedRaceMap] 
AS 
    SELECT 
        StudentIdentifierState,
        LeaIdentifierSeaAccountability,
        SchoolIdentifierSea,
        RaceMap,
        SchoolYear
    FROM (
        SELECT 
            StudentIdentifierState,
            LeaIdentifierSeaAccountability,
            SchoolIdentifierSea,
            CASE 
                WHEN COUNT(InputCode) > 1 
                    THEN (SELECT MAX(inputcode)
                          FROM staging.SourceSystemReferenceData
                          WHERE TableName = 'refRace'
                          AND schoolyear = spr.SchoolYear
                          AND outputcode = 'TwoOrMoreRaces')
                    ELSE MAX(sssrd.InputCode)
            END AS RaceMap,
            spr.SchoolYear
        FROM staging.K12PersonRace spr
        JOIN Staging.SourceSystemReferenceData sssrd
            ON spr.RaceType = sssrd.InputCode
            AND spr.SchoolYear = sssrd.SchoolYear
            AND sssrd.TableName = 'RefRace'
        GROUP BY
            StudentIdentifierState,
            LeaIdentifierSeaAccountability,
            SchoolIdentifierSea,
            spr.SchoolYear
    ) stagingRaces
```

**PostgreSQL:**
```sql
CREATE OR REPLACE VIEW rds.vw_unduplicated_race_map AS 
SELECT 
    student_identifier_state,
    lea_identifier_sea_accountability,
    school_identifier_sea,
    race_map,
    school_year
FROM (
    SELECT 
        student_identifier_state,
        lea_identifier_sea_accountability,
        school_identifier_sea,
        CASE 
            WHEN COUNT(input_code) > 1 
                THEN (SELECT MAX(input_code)
                      FROM staging.source_system_reference_data
                      WHERE table_name = 'refRace'
                      AND school_year = spr.school_year
                      AND output_code = 'TwoOrMoreRaces')
                ELSE MAX(sssrd.input_code)
        END AS race_map,
        spr.school_year
    FROM staging.k12_person_race spr
    JOIN staging.source_system_reference_data sssrd
        ON spr.race_type = sssrd.input_code
        AND spr.school_year = sssrd.school_year
        AND sssrd.table_name = 'RefRace'
    GROUP BY
        student_identifier_state,
        lea_identifier_sea_accountability,
        school_identifier_sea,
        spr.school_year
) staging_races;
```

## Special Case: Extended Properties View

The `vwCEDS_DataWarehouse_Extended_Properties` view uses SQL Server-specific extended properties functionality that doesn't have a direct PostgreSQL equivalent.

**SQL Server (using extended properties):**
```sql
CREATE VIEW [rds].[vwCEDS_DataWarehouse_Extended_Properties] 
AS
	SELECT 
		c.TABLE_NAME [TableName],
		c.COLUMN_NAME [ColumnName],
		c.data_type [DataType],
		c.character_maximum_length [MaxLength],
		c.ORDINAL_POSITION [ColumnPostion],
		CAST(gi.value as varchar(max)) [GlobalId],
		CAST(el.value as varchar(max)) [ElementTechnicalName],
		CAST(de.value as varchar(max)) [Description],
		CAST(ur.value as varchar(max)) [Url]
	FROM INFORMATION_SCHEMA.COLUMNS c 
	INNER JOIN INFORMATION_SCHEMA.TABLES t ON t.TABLE_NAME = c.TABLE_NAME 
	OUTER APPLY fn_listextendedproperty ('CEDS_Def_Desc', 'schema', 'rds', N'table', c.TABLE_NAME, N'column', c.COLUMN_NAME) de
	OUTER APPLY fn_listextendedproperty ('CEDS_ElementTechnicalName', 'schema', 'rds', N'table', c.TABLE_NAME, N'column', c.COLUMN_NAME) el
	-- ... more OUTER APPLY clauses
```

**PostgreSQL (using comments and custom metadata):**
```sql
CREATE OR REPLACE VIEW rds.vw_ceds_datawarehouse_extended_properties AS
SELECT 
    c.table_name,
    c.column_name,
    c.data_type,
    c.character_maximum_length AS max_length,
    c.ordinal_position AS column_position,
    cm.global_id,
    cm.element_technical_name,
    cm.description,
    cm.url
FROM information_schema.columns c
INNER JOIN information_schema.tables t ON t.table_name = c.table_name 
LEFT JOIN ceds.column_metadata cm 
    ON c.table_schema = cm.schema_name 
    AND c.table_name = cm.table_name 
    AND c.column_name = cm.column_name
WHERE t.table_type = 'BASE TABLE'
    AND t.table_schema = 'rds'

UNION

SELECT 
    t.table_name,
    NULL AS column_name,
    NULL AS data_type,
    NULL AS max_length,
    NULL AS column_position,
    tm.global_id,
    tm.element_technical_name,
    tm.description,
    tm.url
FROM information_schema.tables t 
LEFT JOIN ceds.table_metadata tm 
    ON t.table_schema = tm.schema_name 
    AND t.table_name = tm.table_name
WHERE t.table_type = 'BASE TABLE'
    AND t.table_schema = 'rds';

-- Supporting metadata tables needed:
CREATE TABLE IF NOT EXISTS ceds.table_metadata (
    schema_name VARCHAR(64),
    table_name VARCHAR(64),
    global_id TEXT,
    element_technical_name TEXT,
    description TEXT,
    url TEXT,
    PRIMARY KEY (schema_name, table_name)
);

CREATE TABLE IF NOT EXISTS ceds.column_metadata (
    schema_name VARCHAR(64),
    table_name VARCHAR(64),
    column_name VARCHAR(64),
    global_id TEXT,
    element_technical_name TEXT,
    description TEXT,
    url TEXT,
    PRIMARY KEY (schema_name, table_name, column_name)
);
```

## Conversion Checklist

### Automated Conversions
- ✅ View name: `[RDS].[vwViewName]` → `rds.vw_view_name`
- ✅ Schema references: `[RDS].[Table]` → `rds.table`
- ✅ Function calls: `ISNULL()` → `COALESCE()`
- ✅ Column aliases: `[ColumnName]` → `column_name`
- ✅ Table references: `staging.SourceSystemReferenceData` → `staging.source_system_reference_data`

### Manual Review Required
- ⚠️ Complex column name conversions in SELECT lists
- ⚠️ Subquery correlation references
- ⚠️ CASE statements with column references
- ⚠️ Extended properties functionality
- ⚠️ Performance implications of CROSS JOIN patterns

## Performance Considerations

### CROSS JOIN Pattern
Many views use this pattern:
```sql
CROSS JOIN (SELECT DISTINCT SchoolYear FROM staging.SourceSystemReferenceData) rsy
```

**PostgreSQL Optimization:**
Consider materialized views for frequently accessed data:
```sql
CREATE MATERIALIZED VIEW rds.vw_dim_languages AS
-- view definition
WITH DATA;

-- Refresh strategy
REFRESH MATERIALIZED VIEW CONCURRENTLY rds.vw_dim_languages;
```

### Indexing Support Views
Add indexes on underlying tables to support view performance:
```sql
-- Index on frequently joined columns
CREATE INDEX idx_source_system_ref_data_lookup 
ON staging.source_system_reference_data (output_code, table_name, school_year);

CREATE INDEX idx_source_system_ref_data_school_year 
ON staging.source_system_reference_data (school_year);
```

## Testing Converted Views

### Basic Functionality Test
```sql
-- Test view creation
CREATE OR REPLACE VIEW rds.vw_dim_languages AS ...;

-- Test view query
SELECT * FROM rds.vw_dim_languages LIMIT 10;

-- Compare row counts (if migrating existing data)
SELECT COUNT(*) FROM rds.vw_dim_languages;
```

### Data Validation Test
```sql
-- Check for NULL mappings
SELECT school_year, COUNT(*) 
FROM rds.vw_dim_languages 
WHERE iso6392_language_map IS NULL 
GROUP BY school_year;

-- Verify CROSS JOIN produces expected combinations
SELECT school_year, COUNT(DISTINCT dim_language_id)
FROM rds.vw_dim_languages 
GROUP BY school_year;
```

### Performance Test
```sql
-- Check query performance
EXPLAIN ANALYZE SELECT * FROM rds.vw_dim_languages WHERE school_year = 2023;

-- Compare with SQL Server execution plan
-- Look for table scans that might need indexes
```

## Common Conversion Issues

### Issue 1: Column Name Case Sensitivity
**Problem**: PostgreSQL identifiers are case-sensitive when quoted
**Solution**: Use consistent snake_case naming throughout

### Issue 2: CROSS JOIN Performance
**Problem**: CROSS JOIN with large reference data can be slow
**Solution**: Consider materialized views or restructuring the join logic

### Issue 3: NULL Handling in Aggregations
**Problem**: PostgreSQL NULL behavior might differ in edge cases
**Solution**: Test aggregation results thoroughly, especially with CASE expressions

### Issue 4: Information Schema Differences
**Problem**: Some INFORMATION_SCHEMA views have different column names
**Solution**: Use PostgreSQL-specific information_schema column names

## Automated Conversion

Use the provided conversion tool:
```bash
# Convert single view
python convert-views.py input-view.sql output-view.sql

# Convert entire directory
python convert-views.py --directory ../RDS/Views/ ./converted-views/
```

**Post-Conversion Steps:**
1. Manual review of complex views
2. Test each view individually
3. Update any dependent stored procedures/functions
4. Add appropriate indexes for performance
5. Consider materialized views for frequently accessed data

This guide covers the conversion of all 37 views in the CEDS Data Warehouse from SQL Server to PostgreSQL format.