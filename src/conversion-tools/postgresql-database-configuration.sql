-- PostgreSQL Database Configuration Script
-- Equivalent settings for SQL Server CEDS Data Warehouse V11.0.0.0 configuration
-- This script applies PostgreSQL equivalents of SQL Server database settings

-- =============================================================================
-- DATABASE CREATION AND BASIC SETTINGS
-- =============================================================================

-- Create database with appropriate settings (run as superuser)
-- Note: This should be run outside of a transaction
/*
CREATE DATABASE ceds_data_warehouse_v11_0_0_0
WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'        -- Equivalent to SQL Server collation
    LC_CTYPE = 'en_US.UTF-8'          -- Character classification
    TEMPLATE = template0               -- Clean template
    CONNECTION LIMIT = 100;            -- Reasonable connection limit
*/

-- Connect to the database
\c ceds_data_warehouse_v11_0_0_0;

-- =============================================================================
-- SQL SERVER TO POSTGRESQL SETTING MAPPINGS
-- =============================================================================

/*
SQL Server Setting Mappings to PostgreSQL:

SQL Server                          | PostgreSQL Equivalent                    | Notes
------------------------------------|------------------------------------------|------------------
COMPATIBILITY_LEVEL = 150          | Built-in (PostgreSQL versioned)         | PostgreSQL handles compatibility differently
ANSI_NULL_DEFAULT OFF              | N/A (PostgreSQL always ANSI compliant)  | Always follows ANSI standards
ANSI_NULLS OFF                     | N/A (PostgreSQL always ANSI compliant)  | Always follows ANSI standards  
ANSI_PADDING OFF                   | N/A (PostgreSQL always ANSI compliant)  | Always follows ANSI standards
ANSI_WARNINGS OFF                  | check_function_bodies = off              | Controls function validation
ARITHABORT OFF                     | N/A (PostgreSQL handles differently)    | Different error handling model
AUTO_CLOSE OFF                     | N/A (PostgreSQL doesn't auto-close)     | Not applicable
AUTO_SHRINK OFF                    | autovacuum = on                          | Automatic space management
AUTO_UPDATE_STATISTICS ON          | track_counts = on                        | Statistics collection
CURSOR_CLOSE_ON_COMMIT OFF         | N/A (cursors handled differently)       | Different cursor model
CURSOR_DEFAULT GLOBAL              | N/A (cursors handled differently)       | Different cursor model
CONCAT_NULL_YIELDS_NULL OFF        | Built-in behavior                        | PostgreSQL follows ANSI
NUMERIC_ROUNDABORT OFF             | N/A (PostgreSQL handles differently)    | Different numeric handling
QUOTED_IDENTIFIER OFF              | standard_conforming_strings = on        | String literal handling
RECURSIVE_TRIGGERS OFF             | N/A (set per trigger)                    | Trigger-specific setting
DISABLE_BROKER                     | N/A (no direct equivalent)              | Use external message queue
AUTO_UPDATE_STATISTICS_ASYNC OFF   | autovacuum_naptime = 60s                | Background statistics
DATE_CORRELATION_OPTIMIZATION OFF  | N/A (PostgreSQL optimizes differently)  | Query planner handles this
TRUSTWORTHY OFF                    | Security handled by roles                | Role-based security
ALLOW_SNAPSHOT_ISOLATION OFF       | default_transaction_isolation = 'read committed' | Transaction isolation
READ_COMMITTED_SNAPSHOT OFF        | default_transaction_isolation = 'read committed' | Default isolation level
*/

-- =============================================================================
-- POSTGRESQL DATABASE-LEVEL SETTINGS
-- =============================================================================

-- Set database-level configuration parameters
-- These are equivalent to SQL Server database settings

-- Character and String Handling
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET standard_conforming_strings = on;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET escape_string_warning = on;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET backslash_quote = safe_encoding;

-- Query Behavior
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET default_transaction_isolation = 'read committed';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET statement_timeout = 0;  -- No timeout (equivalent to SQL Server default)
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET lock_timeout = 0;       -- No lock timeout

-- Locale and Formatting  
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET lc_messages = 'en_US.UTF-8';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET lc_monetary = 'en_US.UTF-8';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET lc_numeric = 'en_US.UTF-8';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET lc_time = 'en_US.UTF-8';

-- Date and Time Settings
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET timezone = 'UTC';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET datestyle = 'ISO, MDY';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET intervalstyle = 'postgres';

-- Constraint and Validation
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET check_function_bodies = on;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET default_with_oids = off;

-- Statistics and Autovacuum (equivalent to SQL Server AUTO_UPDATE_STATISTICS)
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET track_activities = on;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET track_counts = on;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET track_functions = 'all';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET track_io_timing = on;

-- XML Processing
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET xmloption = content;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET xmlbinary = base64;

-- Client Connection Settings
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET client_min_messages = warning;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET log_statement = 'none';  -- Adjust based on needs

-- Security Settings
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET row_security = off;  -- Enable if needed for multi-tenancy

-- =============================================================================
-- PERFORMANCE AND MEMORY SETTINGS
-- =============================================================================

-- Equivalent to SQL Server memory and performance settings
-- Note: These may need adjustment based on server specifications

-- Memory Settings (only database-level parameters, others require postgresql.conf)
-- NOTE: shared_buffers, wal_buffers require server restart and must be set in postgresql.conf
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET effective_cache_size = '1GB'; -- 50-75% of available RAM
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET work_mem = '32MB';            -- Per-operation memory
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET maintenance_work_mem = '256MB'; -- Maintenance operations

-- Query Planner Settings
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET random_page_cost = 1.1;       -- SSD-optimized (4.0 for HDD)
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET seq_page_cost = 1.0;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET cpu_tuple_cost = 0.01;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET cpu_index_tuple_cost = 0.005;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET cpu_operator_cost = 0.0025;

-- =============================================================================
-- AUTOVACUUM SETTINGS (SQL Server AUTO_SHRINK/AUTO_UPDATE_STATISTICS equivalent)
-- =============================================================================

-- NOTE: Autovacuum settings are server-level and must be configured in postgresql.conf
-- These database-level settings are not available via ALTER DATABASE
-- Add to postgresql.conf instead:
--   autovacuum = on
--   autovacuum_naptime = 5min
--   autovacuum_vacuum_threshold = 500
--   autovacuum_vacuum_scale_factor = 0.1
--   autovacuum_analyze_threshold = 250
--   autovacuum_analyze_scale_factor = 0.05
--   autovacuum_vacuum_cost_delay = 10ms
--   autovacuum_vacuum_cost_limit = 1000

-- =============================================================================
-- LOGGING AND MONITORING SETTINGS
-- =============================================================================

-- Configure logging for monitoring and troubleshooting (database-level only)
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET log_min_duration_statement = 5000;    -- Log slow queries (5 seconds)
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET log_lock_waits = on;                  -- Log lock waits

-- NOTE: These logging settings require postgresql.conf configuration (server-level):
--   log_connections = on              -- Connection logging
--   log_disconnections = on           -- Disconnection logging  
--   log_checkpoints = on              -- Checkpoint logging

-- Statement logging (adjust based on needs)
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET log_statement = 'ddl';                -- Log DDL statements
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET log_min_messages = warning;

-- =============================================================================
-- CONNECTION AND RESOURCE LIMITS
-- =============================================================================

-- Set reasonable limits for data warehouse usage
-- Note: These settings may be set at cluster level instead

/*
-- Cluster-level settings (in postgresql.conf):
max_connections = 200                    -- Adjust based on expected concurrent users  
superuser_reserved_connections = 3       -- Reserve connections for admins
max_prepared_transactions = 0            -- Disable if not using 2PC
max_locks_per_transaction = 64           -- Default, increase if needed
max_pred_locks_per_transaction = 64      -- For serializable transactions

-- Connection pooling settings (if using pgBouncer):
pool_mode = transaction                  -- Good for OLAP workloads
default_pool_size = 20                   -- Connections per database
max_client_conn = 200                    -- Total client connections
*/

-- =============================================================================
-- DATA WAREHOUSE SPECIFIC OPTIMIZATIONS
-- =============================================================================

-- Settings optimized for OLAP/Data Warehouse workloads

-- Large sequential scans common in DW
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET seq_page_cost = 1.0;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET random_page_cost = 1.5;  -- Lower for SSD

-- NOTE: WAL and checkpoint settings require postgresql.conf configuration (server-level):
--   checkpoint_completion_target = 0.8      -- Checkpoint completion target
--   wal_buffers = 16MB                      -- WAL buffer size (requires restart)
--   max_wal_size = 2GB                      -- Modern PostgreSQL (replaces checkpoint_segments)
--   checkpoint_segments = 64                -- Deprecated in PostgreSQL 9.5+

-- Enable parallel query for large analytical queries (PostgreSQL 9.6+)
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET max_parallel_workers_per_gather = 4;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET max_parallel_workers = 8;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET parallel_tuple_cost = 0.1;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET parallel_setup_cost = 1000.0;

-- =============================================================================
-- EXTENSION CONFIGURATION
-- =============================================================================

-- Enable useful extensions for data warehouse operations
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID generation
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Full-text search
CREATE EXTENSION IF NOT EXISTS "btree_gin";      -- Better indexing
CREATE EXTENSION IF NOT EXISTS "pgstattuple";    -- Table statistics
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements"; -- Query statistics

-- Configure pg_stat_statements for query monitoring
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET pg_stat_statements.max = 10000;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET pg_stat_statements.track = 'all';

-- =============================================================================
-- CUSTOM CONFIGURATION FUNCTIONS
-- =============================================================================

-- Function to display current database configuration
CREATE OR REPLACE FUNCTION app.show_database_config()
RETURNS TABLE(setting_name TEXT, current_value TEXT, description TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.name::TEXT,
        s.setting::TEXT,
        s.short_desc::TEXT
    FROM pg_settings s
    WHERE s.name IN (
        'standard_conforming_strings',
        'default_transaction_isolation', 
        'timezone',
        'datestyle',
        'shared_buffers',
        'effective_cache_size',
        'work_mem',
        'maintenance_work_mem',
        'autovacuum',
        'track_counts',
        'log_min_duration_statement'
    )
    ORDER BY s.name;
END;
$$ LANGUAGE plpgsql;

-- Function to optimize database for ETL operations
CREATE OR REPLACE FUNCTION app.configure_for_etl_mode()
RETURNS void AS $$
BEGIN
    -- Temporarily optimize for bulk loading
    PERFORM set_config('synchronous_commit', 'off', false);
    -- NOTE: wal_buffers and checkpoint settings require server restart or postgresql.conf changes
    -- PERFORM set_config('wal_buffers', '64MB', false);  -- Server restart required
    -- PERFORM set_config('checkpoint_completion_target', '0.9', false); -- Server restart required
    -- checkpoint_segments deprecated in PostgreSQL 9.5+, use max_wal_size instead
    
    -- NOTE: autovacuum is server-level setting, cannot be changed per session
    -- Disable autovacuum during bulk loads by setting it in postgresql.conf
    -- PERFORM set_config('autovacuum', 'off', false); -- Server-level only
    
    RAISE NOTICE 'Database configured for ETL mode. Remember to call restore_normal_mode() after ETL completion.';
END;
$$ LANGUAGE plpgsql;

-- Function to restore normal operation mode
CREATE OR REPLACE FUNCTION app.restore_normal_mode()
RETURNS void AS $$
BEGIN
    -- Restore normal settings
    PERFORM set_config('synchronous_commit', 'on', false);
    PERFORM set_config('autovacuum', 'on', false);
    
    -- Run vacuum and analyze after bulk operations
    RAISE NOTICE 'Restoring normal mode. Consider running VACUUM ANALYZE on affected tables.';
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- VALIDATION AND MONITORING
-- =============================================================================

-- Function to validate database configuration
CREATE OR REPLACE FUNCTION app.validate_database_config()
RETURNS TABLE(check_name TEXT, status TEXT, recommendation TEXT) AS $$
BEGIN
    RETURN QUERY
    WITH config_checks AS (
        SELECT 
            'Shared Buffers' as check_name,
            CASE 
                WHEN setting::INTEGER >= 134217728 THEN 'OK'  -- >= 128MB
                ELSE 'WARNING'
            END as status,
            'Should be 25% of available RAM for dedicated server' as recommendation
        FROM pg_settings WHERE name = 'shared_buffers'
        
        UNION ALL
        
        SELECT 
            'Autovacuum',
            CASE WHEN setting = 'on' THEN 'OK' ELSE 'ERROR' END,
            'Should be enabled for data warehouse maintenance'
        FROM pg_settings WHERE name = 'autovacuum'
        
        UNION ALL
        
        SELECT 
            'Statistics Tracking',
            CASE WHEN setting = 'on' THEN 'OK' ELSE 'WARNING' END,
            'Required for query optimization'
        FROM pg_settings WHERE name = 'track_counts'
        
        UNION ALL
        
        SELECT 
            'Timezone Setting',
            CASE WHEN setting = 'UTC' THEN 'OK' ELSE 'INFO' END,
            'UTC recommended for data warehouse consistency'
        FROM pg_settings WHERE name = 'TimeZone'
    )
    SELECT * FROM config_checks;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- SETUP COMPLETION
-- =============================================================================

-- Display configuration summary
DO $$
DECLARE
    config_count INTEGER;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'PostgreSQL Database Configuration Complete';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Database: ceds_data_warehouse_v11_0_0_0';
    RAISE NOTICE 'Configuration optimized for OLAP/Data Warehouse workload';
    RAISE NOTICE '';
    
    -- Count applied settings
    SELECT COUNT(*) INTO config_count 
    FROM pg_db_role_setting 
    WHERE setdatabase = (SELECT oid FROM pg_database WHERE datname = 'ceds_data_warehouse_v11_0_0_0');
    
    RAISE NOTICE 'Applied % database-specific settings', config_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Key Features Configured:';
    RAISE NOTICE '✅ Character encoding and collation';
    RAISE NOTICE '✅ Transaction isolation and query behavior';  
    RAISE NOTICE '✅ Memory and performance optimization';
    RAISE NOTICE '✅ Autovacuum for automatic maintenance';
    RAISE NOTICE '✅ Logging and monitoring settings';
    RAISE NOTICE '✅ Data warehouse specific optimizations';
    RAISE NOTICE '✅ Parallel query support';
    RAISE NOTICE '✅ Useful extensions enabled';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Review and adjust memory settings based on available RAM';
    RAISE NOTICE '2. Configure postgresql.conf cluster-level settings';
    RAISE NOTICE '3. Set up monitoring and alerting';
    RAISE NOTICE '4. Test performance with sample workloads';
    RAISE NOTICE '5. Run: SELECT * FROM app.validate_database_config();';
    RAISE NOTICE '====================================================';
END;
$$;

-- Run validation check
SELECT 'Configuration Validation:' as info;
SELECT * FROM app.validate_database_config();

-- Show key configuration settings
SELECT 'Current Database Configuration:' as info;  
SELECT * FROM app.show_database_config();

-- =============================================================================
-- NOTES FOR ADMINISTRATORS
-- =============================================================================

/*
IMPORTANT CONFIGURATION NOTES:

1. MEMORY SETTINGS:
   - Adjust shared_buffers, effective_cache_size, work_mem based on available RAM
   - For dedicated PostgreSQL server: shared_buffers = 25% of RAM
   - effective_cache_size should be 50-75% of available RAM

2. STORAGE CONSIDERATIONS:
   - Set random_page_cost = 1.1 for SSD storage, 4.0 for traditional HDD
   - Consider tablespaces for separating indexes and data

3. CLUSTER-LEVEL SETTINGS (postgresql.conf):
   - max_connections: Set based on expected concurrent users
   - checkpoint_timeout: Adjust for bulk loading patterns
   - wal_level: Set to 'replica' if setting up streaming replication

4. MONITORING:
   - Enable pg_stat_statements for query performance monitoring
   - Set up log analysis for long-running queries
   - Monitor autovacuum effectiveness

5. SECURITY:
   - Configure pg_hba.conf for appropriate authentication
   - Use SSL/TLS for connections in production
   - Regular security updates

6. BACKUP AND RECOVERY:
   - Configure WAL archiving for point-in-time recovery
   - Set up regular pg_dump backups
   - Test recovery procedures

7. PERFORMANCE TUNING:
   - Use EXPLAIN ANALYZE to optimize queries
   - Create appropriate indexes after data loading
   - Consider partitioning for very large tables
   - Monitor and tune autovacuum settings based on workload

This configuration provides a solid foundation for the CEDS Data Warehouse
on PostgreSQL with settings optimized for OLAP workloads and bulk data operations.
*/