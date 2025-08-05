# T-SQL to PL/pgSQL Quick Reference Guide

## Overview
This is a focused reference for converting common T-SQL syntax patterns to PostgreSQL PL/pgSQL, specifically targeting patterns found in the CEDS Data Warehouse.

## Variables and Declarations

| T-SQL | PL/pgSQL | Notes |
|-------|----------|-------|
| `DECLARE @var INT` | `DECLARE var INTEGER;` | Remove `@`, add semicolon |
| `DECLARE @var VARCHAR(50)` | `DECLARE var VARCHAR(50);` | Direct mapping |
| `SET @var = value` | `var := value;` | Assignment operator change |
| `SELECT @var = column FROM table` | `SELECT column INTO var FROM table;` | Different syntax |

## Control Flow

| T-SQL | PL/pgSQL | Notes |
|-------|----------|-------|
| `IF condition BEGIN ... END` | `IF condition THEN ... END IF;` | Use THEN/END IF |
| `WHILE condition BEGIN ... END` | `WHILE condition LOOP ... END LOOP;` | Use LOOP/END LOOP |
| `CASE WHEN ... THEN ... END` | `CASE WHEN ... THEN ... END` | Same syntax |

## String Operations

| T-SQL | PL/pgSQL | Notes |
|-------|----------|-------|
| `'string' + 'other'` | `'string' \|\| 'other'` | Use \|\| for concatenation |
| `LEN(string)` | `LENGTH(string)` | Function name change |
| `SUBSTRING(str, start, len)` | `SUBSTRING(str FROM start FOR len)` | Different syntax |
| `LTRIM(RTRIM(str))` | `TRIM(str)` | Single function |

## Date/Time Functions

| T-SQL | PL/pgSQL | Notes |
|-------|----------|-------|
| `GETDATE()` | `CURRENT_TIMESTAMP` | Different function |
| `DATEADD(day, 1, date)` | `date + INTERVAL '1 day'` | Interval arithmetic |
| `DATEDIFF(day, date1, date2)` | `date2 - date1` | Direct subtraction |
| `YEAR(date)` | `EXTRACT(YEAR FROM date)` | Use EXTRACT |

## Error Handling

| T-SQL | PL/pgSQL | Notes |
|-------|----------|-------|
| `@@ERROR` | `SQLSTATE` | Different error detection |
| `RAISERROR()` | `RAISE EXCEPTION` | Different syntax |
| `TRY...CATCH` | `BEGIN...EXCEPTION WHEN...` | Exception blocks |

## System Functions

| T-SQL | PL/pgSQL | Notes |
|-------|----------|-------|
| `@@ROWCOUNT` | `GET DIAGNOSTICS var = ROW_COUNT` | More verbose |
| `@@IDENTITY` | `lastval()` | For sequences |
| `SCOPE_IDENTITY()` | `currval('sequence_name')` | Sequence-specific |

## Temporary Tables

| T-SQL | PL/pgSQL | Notes |
|-------|----------|-------|
| `CREATE TABLE #temp (...)` | `CREATE TEMPORARY TABLE temp (...);` | Remove # prefix |
| `DROP TABLE #temp` | `DROP TABLE temp;` | Auto-dropped at end |

## Common Patterns in CEDS

### Pattern 1: Variable Assignment from Query
```sql
-- T-SQL
DECLARE @StateCode VARCHAR(2)
SELECT @StateCode = StateAbbreviationCode FROM Staging.StateDetail

-- PL/pgSQL
DECLARE
    state_code VARCHAR(2);
BEGIN
    SELECT state_abbreviation_code INTO state_code FROM staging.state_detail LIMIT 1;
```

### Pattern 2: Conditional Logic
```sql
-- T-SQL
IF NOT EXISTS (SELECT 1 FROM RDS.DimK12Schools WHERE DimK12SchoolId = -1)
BEGIN
    INSERT INTO RDS.DimK12Schools (DimK12SchoolId) VALUES (-1)
END

-- PL/pgSQL
IF NOT EXISTS (SELECT 1 FROM rds.dim_k12_schools WHERE dim_k12_school_id = -1) THEN
    INSERT INTO rds.dim_k12_schools (dim_k12_school_id) VALUES (-1);
END IF;
```

### Pattern 3: While Loop Processing
```sql
-- T-SQL
WHILE EXISTS(SELECT TOP 1 * FROM #SchoolYears)
BEGIN
    SELECT @Year = (SELECT TOP 1 SchoolYear FROM #SchoolYears)
    -- Process logic
    DELETE TOP(1) FROM #SchoolYears
END

-- PL/pgSQL
WHILE EXISTS(SELECT 1 FROM school_years LIMIT 1) LOOP
    SELECT school_year INTO year_var FROM school_years LIMIT 1;
    -- Process logic
    DELETE FROM school_years WHERE school_year = year_var;
END LOOP;
```

### Pattern 4: Error Handling and Logging
```sql
-- T-SQL
INSERT INTO app.DataMigrationHistories (...) 
VALUES (GETUTCDATE(), 4, 'Error: ' + CONVERT(VARCHAR, @ErrorMsg))

-- PL/pgSQL
INSERT INTO app.data_migration_histories (...) 
VALUES (CURRENT_TIMESTAMP, 4, 'Error: ' || error_msg::TEXT);
```

## Quick Conversion Checklist

### ✅ Simple Replacements
- [ ] `@variables` → `variables`
- [ ] `BEGIN...END` → `BEGIN...END;` (with proper IF/LOOP syntax)
- [ ] `'string' +` → `'string' ||`
- [ ] `GETDATE()` → `CURRENT_TIMESTAMP`
- [ ] `ISNULL()` → `COALESCE()`

### ⚠️ Syntax Changes Required
- [ ] `DECLARE @var TYPE` → `DECLARE var TYPE;`
- [ ] `SELECT @var = value` → `SELECT value INTO var`
- [ ] `IF condition BEGIN` → `IF condition THEN`
- [ ] `WHILE condition BEGIN` → `WHILE condition LOOP`
- [ ] `#tempTable` → `temporary table temp_table`

### 🔧 Function Replacements
- [ ] `LEN()` → `LENGTH()`
- [ ] `CONVERT()` → `::type` or `CAST()`
- [ ] `DATEADD()` → `+ INTERVAL`
- [ ] `DATEDIFF()` → Direct subtraction
- [ ] `@@ROWCOUNT` → `GET DIAGNOSTICS ... ROW_COUNT`

This reference covers the most common patterns found in CEDS stored procedures and functions.