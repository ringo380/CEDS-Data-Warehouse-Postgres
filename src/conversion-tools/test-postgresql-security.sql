-- Test Script for PostgreSQL Security Setup
-- This script validates that the security configuration is working correctly
-- Run this after setting up schemas and roles

-- =============================================================================
-- SECURITY VALIDATION TESTS
-- =============================================================================

-- Test 1: Verify schemas exist
DO $$
BEGIN
    RAISE NOTICE '=== Testing Schema Creation ===';
    
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ceds') THEN
        RAISE NOTICE '✅ CEDS schema exists';
    ELSE
        RAISE NOTICE '❌ CEDS schema missing';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'rds') THEN
        RAISE NOTICE '✅ RDS schema exists';
    ELSE
        RAISE NOTICE '❌ RDS schema missing';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'staging') THEN
        RAISE NOTICE '✅ Staging schema exists';
    ELSE
        RAISE NOTICE '❌ Staging schema missing';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app') THEN
        RAISE NOTICE '✅ App schema exists';
    ELSE
        RAISE NOTICE '❌ App schema missing';
    END IF;
END $$;

-- Test 2: Verify roles exist
DO $$
DECLARE
    role_name TEXT;
    role_exists BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Testing Role Creation ===';
    
    FOR role_name IN VALUES ('ceds_data_reader'), ('ceds_data_analyst'), ('ceds_data_writer'), 
                            ('ceds_etl_process'), ('ceds_application'), ('ceds_admin')
    LOOP
        SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) INTO role_exists;
        
        IF role_exists THEN
            RAISE NOTICE '✅ Role % exists', role_name;
        ELSE
            RAISE NOTICE '❌ Role % missing', role_name;
        END IF;
    END LOOP;
END $$;

-- Test 3: Check search path configuration
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Testing Search Path ===';
    RAISE NOTICE 'Current search_path: %', current_setting('search_path');
    
    IF position('rds' in current_setting('search_path')) > 0 THEN
        RAISE NOTICE '✅ RDS schema in search path';
    ELSE
        RAISE NOTICE '❌ RDS schema not in search path';
    END IF;
END $$;

-- Test 4: Create test tables to verify permissions
CREATE TABLE IF NOT EXISTS staging.test_permissions (
    id SERIAL PRIMARY KEY,
    test_data VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS rds.test_permissions (
    id SERIAL PRIMARY KEY,
    test_data VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert test data
INSERT INTO staging.test_permissions (test_data) VALUES ('test staging data');
INSERT INTO rds.test_permissions (test_data) VALUES ('test rds data');

-- Test 5: Verify table permissions work
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Testing Table Permissions ===';
    
    -- Test if tables were created successfully
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'staging' AND table_name = 'test_permissions') THEN
        RAISE NOTICE '✅ Test staging table created';
    ELSE
        RAISE NOTICE '❌ Test staging table not found';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rds' AND table_name = 'test_permissions') THEN
        RAISE NOTICE '✅ Test RDS table created';
    ELSE
        RAISE NOTICE '❌ Test RDS table not found';
    END IF;
END $$;

-- Test 6: Check privilege assignments
SELECT 
    CASE 
        WHEN has_schema_privilege('ceds_data_reader', 'rds', 'USAGE') THEN '✅ ceds_data_reader has RDS schema usage'
        ELSE '❌ ceds_data_reader missing RDS schema usage'
    END as reader_rds_usage;

SELECT 
    CASE 
        WHEN has_table_privilege('ceds_data_reader', 'rds.test_permissions', 'SELECT') THEN '✅ ceds_data_reader has RDS table SELECT'
        ELSE '❌ ceds_data_reader missing RDS table SELECT'
    END as reader_rds_select;

SELECT 
    CASE 
        WHEN has_table_privilege('ceds_etl_process', 'staging.test_permissions', 'INSERT') THEN '✅ ceds_etl_process has staging INSERT'
        ELSE '❌ ceds_etl_process missing staging INSERT'
    END as etl_staging_insert;

-- Test 7: Function permissions (if functions exist)
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Testing Function Permissions ===';
    
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rds' AND routine_name = 'get_age') THEN
        IF has_function_privilege('ceds_data_reader', 'rds.get_age(date)', 'EXECUTE') THEN
            RAISE NOTICE '✅ ceds_data_reader can execute rds.get_age function';
        ELSE
            RAISE NOTICE '❌ ceds_data_reader cannot execute rds.get_age function';
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️  rds.get_age function not found (may not be created yet)';
    END IF;
END $$;

-- Test 8: Default privileges check
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Testing Default Privileges ===';
    
    -- Check if default privileges are set (this is more complex to test)
    IF EXISTS (SELECT 1 FROM pg_default_acl WHERE defaclnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'rds')) THEN
        RAISE NOTICE '✅ Default privileges configured for RDS schema';
    ELSE
        RAISE NOTICE '⚠️  No default privileges found for RDS schema';
    END IF;
END $$;

-- Test 9: Connection limits (if set)
SELECT 
    rolname,
    rolconnlimit,
    CASE 
        WHEN rolconnlimit = -1 THEN 'No limit'
        WHEN rolconnlimit > 0 THEN rolconnlimit::text || ' connections'
        ELSE 'Not set'
    END as connection_limit
FROM pg_roles 
WHERE rolname LIKE 'ceds_%'
ORDER BY rolname;

-- Test 10: Summary report
DO $$
DECLARE
    schema_count INTEGER;
    role_count INTEGER;
    table_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Security Setup Summary ===';
    
    SELECT COUNT(*) INTO schema_count 
    FROM information_schema.schemata 
    WHERE schema_name IN ('ceds', 'rds', 'staging', 'app');
    
    SELECT COUNT(*) INTO role_count 
    FROM pg_roles 
    WHERE rolname LIKE 'ceds_%';
    
    SELECT COUNT(*) INTO table_count 
    FROM information_schema.tables 
    WHERE table_schema IN ('ceds', 'rds', 'staging', 'app');
    
    RAISE NOTICE 'Schemas configured: % / 4', schema_count;
    RAISE NOTICE 'Roles created: % / 6', role_count;
    RAISE NOTICE 'Tables in CEDS schemas: %', table_count;
    
    IF schema_count = 4 AND role_count = 6 THEN
        RAISE NOTICE '✅ Security setup appears complete!';
    ELSE
        RAISE NOTICE '⚠️  Security setup may be incomplete. Check previous messages.';
    END IF;
END $$;

-- Cleanup test tables
DROP TABLE IF EXISTS staging.test_permissions;
DROP TABLE IF EXISTS rds.test_permissions;

-- =============================================================================
-- INTERACTIVE PERMISSION TESTS
-- =============================================================================

-- The following tests require connecting as different users
-- Uncomment and run manually with different user connections

/*
-- Test as data reader (should succeed)
SET ROLE ceds_data_reader;
SELECT COUNT(*) FROM rds.dim_k12_schools; -- Should work
-- INSERT INTO rds.dim_k12_schools DEFAULT VALUES; -- Should fail
RESET ROLE;

-- Test as ETL process (should succeed)  
SET ROLE ceds_etl_process;
-- CREATE TEMP TABLE test_temp AS SELECT 1; -- Should work
-- TRUNCATE TABLE staging.some_table; -- Should work (if table exists)
RESET ROLE;

-- Test as application role (should succeed with limited access)
SET ROLE ceds_application;
SELECT COUNT(*) FROM rds.dim_k12_schools; -- Should work
-- DELETE FROM rds.dim_k12_schools; -- Should fail or be limited
RESET ROLE;
*/

RAISE NOTICE '';
RAISE NOTICE '=== Security Validation Complete ===';
RAISE NOTICE 'Run the commented tests manually with actual user connections to fully validate security.';
RAISE NOTICE '';