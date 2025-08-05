# SQL Server to PostgreSQL Data Migration Guide

## Overview

This comprehensive guide provides step-by-step instructions for migrating existing data from SQL Server CEDS Data Warehouse to PostgreSQL. The migration process ensures data integrity, handles data type conversions, and maintains referential relationships throughout the transfer.

## Table of Contents

1. [Migration Strategy](#migration-strategy)
2. [Prerequisites](#prerequisites)
3. [Phase 1: Data Export from SQL Server](#phase-1-data-export-from-sql-server)
4. [Phase 2: Data Transformation](#phase-2-data-transformation)
5. [Phase 3: Data Loading into PostgreSQL](#phase-3-data-loading-into-postgresql)
6. [Data Validation and Quality Checks](#data-validation-and-quality-checks)
7. [Performance Optimization](#performance-optimization)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## Migration Strategy

### Three-Phase Approach

The migration follows a proven **Extract-Transform-Load (ETL)** methodology:

1. **EXTRACT**: Export data from SQL Server into CSV files
2. **TRANSFORM**: Convert data types and handle format differences  
3. **LOAD**: Import transformed data into PostgreSQL with validation

### Data Migration Order

To maintain referential integrity, migrate tables in this specific order:

1. **Reference/Lookup Tables**: States, school types, grade levels
2. **Dimension Tables**: Schools, students, time dimensions  
3. **Fact Tables**: Enrollments, assessments, personnel
4. **Staging Tables**: ETL working tables

## Prerequisites

### System Requirements

- **Source**: SQL Server with CEDS Data Warehouse V11.0.0.0
- **Target**: PostgreSQL 12+ with CEDS schema installed
- **Network**: Connectivity between source and target systems
- **Storage**: 2x source database size for temporary files
- **Memory**: 8GB+ RAM recommended for large datasets

### Required Permissions

#### SQL Server Source
```sql
-- Minimum permissions required
GRANT SELECT ON SCHEMA::[RDS] TO [migration_user];
GRANT SELECT ON SCHEMA::[Staging] TO [migration_user];  
GRANT SELECT ON SCHEMA::[CEDS] TO [migration_user];
```

#### PostgreSQL Target
```sql
-- Required permissions
GRANT ALL ON SCHEMA migration TO migration_user;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA rds TO migration_user;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA staging TO migration_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA rds TO migration_user;
```

### Required Tools

- **SQL Server**: BCP utility or SQL Server Management Studio
- **PostgreSQL**: psql client and COPY command access
- **File Transfer**: SCP, FTP, or shared network storage
- **Monitoring**: Disk space and process monitoring tools

## Phase 1: Data Export from SQL Server

### 1.1 Prepare Export Environment

```powershell
# Create export directory
mkdir C:\ceds_migration\data
mkdir C:\ceds_migration\logs

# Set environment variables
$EXPORT_PATH = "C:\ceds_migration\data"
$SQL_SERVER = "your-sql-server"
$DATABASE = "CEDS-Data-Warehouse-V11.0.0.0"
```

### 1.2 Export Reference and Dimension Tables

#### Essential Dimension Tables
```cmd
# Export school dimensions
bcp "SELECT * FROM [RDS].[DimK12Schools]" queryout "%EXPORT_PATH%\dim_k12_schools.csv" -c -t, -r\n -S %SQL_SERVER% -d %DATABASE% -T -e error_schools.log

# Export student dimensions  
bcp "SELECT * FROM [RDS].[DimK12Students]" queryout "%EXPORT_PATH%\dim_k12_students.csv" -c -t, -r\n -S %SQL_SERVER% -d %DATABASE% -T -e error_students.log

# Export time dimensions
bcp "SELECT * FROM [RDS].[DimSchoolYears]" queryout "%EXPORT_PATH%\dim_school_years.csv" -c -t, -r\n -S %SQL_SERVER% -d %DATABASE% -T -e error_school_years.log

# Export LEA (Local Education Agency) dimensions
bcp "SELECT * FROM [RDS].[DimLeas]" queryout "%EXPORT_PATH%\dim_leas.csv" -c -t, -r\n -S %SQL_SERVER% -d %DATABASE% -T -e error_leas.log
```

### 1.3 Export Fact Tables

```cmd
# Export student enrollment facts
bcp "SELECT * FROM [RDS].[FactK12StudentEnrollments]" queryout "%EXPORT_PATH%\fact_k12_student_enrollments.csv" -c -t, -r\n -S %SQL_SERVER% -d %DATABASE% -T -e error_enrollments.log

# Export student count facts
bcp "SELECT * FROM [RDS].[FactK12StudentCounts]" queryout "%EXPORT_PATH%\fact_k12_student_counts.csv" -c -t, -r\n -S %SQL_SERVER% -d %DATABASE% -T -e error_counts.log

# Export personnel facts
bcp "SELECT * FROM [RDS].[FactK12StaffCounts]" queryout "%EXPORT_PATH%\fact_k12_staff_counts.csv" -c -t, -r\n -S %SQL_SERVER% -d %DATABASE% -T -e error_staff.log
```

### 1.4 Export Staging Tables

```cmd
# Export staging enrollment data
bcp "SELECT * FROM [Staging].[K12Enrollment]" queryout "%EXPORT_PATH%\staging_k12_enrollment.csv" -c -t, -r\n -S %SQL_SERVER% -d %DATABASE% -T -e error_staging_enrollment.log

# Export source system reference data
bcp "SELECT * FROM [Staging].[SourceSystemReferenceData]" queryout "%EXPORT_PATH%\staging_source_system_reference_data.csv" -c -t, -r\n -S %SQL_SERVER% -d %DATABASE% -T -e error_staging_reference.log
```

### 1.5 Alternative: SQL Server Management Studio Export

For smaller datasets or when BCP is not available:

1. **Right-click database** → Tasks → Export Data
2. **Choose Data Source**: SQL Server Native Client
3. **Choose Destination**: Flat File Destination
4. **Select Tables**: Choose tables in dependency order
5. **Configure Format**: 
   - Row delimiter: {CR}{LF}
   - Column delimiter: Comma
   - Text qualifier: Double quote
   - First row has column names: Yes

### 1.6 Validate Export Files

```powershell
# Check file sizes and record counts
Get-ChildItem C:\ceds_migration\data\*.csv | ForEach-Object {
    $lines = (Get-Content $_.FullName | Measure-Object -Line).Lines
    Write-Host "$($_.Name): $($_.Length) bytes, $lines lines"
}

# Check for export errors
Get-ChildItem C:\ceds_migration\*.log | ForEach-Object {
    if ((Get-Content $_.FullName).Length -gt 0) {
        Write-Warning "Errors found in $($_.Name)"
        Get-Content $_.FullName
    }
}
```

## Phase 2: Data Transformation

### 2.1 Install Migration Scripts

```bash
# Copy files to PostgreSQL server
scp -r C:\ceds_migration\data\ user@postgres-server:/var/lib/postgresql/migration/
scp sql-server-data-migration-scripts.sql user@postgres-server:/var/lib/postgresql/migration/

# Connect to PostgreSQL
psql -h localhost -U postgres -d ceds_data_warehouse_v11_0_0_0
```

### 2.2 Load Migration Functions

```sql
-- Load the migration script
\i /var/lib/postgresql/migration/sql-server-data-migration-scripts.sql

-- Verify migration schema created
\dn migration

-- List available migration functions
\df migration.*
```

### 2.3 Configure Data Type Conversions

The migration scripts automatically handle these conversions:

| SQL Server Type | PostgreSQL Type | Conversion Function |
|----------------|-----------------|-------------------|
| `NVARCHAR(n)` | `VARCHAR(n)` | `convert_sqlserver_nvarchar()` |
| `DATETIME` | `TIMESTAMP` | `convert_sqlserver_datetime()` |
| `BIT` | `BOOLEAN` | `convert_sqlserver_bit()` |
| `NUMERIC(p,s)` | `NUMERIC(p,s)` | `convert_sqlserver_numeric()` |
| `IDENTITY` | `SERIAL` | Handled by sequences |

## Phase 3: Data Loading into PostgreSQL

### 3.1 Optimize Database for Bulk Loading

```sql
-- Temporarily optimize for bulk operations
SELECT app.configure_for_etl_mode();

-- Increase work memory for this session
SET work_mem = '1GB';
SET maintenance_work_mem = '2GB';

-- Disable autovacuum temporarily
ALTER TABLE rds.dim_k12_schools SET (autovacuum_enabled = false);
```

### 3.2 Load Dimension Tables

#### Load School Dimensions
```sql
-- Load from CSV file
SELECT migration.load_dim_k12_schools_from_csv('/var/lib/postgresql/migration/data/dim_k12_schools.csv');

-- Transform and load into target
SELECT migration.transform_and_load_dim_k12_schools();

-- Verify load
SELECT COUNT(*) as school_count FROM rds.dim_k12_schools;
```

#### Load Student Dimensions
```sql
-- Create staging table for students
CREATE TABLE migration.staging_dim_k12_students (
    dim_k12_student_id INTEGER,
    student_identifier_state TEXT,
    first_name TEXT,
    middle_name TEXT,
    last_name TEXT,
    birth_date TEXT,
    sex_code TEXT,
    -- Add other columns as needed
    PRIMARY KEY (dim_k12_student_id)
);

-- Load and transform student data
COPY migration.staging_dim_k12_students 
FROM '/var/lib/postgresql/migration/data/dim_k12_students.csv' 
WITH (FORMAT csv, HEADER true, NULL 'NULL');

-- Transform to target table
INSERT INTO rds.dim_k12_students (
    dim_k12_student_id,
    student_identifier_state,
    first_name,
    middle_name,
    last_name,
    birth_date,
    sex_code
)
SELECT 
    s.dim_k12_student_id,
    migration.convert_sqlserver_nvarchar(s.student_identifier_state),
    migration.convert_sqlserver_nvarchar(s.first_name),
    migration.convert_sqlserver_nvarchar(s.middle_name),
    migration.convert_sqlserver_nvarchar(s.last_name),
    migration.convert_sqlserver_datetime(s.birth_date)::DATE,
    migration.convert_sqlserver_nvarchar(s.sex_code)
FROM migration.staging_dim_k12_students s
ON CONFLICT (dim_k12_student_id) DO UPDATE SET
    student_identifier_state = EXCLUDED.student_identifier_state,
    first_name = EXCLUDED.first_name,
    middle_name = EXCLUDED.middle_name,
    last_name = EXCLUDED.last_name,
    birth_date = EXCLUDED.birth_date,
    sex_code = EXCLUDED.sex_code;
```

### 3.3 Load Fact Tables

```sql
-- Load fact table with foreign key validation
INSERT INTO rds.fact_k12_student_enrollments (
    fact_k12_student_enrollment_id,
    school_year_id,
    dim_k12_school_id,
    dim_k12_student_id,
    dim_lea_id,
    student_count
)
SELECT 
    s.fact_k12_student_enrollment_id,
    s.school_year_id,
    s.dim_k12_school_id,
    s.dim_k12_student_id,
    s.dim_lea_id,
    s.student_count::INTEGER
FROM migration.staging_fact_k12_student_enrollments s
WHERE EXISTS (SELECT 1 FROM rds.dim_k12_schools ds WHERE ds.dim_k12_school_id = s.dim_k12_school_id)
AND EXISTS (SELECT 1 FROM rds.dim_k12_students dt WHERE dt.dim_k12_student_id = s.dim_k12_student_id);
```

### 3.4 Run Complete Migration

```sql
-- Execute full automated migration
SELECT * FROM migration.run_full_migration('/var/lib/postgresql/migration/data/');

-- Check results
SELECT 
    step_name,
    status,
    row_count,
    duration,
    notes
FROM migration.run_full_migration('/var/lib/postgresql/migration/data/');
```

### 3.5 Restore Normal Database Operation

```sql
-- Reset sequences to prevent conflicts
SELECT migration.reset_sequences();

-- Re-enable autovacuum
ALTER TABLE rds.dim_k12_schools SET (autovacuum_enabled = true);

-- Restore normal operation mode
SELECT app.restore_normal_mode();

-- Update table statistics
ANALYZE;
```

## Data Validation and Quality Checks

### 4.1 Row Count Validation

```sql
-- Compare source and target row counts
SELECT * FROM migration.validate_migration_integrity();

-- Expected output:
-- table_name              | source_count | target_count | status | notes
-- dim_k12_schools        | 125000       | 125000       | PASS   | Row count comparison
-- fact_k12_student_enrollments | 2500000 | 2500000    | PASS   | Row count comparison
```

### 4.2 Data Quality Checks

```sql
-- Check for data quality issues
SELECT * FROM migration.check_data_quality();

-- Check for missing foreign key relationships
SELECT 
    'Orphaned enrollments' as issue,
    COUNT(*) as count
FROM rds.fact_k12_student_enrollments f
WHERE NOT EXISTS (
    SELECT 1 FROM rds.dim_k12_schools s 
    WHERE s.dim_k12_school_id = f.dim_k12_school_id
);
```

### 4.3 Sample Data Verification

```sql
-- Compare sample records between source and target
-- (Run this query on both SQL Server and PostgreSQL)

-- SQL Server version:
SELECT TOP 10
    DimK12SchoolId,
    SchoolName,
    SchoolIdentifierState,
    StateCode,
    RecordStartDateTime
FROM [RDS].[DimK12Schools]
ORDER BY DimK12SchoolId;

-- PostgreSQL version:
SELECT 
    dim_k12_school_id,
    school_name,
    school_identifier_state,
    state_code,
    record_start_datetime
FROM rds.dim_k12_schools
ORDER BY dim_k12_school_id
LIMIT 10;
```

### 4.4 Referential Integrity Validation

```sql
-- Check all foreign key constraints
DO $$
DECLARE
    constraint_record RECORD;
    violation_count INTEGER;
BEGIN
    FOR constraint_record IN 
        SELECT conname, conrelid::regclass AS table_name
        FROM pg_constraint 
        WHERE contype = 'f' 
        AND connamespace = 'rds'::regnamespace
    LOOP
        EXECUTE format('
            SELECT COUNT(*) FROM %s 
            WHERE NOT EXISTS (SELECT 1 FROM %s WHERE %s)',
            constraint_record.table_name,
            constraint_record.conname -- This would need proper FK table resolution
        ) INTO violation_count;
        
        IF violation_count > 0 THEN
            RAISE WARNING 'Foreign key violations in %: % records', 
                constraint_record.table_name, violation_count;
        END IF;
    END LOOP;
END;
$$;
```

## Performance Optimization

### 5.1 Index Management During Migration

```sql
-- Disable indexes during bulk loading
DO $$
DECLARE
    index_record RECORD;
BEGIN
    -- Drop non-unique indexes temporarily
    FOR index_record IN
        SELECT schemaname, tablename, indexname
        FROM pg_indexes 
        WHERE schemaname IN ('rds', 'staging')
        AND indexname NOT LIKE '%_pkey'
    LOOP
        EXECUTE format('DROP INDEX IF EXISTS %I.%I', 
                      index_record.schemaname, index_record.indexname);
        RAISE NOTICE 'Dropped index %', index_record.indexname;
    END LOOP;
END;
$$;

-- After migration, recreate indexes
\i create_indexes.sql  -- Run index creation script
```

### 5.2 Parallel Loading

For very large tables, consider parallel loading:

```sql
-- Split large table into chunks and load in parallel sessions
-- Session 1:
COPY migration.staging_large_table FROM '/data/large_table_part1.csv' WITH (FORMAT csv, HEADER true);

-- Session 2 (concurrent):
COPY migration.staging_large_table FROM '/data/large_table_part2.csv' WITH (FORMAT csv, HEADER true);

-- Session 3 (concurrent):
COPY migration.staging_large_table FROM '/data/large_table_part3.csv' WITH (FORMAT csv, HEADER true);
```

### 5.3 Memory Optimization

```sql
-- Optimize memory settings for migration session
SET work_mem = '2GB';
SET maintenance_work_mem = '4GB';
SET temp_buffers = '1GB';
SET shared_buffers = '4GB';  -- Cluster level setting
```

## Troubleshooting

### 6.1 Common Issues and Solutions

#### Issue: CSV Loading Errors
```sql
-- Error: invalid input syntax for type integer
-- Solution: Check for NULL values or invalid data

-- Identify problematic rows
CREATE TEMP TABLE error_rows AS
SELECT line_number, raw_line
FROM (
    SELECT row_number() OVER () as line_number, *
    FROM migration.staging_raw_data
) t
WHERE column_name !~ '^[0-9]+$';  -- For integer columns
```

#### Issue: Memory Exhaustion
```sql
-- Reduce batch size and increase available memory
SET work_mem = '256MB';  -- Reduce if getting out of memory errors

-- Process in smaller batches
INSERT INTO target_table 
SELECT * FROM staging_table 
WHERE id BETWEEN 1 AND 100000;
```

#### Issue: Slow Performance
```sql
-- Check for long-running operations
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query 
FROM pg_stat_activity 
WHERE state = 'active';

-- Monitor table sizes during migration
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname IN ('rds', 'staging', 'migration')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### 6.2 Recovery Procedures

If migration fails partway through:

```sql
-- Check what was successfully migrated
SELECT * FROM migration.generate_migration_report();

-- Roll back specific table
TRUNCATE rds.fact_k12_student_enrollments;

-- Restart from specific step
SELECT migration.transform_and_load_dim_k12_schools();  -- Restart specific step
```

## Best Practices

### 7.1 Pre-Migration Checklist

- [ ] **Backup source database** before beginning
- [ ] **Test migration** on subset of data first  
- [ ] **Verify disk space** (3x source size recommended)
- [ ] **Plan maintenance window** for production migration
- [ ] **Coordinate with stakeholders** on downtime
- [ ] **Document custom configurations** and settings

### 7.2 During Migration

- [ ] **Monitor system resources** (CPU, memory, disk I/O)
- [ ] **Log all operations** for audit trail
- [ ] **Validate each phase** before proceeding
- [ ] **Keep source system** available for comparison
- [ ] **Run incremental backups** during long operations

### 7.3 Post-Migration

- [ ] **Update statistics** on all tables
- [ ] **Recreate indexes** and constraints
- [ ] **Test application connectivity** 
- [ ] **Run performance benchmarks**
- [ ] **Update documentation** with new connection strings
- [ ] **Plan ongoing maintenance** procedures

### 7.4 Performance Tips

1. **Use UNLOGGED tables** for staging (faster writes)
2. **Disable WAL logging** temporarily for bulk operations
3. **Load in dependency order** to avoid constraint violations
4. **Use COPY instead of INSERT** for bulk data
5. **Partition large tables** before migration
6. **Monitor autovacuum** and adjust settings

### 7.5 Security Considerations

- **Encrypt data in transit** between systems
- **Use secure file transfer** methods (SCP, SFTP)
- **Limit access permissions** to migration directories
- **Audit migration activities** for compliance
- **Clean up temporary files** after completion

## Migration Summary

This guide provides a comprehensive framework for migrating CEDS Data Warehouse from SQL Server to PostgreSQL. The process ensures:

✅ **Data Integrity**: All referential relationships maintained  
✅ **Type Safety**: Proper data type conversions applied  
✅ **Performance**: Optimized bulk loading procedures  
✅ **Validation**: Comprehensive quality checks throughout  
✅ **Recovery**: Rollback procedures for failed migrations  
✅ **Documentation**: Complete audit trail of all operations  

The migration scripts and procedures are designed to handle large datasets efficiently while maintaining the highest standards of data quality and system reliability.