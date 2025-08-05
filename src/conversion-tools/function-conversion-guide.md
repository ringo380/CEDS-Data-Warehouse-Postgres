# SQL Server to PostgreSQL Function Conversion Guide

## Overview

This guide covers converting SQL Server T-SQL scalar functions to PostgreSQL PL/pgSQL functions for the CEDS Data Warehouse migration.

## Key Differences

### SQL Server T-SQL Functions
- Syntax: `CREATE FUNCTION [Schema].[FunctionName](@param TYPE) RETURNS TYPE AS BEGIN ... END`
- Variable assignment: `SELECT @var = value FROM table`
- Parameter prefix: `@parameter`
- Date functions: `GETDATE()`, `CONVERT()`, `CAST()`
- String concatenation: `+` operator

### PostgreSQL PL/pgSQL Functions
- Syntax: `CREATE OR REPLACE FUNCTION schema.function_name(param TYPE) RETURNS TYPE LANGUAGE plpgsql AS $$ BEGIN ... END; $$`
- Variable assignment: `SELECT value INTO var FROM table`
- No parameter prefix needed
- Date functions: `CURRENT_TIMESTAMP`, type casting with `::`
- String concatenation: `||` operator

## Conversion Examples

### 1. RDS.Get_Age Function

**SQL Server T-SQL:**
```sql
CREATE FUNCTION [RDS].[Get_Age](
      @birthDate DATETIME = NULL
	, @asOfDate DATETIME = NULL
) RETURNS INT

BEGIN
	RETURN 
		CASE 
			WHEN @birthDate IS NULL THEN -1
			WHEN (CONVERT(INT,CONVERT(char(8), ISNULL(@asOfDate, GETDATE()),112))-CONVERT(char(8), ISNULL(@birthDate, GETDATE()),112))/10000 <= 0 THEN -1
			ELSE CONVERT(VARCHAR(5), (CONVERT(INT,CONVERT(char(8), ISNULL(@asOfDate, GETDATE()),112))-CONVERT(char(8), ISNULL(@birthDate, GETDATE()),112))/10000)
		END 
END
```

**PostgreSQL PL/pgSQL:**
```sql
CREATE OR REPLACE FUNCTION rds.get_age(
    birth_date TIMESTAMP DEFAULT NULL,
    as_of_date TIMESTAMP DEFAULT NULL
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN 
        CASE 
            WHEN birth_date IS NULL THEN -1
            WHEN EXTRACT(YEAR FROM AGE(COALESCE(as_of_date, CURRENT_TIMESTAMP), birth_date)) <= 0 THEN -1
            ELSE EXTRACT(YEAR FROM AGE(COALESCE(as_of_date, CURRENT_TIMESTAMP), birth_date))::INTEGER
        END;
END;
$$;
```

### 2. Staging.GetFiscalYearStartDate Function

**SQL Server T-SQL:**
```sql
CREATE FUNCTION Staging.GetFiscalYearStartDate(@SchoolYear SMALLINT)
RETURNS DATE
AS BEGIN
	RETURN CAST(CAST(@SchoolYear - 1 AS VARCHAR) + '-07-01' AS DATE)
END
```

**PostgreSQL PL/pgSQL:**
```sql
CREATE OR REPLACE FUNCTION staging.get_fiscal_year_start_date(school_year SMALLINT)
RETURNS DATE
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN ((school_year - 1)::TEXT || '-07-01')::DATE;
END;
$$;
```

### 3. Staging.GetStateName Function (with SELECT INTO)

**SQL Server T-SQL:**
```sql
CREATE FUNCTION [Staging].[GetStateName] (@StateAbbreviation CHAR(2))
RETURNS VARCHAR(50)
AS BEGIN
	DECLARE @StateName VARCHAR(50)

	SELECT @StateName = [Definition] FROM dbo.RefState WHERE Code = @StateAbbreviation

	RETURN @StateName
END
```

**PostgreSQL PL/pgSQL:**
```sql
CREATE OR REPLACE FUNCTION staging.get_state_name(state_abbreviation CHAR(2))
RETURNS VARCHAR(50)
LANGUAGE plpgsql
AS $$
DECLARE
    state_name VARCHAR(50);
BEGIN
    SELECT definition INTO state_name 
    FROM public.ref_state 
    WHERE code = state_abbreviation;

    RETURN state_name;
END;
$$;
```

### 4. Staging.GetOrganizationIdentifierSystemId Function (with JOIN)

**SQL Server T-SQL:**
```sql
CREATE FUNCTION Staging.GetOrganizationIdentifierSystemId (
    @OrganizationIdentifierSystemCode VARCHAR(100), 
    @OrganizationIdentifierTypeCode VARCHAR(6)
)
RETURNS INT
AS BEGIN
	DECLARE @RefOrganizationIdentifierSystemId INT
	
    SELECT @RefOrganizationIdentifierSystemId = rois.RefOrganizationIdentificationSystemId
    FROM dbo.RefOrganizationIdentificationSystem rois
    JOIN dbo.RefOrganizationIdentifierType roit
        ON rois.RefOrganizationIdentifierTypeId = roit.RefOrganizationIdentifierTypeId
    WHERE rois.Code = @OrganizationIdentifierSystemCode
        AND roit.Code = @OrganizationIdentifierTypeCode

    RETURN (@RefOrganizationIdentifierSystemId)
END
```

**PostgreSQL PL/pgSQL:**
```sql
CREATE OR REPLACE FUNCTION staging.get_organization_identifier_system_id(
    organization_identifier_system_code VARCHAR(100), 
    organization_identifier_type_code VARCHAR(6)
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    ref_organization_identifier_system_id INTEGER;
BEGIN
    SELECT rois.ref_organization_identification_system_id
    INTO ref_organization_identifier_system_id
    FROM public.ref_organization_identification_system rois
    JOIN public.ref_organization_identifier_type roit
        ON rois.ref_organization_identifier_type_id = roit.ref_organization_identifier_type_id
    WHERE rois.code = organization_identifier_system_code
        AND roit.code = organization_identifier_type_code;

    RETURN ref_organization_identifier_system_id;
END;
$$;
```

## Conversion Patterns

### 1. Function Signature Conversion

| Component | SQL Server | PostgreSQL |
|-----------|------------|------------|
| **Schema** | `[RDS].[FunctionName]` | `rds.function_name` |
| **Parameters** | `@param TYPE = NULL` | `param TYPE DEFAULT NULL` |
| **Return Type** | `RETURNS INT` | `RETURNS INTEGER` |
| **Language** | T-SQL (implicit) | `LANGUAGE plpgsql` |
| **Body Delimiters** | `AS BEGIN ... END` | `AS $$ BEGIN ... END; $$` |

### 2. Data Type Conversions

| SQL Server | PostgreSQL |
|------------|------------|
| `INT` | `INTEGER` |
| `SMALLINT` | `SMALLINT` |
| `VARCHAR(n)` | `VARCHAR(n)` |
| `CHAR(n)` | `CHAR(n)` |
| `DATETIME` | `TIMESTAMP` |
| `DATE` | `DATE` |
| `BIT` | `BOOLEAN` |

### 3. Variable Declaration and Assignment

**SQL Server:**
```sql
DECLARE @Variable TYPE
SELECT @Variable = column FROM table WHERE condition
```

**PostgreSQL:**
```sql
DECLARE
    variable TYPE;
BEGIN
    SELECT column INTO variable FROM table WHERE condition;
```

### 4. Function Replacements

| SQL Server Function | PostgreSQL Equivalent | Notes |
|-------------------|---------------------|---------|
| `GETDATE()` | `CURRENT_TIMESTAMP` | Current date/time |
| `ISNULL(a, b)` | `COALESCE(a, b)` | NULL handling |
| `CAST(x AS TYPE)` | `x::TYPE` | Type casting |
| `CONVERT(TYPE, x)` | `x::TYPE` | Type conversion |
| `LEN(string)` | `LENGTH(string)` | String length |
| `SUBSTRING(s,start,len)` | `SUBSTRING(s FROM start FOR len)` | String extraction |

### 5. String Operations

**SQL Server (concatenation with +):**
```sql
CAST(@SchoolYear - 1 AS VARCHAR) + '-07-01'
```

**PostgreSQL (concatenation with ||):**
```sql
(school_year - 1)::TEXT || '-07-01'
```

### 6. Date Operations

**SQL Server (complex date arithmetic):**
```sql
CONVERT(INT,CONVERT(char(8), ISNULL(@asOfDate, GETDATE()),112))
```

**PostgreSQL (using AGE and EXTRACT):**
```sql
EXTRACT(YEAR FROM AGE(COALESCE(as_of_date, CURRENT_TIMESTAMP), birth_date))
```

## Table and Column Reference Conversions

### Schema References
- `dbo.TableName` → `public.table_name`
- `[RDS].[TableName]` → `rds.table_name`
- `[Staging].[TableName]` → `staging.table_name`

### Column References
- `[ColumnName]` → `column_name`
- Convert PascalCase to snake_case
- Remove square brackets

### Examples:
- `dbo.RefState` → `public.ref_state`
- `[Definition]` → `definition`
- `RefOrganizationIdentificationSystemId` → `ref_organization_identification_system_id`

## Complete Function Inventory

Based on the CEDS Data Warehouse, here are all functions that need conversion:

### RDS Schema Functions:
1. `Get_Age` - Calculate age from birth date

### Staging Schema Functions:
1. `GetFiscalYearEndDate` - Get fiscal year end date (June 30)
2. `GetFiscalYearStartDate` - Get fiscal year start date (July 1)  
3. `GetOrganizationIdentifierSystemId` - Lookup organization identifier system ID
4. `GetOrganizationIdentifierTypeId` - Lookup organization identifier type ID
5. `GetOrganizationRelationshipId` - Lookup organization relationship ID
6. `GetOrganizationTypeId` - Lookup organization type ID
7. `GetPersonIdentifierSystemId` - Lookup person identifier system ID
8. `GetPersonIdentifierTypeId` - Lookup person identifier type ID
9. `GetProgramTypeId` - Lookup program type ID
10. `GetRefIDEAEducationalEnvironmentECId` - Lookup IDEA environment ID (early childhood)
11. `GetRefIDEAEducationalEnvironmentSchoolAgeId` - Lookup IDEA environment ID (school age)
12. `GetRefInstitutionTelephoneType` - Lookup institution telephone type
13. `GetRefOrganizationLocationTypeId` - Lookup organization location type ID
14. `GetRefPersonalInformationVerificationId` - Lookup personal info verification ID
15. `GetRefPersonIdentificationSystemId` - Lookup person identification system ID
16. `GetRefStateAnsiCode` - Lookup state ANSI code
17. `GetRefStateId` - Lookup state ID
18. `GetRoleId` - Lookup role ID
19. `GetStateName` - Lookup state name from abbreviation

## Automated Conversion Process

1. **Use the conversion tool**: `python convert-functions.py input.sql output.sql`
2. **Manual review required** for:
   - Complex date arithmetic
   - Multi-step variable assignments
   - Nested function calls
   - Table references that need schema mapping
3. **Test converted functions** with sample data
4. **Update function calls** in stored procedures and views

## Testing Converted Functions

```sql
-- Test the converted get_age function
SELECT rds.get_age('1990-05-15'::TIMESTAMP, '2023-05-15'::TIMESTAMP); -- Should return 33

-- Test fiscal year functions
SELECT staging.get_fiscal_year_start_date(2024); -- Should return '2023-07-01'
SELECT staging.get_fiscal_year_end_date(2024);   -- Should return '2024-06-30'

-- Test lookup functions
SELECT staging.get_state_name('CA'); -- Should return 'California'
```

## Common Issues and Solutions

### Issue 1: Parameter Naming
**Problem**: PostgreSQL doesn't use `@` prefix
**Solution**: Remove `@` and convert to snake_case

### Issue 2: Variable Assignment Syntax
**Problem**: SQL Server uses `SELECT @var = value`
**Solution**: PostgreSQL uses `SELECT value INTO var`

### Issue 3: String Concatenation
**Problem**: SQL Server uses `+` operator
**Solution**: PostgreSQL uses `||` operator

### Issue 4: Date Format Codes
**Problem**: `CONVERT(char(8), date, 112)` format codes
**Solution**: Use `TO_CHAR(date, 'YYYYMMDD')` or PostgreSQL date functions

### Issue 5: Table Schema References
**Problem**: `dbo.TableName` doesn't exist in PostgreSQL
**Solution**: Map to appropriate schema (`public.table_name`, `rds.table_name`, etc.)

This conversion guide provides the foundation for transforming all 20 SQL Server functions in the CEDS Data Warehouse to PostgreSQL equivalents.