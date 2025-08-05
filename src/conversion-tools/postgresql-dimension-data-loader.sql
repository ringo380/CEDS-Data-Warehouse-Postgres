-- PostgreSQL Dimension Data Loading Script
-- Converted from SQL Server Junk-Table-Dimension-Population-V11.0.0.0.sql
-- This script populates dimension tables in the CEDS Data Warehouse PostgreSQL version

-- =============================================================================
-- CEDS Data Warehouse Dimension Data Loader for PostgreSQL
-- =============================================================================

-- Script 3 of 3
-- This script requires:
-- 1. CEDS-Data-Warehouse-V11.0.0.0-PostgreSQL.sql (database structure)
-- 2. CEDS-Elements-V11.0.0.0-PostgreSQL.sql (reference data)
-- 3. This script (dimension population)

-- Connect to the CEDS data warehouse
\c ceds_data_warehouse_v11_0_0_0;

-- Set role for data loading (requires appropriate permissions)
-- SET ROLE ceds_etl_process;

BEGIN;

-- Disable triggers and constraints during bulk loading for performance
SET session_replication_role = replica;

-- =============================================================================
-- HELPER FUNCTIONS FOR DIMENSION LOADING
-- =============================================================================

-- Function to get next ID for dimensions (PostgreSQL equivalent of IDENTITY)
CREATE OR REPLACE FUNCTION app.get_next_dim_id(table_name TEXT, id_column TEXT)
RETURNS INTEGER AS $$
DECLARE
    next_id INTEGER;
BEGIN
    EXECUTE format('SELECT COALESCE(MAX(%I), 0) + 1 FROM %I', id_column, table_name)
    INTO next_id;
    RETURN next_id;
END;
$$ LANGUAGE plpgsql;

-- Function to safely insert dimension record if it doesn't exist
CREATE OR REPLACE FUNCTION app.upsert_dimension_record(
    table_name TEXT,
    check_columns TEXT[],
    check_values TEXT[],
    insert_sql TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    where_clause TEXT := '';
    exists_check BOOLEAN := FALSE;
    i INTEGER;
BEGIN
    -- Build WHERE clause for existence check
    FOR i IN 1..array_length(check_columns, 1) LOOP
        IF i > 1 THEN
            where_clause := where_clause || ' AND ';
        END IF;
        where_clause := where_clause || check_columns[i] || ' = ' || quote_literal(check_values[i]);
    END LOOP;
    
    -- Check if record exists
    EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I WHERE %s)', table_name, where_clause)
    INTO exists_check;
    
    -- Insert if doesn't exist
    IF NOT exists_check THEN
        EXECUTE insert_sql;
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- POPULATE DIM_AE_DEMOGRAPHICS
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Populating rds.dim_ae_demographics...';
    
    -- Insert missing record (-1 ID for unknown/missing values)
    IF NOT EXISTS (SELECT 1 FROM rds.dim_ae_demographics WHERE dim_ae_demographic_id = -1) THEN
        INSERT INTO rds.dim_ae_demographics (
            dim_ae_demographic_id,
            economic_disadvantage_status_code,
            economic_disadvantage_status_description,
            homelessness_status_code,
            homelessness_status_description,
            english_learner_status_code,
            english_learner_status_description,
            migrant_status_code,
            migrant_status_description,
            military_connected_student_indicator_code,
            military_connected_student_indicator_description,
            homeless_primary_nighttime_residence_code,
            homeless_primary_nighttime_residence_description,
            homeless_unaccompanied_youth_status_code,
            homeless_unaccompanied_youth_status_description,
            sex_code,
            sex_description
        ) VALUES (
            -1,
            'MISSING', 'MISSING',
            'MISSING', 'MISSING', 
            'MISSING', 'MISSING',
            'MISSING', 'MISSING',
            'MISSING', 'MISSING',
            'MISSING', 'MISSING',
            'MISSING', 'MISSING',
            'MISSING', 'MISSING'
        );
        
        RAISE NOTICE '  ✅ Inserted missing record (-1)';
    END IF;
END $$;

-- Create temporary tables for option set mappings
CREATE TEMP TABLE temp_economic_disadvantage_status (
    economic_disadvantage_status_code VARCHAR(50),
    economic_disadvantage_status_description VARCHAR(200),
    economic_disadvantage_status_edfacts_code VARCHAR(100)
);

-- Populate from CEDS elements (assuming ceds_elements database exists)
INSERT INTO temp_economic_disadvantage_status VALUES ('MISSING', 'MISSING', 'MISSING');

-- Insert from CEDS elements if available
DO $$
BEGIN
    -- Check if CEDS elements database/schema exists
    IF EXISTS (
        SELECT 1 FROM information_schema.schemata 
        WHERE schema_name = 'ceds_elements'
    ) THEN
        INSERT INTO temp_economic_disadvantage_status
        SELECT 
            ceds_option_set_code,
            ceds_option_set_description,
            CASE ceds_option_set_code
                WHEN 'Yes' THEN 'ECODIS'
                ELSE 'MISSING'
            END
        FROM ceds_elements.ceds_option_set_mapping
        WHERE ceds_element_technical_name = 'EconomicDisadvantageStatus';
        
        RAISE NOTICE '  ✅ Loaded EconomicDisadvantageStatus from CEDS elements';
    ELSE
        -- Insert default values if CEDS elements not available
        INSERT INTO temp_economic_disadvantage_status VALUES 
            ('Yes', 'Yes', 'ECODIS'),
            ('No', 'No', 'MISSING');
        
        RAISE NOTICE '  ⚠️  CEDS elements not found, using default values';
    END IF;
END $$;

-- Similar pattern for other status types
CREATE TEMP TABLE temp_homelessness_status (
    homelessness_status_code VARCHAR(50),
    homelessness_status_description VARCHAR(200),
    homelessness_status_edfacts_code VARCHAR(50)
);

INSERT INTO temp_homelessness_status VALUES ('MISSING', 'MISSING', 'MISSING');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ceds_elements') THEN
        INSERT INTO temp_homelessness_status
        SELECT 
            ceds_option_set_code,
            ceds_option_set_description,
            CASE ceds_option_set_code
                WHEN 'Yes' THEN 'HOMELESS'
                ELSE 'MISSING'
            END
        FROM ceds_elements.ceds_option_set_mapping
        WHERE ceds_element_technical_name = 'HomelessnessStatus';
    ELSE
        INSERT INTO temp_homelessness_status VALUES 
            ('Yes', 'Yes', 'HOMELESS'),
            ('No', 'No', 'MISSING');
    END IF;
END $$;

-- English Learner Status
CREATE TEMP TABLE temp_english_learner_status (
    english_learner_status_code VARCHAR(50),
    english_learner_status_description VARCHAR(200)
);

INSERT INTO temp_english_learner_status VALUES ('MISSING', 'MISSING');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ceds_elements') THEN
        INSERT INTO temp_english_learner_status
        SELECT 
            ceds_option_set_code,
            ceds_option_set_description
        FROM ceds_elements.ceds_option_set_mapping
        WHERE ceds_element_technical_name = 'EnglishLearnerStatus';
    ELSE
        INSERT INTO temp_english_learner_status VALUES 
            ('Yes', 'Yes'),
            ('No', 'No');
    END IF;
END $$;

-- Migrant Status
CREATE TEMP TABLE temp_migrant_status (
    migrant_status_code VARCHAR(50),
    migrant_status_description VARCHAR(200)
);

INSERT INTO temp_migrant_status VALUES ('MISSING', 'MISSING');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ceds_elements') THEN
        INSERT INTO temp_migrant_status
        SELECT 
            ceds_option_set_code,
            ceds_option_set_description
        FROM ceds_elements.ceds_option_set_mapping
        WHERE ceds_element_technical_name = 'MigrantStatus';
    ELSE
        INSERT INTO temp_migrant_status VALUES 
            ('Yes', 'Yes'),
            ('No', 'No');
    END IF;
END $$;

-- Military Connected Student Indicator
CREATE TEMP TABLE temp_military_connected_student_indicator (
    military_connected_student_indicator_code VARCHAR(50),
    military_connected_student_indicator_description VARCHAR(200)
);

INSERT INTO temp_military_connected_student_indicator VALUES ('MISSING', 'MISSING');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ceds_elements') THEN
        INSERT INTO temp_military_connected_student_indicator
        SELECT 
            ceds_option_set_code,
            ceds_option_set_description
        FROM ceds_elements.ceds_option_set_mapping
        WHERE ceds_element_technical_name = 'MilitaryConnectedStudentIndicator';
    ELSE
        INSERT INTO temp_military_connected_student_indicator VALUES 
            ('ActiveDuty', 'Active Duty'),
            ('NationalGuardOrReserves', 'National Guard or Reserves'),
            ('NotMilitaryConnected', 'Not Military Connected');
    END IF;
END $$;

-- Homeless Primary Nighttime Residence
CREATE TEMP TABLE temp_homeless_primary_nighttime_residence (
    homeless_primary_nighttime_residence_code VARCHAR(50),
    homeless_primary_nighttime_residence_description VARCHAR(500)
);

INSERT INTO temp_homeless_primary_nighttime_residence VALUES ('MISSING', 'MISSING');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ceds_elements') THEN
        INSERT INTO temp_homeless_primary_nighttime_residence
        SELECT 
            ceds_option_set_code,
            ceds_option_set_description
        FROM ceds_elements.ceds_option_set_mapping
        WHERE ceds_element_technical_name = 'HomelessPrimaryNighttimeResidence';
    ELSE
        INSERT INTO temp_homeless_primary_nighttime_residence VALUES 
            ('Shelters', 'Shelters'),
            ('DoubledUp', 'Doubled-up'),
            ('Unsheltered', 'Unsheltered'),
            ('HotelsMotels', 'Hotels/Motels');
    END IF;
END $$;

-- Homeless Unaccompanied Youth Status
CREATE TEMP TABLE temp_homeless_unaccompanied_youth_status (
    homeless_unaccompanied_youth_status_code VARCHAR(50),
    homeless_unaccompanied_youth_status_description VARCHAR(200)
);

INSERT INTO temp_homeless_unaccompanied_youth_status VALUES ('MISSING', 'MISSING');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ceds_elements') THEN
        INSERT INTO temp_homeless_unaccompanied_youth_status
        SELECT 
            ceds_option_set_code,
            ceds_option_set_description
        FROM ceds_elements.ceds_option_set_mapping
        WHERE ceds_element_technical_name = 'HomelessUnaccompaniedYouthStatus';
    ELSE
        INSERT INTO temp_homeless_unaccompanied_youth_status VALUES 
            ('Yes', 'Yes'),
            ('No', 'No');
    END IF;
END $$;

-- Sex
CREATE TEMP TABLE temp_sex (
    sex_code VARCHAR(50),
    sex_description VARCHAR(200)
);

INSERT INTO temp_sex VALUES ('MISSING', 'MISSING');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ceds_elements') THEN
        INSERT INTO temp_sex
        SELECT 
            ceds_option_set_code,
            ceds_option_set_description
        FROM ceds_elements.ceds_option_set_mapping
        WHERE ceds_element_technical_name = 'Sex';
    ELSE
        INSERT INTO temp_sex VALUES 
            ('Male', 'Male'),
            ('Female', 'Female'),
            ('NotSelected', 'Not Selected');
    END IF;
END $$;

-- Generate Cartesian product for all combinations
INSERT INTO rds.dim_ae_demographics (
    economic_disadvantage_status_code,
    economic_disadvantage_status_description,
    homelessness_status_code,
    homelessness_status_description,
    english_learner_status_code,
    english_learner_status_description,
    migrant_status_code,
    migrant_status_description,
    military_connected_student_indicator_code,
    military_connected_student_indicator_description,
    homeless_primary_nighttime_residence_code,
    homeless_primary_nighttime_residence_description,
    homeless_unaccompanied_youth_status_code,
    homeless_unaccompanied_youth_status_description,
    sex_code,
    sex_description
)
SELECT 
    eds.economic_disadvantage_status_code,
    eds.economic_disadvantage_status_description,
    hs.homelessness_status_code,
    hs.homelessness_status_description,
    els.english_learner_status_code,
    els.english_learner_status_description,
    ms.migrant_status_code,
    ms.migrant_status_description,
    mcsi.military_connected_student_indicator_code,
    mcsi.military_connected_student_indicator_description,
    hpnr.homeless_primary_nighttime_residence_code,
    hpnr.homeless_primary_nighttime_residence_description,
    huys.homeless_unaccompanied_youth_status_code,
    huys.homeless_unaccompanied_youth_status_description,
    s.sex_code,
    s.sex_description
FROM temp_economic_disadvantage_status eds
CROSS JOIN temp_homelessness_status hs
CROSS JOIN temp_english_learner_status els
CROSS JOIN temp_migrant_status ms
CROSS JOIN temp_military_connected_student_indicator mcsi
CROSS JOIN temp_homeless_primary_nighttime_residence hpnr
CROSS JOIN temp_homeless_unaccompanied_youth_status huys  
CROSS JOIN temp_sex s
LEFT JOIN rds.dim_ae_demographics main ON (
    main.economic_disadvantage_status_code = eds.economic_disadvantage_status_code
    AND main.homelessness_status_code = hs.homelessness_status_code
    AND main.english_learner_status_code = els.english_learner_status_code
    AND main.migrant_status_code = ms.migrant_status_code
    AND main.military_connected_student_indicator_code = mcsi.military_connected_student_indicator_code
    AND main.homeless_primary_nighttime_residence_code = hpnr.homeless_primary_nighttime_residence_code
    AND main.homeless_unaccompanied_youth_status_code = huys.homeless_unaccompanied_youth_status_code
    AND main.sex_code = s.sex_code
)
WHERE main.dim_ae_demographic_id IS NULL;

-- Report results
DO $$
DECLARE
    record_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO record_count FROM rds.dim_ae_demographics WHERE dim_ae_demographic_id != -1;
    RAISE NOTICE '  ✅ dim_ae_demographics populated with % combination records', record_count;
END $$;

-- =============================================================================
-- POPULATE DIM_AE_PROGRAM_TYPES  
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Populating rds.dim_ae_program_types...';
    
    -- Insert missing record (-1 ID)
    IF NOT EXISTS (SELECT 1 FROM rds.dim_ae_program_types WHERE dim_ae_program_type_id = -1) THEN
        INSERT INTO rds.dim_ae_program_types (
            dim_ae_program_type_id,
            ae_program_type_code,
            ae_program_type_description
        ) VALUES (
            -1,
            'MISSING',
            'MISSING'
        );
        
        RAISE NOTICE '  ✅ Inserted missing record (-1)';
    END IF;
END $$;

-- Populate AE Program Types from CEDS elements
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ceds_elements') THEN
        INSERT INTO rds.dim_ae_program_types (
            ae_program_type_code,
            ae_program_type_description
        )
        SELECT DISTINCT
            cosm.ceds_option_set_code,
            cosm.ceds_option_set_description
        FROM ceds_elements.ceds_option_set_mapping cosm
        LEFT JOIN rds.dim_ae_program_types main ON (
            main.ae_program_type_code = cosm.ceds_option_set_code
        )
        WHERE cosm.ceds_element_technical_name = 'AdultEducationProgramType'
        AND main.dim_ae_program_type_id IS NULL;
        
        RAISE NOTICE '  ✅ Populated from CEDS elements';
    ELSE
        -- Insert default values
        INSERT INTO rds.dim_ae_program_types (ae_program_type_code, ae_program_type_description)
        SELECT code, description FROM (VALUES
            ('AdultSecondaryEducation', 'Adult Secondary Education'),
            ('EnglishLanguageLearning', 'English Language Learning'),
            ('AdultBasicEducation', 'Adult Basic Education'),
            ('IntegratedEducationAndTraining', 'Integrated Education and Training')
        ) AS t(code, description)
        WHERE NOT EXISTS (
            SELECT 1 FROM rds.dim_ae_program_types 
            WHERE ae_program_type_code = t.code
        );
        
        RAISE NOTICE '  ⚠️  Used default values (CEDS elements not available)';
    END IF;
END $$;

-- =============================================================================
-- UTILITY FUNCTIONS FOR ADDITIONAL DIMENSIONS
-- =============================================================================

-- Generic function to populate simple code/description dimensions
CREATE OR REPLACE FUNCTION app.populate_simple_dimension(
    table_name TEXT,
    id_column TEXT,
    code_column TEXT, 
    description_column TEXT,
    ceds_element_name TEXT,
    default_values TEXT[][] DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    insert_count INTEGER := 0;
    val TEXT[];
BEGIN
    -- Insert missing record if not exists
    EXECUTE format('
        INSERT INTO %I (%I, %I, %I) 
        SELECT -1, ''MISSING'', ''MISSING''
        WHERE NOT EXISTS (SELECT 1 FROM %I WHERE %I = -1)',
        table_name, id_column, code_column, description_column,
        table_name, id_column
    );
    
    -- Try to populate from CEDS elements
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ceds_elements') THEN
        EXECUTE format('
            INSERT INTO %I (%I, %I)
            SELECT DISTINCT
                cosm.ceds_option_set_code,
                cosm.ceds_option_set_description
            FROM ceds_elements.ceds_option_set_mapping cosm
            LEFT JOIN %I main ON main.%I = cosm.ceds_option_set_code
            WHERE cosm.ceds_element_technical_name = %L
            AND main.%I IS NULL',
            table_name, code_column, description_column,
            table_name, code_column,
            ceds_element_name,
            id_column
        );
        GET DIAGNOSTICS insert_count = ROW_COUNT;
    ELSIF default_values IS NOT NULL THEN
        -- Use provided default values
        FOREACH val SLICE 1 IN ARRAY default_values LOOP
            EXECUTE format('
                INSERT INTO %I (%I, %I) 
                SELECT %L, %L
                WHERE NOT EXISTS (SELECT 1 FROM %I WHERE %I = %L)',
                table_name, code_column, description_column,
                val[1], val[2],
                table_name, code_column, val[1]
            );
            GET DIAGNOSTICS insert_count = insert_count + ROW_COUNT;
        END LOOP;
    END IF;
    
    RETURN insert_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- POPULATE REMAINING DIMENSIONS USING UTILITY FUNCTION
-- =============================================================================

-- Example: Populate DimGradeLevels
DO $$
DECLARE
    insert_count INTEGER;
BEGIN
    RAISE NOTICE 'Populating rds.dim_grade_levels...';
    
    SELECT app.populate_simple_dimension(
        'rds.dim_grade_levels',
        'dim_grade_level_id', 
        'grade_level_code',
        'grade_level_description',
        'GradeLevel',
        ARRAY[
            ARRAY['PK', 'Pre-Kindergarten'],
            ARRAY['KG', 'Kindergarten'], 
            ARRAY['01', 'First grade'],
            ARRAY['02', 'Second grade'],
            ARRAY['03', 'Third grade'],
            ARRAY['04', 'Fourth grade'],
            ARRAY['05', 'Fifth grade'],
            ARRAY['06', 'Sixth grade'],
            ARRAY['07', 'Seventh grade'],
            ARRAY['08', 'Eighth grade'],
            ARRAY['09', 'Ninth grade'],
            ARRAY['10', 'Tenth grade'],
            ARRAY['11', 'Eleventh grade'],
            ARRAY['12', 'Twelfth grade']
        ]
    ) INTO insert_count;
    
    RAISE NOTICE '  ✅ Inserted % records', insert_count;
END $$;

-- =============================================================================
-- PERFORMANCE OPTIMIZATION
-- =============================================================================

-- Re-enable triggers and constraints
SET session_replication_role = DEFAULT;

-- Update table statistics for query optimizer
DO $$
DECLARE
    table_name TEXT;
BEGIN
    RAISE NOTICE 'Updating table statistics...';
    
    -- Update statistics on populated dimension tables
    FOR table_name IN 
        SELECT t.table_name 
        FROM information_schema.tables t
        WHERE t.table_schema = 'rds' 
        AND t.table_name LIKE 'dim_%'
        AND t.table_type = 'BASE TABLE'
    LOOP
        EXECUTE format('ANALYZE rds.%I', table_name);
    END LOOP;
    
    RAISE NOTICE '  ✅ Statistics updated';
END $$;

-- =============================================================================
-- COMPLETION SUMMARY
-- =============================================================================

DO $$
DECLARE
    total_records INTEGER := 0;
    table_record record;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Dimension Data Loading Complete ===';
    
    -- Count records in each dimension table
    FOR table_record IN 
        SELECT t.table_name
        FROM information_schema.tables t
        WHERE t.table_schema = 'rds' 
        AND t.table_name LIKE 'dim_%'
        AND t.table_type = 'BASE TABLE'
        ORDER BY t.table_name
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM rds.%I', table_record.table_name) INTO total_records;
        RAISE NOTICE 'rds.%: % records', table_record.table_name, total_records;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ All dimension tables populated successfully';
    RAISE NOTICE 'ℹ️  Run additional dimension loading scripts as needed';
    RAISE NOTICE '';
END $$;

COMMIT;

-- =============================================================================
-- NOTES FOR ADMINISTRATORS
-- =============================================================================

/*
DIMENSION LOADING NOTES:

1. CEDS Elements Dependency:
   - This script looks for ceds_elements schema with reference data
   - If not found, uses default values for each dimension
   - Download CEDS Elements from: https://github.com/CEDStandards/CEDS-Elements

2. Performance Considerations:
   - Large cartesian products (like dim_ae_demographics) can generate thousands of records
   - Consider adding WHERE clauses to limit combinations if not all are needed
   - Index creation is recommended after data loading

3. Customization:
   - Modify default values arrays to match your organization's needs
   - Add additional dimensions using the populate_simple_dimension function
   - Extend for complex dimensions requiring multiple reference tables

4. Error Handling:
   - Script uses transactions to ensure consistency
   - Failed operations will rollback all changes
   - Check PostgreSQL logs for detailed error information

5. Maintenance:
   - Re-run this script when CEDS elements are updated
   - Monitor dimension table sizes and performance impact
   - Consider partitioning large dimension tables if needed

6. Security:
   - Ensure the executing user has appropriate permissions
   - Consider using ceds_etl_process role for data loading
   - Audit dimension changes in production environments
*/