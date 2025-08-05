# SQL Server IDENTITY to PostgreSQL SERIAL Conversion Guide

## Overview

SQL Server IDENTITY columns provide auto-incrementing integer values, while PostgreSQL uses SERIAL data types backed by sequences. This guide covers the conversion process for the CEDS Data Warehouse.

## Key Differences

### SQL Server IDENTITY
- Built into column definition: `INT IDENTITY(1,1)`
- Managed automatically by SQL Server
- Uses `SET IDENTITY_INSERT` to manually insert values
- `@@IDENTITY`, `SCOPE_IDENTITY()`, `IDENT_CURRENT()` functions

### PostgreSQL SERIAL
- Creates underlying sequence automatically
- Three variants: `SERIAL` (4-byte), `BIGSERIAL` (8-byte), `SMALLSERIAL` (2-byte)
- Uses `nextval()`, `currval()`, `setval()` functions
- More flexible sequence management

## Conversion Mapping

### Common IDENTITY Patterns → SERIAL Equivalents

| SQL Server | PostgreSQL | Notes |
|------------|------------|--------|
| `INT IDENTITY(1,1)` | `SERIAL` | 32-bit auto-increment starting at 1 |
| `BIGINT IDENTITY(1,1)` | `BIGSERIAL` | 64-bit auto-increment starting at 1 |
| `SMALLINT IDENTITY(1,1)` | `SMALLSERIAL` | 16-bit auto-increment starting at 1 |
| `INT IDENTITY(100,5)` | `INTEGER DEFAULT nextval('seq_name')` | Custom start/increment |

### CEDS Data Warehouse Examples

#### Dimension Tables (Use SERIAL)
```sql
-- SQL Server
CREATE TABLE [RDS].[DimK12Schools] (
    [DimK12SchoolId] INT IDENTITY(1,1) NOT NULL,
    ...
    CONSTRAINT [PK_DimK12Schools] PRIMARY KEY CLUSTERED ([DimK12SchoolId] ASC)
);

-- PostgreSQL
CREATE TABLE rds.dim_k12_schools (
    dim_k12_school_id SERIAL PRIMARY KEY,
    ...
);
```

#### Fact Tables (Use BIGSERIAL for high volume)
```sql
-- SQL Server
CREATE TABLE [RDS].[FactK12StudentEnrollments] (
    [FactK12StudentEnrollmentId] BIGINT IDENTITY(1,1) NOT NULL,
    ...
    CONSTRAINT [PK_FactK12StudentEnrollments] PRIMARY KEY CLUSTERED ([FactK12StudentEnrollmentId] ASC)
);

-- PostgreSQL
CREATE TABLE rds.fact_k12_student_enrollments (
    fact_k12_student_enrollment_id BIGSERIAL PRIMARY KEY,
    ...
);
```

#### Staging Tables (Use SERIAL)
```sql
-- SQL Server
CREATE TABLE [Staging].[SourceSystemReferenceData](
    [SourceSystemReferenceDataId] INT IDENTITY(1,1) NOT NULL,
    ...
    CONSTRAINT [PK_SourceSystemReferenceData] PRIMARY KEY CLUSTERED ([SourceSystemReferenceDataId] ASC)
);

-- PostgreSQL
CREATE TABLE staging.source_system_reference_data (
    source_system_reference_data_id SERIAL PRIMARY KEY,
    ...
);
```

## Advanced Conversions

### Custom Start Values and Increments

When SQL Server uses non-standard IDENTITY parameters:

```sql
-- SQL Server with custom start/increment
CREATE TABLE [RDS].[CustomTable] (
    [CustomId] INT IDENTITY(1000, 10) NOT NULL
);

-- PostgreSQL equivalent
CREATE SEQUENCE rds.custom_table_custom_id_seq
    START WITH 1000
    INCREMENT BY 10
    MINVALUE 1000
    MAXVALUE 2147483647
    CACHE 1;

CREATE TABLE rds.custom_table (
    custom_id INTEGER DEFAULT nextval('rds.custom_table_custom_id_seq') NOT NULL
);

-- Set sequence ownership
ALTER SEQUENCE rds.custom_table_custom_id_seq OWNED BY rds.custom_table.custom_id;
```

### Multiple IDENTITY Columns (Not Supported)

SQL Server only allows one IDENTITY column per table, but if converting from systems that might have multiple auto-incrementing columns:

```sql
-- Not possible in SQL Server, but if needed in PostgreSQL:
CREATE TABLE rds.multi_auto_table (
    id1 SERIAL,
    id2 SERIAL,
    data TEXT
);
```

## Data Migration Considerations

### Preserving Existing Values

When migrating data with existing IDENTITY values:

```sql
-- 1. Migrate data without SERIAL column
CREATE TABLE rds.dim_k12_schools_temp (
    dim_k12_school_id INTEGER,
    -- other columns...
);

-- 2. Import existing data
COPY rds.dim_k12_schools_temp FROM 'schools_data.csv' WITH CSV HEADER;

-- 3. Create final table with SERIAL
CREATE TABLE rds.dim_k12_schools (
    dim_k12_school_id SERIAL PRIMARY KEY,
    -- other columns...
);

-- 4. Insert data and update sequence
INSERT INTO rds.dim_k12_schools (dim_k12_school_id, /* other columns */)
SELECT dim_k12_school_id, /* other columns */
FROM rds.dim_k12_schools_temp;

-- 5. Update sequence to continue from max value
SELECT setval('rds.dim_k12_schools_dim_k12_school_id_seq', 
              (SELECT MAX(dim_k12_school_id) FROM rds.dim_k12_schools));
```

### Identity Insert Equivalent

SQL Server's `SET IDENTITY_INSERT` equivalent in PostgreSQL:

```sql
-- SQL Server
SET IDENTITY_INSERT [RDS].[DimK12Schools] ON;
INSERT INTO [RDS].[DimK12Schools] ([DimK12SchoolId], [Name]) VALUES (1, 'Test School');
SET IDENTITY_INSERT [RDS].[DimK12Schools] OFF;

-- PostgreSQL - just insert the value directly
INSERT INTO rds.dim_k12_schools (dim_k12_school_id, name) VALUES (1, 'Test School');

-- Then update sequence if needed
SELECT setval('rds.dim_k12_schools_dim_k12_school_id_seq', 
              (SELECT MAX(dim_k12_school_id) FROM rds.dim_k12_schools));
```

## Sequence Management Functions

### SQL Server vs PostgreSQL Functions

| SQL Server Function | PostgreSQL Equivalent | Purpose |
|-------------------|---------------------|---------|
| `@@IDENTITY` | `lastval()` | Last generated value in session |
| `SCOPE_IDENTITY()` | `currval('sequence_name')` | Last value from specific sequence |
| `IDENT_CURRENT('table')` | `currval('sequence_name')` | Current value of sequence |
| `IDENT_SEED('table')` | Check sequence definition | Initial value |
| `IDENT_INCR('table')` | Check sequence definition | Increment value |

### PostgreSQL Sequence Functions

```sql
-- Get next value (equivalent to INSERT with SERIAL)
SELECT nextval('rds.dim_k12_schools_dim_k12_school_id_seq');

-- Get current value (must have called nextval() in session)
SELECT currval('rds.dim_k12_schools_dim_k12_school_id_seq');

-- Get last value generated in this session (any sequence)
SELECT lastval();

-- Set sequence to specific value
SELECT setval('rds.dim_k12_schools_dim_k12_school_id_seq', 1000);

-- Set sequence to specific value without advancing
SELECT setval('rds.dim_k12_schools_dim_k12_school_id_seq', 1000, false);
```

## Performance Considerations

### Sequence Caching

PostgreSQL sequences can be cached for better performance:

```sql
-- Create sequence with cache for high-volume tables
CREATE SEQUENCE rds.fact_k12_student_enrollments_id_seq
    CACHE 100;  -- Cache 100 values at a time

-- Or alter existing sequence
ALTER SEQUENCE rds.fact_k12_student_enrollments_fact_k12_student_enrollment_id_seq
    CACHE 100;
```

### Recommendations by Table Type

| Table Type | Recommended Type | Cache Size | Reasoning |
|------------|------------------|------------|-----------|
| Dimension Tables | `SERIAL` | 1 (default) | Lower volume, consistency important |
| Fact Tables | `BIGSERIAL` | 50-100 | High volume, need 64-bit range |
| Bridge Tables | `SERIAL` | 10-20 | Medium volume |
| Staging Tables | `SERIAL` | 1 (default) | Temporary data |
| Log/Audit Tables | `BIGSERIAL` | 100+ | Very high volume |

## Common Pitfalls and Solutions

### 1. Sequence Not Updated After Manual Insert

```sql
-- Problem: Inserted value 5000, but sequence is still at 1
INSERT INTO rds.dim_k12_schools (dim_k12_school_id, name) VALUES (5000, 'Manual');

-- Next SERIAL insert will fail with duplicate key error
-- Solution: Update sequence
SELECT setval('rds.dim_k12_schools_dim_k12_school_id_seq', 5000);
```

### 2. Sequence Ownership

```sql
-- Ensure sequence is owned by the column for proper cleanup
ALTER SEQUENCE rds.dim_k12_schools_dim_k12_school_id_seq 
    OWNED BY rds.dim_k12_schools.dim_k12_school_id;
```

### 3. Getting Next Value Without Inserting

```sql
-- Don't do this - wastes sequence values
SELECT nextval('rds.dim_k12_schools_dim_k12_school_id_seq');

-- Instead, let INSERT handle it automatically
INSERT INTO rds.dim_k12_schools (name) VALUES ('New School');
```

## Conversion Validation

### Verify SERIAL Conversion

```sql
-- Check table structure
\d rds.dim_k12_schools

-- Verify sequence exists and is properly owned
SELECT 
    schemaname,
    sequencename,
    start_value,
    increment_by,
    max_value,
    min_value,
    cache_value,
    cycle
FROM pg_sequences 
WHERE schemaname = 'rds' 
AND sequencename LIKE '%dim_k12_schools%';

-- Check sequence ownership
SELECT 
    t.relname AS table_name,
    a.attname AS column_name,
    s.relname AS sequence_name
FROM pg_class t
JOIN pg_attribute a ON a.attrelid = t.oid
JOIN pg_depend d ON d.objid = a.attrelid AND d.objsubid = a.attnum
JOIN pg_class s ON s.oid = d.refobjid
WHERE t.relname = 'dim_k12_schools'
  AND s.relkind = 'S';
```

### Test SERIAL Functionality

```sql
-- Test auto-increment
INSERT INTO rds.dim_k12_schools (name_of_institution) VALUES ('Test School 1');
INSERT INTO rds.dim_k12_schools (name_of_institution) VALUES ('Test School 2');

-- Verify sequential IDs
SELECT dim_k12_school_id, name_of_institution 
FROM rds.dim_k12_schools 
ORDER BY dim_k12_school_id DESC 
LIMIT 5;

-- Check current sequence value
SELECT currval('rds.dim_k12_schools_dim_k12_school_id_seq');
```

## Automated Conversion Script Integration

The conversion is already integrated into the `convert-table-ddl.py` script with these patterns:

```python
# IDENTITY to SERIAL conversion patterns
datatype_map = {
    r'INT\s+IDENTITY\s*\(\s*1\s*,\s*1\s*\)': 'SERIAL',
    r'BIGINT\s+IDENTITY\s*\(\s*1\s*,\s*1\s*\)': 'BIGSERIAL',
    r'SMALLINT\s+IDENTITY\s*\(\s*1\s*,\s*1\s*\)': 'SMALLSERIAL',
}
```

This automatically handles the most common IDENTITY patterns found in the CEDS Data Warehouse.