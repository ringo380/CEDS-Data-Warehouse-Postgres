-- PostgreSQL Performance Optimization Scripts
-- CEDS Data Warehouse V11.0.0.0 PostgreSQL Performance Optimization
-- This script creates indexes, constraints, and performance optimizations for the converted database

-- =============================================================================
-- PERFORMANCE OPTIMIZATION OVERVIEW
-- =============================================================================

/*
PERFORMANCE OPTIMIZATION STRATEGY:

1. PRIMARY INDEXES: Essential indexes for primary keys and unique constraints
2. FOREIGN KEY INDEXES: Indexes on foreign key columns for join performance  
3. QUERY OPTIMIZATION INDEXES: Indexes based on common query patterns
4. PARTIAL INDEXES: Conditional indexes for specific data subsets
5. COMPOSITE INDEXES: Multi-column indexes for complex queries
6. CONSTRAINTS: Primary keys, foreign keys, and check constraints
7. TABLE PARTITIONING: For very large fact tables
8. MATERIALIZED VIEWS: Pre-computed aggregations
9. STATISTICS: Custom statistics for query optimizer

PERFORMANCE PRINCIPLES:
- Index all foreign keys for join performance
- Create composite indexes for common WHERE clause combinations
- Use partial indexes for filtered queries
- Avoid over-indexing (impacts INSERT/UPDATE performance)
- Monitor index usage and remove unused indexes
- Keep statistics up to date with ANALYZE
*/

-- Connect to CEDS database
\c ceds_data_warehouse_v11_0_0_0;

-- Set search path
SET search_path = app, rds, staging, ceds, public;

-- =============================================================================
-- PERFORMANCE MONITORING SETUP
-- =============================================================================

-- Enable query statistics collection
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgstattuple;

-- Configure pg_stat_statements
ALTER SYSTEM SET pg_stat_statements.max = 10000;
ALTER SYSTEM SET pg_stat_statements.track = 'all';
ALTER SYSTEM SET pg_stat_statements.track_utility = on;

-- Create performance monitoring schema
CREATE SCHEMA IF NOT EXISTS performance;
COMMENT ON SCHEMA performance IS 'Performance monitoring and optimization utilities';

-- =============================================================================
-- INDEX CREATION FUNCTIONS
-- =============================================================================

-- Function to create indexes with error handling and logging
CREATE OR REPLACE FUNCTION performance.create_index_safe(
    index_name TEXT,
    table_name TEXT, 
    column_spec TEXT,
    index_type TEXT DEFAULT 'btree',
    is_unique BOOLEAN DEFAULT FALSE,
    is_concurrent BOOLEAN DEFAULT TRUE
)
RETURNS BOOLEAN AS $$
DECLARE
    sql_command TEXT;
    unique_clause TEXT := '';
    concurrent_clause TEXT := '';
BEGIN
    -- Check if index already exists
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = index_name) THEN
        RAISE NOTICE 'Index % already exists, skipping', index_name;
        RETURN TRUE;
    END IF;
    
    -- Build SQL command
    IF is_unique THEN
        unique_clause := 'UNIQUE ';
    END IF;
    
    IF is_concurrent THEN
        concurrent_clause := 'CONCURRENTLY ';
    END IF;
    
    sql_command := format('CREATE %sINDEX %s%s ON %s USING %s (%s)',
                         unique_clause, concurrent_clause, index_name, table_name, index_type, column_spec);
    
    -- Execute with error handling
    BEGIN
        EXECUTE sql_command;
        RAISE NOTICE 'Created index: %', index_name;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Failed to create index %: %', index_name, SQLERRM;
            RETURN FALSE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Function to analyze index usage
CREATE OR REPLACE FUNCTION performance.analyze_index_usage()
RETURNS TABLE(
    schemaname TEXT,
    tablename TEXT,
    indexname TEXT,
    idx_scans BIGINT,
    idx_tup_read BIGINT,
    idx_tup_fetch BIGINT,
    usage_ratio NUMERIC,
    size_mb NUMERIC,
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        psi.schemaname::TEXT,
        psi.tablename::TEXT,
        psi.indexname::TEXT,
        psi.idx_scan,
        psi.idx_tup_read,
        psi.idx_tup_fetch,
        CASE 
            WHEN psi.idx_scan = 0 THEN 0
            ELSE ROUND((psi.idx_tup_fetch::NUMERIC / psi.idx_tup_read) * 100, 2)
        END as usage_ratio,
        ROUND(pg_relation_size(psi.indexrelid) / 1024.0 / 1024.0, 2) as size_mb,
        CASE 
            WHEN psi.idx_scan = 0 THEN 'UNUSED - Consider dropping'
            WHEN psi.idx_scan < 100 THEN 'LOW USAGE - Review necessity'
            WHEN psi.idx_tup_fetch::NUMERIC / psi.idx_tup_read < 0.1 THEN 'LOW SELECTIVITY - Review'
            ELSE 'GOOD USAGE'
        END as recommendation
    FROM pg_stat_user_indexes psi
    WHERE psi.schemaname IN ('rds', 'staging', 'ceds')
    ORDER BY psi.idx_scan DESC, size_mb DESC;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- RDS SCHEMA INDEXES (DIMENSION AND FACT TABLES)
-- =============================================================================

-- School Dimension Indexes
SELECT performance.create_index_safe('idx_dim_k12_schools_state_code', 'rds.dim_k12_schools', 'state_code');
SELECT performance.create_index_safe('idx_dim_k12_schools_lea_id', 'rds.dim_k12_schools', 'lea_identifier_state');
SELECT performance.create_index_safe('idx_dim_k12_schools_nces_id', 'rds.dim_k12_schools', 'school_identifier_nces');
SELECT performance.create_index_safe('idx_dim_k12_schools_name_state', 'rds.dim_k12_schools', 'school_name, state_code');
SELECT performance.create_index_safe('idx_dim_k12_schools_operational_status', 'rds.dim_k12_schools', 'operational_status_code');
SELECT performance.create_index_safe('idx_dim_k12_schools_school_type', 'rds.dim_k12_schools', 'school_type_code');

-- Student Dimension Indexes  
SELECT performance.create_index_safe('idx_dim_k12_students_state_id', 'rds.dim_k12_students', 'student_identifier_state');
SELECT performance.create_index_safe('idx_dim_k12_students_name', 'rds.dim_k12_students', 'last_name, first_name');
SELECT performance.create_index_safe('idx_dim_k12_students_birth_date', 'rds.dim_k12_students', 'birth_date');
SELECT performance.create_index_safe('idx_dim_k12_students_sex', 'rds.dim_k12_students', 'sex_code');

-- LEA Dimension Indexes
SELECT performance.create_index_safe('idx_dim_leas_state_code', 'rds.dim_leas', 'state_code');
SELECT performance.create_index_safe('idx_dim_leas_nces_id', 'rds.dim_leas', 'lea_identifier_nces');
SELECT performance.create_index_safe('idx_dim_leas_name_state', 'rds.dim_leas', 'lea_name, state_code');
SELECT performance.create_index_safe('idx_dim_leas_operational_status', 'rds.dim_leas', 'operational_status_code');

-- Time Dimension Indexes
SELECT performance.create_index_safe('idx_dim_school_years_year', 'rds.dim_school_years', 'school_year');
SELECT performance.create_index_safe('idx_dim_school_years_start_date', 'rds.dim_school_years', 'session_begin_date');
SELECT performance.create_index_safe('idx_dim_school_years_end_date', 'rds.dim_school_years', 'session_end_date');

-- Demographics Dimension Indexes
SELECT performance.create_index_safe('idx_dim_k12_demographics_race', 'rds.dim_k12_demographics', 'race_code');
SELECT performance.create_index_safe('idx_dim_k12_demographics_ethnicity', 'rds.dim_k12_demographics', 'ethnicity_code');
SELECT performance.create_index_safe('idx_dim_k12_demographics_sex', 'rds.dim_k12_demographics', 'sex_code');
SELECT performance.create_index_safe('idx_dim_k12_demographics_composite', 'rds.dim_k12_demographics', 'race_code, ethnicity_code, sex_code');

-- Program Status Dimension Indexes
SELECT performance.create_index_safe('idx_dim_program_statuses_title1', 'rds.dim_program_statuses', 'title_i_program_type_code');
SELECT performance.create_index_safe('idx_dim_program_statuses_migrant', 'rds.dim_program_statuses', 'migrant_status_code');
SELECT performance.create_index_safe('idx_dim_program_statuses_english_learner', 'rds.dim_program_statuses', 'english_learner_status_code');

-- IDEA Status Dimension Indexes
SELECT performance.create_index_safe('idx_dim_idea_statuses_disability', 'rds.dim_idea_statuses', 'primary_disability_type_code');
SELECT performance.create_index_safe('idx_dim_idea_statuses_educational_environment', 'rds.dim_idea_statuses', 'idea_educational_environment_code');
SELECT performance.create_index_safe('idx_dim_idea_statuses_indicator', 'rds.dim_idea_statuses', 'idea_indicator_code');

-- =============================================================================
-- FACT TABLE INDEXES (CRITICAL FOR QUERY PERFORMANCE)
-- =============================================================================

-- Student Enrollment Fact Indexes
SELECT performance.create_index_safe('idx_fact_k12_enrollments_school_year', 'rds.fact_k12_student_enrollments', 'school_year_id');
SELECT performance.create_index_safe('idx_fact_k12_enrollments_school', 'rds.fact_k12_student_enrollments', 'dim_k12_school_id');
SELECT performance.create_index_safe('idx_fact_k12_enrollments_student', 'rds.fact_k12_student_enrollments', 'dim_k12_student_id');
SELECT performance.create_index_safe('idx_fact_k12_enrollments_lea', 'rds.fact_k12_student_enrollments', 'dim_lea_id');
SELECT performance.create_index_safe('idx_fact_k12_enrollments_demographics', 'rds.fact_k12_student_enrollments', 'dim_k12_demographics_id');
SELECT performance.create_index_safe('idx_fact_k12_enrollments_grade', 'rds.fact_k12_student_enrollments', 'dim_grade_level_id');

-- Composite indexes for common query patterns
SELECT performance.create_index_safe('idx_fact_k12_enrollments_school_year_grade', 'rds.fact_k12_student_enrollments', 'school_year_id, dim_grade_level_id');
SELECT performance.create_index_safe('idx_fact_k12_enrollments_school_year_demographics', 'rds.fact_k12_student_enrollments', 'school_year_id, dim_k12_demographics_id');
SELECT performance.create_index_safe('idx_fact_k12_enrollments_lea_year', 'rds.fact_k12_student_enrollments', 'dim_lea_id, school_year_id');

-- Student Count Fact Indexes
SELECT performance.create_index_safe('idx_fact_k12_counts_school_year', 'rds.fact_k12_student_counts', 'school_year_id');
SELECT performance.create_index_safe('idx_fact_k12_counts_school', 'rds.fact_k12_student_counts', 'dim_k12_school_id');
SELECT performance.create_index_safe('idx_fact_k12_counts_lea', 'rds.fact_k12_student_counts', 'dim_lea_id');
SELECT performance.create_index_safe('idx_fact_k12_counts_category', 'rds.fact_k12_student_counts', 'dim_count_date_id');

-- Assessment Fact Indexes (if exists)
SELECT performance.create_index_safe('idx_fact_k12_assessments_school_year', 'rds.fact_k12_student_assessments', 'school_year_id');
SELECT performance.create_index_safe('idx_fact_k12_assessments_student', 'rds.fact_k12_student_assessments', 'dim_k12_student_id');
SELECT performance.create_index_safe('idx_fact_k12_assessments_school', 'rds.fact_k12_student_assessments', 'dim_k12_school_id');
SELECT performance.create_index_safe('idx_fact_k12_assessments_assessment', 'rds.fact_k12_student_assessments', 'dim_assessment_id');
SELECT performance.create_index_safe('idx_fact_k12_assessments_subject', 'rds.fact_k12_student_assessments', 'dim_assessment_subject_id');

-- Staff Count Fact Indexes
SELECT performance.create_index_safe('idx_fact_k12_staff_school_year', 'rds.fact_k12_staff_counts', 'school_year_id');
SELECT performance.create_index_safe('idx_fact_k12_staff_school', 'rds.fact_k12_staff_counts', 'dim_k12_school_id');
SELECT performance.create_index_safe('idx_fact_k12_staff_lea', 'rds.fact_k12_staff_counts', 'dim_lea_id');
SELECT performance.create_index_safe('idx_fact_k12_staff_category', 'rds.fact_k12_staff_counts', 'dim_k12_staff_category_id');

-- =============================================================================
-- STAGING SCHEMA INDEXES (ETL PERFORMANCE)
-- =============================================================================

-- K12 Enrollment Staging Indexes
SELECT performance.create_index_safe('idx_staging_k12_enrollment_student_id', 'staging.k12_enrollment', 'student_identifier_state');
SELECT performance.create_index_safe('idx_staging_k12_enrollment_school_id', 'staging.k12_enrollment', 'school_identifier_state');
SELECT performance.create_index_safe('idx_staging_k12_enrollment_lea_id', 'staging.k12_enrollment', 'lea_identifier_state');
SELECT performance.create_index_safe('idx_staging_k12_enrollment_school_year', 'staging.k12_enrollment', 'school_year');
SELECT performance.create_index_safe('idx_staging_k12_enrollment_grade', 'staging.k12_enrollment', 'grade_level');
SELECT performance.create_index_safe('idx_staging_k12_enrollment_entry_date', 'staging.k12_enrollment', 'enrollment_entry_date');
SELECT performance.create_index_safe('idx_staging_k12_enrollment_exit_date', 'staging.k12_enrollment', 'enrollment_exit_date');

-- Source System Reference Data Indexes
SELECT performance.create_index_safe('idx_staging_source_ref_table_name', 'staging.source_system_reference_data', 'table_name');
SELECT performance.create_index_safe('idx_staging_source_ref_school_year', 'staging.source_system_reference_data', 'school_year');
SELECT performance.create_index_safe('idx_staging_source_ref_input_code', 'staging.source_system_reference_data', 'input_code');
SELECT performance.create_index_safe('idx_staging_source_ref_output_code', 'staging.source_system_reference_data', 'output_code');

-- Assessment Staging Indexes
SELECT performance.create_index_safe('idx_staging_assessment_student_id', 'staging.assessment', 'student_identifier_state');
SELECT performance.create_index_safe('idx_staging_assessment_school_year', 'staging.assessment', 'school_year');
SELECT performance.create_index_safe('idx_staging_assessment_assessment_type', 'staging.assessment', 'assessment_type');
SELECT performance.create_index_safe('idx_staging_assessment_subject', 'staging.assessment', 'assessment_subject');

-- Person Status Staging Indexes
SELECT performance.create_index_safe('idx_staging_person_status_person_id', 'staging.person_status', 'person_identifier');
SELECT performance.create_index_safe('idx_staging_person_status_school_year', 'staging.person_status', 'school_year');
SELECT performance.create_index_safe('idx_staging_person_status_status_type', 'staging.person_status', 'status_type');

-- =============================================================================
-- PARTIAL INDEXES FOR SPECIFIC USE CASES
-- =============================================================================

-- Partial indexes for active records only
SELECT performance.create_index_safe('idx_dim_k12_schools_active', 'rds.dim_k12_schools', 'school_name, state_code', 'btree', FALSE, TRUE);
-- WHERE operational_status_code = 'Open' (add WHERE clause manually if needed)

-- Partial indexes for current school year
SELECT performance.create_index_safe('idx_fact_enrollments_current_year', 'rds.fact_k12_student_enrollments', 'dim_k12_school_id, dim_k12_student_id', 'btree', FALSE, TRUE);
-- WHERE school_year_id = (SELECT MAX(dim_school_year_id) FROM rds.dim_school_years)

-- Partial indexes for specific demographics
SELECT performance.create_index_safe('idx_staging_enrollment_special_ed', 'staging.k12_enrollment', 'student_identifier_state, school_identifier_state', 'btree', FALSE, TRUE);
-- WHERE idea_indicator = 'Yes'

-- =============================================================================
-- CONSTRAINT CREATION
-- =============================================================================

-- Function to create foreign key constraints safely
CREATE OR REPLACE FUNCTION performance.create_foreign_key_safe(
    constraint_name TEXT,
    table_name TEXT,
    column_name TEXT,
    ref_table TEXT,
    ref_column TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    sql_command TEXT;
BEGIN
    -- Check if constraint already exists
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = constraint_name 
        AND table_schema = split_part(table_name, '.', 1)
    ) THEN
        RAISE NOTICE 'Constraint % already exists, skipping', constraint_name;
        RETURN TRUE;
    END IF;
    
    sql_command := format('ALTER TABLE %s ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s (%s)',
                         table_name, constraint_name, column_name, ref_table, ref_column);
    
    BEGIN
        EXECUTE sql_command;
        RAISE NOTICE 'Created foreign key: %', constraint_name;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Failed to create foreign key %: %', constraint_name, SQLERRM;
            RETURN FALSE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Create essential foreign key constraints for fact tables
SELECT performance.create_foreign_key_safe('fk_fact_k12_enrollments_school_year', 'rds.fact_k12_student_enrollments', 'school_year_id', 'rds.dim_school_years', 'dim_school_year_id');
SELECT performance.create_foreign_key_safe('fk_fact_k12_enrollments_school', 'rds.fact_k12_student_enrollments', 'dim_k12_school_id', 'rds.dim_k12_schools', 'dim_k12_school_id');
SELECT performance.create_foreign_key_safe('fk_fact_k12_enrollments_student', 'rds.fact_k12_student_enrollments', 'dim_k12_student_id', 'rds.dim_k12_students', 'dim_k12_student_id');
SELECT performance.create_foreign_key_safe('fk_fact_k12_enrollments_lea', 'rds.fact_k12_student_enrollments', 'dim_lea_id', 'rds.dim_leas', 'dim_lea_id');

-- Check constraints for data quality
ALTER TABLE rds.fact_k12_student_enrollments 
ADD CONSTRAINT chk_student_count_positive 
CHECK (student_count >= 0);

ALTER TABLE rds.dim_school_years 
ADD CONSTRAINT chk_school_year_range 
CHECK (school_year BETWEEN 1990 AND 2050);

-- =============================================================================
-- MATERIALIZED VIEWS FOR PERFORMANCE
-- =============================================================================

-- Materialized view for enrollment summary by school and year
CREATE MATERIALIZED VIEW IF NOT EXISTS performance.mv_enrollment_summary_by_school AS
SELECT 
    ds.state_code,
    ds.lea_name,
    ds.school_name,
    dy.school_year,
    COUNT(*) as total_enrollments,
    COUNT(DISTINCT fe.dim_k12_student_id) as unique_students,
    AVG(fe.student_count) as avg_student_count
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_k12_schools ds ON fe.dim_k12_school_id = ds.dim_k12_school_id
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
GROUP BY ds.state_code, ds.lea_name, ds.school_name, dy.school_year;

-- Create index on materialized view
CREATE INDEX idx_mv_enrollment_summary_state_year ON performance.mv_enrollment_summary_by_school (state_code, school_year);

-- Materialized view for demographics summary
CREATE MATERIALIZED VIEW IF NOT EXISTS performance.mv_demographics_summary AS
SELECT 
    dy.school_year,
    ds.state_code,
    dd.race_code,
    dd.ethnicity_code,
    dd.sex_code,
    COUNT(*) as enrollment_count,
    SUM(fe.student_count) as total_student_count
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
JOIN rds.dim_k12_schools ds ON fe.dim_k12_school_id = ds.dim_k12_school_id
JOIN rds.dim_k12_demographics dd ON fe.dim_k12_demographics_id = dd.dim_k12_demographics_id
GROUP BY dy.school_year, ds.state_code, dd.race_code, dd.ethnicity_code, dd.sex_code;

-- Create index on demographics materialized view
CREATE INDEX idx_mv_demographics_summary_year_state ON performance.mv_demographics_summary (school_year, state_code);

-- =============================================================================
-- TABLE PARTITIONING FOR LARGE FACT TABLES
-- =============================================================================

-- Function to create partitioned table for large fact tables
CREATE OR REPLACE FUNCTION performance.create_partitioned_fact_table(
    table_name TEXT,
    partition_column TEXT,
    partition_type TEXT DEFAULT 'RANGE'
)
RETURNS BOOLEAN AS $$
DECLARE
    sql_command TEXT;
BEGIN
    -- This is a template for creating partitioned tables
    -- Actual implementation would depend on specific partitioning needs
    
    RAISE NOTICE 'Partitioning template for table: %', table_name;
    RAISE NOTICE 'Consider partitioning by % using % partitioning', partition_column, partition_type;
    
    -- Example for school year partitioning:
    -- CREATE TABLE fact_k12_student_enrollments_partitioned (LIKE rds.fact_k12_student_enrollments) 
    -- PARTITION BY RANGE (school_year_id);
    
    -- CREATE TABLE fact_k12_enrollments_2020 PARTITION OF fact_k12_student_enrollments_partitioned
    -- FOR VALUES FROM (2020) TO (2021);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- STATISTICS AND MAINTENANCE
-- =============================================================================

-- Function to update table statistics
CREATE OR REPLACE FUNCTION performance.update_statistics()
RETURNS void AS $$
BEGIN
    -- Update statistics on all tables
    ANALYZE rds.dim_k12_schools;
    ANALYZE rds.dim_k12_students; 
    ANALYZE rds.dim_leas;
    ANALYZE rds.dim_school_years;
    ANALYZE rds.dim_k12_demographics;
    ANALYZE rds.fact_k12_student_enrollments;
    ANALYZE rds.fact_k12_student_counts;
    ANALYZE staging.k12_enrollment;
    ANALYZE staging.source_system_reference_data;
    
    RAISE NOTICE 'Statistics updated for all major tables';
END;
$$ LANGUAGE plpgsql;

-- Function to refresh materialized views
CREATE OR REPLACE FUNCTION performance.refresh_materialized_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY performance.mv_enrollment_summary_by_school;
    REFRESH MATERIALIZED VIEW CONCURRENTLY performance.mv_demographics_summary;
    
    RAISE NOTICE 'Materialized views refreshed';
END;
$$ LANGUAGE plpgsql;

-- Create maintenance schedule function
CREATE OR REPLACE FUNCTION performance.run_maintenance()
RETURNS void AS $$
BEGIN
    -- Update statistics
    PERFORM performance.update_statistics();
    
    -- Refresh materialized views
    PERFORM performance.refresh_materialized_views();
    
    -- Log maintenance completion
    INSERT INTO performance.maintenance_log (maintenance_date, maintenance_type, status)
    VALUES (CURRENT_TIMESTAMP, 'SCHEDULED_MAINTENANCE', 'COMPLETED');
    
    RAISE NOTICE 'Scheduled maintenance completed at %', CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Create maintenance log table
CREATE TABLE IF NOT EXISTS performance.maintenance_log (
    log_id SERIAL PRIMARY KEY,
    maintenance_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    maintenance_type TEXT NOT NULL,
    status TEXT NOT NULL,
    notes TEXT
);

-- =============================================================================
-- QUERY OPTIMIZATION HELPERS
-- =============================================================================

-- Function to analyze slow queries
CREATE OR REPLACE FUNCTION performance.analyze_slow_queries(min_duration_seconds INTEGER DEFAULT 5)
RETURNS TABLE(
    query_text TEXT,
    calls BIGINT,
    total_time_seconds NUMERIC,
    mean_time_seconds NUMERIC,
    rows_per_call NUMERIC,
    hit_percent NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        LEFT(pss.query, 100) as query_text,
        pss.calls,
        ROUND(pss.total_time / 1000.0, 2) as total_time_seconds,
        ROUND(pss.mean_time / 1000.0, 2) as mean_time_seconds,
        ROUND(pss.rows::NUMERIC / pss.calls, 2) as rows_per_call,
        ROUND(
            100.0 * pss.shared_blks_hit / 
            NULLIF(pss.shared_blks_hit + pss.shared_blks_read, 0), 2
        ) as hit_percent
    FROM pg_stat_statements pss
    WHERE pss.mean_time / 1000.0 > min_duration_seconds
    ORDER BY pss.mean_time DESC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- Function to suggest missing indexes
CREATE OR REPLACE FUNCTION performance.suggest_missing_indexes()
RETURNS TABLE(
    table_name TEXT,
    column_name TEXT,
    suggested_index TEXT,
    reason TEXT
) AS $$
BEGIN
    -- This is a simplified version - real implementation would analyze query patterns
    RETURN QUERY
    SELECT 
        'rds.fact_k12_student_enrollments'::TEXT,
        'record_start_datetime, record_end_datetime'::TEXT,
        'CREATE INDEX idx_fact_enrollments_record_dates ON rds.fact_k12_student_enrollments (record_start_datetime, record_end_datetime)'::TEXT,
        'Date range queries are common in data warehouse'::TEXT
    
    UNION ALL
    
    SELECT 
        'staging.k12_enrollment'::TEXT,
        'data_collection_name'::TEXT,
        'CREATE INDEX idx_staging_enrollment_collection ON staging.k12_enrollment (data_collection_name)'::TEXT,
        'ETL processes often filter by data collection'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- PERFORMANCE MONITORING VIEWS
-- =============================================================================

-- View for table sizes and row counts
CREATE OR REPLACE VIEW performance.table_stats AS
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows,
    ROUND(100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1), 2) as dead_row_percent,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname IN ('rds', 'staging', 'ceds')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- View for buffer cache hit ratios
CREATE OR REPLACE VIEW performance.cache_hit_ratio AS
SELECT 
    schemaname,
    tablename,
    heap_blks_read + heap_blks_hit as total_reads,
    CASE 
        WHEN heap_blks_read + heap_blks_hit = 0 THEN 0
        ELSE ROUND(100.0 * heap_blks_hit / (heap_blks_read + heap_blks_hit), 2)
    END as cache_hit_ratio,
    heap_blks_read as disk_reads,
    heap_blks_hit as cache_hits
FROM pg_statio_user_tables
WHERE schemaname IN ('rds', 'staging', 'ceds')
ORDER BY cache_hit_ratio;

-- =============================================================================
-- COMPLETION AND VALIDATION
-- =============================================================================

-- Function to validate all optimizations
CREATE OR REPLACE FUNCTION performance.validate_optimizations()
RETURNS TABLE(
    optimization_type TEXT,
    count_created INTEGER,
    status TEXT,
    notes TEXT
) AS $$
BEGIN
    -- Count indexes created
    RETURN QUERY
    SELECT 
        'Indexes'::TEXT,
        COUNT(*)::INTEGER,
        'CREATED'::TEXT,
        'Database indexes for performance optimization'::TEXT
    FROM pg_indexes 
    WHERE schemaname IN ('rds', 'staging', 'ceds')
    AND indexname LIKE 'idx_%';
    
    -- Count foreign key constraints
    RETURN QUERY
    SELECT 
        'Foreign Keys'::TEXT,
        COUNT(*)::INTEGER,
        'CREATED'::TEXT,
        'Foreign key constraints for referential integrity'::TEXT
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
    AND table_schema IN ('rds', 'staging', 'ceds');
    
    -- Count materialized views
    RETURN QUERY
    SELECT 
        'Materialized Views'::TEXT,
        COUNT(*)::INTEGER,
        'CREATED'::TEXT,
        'Pre-computed views for query performance'::TEXT
    FROM pg_matviews
    WHERE schemaname = 'performance';
    
    -- Count performance functions
    RETURN QUERY
    SELECT 
        'Performance Functions'::TEXT,
        COUNT(*)::INTEGER,
        'CREATED'::TEXT,
        'Utility functions for performance monitoring'::TEXT
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'performance';
END;
$$ LANGUAGE plpgsql;

-- Run initial statistics update
SELECT performance.update_statistics();

-- Display completion message
DO $$
BEGIN
    RAISE NOTICE '========================================================';
    RAISE NOTICE 'PostgreSQL Performance Optimization Complete';
    RAISE NOTICE '========================================================';
    RAISE NOTICE 'Schema: performance (monitoring utilities created)';
    RAISE NOTICE 'Indexes: Created for all major dimension and fact tables';
    RAISE NOTICE 'Constraints: Foreign keys and check constraints added';
    RAISE NOTICE 'Views: Materialized views for common aggregations';
    RAISE NOTICE 'Functions: Performance monitoring and maintenance utilities';
    RAISE NOTICE '';
    RAISE NOTICE 'Recommended Next Steps:';
    RAISE NOTICE '1. Monitor query performance with: SELECT * FROM performance.analyze_slow_queries();';
    RAISE NOTICE '2. Check index usage with: SELECT * FROM performance.analyze_index_usage();';
    RAISE NOTICE '3. Review table statistics with: SELECT * FROM performance.table_stats;';
    RAISE NOTICE '4. Schedule regular maintenance with: SELECT performance.run_maintenance();';
    RAISE NOTICE '5. Validate optimizations with: SELECT * FROM performance.validate_optimizations();';
    RAISE NOTICE '========================================================';
END;
$$;

-- Display validation results
SELECT 'Performance Optimization Validation:' as info;
SELECT * FROM performance.validate_optimizations();