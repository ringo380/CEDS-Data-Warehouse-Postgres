# SQL Server Stored Procedures to PostgreSQL Functions Conversion Guide

## Overview

SQL Server stored procedures in the CEDS Data Warehouse are primarily ETL (Extract, Transform, Load) procedures that populate dimension and fact tables from staging data. These need to be converted to PostgreSQL functions or procedures.

## Key Differences

### SQL Server Stored Procedures
- Syntax: `CREATE PROCEDURE [Schema].[ProcedureName] @param TYPE AS BEGIN ... END`
- Parameter handling: `@parameter`
- Temporary tables: `#tempTable`, `##globalTempTable`
- Variables: `DECLARE @var TYPE`
- Control flow: `IF ... BEGIN ... END`, `WHILE ... BEGIN ... END`
- Identity insert: `SET IDENTITY_INSERT table ON/OFF`
- System functions: `@@ROWCOUNT`, `@@ERROR`

### PostgreSQL Functions/Procedures
- Syntax: `CREATE OR REPLACE FUNCTION schema.procedure_name(param TYPE) RETURNS VOID LANGUAGE plpgsql AS $$ ... $$`
- Parameter handling: Direct parameter names
- Temporary tables: Create temporary tables explicitly
- Variables: `DECLARE var TYPE;`
- Control flow: `IF ... THEN ... END IF;`, `WHILE ... LOOP ... END LOOP;`
- Identity handling: Direct INSERT with sequence values
- System functions: `GET DIAGNOSTICS`, exception handling

## CEDS Stored Procedure Inventory

Based on the repository analysis, there are **37 stored procedures** that need conversion:

### ETL Procedures (Staging to Dimension/Fact)
1. **Dimension Population Procedures** (8):
   - `Staging-To-DimK12Schools`
   - `Staging-To-DimPeople_K12Staff`  
   - `Staging-To-DimPeople_K12Students`
   - `Staging-to-DimCharterSchoolAuthorizers`
   - `Staging-to-DimCharterSchoolManagementOrganizations`
   - `Staging-to-DimEducationOrganizationNetworks`
   - `Staging-to-DimLeas`
   - `Staging-to-DimSeas`

2. **Fact Table Population Procedures** (19):
   - `Staging-to-FactK12ProgramParticipations`
   - `Staging-to-FactK12StaffCounts`
   - `Staging-to-FactK12StudentCounts_*` (12 variations)
   - `Staging-to-FactK12StudentCourseSections`
   - `Staging-to-FactK12StudentDisciplines`
   - `Staging-to-FactK12StudentEnrollments`
   - `Staging-to-FactOrganizationCounts`
   - `Staging-to-FactPsStudentAcademicAwards`
   - `Staging-to-FactPsStudentAcademicRecords`
   - `Staging-to-FactPsStudentEnrollments`
   - `Staging-to-FactSpecialEducation`

3. **Utility Procedures** (2):
   - `Rollover_SourceSystemReferenceData`
   - `Staging-to-DimPeople` (base people procedure)

## Conversion Patterns

### 1. Basic Procedure Structure

**SQL Server:**
```sql
CREATE PROCEDURE [Staging].[Staging-to-DimK12Schools]
    @dataCollectionName AS VARCHAR(50) = NULL,
    @runAsTest AS BIT 
AS 
BEGIN
    -- Procedure body
END
```

**PostgreSQL:**
```sql
CREATE OR REPLACE FUNCTION staging.staging_to_dim_k12_schools(
    data_collection_name VARCHAR(50) DEFAULT NULL,
    run_as_test BOOLEAN DEFAULT FALSE
) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Function body
END;
$$;
```

### 2. Variable Declaration and Assignment

**SQL Server:**
```sql
DECLARE @StateCode VARCHAR(2), @StateName VARCHAR(50), @StateANSICode VARCHAR(5)
SELECT @StateCode = (select StateAbbreviationCode from Staging.StateDetail)
SELECT @StateName = (select [Description] from dbo.RefState where Code = @StateCode)
```

**PostgreSQL:**
```sql
DECLARE
    state_code VARCHAR(2);
    state_name VARCHAR(50);
    state_ansi_code VARCHAR(5);
BEGIN
    SELECT state_abbreviation_code INTO state_code FROM staging.state_detail LIMIT 1;
    SELECT description INTO state_name FROM public.ref_state WHERE code = state_code;
```

### 3. Temporary Tables

**SQL Server:**
```sql
CREATE TABLE #organizationTypes (
    SchoolYear                      SMALLINT,
    K12SchoolOrganizationType       VARCHAR(20)
)

INSERT INTO #organizationTypes
SELECT SchoolYear, InputCode
FROM Staging.SourceSystemReferenceData 
WHERE TableName = 'RefOrganizationType'
```

**PostgreSQL:**
```sql
CREATE TEMPORARY TABLE organization_types (
    school_year                     SMALLINT,
    k12_school_organization_type    VARCHAR(20)
);

INSERT INTO organization_types
SELECT school_year, input_code
FROM staging.source_system_reference_data 
WHERE table_name = 'RefOrganizationType';
```

### 4. Identity Insert Handling

**SQL Server:**
```sql
IF NOT EXISTS (SELECT 1 FROM RDS.DimK12Schools WHERE DimK12SchoolId = -1)
BEGIN
    SET IDENTITY_INSERT RDS.DimK12Schools ON
    INSERT INTO RDS.DimK12Schools (DimK12SchoolId) VALUES (-1)
    SET IDENTITY_INSERT RDS.DimK12Schools OFF
END
```

**PostgreSQL:**
```sql
IF NOT EXISTS (SELECT 1 FROM rds.dim_k12_schools WHERE dim_k12_school_id = -1) THEN
    INSERT INTO rds.dim_k12_schools (dim_k12_school_id) VALUES (-1);
    -- Update sequence to ensure it doesn't conflict
    PERFORM setval('rds.dim_k12_schools_dim_k12_school_id_seq', 
                   (SELECT MAX(dim_k12_school_id) FROM rds.dim_k12_schools));
END IF;
```

### 5. Control Flow Statements

**SQL Server:**
```sql
WHILE EXISTS(SELECT TOP 1 * FROM #SchoolYearsInStaging)
BEGIN
    SELECT @StagingSchoolYear = (SELECT TOP 1 SchoolYear FROM #SchoolYearsInStaging)
    
    IF (SELECT COUNT(*) FROM staging.SourceSystemReferenceData WHERE SchoolYear = @StagingSchoolYear) = 0
    BEGIN
        -- Process logic
    END
    
    DELETE TOP(1) FROM #SchoolYearsInStaging
END
```

**PostgreSQL:**
```sql
WHILE EXISTS(SELECT 1 FROM school_years_in_staging LIMIT 1) LOOP
    SELECT school_year INTO staging_school_year 
    FROM school_years_in_staging LIMIT 1;
    
    IF (SELECT COUNT(*) FROM staging.source_system_reference_data 
        WHERE school_year = staging_school_year) = 0 THEN
        -- Process logic
    END IF;
    
    DELETE FROM school_years_in_staging 
    WHERE school_year = staging_school_year;
END LOOP;
```

### 6. Error Handling and Logging

**SQL Server:**
```sql
INSERT INTO app.DataMigrationHistories (DataMigrationHistoryDate, DataMigrationTypeId, DataMigrationHistoryMessage) 
VALUES (GETUTCDATE(), 4, 'ERROR: Rollover failed for ' + CONVERT(VARCHAR, @StagingSchoolYear))
```

**PostgreSQL:**
```sql
INSERT INTO app.data_migration_histories (data_migration_history_date, data_migration_type_id, data_migration_history_message) 
VALUES (CURRENT_TIMESTAMP, 4, 'ERROR: Rollover failed for ' || staging_school_year::TEXT);
```

## Complex Conversion Examples

### Example 1: Staging-To-DimK12Schools (Simplified)

**Original SQL Server Structure:**
```sql
CREATE PROCEDURE [Staging].[Staging-to-DimK12Schools]
    @dataCollectionName AS VARCHAR(50) = NULL,
    @runAsTest AS BIT 
AS 
BEGIN
    DECLARE @StateCode VARCHAR(2), @StateName VARCHAR(50)
    
    -- Create temp tables
    CREATE TABLE #organizationTypes (...)
    CREATE TABLE #K12Schools (...)
    
    -- Populate temp tables
    INSERT INTO #organizationTypes SELECT ...
    INSERT INTO #K12Schools SELECT ...
    
    -- Main ETL logic
    INSERT INTO RDS.DimK12Schools (...)
    SELECT ... FROM #K12Schools ...
    
    -- Cleanup
    DROP TABLE #organizationTypes
    DROP TABLE #K12Schools
END
```

**Converted PostgreSQL:**
```sql
CREATE OR REPLACE FUNCTION staging.staging_to_dim_k12_schools(
    data_collection_name VARCHAR(50) DEFAULT NULL,
    run_as_test BOOLEAN DEFAULT FALSE
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    state_code VARCHAR(2);
    state_name VARCHAR(50);
BEGIN
    -- Create temporary tables
    CREATE TEMPORARY TABLE organization_types (
        school_year SMALLINT,
        k12_school_organization_type VARCHAR(20)
    );
    
    CREATE TEMPORARY TABLE k12_schools (
        -- column definitions...
    );
    
    -- Get state information
    SELECT state_abbreviation_code INTO state_code 
    FROM staging.state_detail LIMIT 1;
    
    SELECT description INTO state_name 
    FROM public.ref_state WHERE code = state_code;
    
    -- Populate temporary tables
    INSERT INTO organization_types
    SELECT school_year, input_code
    FROM staging.source_system_reference_data 
    WHERE table_name = 'RefOrganizationType' 
        AND table_filter = '001156' 
        AND output_code = 'K12School';
    
    -- Main ETL logic
    INSERT INTO rds.dim_k12_schools (...)
    SELECT ... FROM k12_schools ...;
    
    -- Temporary tables are automatically dropped at end of function
EXCEPTION
    WHEN OTHERS THEN
        -- Error handling
        RAISE NOTICE 'Error in staging_to_dim_k12_schools: %', SQLERRM;
        RAISE;
END;
$$;
```

## Advanced Conversion Considerations

### 1. Batch Processing and Performance

SQL Server procedures often use techniques like:
- `TOP n` for limiting rows
- Batch processing with `WHILE` loops
- `@@ROWCOUNT` for affected rows

PostgreSQL equivalents:
- `LIMIT n` for limiting rows  
- `FOR ... IN ... LOOP` for iteration
- `GET DIAGNOSTICS row_count = ROW_COUNT;` for affected rows

### 2. Transaction Handling

SQL Server implicit transactions vs PostgreSQL explicit control:

**SQL Server (implicit):**
```sql
BEGIN
    INSERT INTO Table1...
    UPDATE Table2...
    -- Automatically committed or rolled back
END
```

**PostgreSQL (explicit control):**
```sql
BEGIN
    INSERT INTO table1...;
    UPDATE table2...;
    -- Can add COMMIT/ROLLBACK as needed
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
```

### 3. Dynamic SQL

**SQL Server:**
```sql
DECLARE @sql NVARCHAR(MAX)
SET @sql = 'SELECT * FROM ' + @tableName
EXEC sp_executesql @sql
```

**PostgreSQL:**
```sql
DECLARE
    sql_query TEXT;
BEGIN
    sql_query := 'SELECT * FROM ' || table_name;
    EXECUTE sql_query;
END;
```

## Conversion Tools and Automation

### Semi-Automated Conversion Process

1. **Structure Analysis**: Parse procedure signature and parameters
2. **Variable Mapping**: Convert `@variables` to `variables`
3. **Table Reference Conversion**: Map schema.table references
4. **Control Flow Conversion**: Transform IF/WHILE/CASE statements
5. **Function Call Mapping**: Replace SQL Server functions with PostgreSQL equivalents
6. **Manual Review**: Complex logic requires human verification

### Recommended Conversion Workflow

1. **Start with simple procedures** (utility functions)
2. **Convert dimension population procedures** (fewer dependencies)
3. **Convert fact table procedures** (complex ETL logic)
4. **Test each procedure** with sample data
5. **Update calling code** to use new function names
6. **Performance tuning** with PostgreSQL-specific optimizations

## Testing Converted Procedures

```sql
-- Test procedure execution
SELECT staging.staging_to_dim_k12_schools('TestCollection', TRUE);

-- Verify results
SELECT COUNT(*) FROM rds.dim_k12_schools WHERE dim_k12_school_id > 0;

-- Check for errors in logs
SELECT * FROM app.data_migration_histories 
WHERE data_migration_history_message LIKE '%ERROR%' 
ORDER BY data_migration_history_date DESC;
```

## Common Conversion Issues

### Issue 1: Parameter Direction
**Problem**: SQL Server `OUTPUT` parameters
**Solution**: Return multiple values using custom types or separate functions

### Issue 2: Temporary Table Scope
**Problem**: SQL Server temp tables persist across batches
**Solution**: PostgreSQL temp tables are session-scoped, plan accordingly

### Issue 3: String Concatenation with NULL
**Problem**: SQL Server `NULL + 'string'` = `NULL`
**Solution**: PostgreSQL `NULL || 'string'` = `'string'`, use `COALESCE` as needed

### Issue 4: TOP vs LIMIT
**Problem**: `SELECT TOP 1 @var = column FROM table`
**Solution**: `SELECT column INTO var FROM table LIMIT 1`

### Issue 5: Identity Column Handling
**Problem**: `SET IDENTITY_INSERT` for manual ID insertion
**Solution**: Direct INSERT with sequence management

This guide provides the foundation for converting all 37 stored procedures in the CEDS Data Warehouse from SQL Server to PostgreSQL.