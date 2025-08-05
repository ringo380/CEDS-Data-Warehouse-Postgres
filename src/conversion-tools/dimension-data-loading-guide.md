# PostgreSQL Dimension Data Loading Guide

## Overview

This guide provides comprehensive instructions for loading dimension data into the CEDS Data Warehouse PostgreSQL implementation, including automated tools, manual procedures, and best practices.

## Files in This Package

### 1. **Automated Loading Scripts**
- `postgresql-dimension-data-loader.sql` - Main dimension population script
- `convert-etl-procedures.py` - Tool to convert SQL Server ETL procedures
- `convert-tsql-production.py` - Production T-SQL to PL/pgSQL converter

### 2. **Reference Data**
- `Junk-Table-Dimension-Population-V11.0.0.0.sql` - Original SQL Server script
- `CEDS-Elements-V11.0.0.0.zip` - CEDS reference data (extract separately)

### 3. **Documentation**
- This guide
- `sql-server-to-postgresql-security-guide.md` - Security setup

## Prerequisites

### Required Database Setup
```sql
-- 1. Ensure database and schemas exist
\c ceds_data_warehouse_v11_0_0_0;

-- 2. Verify schemas are created
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name IN ('ceds', 'rds', 'staging', 'app');

-- 3. Set appropriate role
SET ROLE ceds_etl_process; -- or appropriate role with write permissions
```

### CEDS Elements Database
The dimension loading process requires CEDS Elements reference data:

1. **Download CEDS Elements:**
   ```bash
   # From https://github.com/CEDStandards/CEDS-Elements
   wget https://github.com/CEDStandards/CEDS-Elements/raw/master/src/CEDS-Elements-V11.0.0.0.sql
   ```

2. **Create CEDS Elements Schema:**
   ```sql
   CREATE SCHEMA IF NOT EXISTS ceds_elements;
   -- Import CEDS-Elements-V11.0.0.0.sql into ceds_elements schema
   ```

## Automated Dimension Loading

### Step 1: Run Main Loader Script
```bash
# Connect to PostgreSQL and run the main loader
psql -d ceds_data_warehouse_v11_0_0_0 -f postgresql-dimension-data-loader.sql
```

This script will:
- ✅ Create utility functions for dimension loading
- ✅ Populate `dim_ae_demographics` with all status combinations
- ✅ Populate `dim_ae_program_types` from CEDS elements
- ✅ Provide framework for additional dimensions
- ✅ Update table statistics for performance

### Step 2: Verify Loading Results
```sql
-- Check populated dimension tables
SELECT 
    schemaname,
    tablename,
    n_tup_ins as rows_inserted,
    n_tup_upd as rows_updated
FROM pg_stat_user_tables 
WHERE schemaname = 'rds' AND tablename LIKE 'dim_%'
ORDER BY tablename;

-- Verify specific dimensions
SELECT COUNT(*) as total_combinations FROM rds.dim_ae_demographics;
SELECT COUNT(*) as program_types FROM rds.dim_ae_program_types;
```

## Manual Dimension Loading

### Common Dimension Patterns

#### 1. **Simple Code/Description Dimensions**
```sql
-- Example: Populate DimGradeLevels
INSERT INTO rds.dim_grade_levels (grade_level_code, grade_level_description)
VALUES 
    ('PK', 'Pre-Kindergarten'),
    ('KG', 'Kindergarten'),
    ('01', 'First grade'),
    ('02', 'Second grade'),
    ('03', 'Third grade'),
    ('04', 'Fourth grade'),
    ('05', 'Fifth grade'),
    ('06', 'Sixth grade'),
    ('07', 'Seventh grade'),  
    ('08', 'Eighth grade'),
    ('09', 'Ninth grade'),
    ('10', 'Tenth grade'),
    ('11', 'Eleventh grade'),
    ('12', 'Twelfth grade')
ON CONFLICT (grade_level_code) DO NOTHING;
```

#### 2. **Junk Dimensions (Cartesian Products)**
```sql
-- Example: Create all combinations for a multi-attribute dimension
WITH status_combinations AS (
    SELECT 
        e.economic_status_code,
        e.economic_status_desc,
        h.homeless_status_code,
        h.homeless_status_desc,
        s.sex_code,
        s.sex_desc
    FROM (VALUES 
        ('Yes', 'Economically Disadvantaged'),
        ('No', 'Not Economically Disadvantaged'),  
        ('MISSING', 'Missing')
    ) AS e(economic_status_code, economic_status_desc)
    CROSS JOIN (VALUES
        ('Yes', 'Homeless'),
        ('No', 'Not Homeless'),
        ('MISSING', 'Missing')  
    ) AS h(homeless_status_code, homeless_status_desc)
    CROSS JOIN (VALUES
        ('Male', 'Male'),
        ('Female', 'Female'),
        ('MISSING', 'Missing')
    ) AS s(sex_code, sex_desc)
)
INSERT INTO rds.dim_student_demographics (
    economic_disadvantage_status_code,
    economic_disadvantage_status_description,
    homelessness_status_code,
    homelessness_status_description,  
    sex_code,
    sex_description
)
SELECT * FROM status_combinations
WHERE NOT EXISTS (
    SELECT 1 FROM rds.dim_student_demographics d
    WHERE d.economic_disadvantage_status_code = status_combinations.economic_status_code
    AND d.homelessness_status_code = status_combinations.homeless_status_code
    AND d.sex_code = status_combinations.sex_code
);
```

#### 3. **Date Dimensions**
```sql
-- Generate date dimension for school years
INSERT INTO rds.dim_school_years (school_year, school_year_start_date, school_year_end_date)
SELECT 
    year_value,
    (year_value - 1)::TEXT || '-07-01'::DATE as start_date,
    year_value::TEXT || '-06-30'::DATE as end_date
FROM generate_series(2010, 2030) AS year_value
WHERE NOT EXISTS (
    SELECT 1 FROM rds.dim_school_years 
    WHERE school_year = year_value
);
```

### Loading from CEDS Elements

#### Query CEDS Elements Data
```sql
-- Find available elements
SELECT DISTINCT ceds_element_technical_name 
FROM ceds_elements.ceds_option_set_mapping 
ORDER BY ceds_element_technical_name;

-- Load specific element
INSERT INTO rds.dim_english_learner_statuses (
    english_learner_status_code,
    english_learner_status_description
)
SELECT 
    cosm.ceds_option_set_code,
    cosm.ceds_option_set_description
FROM ceds_elements.ceds_option_set_mapping cosm
LEFT JOIN rds.dim_english_learner_statuses existing 
    ON existing.english_learner_status_code = cosm.ceds_option_set_code
WHERE cosm.ceds_element_technical_name = 'EnglishLearnerStatus'
AND existing.dim_english_learner_status_id IS NULL;
```

## Converting SQL Server ETL Procedures

### Using the ETL Conversion Tool

#### Convert Single Procedure
```bash
# Convert single stored procedure
python convert-etl-procedures.py \
    --input "Staging-to-DimK12Schools.sql" \
    --output "staging_to_dim_k12_schools.sql"
```

#### Convert Directory of Procedures  
```bash
# Convert all procedures in directory
python convert-etl-procedures.py \
    --directory "../CEDS-Data-Warehouse-Project/Staging/StoredProcedures/" \
    --output-directory "./converted-procedures/"
```

#### Preview Conversions
```bash
# Preview conversion without writing files
python convert-etl-procedures.py \
    --input "complex-procedure.sql" \
    --preview
```

### Manual ETL Conversion Patterns

#### 1. **MERGE Statement Conversion**

**SQL Server MERGE:**
```sql
MERGE RDS.DimK12Schools AS target
USING (SELECT ...) AS source ON (target.Id = source.Id)
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT (...) VALUES (...);
```

**PostgreSQL UPSERT:**
```sql
INSERT INTO rds.dim_k12_schools (school_name, state_code, ...)
SELECT school_name, state_code, ...
FROM staging_source
ON CONFLICT (school_name, state_code) 
DO UPDATE SET 
    operational_status = EXCLUDED.operational_status,
    updated_date = CURRENT_TIMESTAMP
WHERE dim_k12_schools.operational_status != EXCLUDED.operational_status;
```

#### 2. **Error Handling Conversion**

**SQL Server TRY/CATCH:**
```sql
BEGIN TRY
    -- Operation
    INSERT INTO target_table ...
END TRY  
BEGIN CATCH
    INSERT INTO error_log VALUES (ERROR_MESSAGE());
    RAISERROR('Custom error', 16, 1);
END CATCH
```

**PostgreSQL Exception Handling:**
```sql
BEGIN
    -- Operation
    INSERT INTO target_table ...
EXCEPTION 
    WHEN OTHERS THEN
        INSERT INTO error_log VALUES (SQLERRM);
        RAISE EXCEPTION 'Custom error: %', SQLERRM;
END;
```

#### 3. **Temp Table Conversion**

**SQL Server:**
```sql  
CREATE TABLE #temp_schools (id INT, name VARCHAR(100));
INSERT INTO #temp_schools SELECT ...;
-- Process temp table
DROP TABLE #temp_schools;
```

**PostgreSQL:**
```sql
CREATE TEMP TABLE temp_schools (id INTEGER, name VARCHAR(100));
INSERT INTO temp_schools SELECT ...;
-- Process temp table (auto-dropped at session end)
```

## Performance Optimization

### Batch Loading Best Practices

#### 1. **Disable Constraints During Loading**
```sql
-- Disable constraints for bulk loading
ALTER TABLE rds.dim_k12_schools DISABLE TRIGGER ALL;
SET session_replication_role = replica;

-- Perform bulk loading
COPY rds.dim_k12_schools FROM '/path/to/data.csv' WITH CSV HEADER;

-- Re-enable constraints
SET session_replication_role = DEFAULT;
ALTER TABLE rds.dim_k12_schools ENABLE TRIGGER ALL;
```

#### 2. **Use COPY for Large Data Sets**
```sql
-- Faster than INSERT for large datasets
COPY rds.dim_students (student_id, first_name, last_name) 
FROM '/path/to/students.csv' 
WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');
```

#### 3. **Batch Processing**
```sql
-- Process in chunks to avoid long transactions
DO $$
DECLARE
    batch_size INTEGER := 10000;
    processed INTEGER := 0;
    total_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_count FROM staging.k12_enrollment;
    
    WHILE processed < total_count LOOP
        INSERT INTO rds.fact_k12_student_enrollments 
        SELECT ... 
        FROM staging.k12_enrollment 
        WHERE student_id > processed 
        ORDER BY student_id 
        LIMIT batch_size;
        
        processed := processed + batch_size;
        COMMIT; -- Commit each batch
        
        RAISE NOTICE 'Processed %/% records', processed, total_count;
    END LOOP;
END $$;
```

### Indexing Strategy

#### Create Indexes After Loading
```sql
-- Create indexes after bulk loading for better performance
CREATE INDEX CONCURRENTLY idx_dim_k12_schools_state 
ON rds.dim_k12_schools (state_code);

CREATE INDEX CONCURRENTLY idx_dim_k12_schools_name 
ON rds.dim_k12_schools (school_name);

-- Update statistics
ANALYZE rds.dim_k12_schools;
```

## Data Validation and Testing

### Validation Queries

#### 1. **Check for Missing Records**
```sql
-- Verify all required combinations exist
SELECT COUNT(*) as missing_combinations
FROM (
    SELECT s.state_code, s.district_type
    FROM staging.organizations s
    WHERE s.organization_type = 'LEA'
) source
LEFT JOIN rds.dim_leas d ON d.state_code = source.state_code
WHERE d.dim_lea_id IS NULL;
```

#### 2. **Data Quality Checks**
```sql
-- Check for duplicates
SELECT 
    school_name, 
    state_code, 
    COUNT(*) as duplicate_count
FROM rds.dim_k12_schools 
GROUP BY school_name, state_code
HAVING COUNT(*) > 1;

-- Check for missing values in required fields  
SELECT COUNT(*) as records_with_missing_data
FROM rds.dim_k12_schools 
WHERE school_name IS NULL 
   OR school_name = 'MISSING'
   OR state_code IS NULL;
```

#### 3. **Referential Integrity**
```sql
-- Verify foreign key relationships
SELECT COUNT(*) as orphaned_records
FROM rds.fact_k12_student_enrollments f
LEFT JOIN rds.dim_k12_schools s ON f.dim_k12_school_id = s.dim_k12_school_id
WHERE s.dim_k12_school_id IS NULL;
```

## Troubleshooting Common Issues

### 1. **Permission Errors**
```sql
-- Check current role and permissions
SELECT current_user, current_role;

-- Grant necessary permissions
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA rds TO ceds_etl_process;
```

### 2. **CEDS Elements Not Found**
```sql
-- Check if CEDS elements schema exists
SELECT schema_name 
FROM information_schema.schemata 
WHERE schema_name = 'ceds_elements';

-- If missing, create and populate
CREATE SCHEMA ceds_elements;
-- Import CEDS-Elements-V11.0.0.0.sql
```

### 3. **Memory Issues with Large Dimensions**
```sql
-- For very large cartesian products, consider staging approach
CREATE TEMP TABLE temp_combinations AS
SELECT a.code as code_a, b.code as code_b
FROM table_a a, table_b b 
WHERE a.include_flag = true AND b.include_flag = true;

-- Insert in batches
INSERT INTO target_dim 
SELECT * FROM temp_combinations 
WHERE row_number <= 10000;
```

### 4. **Sequence/Identity Issues**
```sql
-- Reset sequences after manual inserts
SELECT setval('rds.dim_k12_schools_dim_k12_school_id_seq', 
    (SELECT MAX(dim_k12_school_id) FROM rds.dim_k12_schools));
```

## Maintenance and Monitoring

### Regular Maintenance Tasks

#### 1. **Update Statistics**
```sql
-- Update table statistics for query optimizer
ANALYZE rds.dim_k12_schools;
ANALYZE rds.dim_students;
-- Or update all dimension tables
ANALYZE;
```

#### 2. **Monitor Dimension Growth**
```sql
-- Track dimension table sizes over time
SELECT 
    schemaname,
    tablename,
    n_tup_ins as total_inserts,
    n_tup_upd as total_updates,
    n_tup_del as total_deletes,
    n_live_tup as current_rows
FROM pg_stat_user_tables 
WHERE schemaname = 'rds' AND tablename LIKE 'dim_%'
ORDER BY n_live_tup DESC;
```

#### 3. **Vacuum and Reindex**
```sql
-- Periodic maintenance
VACUUM ANALYZE rds.dim_k12_schools;

-- Rebuild indexes if needed
REINDEX TABLE rds.dim_k12_schools;
```

## Summary

This comprehensive guide provides:

✅ **Automated Loading**: Scripts for common dimension patterns  
✅ **Manual Procedures**: Step-by-step instructions for custom dimensions  
✅ **Conversion Tools**: Automated SQL Server to PostgreSQL conversion  
✅ **Performance Optimization**: Best practices for large-scale loading  
✅ **Validation**: Data quality and integrity checking  
✅ **Troubleshooting**: Common issues and solutions  
✅ **Maintenance**: Ongoing monitoring and optimization  

The combination of automated tools and manual procedures provides a complete solution for migrating and maintaining CEDS Data Warehouse dimensions in PostgreSQL.