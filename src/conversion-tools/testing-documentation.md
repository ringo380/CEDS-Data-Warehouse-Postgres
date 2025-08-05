# PostgreSQL Database Testing and Validation Documentation

## Overview

This comprehensive testing documentation provides complete guidance for validating the PostgreSQL CEDS Data Warehouse conversion. The testing framework ensures data integrity, performance, security, and functional correctness of the migrated database system.

## Table of Contents

1. [Testing Framework Overview](#testing-framework-overview)
2. [Test Categories](#test-categories)
3. [Automated Testing Tools](#automated-testing-tools)
4. [Manual Testing Procedures](#manual-testing-procedures)
5. [Performance Testing](#performance-testing)
6. [Data Integrity Validation](#data-integrity-validation)
7. [Security Testing](#security-testing)
8. [ETL Process Testing](#etl-process-testing)
9. [Reporting Validation](#reporting-validation)
10. [Continuous Testing](#continuous-testing)

## Testing Framework Overview

### Testing Philosophy

The CEDS PostgreSQL testing framework follows these principles:

- **Comprehensive Coverage**: Tests all aspects of the database conversion
- **Automated Execution**: Minimizes manual effort and human error
- **Repeatable Results**: Consistent testing across environments
- **Clear Reporting**: Detailed results with actionable insights
- **Performance Aware**: Validates both functionality and performance
- **Security Focused**: Ensures proper access controls and data protection

### Testing Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Testing Framework                        │
├─────────────────────────────────────────────────────────────┤
│  Validation Suite (SQL)     │  Test Runner (Python)        │
│  ├── Schema Validation      │  ├── Test Orchestration      │
│  ├── Constraint Testing     │  ├── Report Generation       │
│  ├── Function Testing       │  ├── Performance Metrics     │
│  ├── Data Integrity         │  └── CI/CD Integration       │
│  ├── Performance Tests      │                               │
│  ├── Security Tests         │                               │
│  └── ETL Tests              │                               │
├─────────────────────────────────────────────────────────────┤
│                    Reporting Layer                          │
│  ├── HTML Dashboard         │  ├── JSON API Results        │
│  ├── Performance Charts     │  ├── Failed Test Details     │
│  └── Trend Analysis         │  └── Recommendations         │
└─────────────────────────────────────────────────────────────┘
```

## Test Categories

### 1. Schema Validation Tests

**Purpose**: Verify database structure matches conversion specifications

**Test Cases**:
- ✅ **Schema Existence**: Verify all required schemas (rds, staging, ceds, app)
- ✅ **Table Structure**: Confirm all tables exist with correct columns
- ✅ **Data Type Conversion**: Validate SQL Server → PostgreSQL type mappings
- ✅ **Column Properties**: Check nullability, defaults, and constraints
- ✅ **Naming Conventions**: Verify PascalCase → snake_case conversion

**Sample Test**:
```sql
-- Test: Verify dim_k12_schools table structure
SELECT validation.execute_test(
    'SCHEMA_VALIDATION',
    'dim_k12_schools_structure',
    'Verify dim_k12_schools has required columns',
    'SELECT CASE WHEN COUNT(*) = 15 THEN ''CORRECT'' ELSE ''INCORRECT'' END 
     FROM information_schema.columns 
     WHERE table_name = ''dim_k12_schools'' AND table_schema = ''rds''',
    'CORRECT'
);
```

### 2. Constraint Validation Tests

**Purpose**: Ensure referential integrity and data quality constraints

**Test Cases**:
- ✅ **Primary Keys**: Verify all primary key constraints exist
- ✅ **Foreign Keys**: Validate referential integrity constraints
- ✅ **Check Constraints**: Confirm business rule constraints
- ✅ **Unique Constraints**: Verify uniqueness requirements
- ✅ **Not Null Constraints**: Check required field constraints

**Sample Test**:
```sql
-- Test: Verify foreign key relationships
SELECT validation.execute_test(
    'CONSTRAINT_VALIDATION',
    'fact_enrollment_foreign_keys',
    'Verify fact_k12_student_enrollments foreign keys exist',
    'SELECT CASE WHEN COUNT(*) >= 4 THEN ''SUFFICIENT'' ELSE ''MISSING'' END
     FROM information_schema.table_constraints 
     WHERE table_name = ''fact_k12_student_enrollments'' 
     AND constraint_type = ''FOREIGN KEY''',
    'SUFFICIENT'
);
```

### 3. Function Validation Tests

**Purpose**: Verify converted functions work correctly

**Test Cases**:
- ✅ **Function Existence**: Confirm all functions were converted
- ✅ **Parameter Handling**: Test function parameters and return types
- ✅ **Logic Correctness**: Validate function business logic
- ✅ **Error Handling**: Test exception handling and edge cases
- ✅ **Performance**: Ensure functions perform adequately

**Sample Test**:
```sql
-- Test: Age calculation function
SELECT validation.execute_test(
    'FUNCTION_VALIDATION',
    'age_calculation_accuracy',
    'Test age calculation with known values',
    'SELECT CASE WHEN app.get_age(''1990-01-01''::DATE, ''2020-01-01''::DATE) = 30 
           THEN ''ACCURATE'' ELSE ''INACCURATE'' END',
    'ACCURATE'
);
```

### 4. Data Integrity Tests

**Purpose**: Validate data consistency and relationships

**Test Cases**:
- ✅ **Referential Integrity**: Check for orphaned records
- ✅ **Data Consistency**: Verify cross-table data consistency
- ✅ **Value Ranges**: Validate data within expected ranges
- ✅ **Duplicate Detection**: Identify unexpected duplicates
- ✅ **Null Value Analysis**: Check null patterns

### 5. Performance Tests

**Purpose**: Ensure acceptable query and system performance

**Test Cases**:
- ✅ **Index Effectiveness**: Verify indexes improve query performance
- ✅ **Query Response Time**: Test common queries meet SLA requirements
- ✅ **Concurrent Access**: Test multi-user performance
- ✅ **Memory Usage**: Monitor buffer cache efficiency
- ✅ **Storage Performance**: Validate I/O performance

### 6. Security Tests

**Purpose**: Verify access controls and security measures

**Test Cases**:
- ✅ **Role-Based Access**: Test role permissions work correctly
- ✅ **Schema Security**: Verify schema-level access controls
- ✅ **Function Security**: Test function execution permissions
- ✅ **Data Protection**: Validate sensitive data protection
- ✅ **Connection Security**: Test secure connection requirements

### 7. ETL Process Tests

**Purpose**: Validate data loading and transformation processes

**Test Cases**:
- ✅ **Staging Table Access**: Verify staging tables are accessible
- ✅ **Data Loading Functions**: Test dimension loading procedures
- ✅ **Transformation Logic**: Validate data transformation accuracy
- ✅ **Error Handling**: Test ETL error handling and recovery
- ✅ **Performance**: Ensure ETL processes meet time requirements

### 8. Reporting Tests

**Purpose**: Validate common CEDS reporting scenarios

**Test Cases**:
- ✅ **Report Query Structure**: Test standard report queries
- ✅ **Multi-Table Joins**: Verify complex join performance
- ✅ **Aggregation Logic**: Test SUM, COUNT, AVG calculations
- ✅ **Date Filtering**: Validate time-based report filtering
- ✅ **State/District Filtering**: Test geographic filtering

## Automated Testing Tools

### 1. PostgreSQL Validation Suite (`postgresql-validation-suite.sql`)

**Features**:
- 650+ lines of comprehensive testing code
- 8 test categories with 50+ individual tests
- Automated result logging and reporting
- Error handling and recovery
- Performance timing and metrics

**Usage**:
```sql
-- Install and run validation suite
\i postgresql-validation-suite.sql

-- Run comprehensive validation
SELECT validation.run_comprehensive_validation();

-- View results
SELECT * FROM validation.test_results;
SELECT * FROM validation.validation_summary;

-- Generate report
SELECT validation.generate_validation_report();
```

### 2. Python Test Runner (`validation-test-runner.py`)

**Features**:
- Automated test execution and orchestration
- HTML and JSON report generation
- Performance metrics collection
- CI/CD pipeline integration
- Detailed failure analysis

**Usage**:
```bash
# Install dependencies
pip install psycopg2-binary pandas jinja2

# Run full validation
python validation-test-runner.py --config db_config.json --output-dir ./reports

# Generate performance report only
python validation-test-runner.py --config db_config.json --performance-only
```

**Configuration File** (`db_config.json`):
```json
{
  "host": "localhost",
  "port": 5432,
  "database": "ceds_data_warehouse_v11_0_0_0",
  "username": "ceds_admin",
  "password": "your_password"
}
```

## Manual Testing Procedures

### Pre-Testing Checklist

Before running automated tests, complete these manual verification steps:

- [ ] **Database Connection**: Verify connection to PostgreSQL works
- [ ] **Schema Visibility**: Confirm all schemas are visible
- [ ] **Basic Queries**: Test simple SELECT statements work
- [ ] **User Permissions**: Verify test user has required permissions
- [ ] **System Resources**: Ensure adequate CPU, memory, and disk space

### Post-Migration Manual Verification

#### 1. Sample Data Verification

```sql
-- Compare row counts between SQL Server and PostgreSQL
-- (Run on both systems)

-- SQL Server version:
SELECT 'DimK12Schools' as table_name, COUNT(*) as row_count FROM [RDS].[DimK12Schools]
UNION ALL
SELECT 'FactK12StudentEnrollments', COUNT(*) FROM [RDS].[FactK12StudentEnrollments];

-- PostgreSQL version:
SELECT 'dim_k12_schools' as table_name, COUNT(*) as row_count FROM rds.dim_k12_schools
UNION ALL
SELECT 'fact_k12_student_enrollments', COUNT(*) FROM rds.fact_k12_student_enrollments;
```

#### 2. Data Type Validation

```sql
-- Verify data type conversions
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'rds' 
AND table_name = 'dim_k12_schools'
ORDER BY ordinal_position;
```

#### 3. Constraint Verification

```sql
-- Check constraint status
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE connamespace = 'rds'::regnamespace
ORDER BY contype, conname;
```

### Manual Performance Testing

#### 1. Query Performance Baseline

```sql
-- Test common query patterns with EXPLAIN ANALYZE
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    ds.state_code,
    dy.school_year,
    COUNT(*) as enrollment_count
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_k12_schools ds ON fe.dim_k12_school_id = ds.dim_k12_school_id
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
WHERE dy.school_year BETWEEN 2020 AND 2023
GROUP BY ds.state_code, dy.school_year
ORDER BY enrollment_count DESC;
```

#### 2. Index Usage Analysis

```sql
-- Monitor index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname IN ('rds', 'staging', 'ceds')
ORDER BY idx_scan DESC;
```

#### 3. Memory and Cache Analysis

```sql
-- Check buffer cache hit ratio
SELECT 
    schemaname,
    tablename,
    heap_blks_read,
    heap_blks_hit,
    CASE 
        WHEN heap_blks_read + heap_blks_hit = 0 THEN 0
        ELSE ROUND(100.0 * heap_blks_hit / (heap_blks_read + heap_blks_hit), 2)
    END as cache_hit_ratio
FROM pg_statio_user_tables
WHERE schemaname IN ('rds', 'staging', 'ceds')
ORDER BY cache_hit_ratio;
```

## Performance Testing

### Performance Test Categories

#### 1. **Query Performance Tests**

**Baseline Queries**:
```sql
-- Test 1: Simple dimension lookup (target: < 50ms)
\timing on
SELECT COUNT(*) FROM rds.dim_k12_schools WHERE state_code = 'CA';

-- Test 2: Fact table aggregation (target: < 5 seconds)
SELECT 
    COUNT(*) as total_enrollments,
    AVG(student_count) as avg_count
FROM rds.fact_k12_student_enrollments 
WHERE school_year_id = (SELECT dim_school_year_id FROM rds.dim_school_years WHERE school_year = 2023);

-- Test 3: Complex join query (target: < 10 seconds)
SELECT 
    ds.state_code,
    COUNT(DISTINCT fe.dim_k12_student_id) as unique_students,
    SUM(fe.student_count) as total_count
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_k12_schools ds ON fe.dim_k12_school_id = ds.dim_k12_school_id
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
WHERE dy.school_year = 2023
GROUP BY ds.state_code
ORDER BY total_count DESC;
```

#### 2. **Concurrent User Testing**

Use `pgbench` for concurrent user simulation:

```bash
# Create test script file (test_query.sql)
cat > test_query.sql << EOF
SELECT COUNT(*) FROM rds.dim_k12_schools WHERE state_code = 'TX';
SELECT COUNT(*) FROM rds.fact_k12_student_enrollments WHERE school_year_id = 1;
EOF

# Run concurrent test (10 clients, 5 minutes)
pgbench -c 10 -T 300 -f test_query.sql ceds_data_warehouse_v11_0_0_0
```

#### 3. **Load Testing**

```sql
-- Test ETL load performance
\timing on
INSERT INTO staging.k12_enrollment (
    student_identifier_state, school_identifier_state, 
    school_year, grade_level, enrollment_entry_date
)
SELECT 
    'STUDENT_' || generate_series(1, 10000),
    'SCHOOL_001',
    2023,
    'K',
    CURRENT_DATE - (random() * 365)::integer
FROM generate_series(1, 10000);

-- Measure time and check performance
SELECT pg_size_pretty(pg_total_relation_size('staging.k12_enrollment'));
```

### Performance Benchmarks

| Test Category | Target Performance | Acceptable Range | Action Required |
|---------------|-------------------|------------------|-----------------|
| **Simple Queries** | < 50ms | < 100ms | Optimize if > 100ms |
| **Dimension Lookups** | < 100ms | < 200ms | Add indexes if > 200ms |
| **Fact Aggregations** | < 5 seconds | < 10 seconds | Review query plan if > 10s |
| **Complex Reports** | < 30 seconds | < 60 seconds | Consider materialized views if > 60s |
| **ETL Batch Loads** | > 10,000 rows/sec | > 5,000 rows/sec | Optimize bulk loading if < 5,000 |
| **Cache Hit Ratio** | > 95% | > 90% | Increase shared_buffers if < 90% |

## Data Integrity Validation

### Integrity Test Procedures

#### 1. **Referential Integrity**

```sql
-- Check for orphaned records in fact tables
CREATE OR REPLACE FUNCTION validation.check_referential_integrity()
RETURNS TABLE(
    table_name TEXT,
    foreign_key TEXT,
    orphaned_count BIGINT
) AS $$
BEGIN
    -- Check fact_k12_student_enrollments
    RETURN QUERY
    SELECT 
        'fact_k12_student_enrollments'::TEXT,
        'dim_k12_school_id'::TEXT,
        COUNT(*)
    FROM rds.fact_k12_student_enrollments f
    LEFT JOIN rds.dim_k12_schools s ON f.dim_k12_school_id = s.dim_k12_school_id
    WHERE s.dim_k12_school_id IS NULL AND f.dim_k12_school_id IS NOT NULL;
    
    -- Add more referential integrity checks as needed
END;
$$ LANGUAGE plpgsql;

-- Run integrity check
SELECT * FROM validation.check_referential_integrity();
```

#### 2. **Data Consistency Checks**

```sql
-- Check for data inconsistencies
SELECT 
    'Invalid School Years' as check_name,
    COUNT(*) as issue_count
FROM rds.dim_school_years 
WHERE school_year < 1990 OR school_year > 2030

UNION ALL

SELECT 
    'Future Birth Dates',
    COUNT(*)
FROM rds.dim_k12_students 
WHERE birth_date > CURRENT_DATE

UNION ALL

SELECT 
    'Invalid Grade Levels',
    COUNT(*)
FROM rds.dim_grade_levels 
WHERE grade_level_code NOT IN ('K', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12');
```

#### 3. **Business Rule Validation**

```sql
-- Validate business rules
SELECT 
    'Students with Future Enrollment' as rule_name,
    COUNT(*) as violations
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_school_years sy ON fe.school_year_id = sy.dim_school_year_id
WHERE sy.session_begin_date > CURRENT_DATE

UNION ALL

SELECT 
    'Negative Student Counts',
    COUNT(*)
FROM rds.fact_k12_student_enrollments
WHERE student_count < 0;
```

## Security Testing

### Security Test Procedures

#### 1. **Role-Based Access Control**

```sql
-- Test 1: Verify roles exist
SELECT 
    rolname,
    rolsuper,
    rolcreaterole,
    rolcreatedb,
    rolcanlogin
FROM pg_roles 
WHERE rolname LIKE 'ceds_%'
ORDER BY rolname;

-- Test 2: Check role permissions
SELECT 
    r.rolname,
    n.nspname as schema_name,
    p.privilege_type
FROM information_schema.role_usage_grants p
JOIN pg_roles r ON p.grantee = r.rolname
JOIN pg_namespace n ON p.object_name = n.nspname
WHERE r.rolname LIKE 'ceds_%'
ORDER BY r.rolname, n.nspname, p.privilege_type;
```

#### 2. **Data Access Testing**

```sql
-- Test different role access levels
-- (Run as different users)

-- As ceds_data_reader (should work)
SELECT COUNT(*) FROM rds.dim_k12_schools;

-- As ceds_data_reader (should fail)
INSERT INTO rds.dim_k12_schools (school_name) VALUES ('Test School');

-- As ceds_data_writer (should work)
INSERT INTO staging.k12_enrollment (student_identifier_state, school_year) 
VALUES ('TEST_STUDENT', 2023);
```

#### 3. **Function Security Testing**

```sql
-- Test function execution permissions
-- (Run as different users)

-- Should work for authorized users
SELECT app.get_age('1990-01-01'::DATE, CURRENT_DATE);

-- Should fail for unauthorized users (if restrictions in place)
SELECT migration.convert_sqlserver_datetime('2023-01-01 10:00:00');
```

## ETL Process Testing

### ETL Test Procedures

#### 1. **Staging Data Load Testing**

```sql
-- Test 1: Basic staging table access
INSERT INTO staging.k12_enrollment (
    student_identifier_state,
    school_identifier_state,
    lea_identifier_state,
    school_year,
    grade_level,
    enrollment_entry_date
) VALUES (
    'TEST_STUDENT_001',
    'TEST_SCHOOL_001',
    'TEST_LEA_001',
    2023,
    '05',
    '2023-08-15'
);

-- Verify insert worked
SELECT * FROM staging.k12_enrollment WHERE student_identifier_state = 'TEST_STUDENT_001';

-- Clean up test data
DELETE FROM staging.k12_enrollment WHERE student_identifier_state = 'TEST_STUDENT_001';
```

#### 2. **Data Transformation Testing**

```sql
-- Test dimension loading functions
SELECT app.populate_simple_dimension(
    'rds.dim_test',
    'id',
    'code',
    'description',
    'TestElement',
    ARRAY[ARRAY['TEST001', 'Test Value 1'], ARRAY['TEST002', 'Test Value 2']]
);

-- Verify transformation results
SELECT * FROM rds.dim_test WHERE code LIKE 'TEST%';
```

#### 3. **ETL Performance Testing**

```sql
-- Test bulk loading performance
\timing on

-- Load test data
INSERT INTO staging.k12_enrollment (
    student_identifier_state, school_identifier_state, 
    school_year, grade_level
)
SELECT 
    'PERF_TEST_' || generate_series(1, 50000),
    'SCHOOL_' || ((generate_series(1, 50000) % 1000) + 1),
    2023,
    (ARRAY['K','01','02','03','04','05'])[floor(random() * 6) + 1]
FROM generate_series(1, 50000);

-- Measure load time and verify count
SELECT COUNT(*) FROM staging.k12_enrollment WHERE student_identifier_state LIKE 'PERF_TEST_%';

-- Clean up
DELETE FROM staging.k12_enrollment WHERE student_identifier_state LIKE 'PERF_TEST_%';
```

## Reporting Validation

### Report Testing Procedures

#### 1. **Standard CEDS Reports**

```sql
-- Test 1: Enrollment Count by State and Year
SELECT 
    ds.state_code,
    dy.school_year,
    COUNT(*) as enrollment_count,
    SUM(fe.student_count) as total_students
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_k12_schools ds ON fe.dim_k12_school_id = ds.dim_k12_school_id
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
WHERE dy.school_year BETWEEN 2020 AND 2023
GROUP BY ds.state_code, dy.school_year
ORDER BY ds.state_code, dy.school_year;

-- Test 2: Demographics Report
SELECT 
    dd.race_code,
    dd.ethnicity_code,
    dd.sex_code,
    COUNT(*) as student_count
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_k12_demographics dd ON fe.dim_k12_demographics_id = dd.dim_k12_demographics_id
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
WHERE dy.school_year = 2023
GROUP BY dd.race_code, dd.ethnicity_code, dd.sex_code
ORDER BY student_count DESC;
```

#### 2. **Report Performance Testing**

```sql
-- Test report generation time
\timing on

-- Complex analytical query
SELECT 
    ds.state_code,
    ds.lea_name,
    dy.school_year,
    dg.grade_level_code,
    COUNT(DISTINCT fe.dim_k12_student_id) as unique_students,
    AVG(fe.student_count) as avg_enrollment
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_k12_schools ds ON fe.dim_k12_school_id = ds.dim_k12_school_id
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
JOIN rds.dim_grade_levels dg ON fe.dim_grade_level_id = dg.dim_grade_level_id
WHERE dy.school_year BETWEEN 2020 AND 2023
AND ds.state_code IN ('CA', 'TX', 'NY', 'FL')
GROUP BY ds.state_code, ds.lea_name, dy.school_year, dg.grade_level_code
HAVING COUNT(DISTINCT fe.dim_k12_student_id) > 100
ORDER BY ds.state_code, ds.lea_name, dy.school_year, dg.grade_level_code;
```

## Continuous Testing

### CI/CD Integration

#### 1. **Automated Test Pipeline**

```yaml
# .github/workflows/database-validation.yml
name: Database Validation

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  validate-database:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: 3.9
    
    - name: Install dependencies
      run: |
        pip install psycopg2-binary pandas jinja2
    
    - name: Run validation tests
      run: |
        python validation-test-runner.py --config ci-config.json --output-dir ./test-reports
    
    - name: Upload test reports
      uses: actions/upload-artifact@v2
      with:
        name: validation-reports
        path: ./test-reports/
```

#### 2. **Scheduled Health Checks**

```sql
-- Create scheduled health check procedure
CREATE OR REPLACE FUNCTION validation.daily_health_check()
RETURNS void AS $$
BEGIN
    -- Run subset of critical tests daily
    PERFORM validation.test_schema_structure();
    PERFORM validation.test_performance();
    
    -- Log results and send alerts if needed
    INSERT INTO validation.health_check_log (
        check_date,
        tests_run,
        tests_passed,
        status
    )
    SELECT 
        CURRENT_DATE,
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'PASS'),
        CASE 
            WHEN COUNT(*) FILTER (WHERE status = 'FAIL') = 0 THEN 'HEALTHY'
            ELSE 'ISSUES_DETECTED'
        END
    FROM validation.test_results
    WHERE test_timestamp::date = CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- Schedule with pg_cron (if available)
-- SELECT cron.schedule('daily-health-check', '0 6 * * *', 'SELECT validation.daily_health_check();');
```

### Monitoring and Alerting

#### 1. **Performance Monitoring**

```sql
-- Create performance monitoring function
CREATE OR REPLACE FUNCTION validation.monitor_performance()
RETURNS TABLE(
    metric_name TEXT,
    current_value NUMERIC,
    threshold_value NUMERIC,
    status TEXT
) AS $$
BEGIN
    -- Cache hit ratio
    RETURN QUERY
    SELECT 
        'Buffer Cache Hit Ratio'::TEXT,
        ROUND(100.0 * SUM(heap_blks_hit) / NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0), 2),
        95.0,
        CASE 
            WHEN ROUND(100.0 * SUM(heap_blks_hit) / NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0), 2) >= 95 
            THEN 'OK' 
            ELSE 'WARNING' 
        END
    FROM pg_statio_user_tables
    WHERE schemaname IN ('rds', 'staging', 'ceds');
    
    -- Add more performance metrics...
END;
$$ LANGUAGE plpgsql;
```

#### 2. **Automated Alerting**

```python
# monitoring_alerts.py
import smtplib
from email.mime.text import MIMEText
import psycopg2

def check_and_alert():
    conn = psycopg2.connect(
        host='localhost',
        database='ceds_data_warehouse_v11_0_0_0',
        user='monitor_user',
        password='monitor_password'
    )
    cursor = conn.cursor()
    
    # Check for failed tests
    cursor.execute("""
        SELECT COUNT(*) FROM validation.test_results 
        WHERE status = 'FAIL' 
        AND test_timestamp > NOW() - INTERVAL '1 day'
    """)
    
    failed_tests = cursor.fetchone()[0]
    
    if failed_tests > 0:
        send_alert(f"Database validation failed: {failed_tests} tests failed")
    
    cursor.close()
    conn.close()

def send_alert(message):
    # Configure SMTP settings
    smtp_server = "smtp.company.com"
    smtp_port = 587
    sender_email = "alerts@company.com"
    recipient_email = "dba@company.com"
    
    msg = MIMEText(message)
    msg['Subject'] = 'CEDS Database Alert'
    msg['From'] = sender_email
    msg['To'] = recipient_email
    
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        server.starttls()
        server.login(sender_email, "password")
        server.send_message(msg)

if __name__ == "__main__":
    check_and_alert()
```

## Best Practices and Recommendations

### Testing Best Practices

1. **Run Tests Regularly**:
   - Daily: Critical function and performance tests
   - Weekly: Full validation suite
   - Monthly: Comprehensive integrity and security audits

2. **Version Control Tests**:
   - Store all test scripts in version control
   - Track test result history and trends
   - Document test failures and resolutions

3. **Environment Consistency**:
   - Use consistent test data across environments
   - Maintain identical schema structures
   - Document environment-specific configurations

4. **Performance Baselines**:
   - Establish performance baselines after initial deployment
   - Monitor performance trends over time
   - Alert on significant performance degradation

5. **Documentation**:
   - Document all test procedures and expected results
   - Maintain runbooks for test failures
   - Keep test documentation current with schema changes

### Troubleshooting Common Issues

#### Failed Schema Tests
- **Cause**: Missing tables or incorrect column types
- **Solution**: Re-run conversion scripts, verify migration completion
- **Prevention**: Use automated schema comparison tools

#### Performance Degradation
- **Cause**: Missing indexes, outdated statistics, increased data volume
- **Solution**: Add indexes, run ANALYZE, optimize queries
- **Prevention**: Regular performance monitoring and maintenance

#### Data Integrity Violations
- **Cause**: ETL process errors, manual data changes
- **Solution**: Identify source of bad data, implement data quality checks
- **Prevention**: Validate data at ingestion, use constraints

#### Security Test Failures
- **Cause**: Incorrect role assignments, permission changes
- **Solution**: Review and correct role permissions
- **Prevention**: Automated security configuration management

## Conclusion

This comprehensive testing framework ensures the CEDS PostgreSQL Data Warehouse meets all functional, performance, and security requirements. The combination of automated testing tools and manual procedures provides thorough validation coverage while supporting ongoing maintenance and monitoring needs.

### Testing Success Criteria

✅ **Functional Requirements**: All converted components work correctly  
✅ **Performance Standards**: Queries meet response time requirements  
✅ **Data Integrity**: All relationships and constraints are valid  
✅ **Security Compliance**: Access controls function as designed  
✅ **ETL Processes**: Data loading and transformation work reliably  
✅ **Reporting Capability**: Standard reports generate correctly  

The testing framework provides a solid foundation for maintaining database quality and supporting the CEDS community's data warehousing needs on PostgreSQL.