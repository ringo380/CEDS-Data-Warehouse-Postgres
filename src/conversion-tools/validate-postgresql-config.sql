-- PostgreSQL Configuration Validation Script
-- This script validates that PostgreSQL is properly configured for CEDS Data Warehouse

-- Connect to the database
\c ceds_data_warehouse_v11_0_0_0;

-- =============================================================================
-- CONFIGURATION VALIDATION REPORT
-- =============================================================================

\echo '============================================================'
\echo 'PostgreSQL Configuration Validation for CEDS Data Warehouse'
\echo '============================================================'

-- Check PostgreSQL version
SELECT 
    'PostgreSQL Version' as check_category,
    version() as current_value,
    CASE 
        WHEN version() ~ '1[0-9]\.' THEN '✅ PASS'
        WHEN version() ~ '9\.[56789]\.' THEN '⚠️  WARNING' 
        ELSE '❌ FAIL'
    END as status,
    'PostgreSQL 10+ recommended, 9.5+ minimum' as recommendation;

-- Database encoding and collation
SELECT 
    'Database Encoding' as check_category,
    pg_encoding_to_char(encoding) as current_value,
    CASE 
        WHEN pg_encoding_to_char(encoding) = 'UTF8' THEN '✅ PASS'
        ELSE '⚠️  WARNING'
    END as status,
    'UTF8 encoding recommended for international compatibility' as recommendation
FROM pg_database 
WHERE datname = 'ceds_data_warehouse_v11_0_0_0';

-- =============================================================================
-- MEMORY CONFIGURATION VALIDATION
-- =============================================================================

\echo ''
\echo 'Memory Configuration Validation:'
\echo '================================'

-- Shared buffers check
WITH memory_settings AS (
    SELECT 
        name,
        setting,
        unit,
        CASE 
            WHEN unit = '8kB' THEN setting::bigint * 8 * 1024
            WHEN unit = 'kB' THEN setting::bigint * 1024  
            WHEN unit = 'MB' THEN setting::bigint * 1024 * 1024
            WHEN unit = 'GB' THEN setting::bigint * 1024 * 1024 * 1024
            ELSE setting::bigint
        END as bytes_value
    FROM pg_settings 
    WHERE name IN ('shared_buffers', 'effective_cache_size', 'work_mem', 'maintenance_work_mem')
)
SELECT 
    'Shared Buffers' as check_category,
    setting || COALESCE(unit, '') as current_value,
    CASE 
        WHEN bytes_value >= 128 * 1024 * 1024 THEN '✅ PASS'  -- >= 128MB
        WHEN bytes_value >= 64 * 1024 * 1024 THEN '⚠️  WARNING'   -- >= 64MB
        ELSE '❌ FAIL'
    END as status,
    'Minimum 128MB recommended, ideally 25% of available RAM' as recommendation
FROM memory_settings 
WHERE name = 'shared_buffers'

UNION ALL

SELECT 
    'Effective Cache Size' as check_category,
    setting || COALESCE(unit, '') as current_value,
    CASE 
        WHEN bytes_value >= 512 * 1024 * 1024 THEN '✅ PASS'  -- >= 512MB
        WHEN bytes_value >= 256 * 1024 * 1024 THEN '⚠️  WARNING'   -- >= 256MB  
        ELSE '❌ FAIL'
    END as status,
    'Should be 50-75% of available system RAM' as recommendation
FROM memory_settings 
WHERE name = 'effective_cache_size'

UNION ALL

SELECT 
    'Work Memory' as check_category,
    setting || COALESCE(unit, '') as current_value,
    CASE 
        WHEN bytes_value >= 16 * 1024 * 1024 THEN '✅ PASS'   -- >= 16MB
        WHEN bytes_value >= 8 * 1024 * 1024 THEN '⚠️  WARNING'    -- >= 8MB
        ELSE '❌ FAIL'
    END as status,
    'Minimum 16MB, adjust based on query complexity and concurrency' as recommendation
FROM memory_settings 
WHERE name = 'work_mem'

UNION ALL

SELECT 
    'Maintenance Work Memory' as check_category,
    setting || COALESCE(unit, '') as current_value,
    CASE 
        WHEN bytes_value >= 64 * 1024 * 1024 THEN '✅ PASS'   -- >= 64MB
        WHEN bytes_value >= 32 * 1024 * 1024 THEN '⚠️  WARNING'    -- >= 32MB
        ELSE '❌ FAIL'
    END as status,
    'Minimum 64MB for VACUUM and CREATE INDEX operations' as recommendation
FROM memory_settings 
WHERE name = 'maintenance_work_mem';

-- =============================================================================
-- PERFORMANCE CONFIGURATION VALIDATION
-- =============================================================================

\echo ''  
\echo 'Performance Configuration Validation:'
\echo '===================================='

SELECT 
    'Random Page Cost' as check_category,
    setting as current_value,
    CASE 
        WHEN setting::numeric BETWEEN 1.0 AND 2.0 THEN '✅ PASS (SSD optimized)'
        WHEN setting::numeric BETWEEN 3.0 AND 5.0 THEN '✅ PASS (HDD optimized)'
        ELSE '⚠️  WARNING'
    END as status,
    '1.1 for SSD storage, 4.0 for traditional HDD' as recommendation
FROM pg_settings 
WHERE name = 'random_page_cost'

UNION ALL

SELECT 
    'Checkpoint Completion Target' as check_category,
    setting as current_value,
    CASE 
        WHEN setting::numeric BETWEEN 0.7 AND 0.9 THEN '✅ PASS'
        ELSE '⚠️  WARNING'
    END as status,
    'Should be between 0.7 and 0.9 for smooth checkpoint distribution' as recommendation
FROM pg_settings 
WHERE name = 'checkpoint_completion_target'

UNION ALL

SELECT 
    'WAL Buffers' as check_category,
    setting || unit as current_value,
    CASE 
        WHEN setting::integer >= 1024 THEN '✅ PASS'  -- >= 1MB (assuming kB units)
        ELSE '⚠️  WARNING'
    END as status,
    'Minimum 1MB, recommended 16MB for data warehouse workloads' as recommendation
FROM pg_settings 
WHERE name = 'wal_buffers';

-- =============================================================================
-- PARALLEL PROCESSING VALIDATION
-- =============================================================================

\echo ''
\echo 'Parallel Processing Validation:'
\echo '==============================='

SELECT 
    'Max Parallel Workers Per Gather' as check_category,
    setting as current_value,
    CASE 
        WHEN setting::integer >= 2 THEN '✅ PASS'
        WHEN setting::integer >= 1 THEN '⚠️  WARNING'
        ELSE '❌ FAIL'
    END as status,
    'Minimum 2, recommended 4-8 for analytical queries' as recommendation
FROM pg_settings 
WHERE name = 'max_parallel_workers_per_gather'

UNION ALL

SELECT 
    'Max Parallel Workers' as check_category,
    setting as current_value,
    CASE 
        WHEN setting::integer >= 4 THEN '✅ PASS'
        WHEN setting::integer >= 2 THEN '⚠️  WARNING'
        ELSE '❌ FAIL'
    END as status,
    'Should be 2x max_parallel_workers_per_gather' as recommendation
FROM pg_settings 
WHERE name = 'max_parallel_workers';

-- =============================================================================
-- MAINTENANCE AND STATISTICS VALIDATION
-- =============================================================================

\echo ''
\echo 'Maintenance and Statistics Validation:'
\echo '======================================'

SELECT 
    'Autovacuum Enabled' as check_category,
    setting as current_value,
    CASE 
        WHEN setting = 'on' THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as status,
    'Must be enabled for automatic maintenance' as recommendation
FROM pg_settings 
WHERE name = 'autovacuum'

UNION ALL

SELECT 
    'Track Counts' as check_category,
    setting as current_value,
    CASE 
        WHEN setting = 'on' THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as status,
    'Required for query optimization and autovacuum' as recommendation
FROM pg_settings 
WHERE name = 'track_counts'

UNION ALL

SELECT 
    'Track Activities' as check_category,
    setting as current_value,
    CASE 
        WHEN setting = 'on' THEN '✅ PASS'
        ELSE '⚠️  WARNING'
    END as status,
    'Enables monitoring of running queries' as recommendation
FROM pg_settings 
WHERE name = 'track_activities'

UNION ALL

SELECT 
    'Autovacuum Naptime' as check_category,
    setting || 's' as current_value,
    CASE 
        WHEN setting::integer <= 300 THEN '✅ PASS'  -- <= 5 minutes
        WHEN setting::integer <= 600 THEN '⚠️  WARNING'   -- <= 10 minutes
        ELSE '❌ FAIL'
    END as status,
    'Recommended 5 minutes or less for data warehouse workloads' as recommendation
FROM pg_settings 
WHERE name = 'autovacuum_naptime';

-- =============================================================================
-- DATABASE-SPECIFIC SETTINGS VALIDATION
-- =============================================================================

\echo ''
\echo 'Database-Specific Settings Validation:'
\echo '====================================='

-- Check database-specific settings
WITH db_settings AS (
    SELECT 
        unnest(setconfig) as setting_line
    FROM pg_db_role_setting 
    WHERE setdatabase = (SELECT oid FROM pg_database WHERE datname = 'ceds_data_warehouse_v11_0_0_0')
    AND setrole = 0
),
parsed_settings AS (
    SELECT 
        split_part(setting_line, '=', 1) as setting_name,
        split_part(setting_line, '=', 2) as setting_value
    FROM db_settings
)
SELECT 
    'Database-Specific Settings Count' as check_category,
    COUNT(*)::text as current_value,
    CASE 
        WHEN COUNT(*) >= 10 THEN '✅ PASS'
        WHEN COUNT(*) >= 5 THEN '⚠️  WARNING'
        ELSE '❌ FAIL'
    END as status,
    'Should have essential database-specific configurations applied' as recommendation
FROM parsed_settings;

-- List applied database-specific settings
\echo ''
\echo 'Applied Database-Specific Settings:'
\echo '=================================='

SELECT 
    split_part(unnest(setconfig), '=', 1) as setting_name,
    split_part(unnest(setconfig), '=', 2) as setting_value
FROM pg_db_role_setting 
WHERE setdatabase = (SELECT oid FROM pg_database WHERE datname = 'ceds_data_warehouse_v11_0_0_0')
AND setrole = 0
ORDER BY setting_name;

-- =============================================================================
-- EXTENSION VALIDATION
-- =============================================================================

\echo ''
\echo 'Extension Validation:'
\echo '===================='

SELECT 
    'Essential Extensions' as check_category,
    string_agg(extname, ', ' ORDER BY extname) as current_value,
    CASE 
        WHEN COUNT(*) >= 3 THEN '✅ PASS'
        WHEN COUNT(*) >= 1 THEN '⚠️  WARNING'
        ELSE '❌ FAIL'
    END as status,
    'Recommended: uuid-ossp, pg_trgm, btree_gin, pgstattuple' as recommendation
FROM pg_extension 
WHERE extname IN ('uuid-ossp', 'pg_trgm', 'btree_gin', 'pgstattuple', 'pg_stat_statements');

-- =============================================================================
-- SCHEMA AND SECURITY VALIDATION
-- =============================================================================

\echo ''
\echo 'Schema and Security Validation:'
\echo '==============================='

-- Check schemas exist
SELECT 
    'CEDS Schemas' as check_category,
    string_agg(schema_name, ', ' ORDER BY schema_name) as current_value,
    CASE 
        WHEN COUNT(*) = 4 THEN '✅ PASS'
        WHEN COUNT(*) >= 3 THEN '⚠️  WARNING'
        ELSE '❌ FAIL'
    END as status,
    'Should have: ceds, rds, staging, app schemas' as recommendation
FROM information_schema.schemata 
WHERE schema_name IN ('ceds', 'rds', 'staging', 'app');

-- Check roles exist  
SELECT 
    'CEDS Roles' as check_category,
    COUNT(*)::text as current_value,
    CASE 
        WHEN COUNT(*) >= 6 THEN '✅ PASS'
        WHEN COUNT(*) >= 3 THEN '⚠️  WARNING'
        ELSE '❌ FAIL'
    END as status,
    'Should have functional roles: reader, analyst, writer, etl, application, admin' as recommendation
FROM pg_roles 
WHERE rolname LIKE 'ceds_%';

-- =============================================================================
-- PERFORMANCE MONITORING SETUP
-- =============================================================================

\echo ''
\echo 'Performance Monitoring Setup:'
\echo '============================'

-- Check if pg_stat_statements is available
SELECT 
    'Query Statistics Extension' as check_category,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') 
        THEN 'Installed'
        ELSE 'Not Installed'
    END as current_value,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') 
        THEN '✅ PASS'
        ELSE '⚠️  WARNING'
    END as status,
    'pg_stat_statements recommended for query performance monitoring' as recommendation;

-- Check slow query logging
SELECT 
    'Slow Query Logging' as check_category,
    CASE 
        WHEN setting::integer > 0 THEN setting || 'ms'
        ELSE 'Disabled'
    END as current_value,
    CASE 
        WHEN setting::integer BETWEEN 1000 AND 10000 THEN '✅ PASS'
        WHEN setting::integer > 0 THEN '⚠️  WARNING'
        ELSE '❌ FAIL'
    END as status,
    'Recommended: 1000-5000ms for data warehouse workloads' as recommendation
FROM pg_settings 
WHERE name = 'log_min_duration_statement';

-- =============================================================================
-- SUMMARY AND RECOMMENDATIONS
-- =============================================================================

\echo ''
\echo 'Configuration Summary:'
\echo '====================='

-- Overall health check
WITH validation_results AS (
    -- Memory settings
    SELECT 
        CASE 
            WHEN (SELECT setting::bigint * 8 * 1024 FROM pg_settings WHERE name = 'shared_buffers') >= 128 * 1024 * 1024 
            THEN 1 ELSE 0 
        END as shared_buffers_ok,
        CASE 
            WHEN (SELECT setting FROM pg_settings WHERE name = 'autovacuum') = 'on' 
            THEN 1 ELSE 0 
        END as autovacuum_ok,
        CASE 
            WHEN (SELECT setting FROM pg_settings WHERE name = 'track_counts') = 'on' 
            THEN 1 ELSE 0 
        END as track_counts_ok,
        CASE 
            WHEN (SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name IN ('ceds', 'rds', 'staging', 'app')) = 4 
            THEN 1 ELSE 0 
        END as schemas_ok,
        CASE 
            WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp') 
            THEN 1 ELSE 0 
        END as extensions_ok
)
SELECT 
    'Overall Configuration Health' as metric,
    CASE 
        WHEN (shared_buffers_ok + autovacuum_ok + track_counts_ok + schemas_ok + extensions_ok) = 5 
        THEN '✅ EXCELLENT'
        WHEN (shared_buffers_ok + autovacuum_ok + track_counts_ok + schemas_ok + extensions_ok) >= 4 
        THEN '✅ GOOD'
        WHEN (shared_buffers_ok + autovacuum_ok + track_counts_ok + schemas_ok + extensions_ok) >= 3 
        THEN '⚠️  NEEDS ATTENTION'
        ELSE '❌ CRITICAL ISSUES'
    END as status,
    (shared_buffers_ok + autovacuum_ok + track_counts_ok + schemas_ok + extensions_ok)::text || '/5 checks passed' as details
FROM validation_results;

-- =============================================================================
-- NEXT STEPS AND RECOMMENDATIONS
-- =============================================================================

\echo ''
\echo 'Next Steps and Recommendations:'
\echo '=============================='
\echo ''
\echo '1. CRITICAL FIXES (if any ❌ FAIL items above):'
\echo '   - Enable autovacuum if disabled'
\echo '   - Increase shared_buffers to at least 128MB' 
\echo '   - Enable track_counts for statistics'
\echo '   - Create missing schemas and roles'
\echo ''
\echo '2. RECOMMENDED IMPROVEMENTS (for ⚠️  WARNING items):'
\echo '   - Tune memory settings based on available RAM'
\echo '   - Install recommended extensions'
\echo '   - Configure slow query logging'
\echo '   - Adjust parallel worker settings'
\echo ''
\echo '3. MONITORING SETUP:'
\echo '   - Install and configure pg_stat_statements'
\echo '   - Set up regular VACUUM and ANALYZE scheduling'
\echo '   - Monitor buffer cache hit ratios'
\echo '   - Track autovacuum activity'
\echo ''
\echo '4. PERFORMANCE TUNING:'
\echo '   - Adjust random_page_cost for storage type'
\echo '   - Test and optimize work_mem for query workload'
\echo '   - Consider connection pooling (pgBouncer)'
\echo '   - Review and create appropriate indexes'
\echo ''
\echo '5. SECURITY AND BACKUP:'
\echo '   - Configure SSL/TLS connections'
\echo '   - Set up regular backup procedures'
\echo '   - Review and test recovery procedures'
\echo '   - Configure appropriate authentication'
\echo ''

-- Final validation timestamp
SELECT 
    'Validation completed at: ' || CURRENT_TIMESTAMP::text as info;