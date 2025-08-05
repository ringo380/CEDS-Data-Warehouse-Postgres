-- PostgreSQL Schemas and Security Setup for CEDS Data Warehouse
-- Converted from SQL Server schema structure
-- This script creates schemas, roles, and security permissions

-- =============================================================================
-- DATABASE SETUP
-- =============================================================================

-- Create database (run as superuser)
-- This would typically be done outside this script:
-- CREATE DATABASE ceds_data_warehouse_v11_0_0_0 
-- WITH ENCODING = 'UTF8' 
-- LC_COLLATE = 'en_US.UTF-8' 
-- LC_CTYPE = 'en_US.UTF-8' 
-- TEMPLATE = template0;

-- Connect to the database
\c ceds_data_warehouse_v11_0_0_0;

-- =============================================================================
-- SCHEMAS
-- =============================================================================

-- Create schemas (PostgreSQL equivalent of SQL Server schemas)
CREATE SCHEMA IF NOT EXISTS ceds;
CREATE SCHEMA IF NOT EXISTS rds;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS app;

-- Add comments to schemas for documentation
COMMENT ON SCHEMA ceds IS 'CEDS (Common Education Data Standards) reference data and metadata';
COMMENT ON SCHEMA rds IS 'Reporting Data Store - fact and dimension tables for data warehouse';
COMMENT ON SCHEMA staging IS 'Staging area for ETL processes and temporary data processing';
COMMENT ON SCHEMA app IS 'Application utilities, logging, and configuration tables';

-- =============================================================================
-- ROLES AND USERS
-- =============================================================================

-- Create functional roles (PostgreSQL equivalent of SQL Server roles)

-- 1. Data Reader Role - Read-only access to all data
CREATE ROLE ceds_data_reader;
COMMENT ON ROLE ceds_data_reader IS 'Read-only access to all CEDS data warehouse tables and views';

-- 2. Data Writer Role - Read/Write access to staging and app schemas
CREATE ROLE ceds_data_writer;
COMMENT ON ROLE ceds_data_writer IS 'Read/Write access to staging and app schemas for ETL processes';

-- 3. Data Analyst Role - Read access plus ability to create temp tables/views
CREATE ROLE ceds_data_analyst;
COMMENT ON ROLE ceds_data_analyst IS 'Data analyst with read access and temp table creation privileges';

-- 4. ETL Process Role - Full access for data loading and transformation
CREATE ROLE ceds_etl_process;
COMMENT ON ROLE ceds_etl_process IS 'Full access role for ETL processes and data warehouse maintenance';

-- 5. Application Role - Access for application connections
CREATE ROLE ceds_application;
COMMENT ON ROLE ceds_application IS 'Application service role with controlled access to data warehouse';

-- 6. Administrator Role - Full administrative access
CREATE ROLE ceds_admin;
COMMENT ON ROLE ceds_admin IS 'Administrative role with full access to CEDS data warehouse';

-- =============================================================================
-- SCHEMA PERMISSIONS
-- =============================================================================

-- CEDS Schema Permissions (Reference Data)
GRANT USAGE ON SCHEMA ceds TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA ceds TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA ceds TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;

-- Grant write permissions on CEDS schema to ETL and admin roles only
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ceds TO ceds_etl_process, ceds_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA ceds TO ceds_etl_process, ceds_admin;

-- RDS Schema Permissions (Data Warehouse)
GRANT USAGE ON SCHEMA rds TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA rds TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA rds TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;

-- Grant write permissions on RDS schema to writer, ETL and admin roles
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA rds TO ceds_data_writer, ceds_etl_process, ceds_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA rds TO ceds_data_writer, ceds_etl_process, ceds_admin;

-- Staging Schema Permissions (ETL Area)
GRANT USAGE ON SCHEMA staging TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA staging TO ceds_data_writer, ceds_etl_process, ceds_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA staging TO ceds_data_writer, ceds_etl_process, ceds_admin;

-- Allow analysts to read staging data
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO ceds_data_analyst;

-- App Schema Permissions (Application/Logging)
GRANT USAGE ON SCHEMA app TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;

-- =============================================================================
-- FUNCTION AND PROCEDURE PERMISSIONS
-- =============================================================================

-- Grant execute permissions on functions and procedures
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ceds TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA rds TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA staging TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;

-- Grant execute on procedures (PostgreSQL 11+)
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA staging TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA app TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;

-- =============================================================================
-- DEFAULT PRIVILEGES FOR FUTURE OBJECTS
-- =============================================================================

-- Set default privileges for future tables, sequences, and functions
-- This is crucial for maintaining security when new objects are created

-- CEDS Schema defaults
ALTER DEFAULT PRIVILEGES IN SCHEMA ceds GRANT SELECT ON TABLES TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA ceds GRANT INSERT, UPDATE, DELETE ON TABLES TO ceds_etl_process, ceds_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA ceds GRANT USAGE ON SEQUENCES TO ceds_etl_process, ceds_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA ceds GRANT EXECUTE ON FUNCTIONS TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;

-- RDS Schema defaults
ALTER DEFAULT PRIVILEGES IN SCHEMA rds GRANT SELECT ON TABLES TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA rds GRANT INSERT, UPDATE, DELETE ON TABLES TO ceds_data_writer, ceds_etl_process, ceds_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA rds GRANT USAGE ON SEQUENCES TO ceds_data_writer, ceds_etl_process, ceds_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA rds GRANT EXECUTE ON FUNCTIONS TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;

-- Staging Schema defaults
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT ALL ON TABLES TO ceds_data_writer, ceds_etl_process, ceds_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT SELECT ON TABLES TO ceds_data_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT ALL ON SEQUENCES TO ceds_data_writer, ceds_etl_process, ceds_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT EXECUTE ON FUNCTIONS TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;

-- App Schema defaults
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON TABLES TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON SEQUENCES TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT EXECUTE ON FUNCTIONS TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin;

-- =============================================================================
-- SEARCH PATH CONFIGURATION
-- =============================================================================

-- Set search path to include all schemas in logical order
-- This allows unqualified table references to work properly
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET search_path TO rds, staging, ceds, app, public;

-- Set search path for each role (optional, can be overridden by applications)
ALTER ROLE ceds_data_reader SET search_path TO rds, ceds, public;
ALTER ROLE ceds_data_analyst SET search_path TO rds, staging, ceds, app, public;
ALTER ROLE ceds_data_writer SET search_path TO rds, staging, ceds, app, public;
ALTER ROLE ceds_etl_process SET search_path TO staging, rds, ceds, app, public;
ALTER ROLE ceds_application SET search_path TO rds, staging, ceds, app, public;
ALTER ROLE ceds_admin SET search_path TO rds, staging, ceds, app, public;

-- =============================================================================
-- ROW LEVEL SECURITY (Optional - for future use)
-- =============================================================================

-- Enable row level security on database (disabled by default)
-- Can be enabled later if needed for multi-tenant scenarios
-- ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET row_security = on;

-- =============================================================================
-- CONNECTION LIMITS (Optional)
-- =============================================================================

-- Set connection limits for roles to prevent resource exhaustion
-- Uncomment and adjust based on your requirements

-- ALTER ROLE ceds_data_reader CONNECTION LIMIT 10;
-- ALTER ROLE ceds_data_analyst CONNECTION LIMIT 5;
-- ALTER ROLE ceds_data_writer CONNECTION LIMIT 3;
-- ALTER ROLE ceds_etl_process CONNECTION LIMIT 2;
-- ALTER ROLE ceds_application CONNECTION LIMIT 20;
-- ALTER ROLE ceds_admin CONNECTION LIMIT -1; -- No limit for admin

-- =============================================================================
-- EXAMPLE USER CREATION
-- =============================================================================

-- Example of creating actual database users and assigning them to roles
-- These would typically be created based on your specific requirements

/*
-- Example ETL service user
CREATE USER ceds_etl_service WITH PASSWORD 'your_secure_password_here';
GRANT ceds_etl_process TO ceds_etl_service;

-- Example application service user
CREATE USER ceds_app_service WITH PASSWORD 'your_secure_password_here';
GRANT ceds_application TO ceds_app_service;

-- Example analyst user
CREATE USER john_analyst WITH PASSWORD 'your_secure_password_here';
GRANT ceds_data_analyst TO john_analyst;

-- Example read-only reporting user
CREATE USER reporting_service WITH PASSWORD 'your_secure_password_here';
GRANT ceds_data_reader TO reporting_service;
*/

-- =============================================================================
-- AUDIT LOGGING SETUP (Optional)
-- =============================================================================

-- Enable connection and statement logging for security auditing
-- These settings would typically go in postgresql.conf

/*
-- Add to postgresql.conf:
log_connections = on
log_disconnections = on
log_statement = 'ddl'  -- Log DDL statements
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

-- For more detailed auditing, consider using pg_audit extension:
-- CREATE EXTENSION IF NOT EXISTS pgaudit;
-- ALTER SYSTEM SET pgaudit.log = 'all';
*/

-- =============================================================================
-- SECURITY VIEWS (Optional)
-- =============================================================================

-- Create security information views for monitoring and administration

CREATE OR REPLACE VIEW app.role_permissions AS
SELECT 
    r.rolname as role_name,
    n.nspname as schema_name,
    c.relname as table_name,
    p.privilege_type
FROM pg_roles r
JOIN pg_auth_members am ON r.oid = am.roleid
JOIN pg_roles gr ON am.member = gr.oid
JOIN information_schema.table_privileges p ON gr.rolname = p.grantee
JOIN pg_class c ON p.table_name = c.relname
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname IN ('ceds', 'rds', 'staging', 'app')
ORDER BY r.rolname, n.nspname, c.relname, p.privilege_type;

COMMENT ON VIEW app.role_permissions IS 'Shows role-based permissions across CEDS schemas';

-- =============================================================================
-- MAINTENANCE PROCEDURES
-- =============================================================================

-- Procedure to refresh permissions on all existing objects
-- Useful after schema changes or adding new roles

CREATE OR REPLACE FUNCTION app.refresh_schema_permissions()
RETURNS void AS $$
BEGIN
    -- Re-grant permissions on existing objects in each schema
    
    -- CEDS schema
    EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA ceds TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin';
    EXECUTE 'GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ceds TO ceds_etl_process, ceds_admin';
    EXECUTE 'GRANT USAGE ON ALL SEQUENCES IN SCHEMA ceds TO ceds_etl_process, ceds_admin';
    
    -- RDS schema
    EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA rds TO ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin';
    EXECUTE 'GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA rds TO ceds_data_writer, ceds_etl_process, ceds_admin';
    EXECUTE 'GRANT USAGE ON ALL SEQUENCES IN SCHEMA rds TO ceds_data_writer, ceds_etl_process, ceds_admin';
    
    -- Staging schema
    EXECUTE 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA staging TO ceds_data_writer, ceds_etl_process, ceds_admin';
    EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA staging TO ceds_data_analyst';
    EXECUTE 'GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA staging TO ceds_data_writer, ceds_etl_process, ceds_admin';
    
    -- App schema
    EXECUTE 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin';
    EXECUTE 'GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app TO ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin';
    
    RAISE NOTICE 'Schema permissions refreshed successfully';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION app.refresh_schema_permissions() IS 'Refreshes permissions on all existing objects in CEDS schemas';

-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Queries to validate the security setup
-- Run these after setup to verify permissions are correct

/*
-- Check role membership
SELECT 
    r.rolname as role_name,
    m.rolname as member_of
FROM pg_roles r 
JOIN pg_auth_members am ON r.oid = am.member
JOIN pg_roles m ON am.roleid = m.oid
WHERE r.rolname LIKE 'ceds_%'
ORDER BY r.rolname;

-- Check schema privileges
SELECT 
    schemaname,
    schemaowner,
    schemaacl
FROM pg_stat_user_tables 
WHERE schemaname IN ('ceds', 'rds', 'staging', 'app')
GROUP BY schemaname, schemaowner, schemaacl;

-- Check table count by schema
SELECT 
    schemaname,
    COUNT(*) as table_count
FROM pg_stat_user_tables 
WHERE schemaname IN ('ceds', 'rds', 'staging', 'app')
GROUP BY schemaname
ORDER BY schemaname;
*/

-- =============================================================================
-- SETUP COMPLETE
-- =============================================================================

-- Display completion message
DO $$
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'CEDS Data Warehouse PostgreSQL Security Setup Complete';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Schemas created: ceds, rds, staging, app';
    RAISE NOTICE 'Roles created: ceds_data_reader, ceds_data_analyst, ceds_data_writer, ceds_etl_process, ceds_application, ceds_admin';
    RAISE NOTICE 'Default privileges configured for future objects';
    RAISE NOTICE 'Search path configured: rds, staging, ceds, app, public';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Create actual database users and assign to appropriate roles';
    RAISE NOTICE '2. Configure connection pooling and limits';
    RAISE NOTICE '3. Set up monitoring and auditing';
    RAISE NOTICE '4. Test permissions with sample queries';
    RAISE NOTICE '====================================================';
END;
$$;