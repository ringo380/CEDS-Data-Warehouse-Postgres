/*    

	Copyright 2023 Common Education Data Standards
	----------------------------------------------
	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at
	
	    http://www.apache.org/licenses/LICENSE-2.0
	
	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.


	Common Education Data Standards (CEDS)
    Version 11.0.0.0
    Data Warehouse - PostgreSQL Version
	  
    PostgreSQL CONVERSION
	
    This script creates the tables, constraints, and relationships defined in 
    version 11.0.0.0 of the CEDS Data Warehouse, converted for PostgreSQL.
    
    The original script was generated from a model database hosted on 
    Microsoft SQL Server 2019 platform and has been converted to PostgreSQL syntax.

	Script 1 of 3 (PostgreSQL Version)
	To create the CEDS Data Warehouse including population of the dimension tables, 
	the following 3 scripts are needed:

	Script 1: CEDS-Data-Warehouse-V11.0.0.0-PostgreSQL.sql (this file)
	Script 2: CEDS-Elements-V11.0.0.0-PostgreSQL.sql
	Script 3: Junk-Table-Dimension-Population-V11.0.0.0-PostgreSQL.sql

      
    Questions on this script can be sent to https://ceds.ed.gov/ContactUs.aspx
      
    More information on the data model is available at the CEDS website:  
    http://ceds.ed.gov.
		
    WARNING: This script creates a database named ceds_data_warehouse_v11_0_0_0
    
    POSTGRESQL CONVERSION NOTES:
    - Database name changed from [CEDS-Data-Warehouse-V11-0-0-0] to ceds_data_warehouse_v11_0_0_0 (PostgreSQL naming conventions)
    - All SQL Server square brackets [] removed 
    - IDENTITY columns converted to SERIAL/BIGSERIAL
    - SQL Server data types converted to PostgreSQL equivalents
    - GO statements removed (PostgreSQL uses semicolons)
    - SQL Server specific database settings converted to PostgreSQL equivalents
    - Functions converted from T-SQL to PL/pgSQL
*/    

-- Drop database if exists and create new database
DROP DATABASE IF EXISTS ceds_data_warehouse_v11_0_0_0;
CREATE DATABASE ceds_data_warehouse_v11_0_0_0
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- Connect to the new database
\c ceds_data_warehouse_v11_0_0_0;

-- PostgreSQL specific settings (equivalent to SQL Server database settings)
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET timezone TO 'UTC';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET statement_timeout = 0;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET lock_timeout = 0;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET idle_in_transaction_session_timeout = 0;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET client_encoding = 'UTF8';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET standard_conforming_strings = on;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET check_function_bodies = false;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET xmloption = content;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET client_min_messages = warning;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET row_security = off;

-- =============================================================================
-- ENHANCED SCHEMA AND SECURITY SETUP
-- =============================================================================

-- Create schemas (PostgreSQL equivalent of SQL Server schemas)
CREATE SCHEMA IF NOT EXISTS ceds;
CREATE SCHEMA IF NOT EXISTS rds;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS app;

-- Add schema comments for documentation
COMMENT ON SCHEMA ceds IS 'CEDS reference data and metadata';
COMMENT ON SCHEMA rds IS 'Reporting Data Store - fact and dimension tables';
COMMENT ON SCHEMA staging IS 'Staging area for ETL processes';
COMMENT ON SCHEMA app IS 'Application utilities and logging';

-- Set search path to include all schemas
SET search_path TO rds, staging, ceds, app, public;

-- Note: For complete security setup including roles and permissions,
-- run the separate script: postgresql-schemas-and-security.sql

-- PostgreSQL extensions (equivalent to SQL Server features)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";        -- For UUID generation (equivalent to UNIQUEIDENTIFIER)
CREATE EXTENSION IF NOT EXISTS "pg_trgm";          -- For full-text search capabilities
CREATE EXTENSION IF NOT EXISTS "btree_gin";        -- For better indexing performance
CREATE EXTENSION IF NOT EXISTS "pgstattuple";      -- For database statistics

-- Create user-defined functions (converted from SQL Server T-SQL to PostgreSQL PL/pgSQL)

-- RDS.Get_Age function (converted from T-SQL)
CREATE OR REPLACE FUNCTION rds.get_age(
    birth_date TIMESTAMP DEFAULT NULL,
    as_of_date TIMESTAMP DEFAULT NULL
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN 
        CASE 
            WHEN birth_date IS NULL THEN -1
            WHEN EXTRACT(YEAR FROM AGE(COALESCE(as_of_date, CURRENT_TIMESTAMP), birth_date)) <= 0 THEN -1
            ELSE EXTRACT(YEAR FROM AGE(COALESCE(as_of_date, CURRENT_TIMESTAMP), birth_date))::INTEGER
        END;
END;
$$;

-- Staging.GetFiscalYearEndDate function (converted from T-SQL)
CREATE OR REPLACE FUNCTION staging.get_fiscal_year_end_date(school_year SMALLINT)
RETURNS DATE
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN (school_year::TEXT || '-06-30')::DATE;
END;
$$;

-- Staging.GetFiscalYearStartDate function (converted from T-SQL)
CREATE OR REPLACE FUNCTION staging.get_fiscal_year_start_date(school_year SMALLINT)
RETURNS DATE
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN ((school_year - 1)::TEXT || '-07-01')::DATE;
END;
$$;

-- Staging.GetOrganizationIdentifierSystemId function (converted from T-SQL)
CREATE OR REPLACE FUNCTION staging.get_organization_identifier_system_id(
    organization_identifier_system_code VARCHAR(100), 
    organization_identifier_type_code VARCHAR(6)
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    ref_organization_identifier_system_id INTEGER;
BEGIN
    SELECT rois.ref_organization_identification_system_id
    INTO ref_organization_identifier_system_id
    FROM ref_organization_identification_system rois
    JOIN ref_organization_identifier_type roit
        ON rois.ref_organization_identifier_type_id = roit.ref_organization_identifier_type_id
    WHERE rois.code = organization_identifier_system_code
        AND roit.code = organization_identifier_type_code;

    RETURN ref_organization_identifier_system_id;
END;
$$;

-- Staging.GetOrganizationIdentifierTypeId function (converted from T-SQL)
CREATE OR REPLACE FUNCTION staging.get_organization_identifier_type_id(organization_identifier_type_code VARCHAR(6))
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    ref_organization_identifier_type_id INTEGER;
BEGIN
    SELECT roit.ref_organization_identifier_type_id
    INTO ref_organization_identifier_type_id
    FROM ref_organization_identifier_type roit
    WHERE roit.code = organization_identifier_type_code;

    RETURN ref_organization_identifier_type_id;
END;
$$;

-- Additional staging functions would be added here...
-- (GetOrganizationRelationshipId, GetOrganizationTypeId, GetPersonIdentifierSystemId, etc.)

-- Create first staging table as example (converted from SQL Server syntax)
CREATE TABLE staging.source_system_reference_data (
    source_system_reference_data_id SERIAL PRIMARY KEY,
    school_year SMALLINT NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    table_filter VARCHAR(100),
    input_code TEXT,
    output_code TEXT
);

-- Create indexes for performance (equivalent to SQL Server clustered indexes)
CREATE INDEX idx_source_system_reference_data_school_year ON staging.source_system_reference_data(school_year);
CREATE INDEX idx_source_system_reference_data_table_name ON staging.source_system_reference_data(table_name);

-- Create first RDS dimension table as example
CREATE TABLE rds.dim_title_i_statuses (
    dim_title_i_status_id SERIAL PRIMARY KEY,
    title_i_instructional_services_code VARCHAR(50),
    title_i_instructional_services_description VARCHAR(100),
    title_i_instructional_services_edfacts_code VARCHAR(50),
    title_i_program_type_code VARCHAR(50),
    title_i_program_type_description VARCHAR(100),
    title_i_program_type_edfacts_code VARCHAR(50),
    title_i_school_status_code VARCHAR(50),
    title_i_school_status_description VARCHAR(100),
    title_i_school_status_edfacts_code VARCHAR(50),
    title_i_support_services_code VARCHAR(50),
    title_i_support_services_description VARCHAR(100),
    title_i_support_services_edfacts_code VARCHAR(50)
);

-- PostgreSQL Comments (equivalent to SQL Server extended properties)
COMMENT ON DATABASE ceds_data_warehouse_v11_0_0_0 IS 'CEDS Data Warehouse Version 11.0.0.0 - PostgreSQL Conversion';
COMMENT ON SCHEMA rds IS 'Reporting Data Store - Contains dimension and fact tables for data warehouse';
COMMENT ON SCHEMA staging IS 'Staging area for ETL processes and data transformation';
COMMENT ON SCHEMA ceds IS 'Common Education Data Standards reference data';

-- Grant permissions (PostgreSQL equivalent of SQL Server security)
GRANT USAGE ON SCHEMA rds TO PUBLIC;
GRANT USAGE ON SCHEMA staging TO PUBLIC;
GRANT USAGE ON SCHEMA ceds TO PUBLIC;

-- Grant sequence permissions for SERIAL columns
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA rds TO PUBLIC;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA staging TO PUBLIC;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ceds TO PUBLIC;

/*
    TODO: Complete conversion of remaining database objects:
    
    1. Convert all remaining tables (150+ dimension tables, 25+ fact tables, 50+ bridge tables)
    2. Convert all remaining functions (15+ staging functions)
    3. Convert all views (40+ views)
    4. Convert all stored procedures to PostgreSQL functions (50+ procedures)
    5. Add proper constraints, indexes, and foreign keys
    6. Add table partitioning for large fact tables
    7. Set up PostgreSQL-specific optimizations
    
    This file provides the foundation and conversion patterns for the complete migration.
*/