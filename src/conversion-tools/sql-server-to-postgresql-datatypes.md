# SQL Server to PostgreSQL Data Type Conversion Reference

## Overview
This document provides comprehensive mapping for converting SQL Server data types to PostgreSQL equivalents for the CEDS Data Warehouse migration.

## Data Type Conversion Mapping

### String/Text Types
| SQL Server | PostgreSQL | Notes |
|------------|------------|--------|
| `NVARCHAR(n)` | `VARCHAR(n)` | PostgreSQL uses UTF-8 by default, no need for NVARCHAR |
| `NVARCHAR(MAX)` | `TEXT` | Unlimited length text |
| `VARCHAR(n)` | `VARCHAR(n)` | Direct mapping |
| `VARCHAR(MAX)` | `TEXT` | Unlimited length text |
| `NCHAR(n)` | `CHAR(n)` | Fixed-length character |
| `CHAR(n)` | `CHAR(n)` | Direct mapping |
| `NTEXT` | `TEXT` | Legacy type, use TEXT |
| `TEXT` | `TEXT` | Direct mapping |

### Numeric Types
| SQL Server | PostgreSQL | Notes |
|------------|------------|--------|
| `INT` | `INTEGER` | 32-bit integer |
| `BIGINT` | `BIGINT` | 64-bit integer |
| `SMALLINT` | `SMALLINT` | 16-bit integer |
| `TINYINT` | `SMALLINT` | PostgreSQL has no TINYINT, use SMALLINT |
| `BIT` | `BOOLEAN` | SQL Server BIT(0/1) → PostgreSQL BOOLEAN(true/false) |
| `DECIMAL(p,s)` | `DECIMAL(p,s)` | Direct mapping |
| `NUMERIC(p,s)` | `NUMERIC(p,s)` | Direct mapping |
| `MONEY` | `DECIMAL(19,4)` | No native MONEY type in PostgreSQL |
| `SMALLMONEY` | `DECIMAL(10,4)` | No native SMALLMONEY type |
| `FLOAT(n)` | `DOUBLE PRECISION` | Double precision floating point |
| `REAL` | `REAL` | Single precision floating point |

### Date/Time Types
| SQL Server | PostgreSQL | Notes |
|------------|------------|--------|
| `DATETIME` | `TIMESTAMP` | Date and time without timezone |
| `DATETIME2` | `TIMESTAMP` | Higher precision datetime |
| `SMALLDATETIME` | `TIMESTAMP` | Use regular TIMESTAMP |
| `DATE` | `DATE` | Direct mapping |
| `TIME` | `TIME` | Direct mapping |
| `DATETIMEOFFSET` | `TIMESTAMPTZ` | Date/time with timezone |

### Binary Types
| SQL Server | PostgreSQL | Notes |
|------------|------------|--------|
| `BINARY(n)` | `BYTEA` | Binary data |
| `VARBINARY(n)` | `BYTEA` | Variable binary data |
| `VARBINARY(MAX)` | `BYTEA` | Large binary data |
| `IMAGE` | `BYTEA` | Legacy binary type |

### Other Types
| SQL Server | PostgreSQL | Notes |
|------------|------------|--------|
| `UNIQUEIDENTIFIER` | `UUID` | Requires uuid-ossp extension |
| `XML` | `XML` | Requires xml support |
| `JSON` | `JSONB` | Use JSONB for better performance |
| `GEOGRAPHY` | `GEOMETRY` | Requires PostGIS extension |
| `GEOMETRY` | `GEOMETRY` | Requires PostGIS extension |

### Identity Columns
| SQL Server | PostgreSQL | Notes |
|------------|------------|--------|
| `INT IDENTITY(1,1)` | `SERIAL` | Auto-incrementing 32-bit integer |
| `BIGINT IDENTITY(1,1)` | `BIGSERIAL` | Auto-incrementing 64-bit integer |
| `SMALLINT IDENTITY(1,1)` | `SMALLSERIAL` | Auto-incrementing 16-bit integer |

## CEDS Data Warehouse Specific Conversions

Based on analysis of the CEDS codebase, here are the most common conversions needed:

### Dimension Table Primary Keys
```sql
-- SQL Server
[DimK12SchoolId] INT IDENTITY(1,1) NOT NULL

-- PostgreSQL  
dim_k12_school_id SERIAL PRIMARY KEY
```

### Fact Table Primary Keys
```sql
-- SQL Server
[FactK12StudentEnrollmentId] BIGINT IDENTITY(1,1) NOT NULL

-- PostgreSQL
fact_k12_student_enrollment_id BIGSERIAL PRIMARY KEY
```

### String Fields
```sql
-- SQL Server
[LeaOrganizationName] NVARCHAR(1000) NULL

-- PostgreSQL
lea_organization_name VARCHAR(1000)
```

### Boolean Fields
```sql
-- SQL Server
[CharterSchoolIndicator] BIT NULL

-- PostgreSQL
charter_school_indicator BOOLEAN
```

### Date Fields
```sql
-- SQL Server
[RecordStartDateTime] DATETIME NULL

-- PostgreSQL
record_start_datetime TIMESTAMP
```

## Column Naming Convention Changes

SQL Server uses `[BracketedNames]` while PostgreSQL uses `snake_case`:

### Conversion Rules
1. Remove square brackets `[` and `]`
2. Convert PascalCase to snake_case
3. Replace spaces with underscores
4. Convert to lowercase

### Examples
```sql
-- SQL Server → PostgreSQL
[DimK12SchoolId] → dim_k12_school_id
[LeaOrganizationName] → lea_organization_name
[CharterSchoolIndicator] → charter_school_indicator
[RecordStartDateTime] → record_start_datetime
[MailingAddressApartmentRoomOrSuiteNumber] → mailing_address_apartment_room_or_suite_number
```

## Constraint Conversions

### Primary Key Constraints
```sql
-- SQL Server
CONSTRAINT [PK_DimK12Schools] PRIMARY KEY CLUSTERED ([DimK12SchoolId] ASC)

-- PostgreSQL
CONSTRAINT pk_dim_k12_schools PRIMARY KEY (dim_k12_school_id)
```

### Foreign Key Constraints
```sql
-- SQL Server
CONSTRAINT [FK_FactK12StudentEnrollments_DimK12Schools] 
FOREIGN KEY ([K12SchoolId]) REFERENCES [RDS].[DimK12Schools] ([DimK12SchoolId])

-- PostgreSQL
CONSTRAINT fk_fact_k12_student_enrollments_dim_k12_schools 
FOREIGN KEY (k12_school_id) REFERENCES rds.dim_k12_schools (dim_k12_school_id)
```

### Default Constraints
```sql
-- SQL Server
CONSTRAINT [DF_FactK12StudentEnrollments_CountDateId] DEFAULT ((-1))

-- PostgreSQL
DEFAULT -1
```

## Index Conversions

### Clustered Index (Primary Key)
```sql
-- SQL Server
CONSTRAINT [PK_DimK12Schools] PRIMARY KEY CLUSTERED ([DimK12SchoolId] ASC)

-- PostgreSQL (automatic with PRIMARY KEY)
PRIMARY KEY (dim_k12_school_id)
```

### Non-Clustered Index
```sql
-- SQL Server
CREATE NONCLUSTERED INDEX [IX_DimSchools_StateANSICode]
ON [RDS].[DimK12Schools]([StateAnsiCode] ASC);

-- PostgreSQL
CREATE INDEX idx_dim_k12_schools_state_ansi_code 
ON rds.dim_k12_schools (state_ansi_code);
```

### Index with INCLUDE columns
```sql
-- SQL Server
CREATE NONCLUSTERED INDEX [IX_DimK12Schools_RecordStartDateTime]
ON [RDS].[DimK12Schools]([RecordStartDateTime] ASC)
INCLUDE([SchoolIdentifierSea], [RecordEndDateTime]);

-- PostgreSQL (no INCLUDE, add columns to index)
CREATE INDEX idx_dim_k12_schools_record_start_datetime 
ON rds.dim_k12_schools (record_start_datetime, school_identifier_sea, record_end_datetime);
```

## Schema Conversions

### Schema Names
```sql
-- SQL Server
[RDS].[DimK12Schools]
[Staging].[SourceSystemReferenceData] 
[CEDS].[SomeTable]

-- PostgreSQL
rds.dim_k12_schools
staging.source_system_reference_data
ceds.some_table
```

## Data Type Size Considerations

### Performance Optimization
- Use `BIGSERIAL` for fact table primary keys (high volume)
- Use `SERIAL` for dimension table primary keys (lower volume)
- Use `TEXT` instead of `VARCHAR(MAX)` for unlimited text
- Use `BOOLEAN` instead of `BIT` for true/false values

### Storage Efficiency
- `SMALLINT` (2 bytes) vs `INTEGER` (4 bytes) for small lookup values
- `VARCHAR(n)` for known-length strings vs `TEXT` for variable length
- Consider `NUMERIC` precision for financial data

## Common Gotchas

1. **BIT to BOOLEAN**: SQL Server BIT stores 0/1, PostgreSQL BOOLEAN stores true/false
2. **NVARCHAR vs VARCHAR**: PostgreSQL VARCHAR is Unicode by default
3. **IDENTITY vs SERIAL**: Different syntax for auto-incrementing columns
4. **Square brackets**: Must be removed in PostgreSQL
5. **Case sensitivity**: PostgreSQL identifiers are case-sensitive when quoted
6. **NULL handling**: Both handle NULL similarly, but syntax differs in functions
7. **Date formats**: PostgreSQL is more strict about date format validation

## Validation Queries

After conversion, use these queries to validate data type mappings:

```sql
-- Check column data types
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'rds' AND table_name = 'dim_k12_schools'
ORDER BY ordinal_position;

-- Check constraints
SELECT constraint_name, constraint_type 
FROM information_schema.table_constraints 
WHERE table_schema = 'rds' AND table_name = 'dim_k12_schools';

-- Check indexes
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE schemaname = 'rds' AND tablename = 'dim_k12_schools';
```