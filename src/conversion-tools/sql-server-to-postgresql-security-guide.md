# SQL Server to PostgreSQL Security Model Conversion Guide

## Overview

This guide explains how the CEDS Data Warehouse security model converts from SQL Server to PostgreSQL, including schemas, roles, permissions, and best practices.

## Schema Comparison

### SQL Server Schemas
```sql
-- SQL Server approach
CREATE SCHEMA [CEDS]
CREATE SCHEMA [RDS] 
CREATE SCHEMA [Staging]

-- Objects referenced with square brackets
SELECT * FROM [RDS].[DimK12Schools]
INSERT INTO [Staging].[K12Enrollment] VALUES (...)
```

### PostgreSQL Schemas
```sql  
-- PostgreSQL approach
CREATE SCHEMA IF NOT EXISTS ceds;
CREATE SCHEMA IF NOT EXISTS rds;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS app;

-- Objects referenced with lowercase, no brackets
SELECT * FROM rds.dim_k12_schools;
INSERT INTO staging.k12_enrollment VALUES (...);
```

## Role-Based Security Model

### SQL Server vs PostgreSQL Security Concepts

| SQL Server | PostgreSQL | Description |
|------------|------------|-------------|
| **Database Users** | **Roles** | Individual database accounts |
| **Database Roles** | **Group Roles** | Collections of permissions |
| **Schema Ownership** | **Schema Privileges** | Control over schema objects |
| **GRANT/DENY/REVOKE** | **GRANT/REVOKE** | Permission management (no DENY in PostgreSQL) |
| **Windows Authentication** | **External Authentication** | OS-level authentication |
| **SQL Server Login** | **PostgreSQL User** | Server-level account |

## CEDS Data Warehouse Role Structure

### Functional Roles Defined

1. **`ceds_data_reader`** - Read-only access
   - **Purpose**: Reporting, analytics, read-only applications
   - **Access**: SELECT on all tables and views in ceds, rds schemas
   - **SQL Server Equivalent**: `db_datareader` + custom read permissions

2. **`ceds_data_analyst`** - Analyst access
   - **Purpose**: Data analysis, temporary tables, exploration
   - **Access**: READ access + temporary table creation
   - **SQL Server Equivalent**: `db_datareader` + CREATE TABLE permissions

3. **`ceds_data_writer`** - Data modification
   - **Purpose**: Data loading, updates to fact/dimension tables
   - **Access**: READ/WRITE on rds, staging schemas
   - **SQL Server Equivalent**: `db_datawriter` + specific schema permissions

4. **`ceds_etl_process`** - ETL operations
   - **Purpose**: ETL processes, data transformation, bulk operations
   - **Access**: Full access to staging, controlled access to production tables
   - **SQL Server Equivalent**: `db_owner` equivalent for ETL operations

5. **`ceds_application`** - Application services
   - **Purpose**: Web applications, services, API backends
   - **Access**: Controlled READ/WRITE based on application needs
   - **SQL Server Equivalent**: Custom application role

6. **`ceds_admin`** - Administrative access
   - **Purpose**: Database administration, maintenance, schema changes
   - **Access**: Full administrative access to all schemas
   - **SQL Server Equivalent**: `db_owner` or `sysadmin`

## Permission Matrix

| Schema | Reader | Analyst | Writer | ETL | Application | Admin |
|--------|---------|---------|---------|-----|-------------|-------|
| **ceds** | SELECT | SELECT | SELECT | ALL | SELECT | ALL |
| **rds** | SELECT | SELECT | INSERT/UPDATE/DELETE | ALL | SELECT/INSERT/UPDATE | ALL |
| **staging** | - | SELECT | ALL | ALL | Limited | ALL |
| **app** | - | - | ALL | ALL | ALL | ALL |

## Security Implementation Examples

### Creating Users and Assigning Roles
```sql
-- Create service users
CREATE USER ceds_etl_service WITH PASSWORD 'secure_password_here';
CREATE USER ceds_app_service WITH PASSWORD 'secure_password_here';  
CREATE USER reporting_user WITH PASSWORD 'secure_password_here';

-- Assign roles
GRANT ceds_etl_process TO ceds_etl_service;
GRANT ceds_application TO ceds_app_service;
GRANT ceds_data_reader TO reporting_user;

-- Multiple role assignment (PostgreSQL supports role inheritance)
GRANT ceds_data_reader, ceds_data_analyst TO data_scientist_user;
```

### Schema-Level Permissions
```sql
-- Grant schema usage (required to access objects)
GRANT USAGE ON SCHEMA rds TO ceds_data_reader;

-- Grant table-level permissions
GRANT SELECT ON ALL TABLES IN SCHEMA rds TO ceds_data_reader;

-- Grant sequence permissions (for SERIAL columns)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA rds TO ceds_data_writer;

-- Set default permissions for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA rds 
    GRANT SELECT ON TABLES TO ceds_data_reader;
```

### Function and Procedure Permissions
```sql
-- Grant execute permissions on functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA rds TO ceds_data_reader;

-- PostgreSQL 11+ procedures
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA staging TO ceds_etl_process;

-- Specific function permissions
GRANT EXECUTE ON FUNCTION rds.get_age(date) TO ceds_application;
```

## Key Differences from SQL Server

### 1. **No DENY Statement**
- **SQL Server**: Has GRANT, DENY, REVOKE
- **PostgreSQL**: Only has GRANT, REVOKE
- **Implication**: Design permissions positively (grant what's needed, don't grant what's not)

### 2. **Role Inheritance**
```sql
-- PostgreSQL supports role inheritance
CREATE ROLE ceds_base_user;
CREATE ROLE ceds_power_user;

-- Power user inherits base permissions
GRANT ceds_base_user TO ceds_power_user;
```

### 3. **Schema Search Path**
```sql
-- PostgreSQL uses search_path for unqualified object references
SET search_path TO rds, staging, ceds, public;

-- Now you can reference tables without schema prefix
SELECT * FROM dim_k12_schools; -- Finds rds.dim_k12_schools
```

### 4. **Default Privileges**
```sql
-- PostgreSQL allows setting permissions for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA rds 
    GRANT SELECT ON TABLES TO ceds_data_reader;

-- Any table created in rds schema automatically gets SELECT permission for data readers
```

## Migration Checklist

### ✅ **Schema Conversion**
- [x] Create PostgreSQL schemas with IF NOT EXISTS
- [x] Convert schema names to lowercase
- [x] Add schema comments for documentation
- [x] Configure search_path for unqualified references

### ✅ **Role Creation**
- [x] Define functional roles based on access patterns
- [x] Create roles with appropriate permissions
- [x] Set up role inheritance where beneficial
- [x] Document role purposes and access levels

### ✅ **Permission Assignment**
- [x] Grant schema usage permissions
- [x] Set table-level permissions (SELECT, INSERT, UPDATE, DELETE)
- [x] Configure sequence permissions for SERIAL columns
- [x] Grant function/procedure execute permissions
- [x] Set default privileges for future objects

### ⚠️ **Security Hardening**
- [ ] Create actual database users (environment-specific)
- [ ] Configure connection limits per role
- [ ] Set up SSL/TLS connections
- [ ] Enable audit logging
- [ ] Configure row-level security (if needed)
- [ ] Set up monitoring and alerting

## Connection Examples

### Application Connection Strings
```bash
# ETL Service Connection
psql "host=localhost dbname=ceds_data_warehouse_v11_0_0_0 user=ceds_etl_service password=xxx sslmode=require"

# Application Service Connection  
psql "host=localhost dbname=ceds_data_warehouse_v11_0_0_0 user=ceds_app_service password=xxx sslmode=require"

# Read-only Reporting Connection
psql "host=localhost dbname=ceds_data_warehouse_v11_0_0_0 user=reporting_user password=xxx sslmode=require"
```

### Testing Permissions
```sql
-- Test as different users to verify permissions work correctly

-- Connect as data reader
SET ROLE ceds_data_reader;
SELECT * FROM rds.dim_k12_schools LIMIT 5; -- Should work
INSERT INTO rds.dim_k12_schools DEFAULT VALUES; -- Should fail

-- Connect as ETL process
SET ROLE ceds_etl_process;  
TRUNCATE TABLE staging.k12_enrollment; -- Should work
DROP TABLE rds.dim_k12_schools; -- Should work (be careful!)

-- Reset to original role
RESET ROLE;
```

## Monitoring and Maintenance

### Security Monitoring Queries
```sql
-- Check current connections by role
SELECT usename, application_name, client_addr, state 
FROM pg_stat_activity 
WHERE usename LIKE 'ceds_%';

-- Review role permissions
SELECT r.rolname, r.rolsuper, r.rolinherit, r.rolcreaterole, r.rolcanlogin
FROM pg_roles r 
WHERE r.rolname LIKE 'ceds_%';

-- Check table permissions
SELECT schemaname, tablename, tableowner, hasinserts, hasselect, hasupdates, hasdeletes
FROM pg_stat_user_tables 
WHERE schemaname IN ('ceds', 'rds', 'staging', 'app');
```

### Permission Refresh Procedure
```sql
-- Use the built-in refresh function
SELECT app.refresh_schema_permissions();

-- Manually refresh specific schema
GRANT SELECT ON ALL TABLES IN SCHEMA rds TO ceds_data_reader;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA rds TO ceds_data_writer;
```

## Best Practices

### 1. **Principle of Least Privilege**
- Grant minimum permissions required for each role
- Regularly review and audit permissions
- Use specific table/column permissions when needed

### 2. **Role-Based Access Control**
- Assign users to roles, not direct permissions
- Use descriptive role names that indicate purpose
- Document role responsibilities clearly

### 3. **Environment Consistency**
- Use same role structure across dev/test/prod
- Automate permission deployment with scripts
- Version control security configurations

### 4. **Security Monitoring**
- Enable connection and query logging
- Monitor for permission escalation attempts
- Set up alerts for unusual access patterns

### 5. **Password Management**
- Use strong passwords for all database users
- Rotate passwords regularly
- Consider external authentication (LDAP, AD, etc.)

## Troubleshooting Common Issues

### Permission Denied Errors
```sql
-- Check if user has schema usage permission
SELECT has_schema_privilege('username', 'schema_name', 'USAGE');

-- Check table permissions
SELECT has_table_privilege('username', 'schema.table', 'SELECT');

-- Grant missing permissions
GRANT USAGE ON SCHEMA schema_name TO username;
GRANT SELECT ON schema.table TO username;
```

### Search Path Issues
```sql
-- Check current search path
SHOW search_path;

-- Set search path for session
SET search_path TO rds, staging, ceds, public;

-- Set permanent search path for role
ALTER ROLE username SET search_path TO rds, staging, ceds, public;
```

### Default Privileges Not Working
```sql
-- Check existing default privileges
SELECT * FROM pg_default_acl;

-- Re-apply default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA rds GRANT SELECT ON TABLES TO ceds_data_reader;

-- Apply to existing objects
GRANT SELECT ON ALL TABLES IN SCHEMA rds TO ceds_data_reader;
```

This comprehensive security model provides a solid foundation for the CEDS Data Warehouse PostgreSQL migration while maintaining security best practices and providing clear migration guidance from the SQL Server model.