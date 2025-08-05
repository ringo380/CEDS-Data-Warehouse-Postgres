-- CEDS Data Warehouse Junk Table Population - PostgreSQL Version
-- Fixed and simplified version focusing on essential missing data

-- =============================================================================
-- POPULATE DIM_RACES TABLE
-- =============================================================================
DO $$
BEGIN
    RAISE NOTICE 'Populating rds.dim_races...';
    
    -- Insert missing record (-1 ID)
    IF NOT EXISTS (SELECT 1 FROM rds.dim_races WHERE dim_race_id = -1) THEN
        INSERT INTO rds.dim_races (
            dim_race_id,
            race_code,
            race_description,
            race_ed_facts_code
        ) VALUES (
            -1,
            'MISSING',
            'MISSING', 
            'MISSING'
        );
        RAISE NOTICE '  ✅ Inserted missing record (-1)';
    END IF;
    
    -- Insert standard race categories
    INSERT INTO rds.dim_races (race_code, race_description, race_ed_facts_code)
    SELECT code, description, edfacts_code FROM (VALUES
        ('AmericanIndianorAlaskanNative', 'American Indian or Alaska Native', 'AM7'),
        ('Asian', 'Asian', 'AS7'),
        ('BlackorAfricanAmerican', 'Black or African American', 'BL7'),
        ('NativeHawaiianorOtherPacificIslander', 'Native Hawaiian or Other Pacific Islander', 'PI7'),
        ('White', 'White', 'WH7'),
        ('TwoorMoreRaces', 'Two or More Races', 'MU7'),
        ('HispanicorLatinoEthnicity', 'Hispanic or Latino', 'HI7')
    ) AS t(code, description, edfacts_code)
    WHERE NOT EXISTS (
        SELECT 1 FROM rds.dim_races 
        WHERE race_code = t.code
    );
    
    RAISE NOTICE '  ✅ Populated race categories';
END $$;

-- =============================================================================
-- POPULATE DIM_AGES TABLE
-- =============================================================================
DO $$
DECLARE
    age_val INTEGER;
BEGIN
    RAISE NOTICE 'Populating rds.dim_ages...';
    
    -- Insert missing record (-1 ID)
    IF NOT EXISTS (SELECT 1 FROM rds.dim_ages WHERE dim_age_id = -1) THEN
        INSERT INTO rds.dim_ages (
            dim_age_id,
            age_code,
            age_description,
            age_ed_facts_code,
            age_value
        ) VALUES (
            -1,
            'MISSING',
            'MISSING',
            'MISSING',
            -1
        );
        RAISE NOTICE '  ✅ Inserted missing record (-1)';
    END IF;
    
    -- Insert age values from 0 to 130
    FOR age_val IN 0..130 LOOP
        INSERT INTO rds.dim_ages (age_code, age_description, age_ed_facts_code, age_value)
        SELECT 
            age_val::text,
            CASE 
                WHEN age_val = 0 THEN 'Less than 1 year old'
                WHEN age_val = 1 THEN '1 year old'
                ELSE age_val::text || ' years old'
            END,
            CASE 
                WHEN age_val <= 2 THEN '0TO2'
                WHEN age_val <= 5 THEN '3TO5' 
                WHEN age_val <= 11 THEN '6TO11'
                WHEN age_val <= 13 THEN '12TO13'
                WHEN age_val <= 17 THEN '14TO17'
                WHEN age_val <= 21 THEN '18TO21'
                ELSE 'ADULT'
            END,
            age_val
        WHERE NOT EXISTS (
            SELECT 1 FROM rds.dim_ages 
            WHERE age_value = age_val
        );
    END LOOP;
    
    RAISE NOTICE '  ✅ Populated ages 0-130';
END $$;

-- =============================================================================
-- POPULATE DIM_DATES TABLE (Essential for data warehouse)
-- =============================================================================
DO $$
DECLARE
    date_val DATE;
    end_date DATE;
    current_year INTEGER;
    current_month INTEGER;
    current_day INTEGER;
    day_of_week INTEGER;
    day_of_year INTEGER;
BEGIN
    RAISE NOTICE 'Populating rds.dim_dates...';
    
    -- Insert missing record (-1 ID)
    IF NOT EXISTS (SELECT 1 FROM rds.dim_dates WHERE dim_date_id = -1) THEN
        INSERT INTO rds.dim_dates (
            dim_date_id,
            date_value,
            day,
            day_of_week,
            day_of_year,
            month,
            month_name,
            submission_year,
            year
        ) VALUES (
            -1,
            '1900-01-01',
            -1,
            'MISSING',
            -1,
            -1,
            'MISSING',
            'MISSING',
            -1
        );
        RAISE NOTICE '  ✅ Inserted missing record (-1)';
    END IF;
    
    -- Generate dates from 2000 to 2050
    date_val := '2000-01-01'::DATE;
    end_date := '2050-12-31'::DATE;
    
    WHILE date_val <= end_date LOOP
        current_year := EXTRACT(YEAR FROM date_val);
        current_month := EXTRACT(MONTH FROM date_val);
        current_day := EXTRACT(DAY FROM date_val);
        day_of_week := EXTRACT(DOW FROM date_val);
        day_of_year := EXTRACT(DOY FROM date_val);
        
        INSERT INTO rds.dim_dates (
            date_value,
            day,
            day_of_week,
            day_of_year, 
            month,
            month_name,
            submission_year,
            year
        )
        SELECT 
            date_val,
            current_day,
            CASE day_of_week
                WHEN 0 THEN 'Sunday'
                WHEN 1 THEN 'Monday'
                WHEN 2 THEN 'Tuesday'
                WHEN 3 THEN 'Wednesday'
                WHEN 4 THEN 'Thursday'
                WHEN 5 THEN 'Friday'
                WHEN 6 THEN 'Saturday'
            END,
            day_of_year,
            current_month,
            TO_CHAR(date_val, 'Month'),
            current_year::text,
            current_year
        WHERE NOT EXISTS (
            SELECT 1 FROM rds.dim_dates 
            WHERE date_value = date_val
        );
        
        date_val := date_val + INTERVAL '1 day';
    END LOOP;
    
    RAISE NOTICE '  ✅ Populated dates 2000-2050';
END $$;

-- =============================================================================
-- NOTE: DIM_SCHOOL_YEARS TABLE NOT FOUND - SKIPPING
-- This table may have a different name or be populated elsewhere
-- =============================================================================

-- =============================================================================
-- COMPLETION MESSAGE
-- =============================================================================
DO $$
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'CEDS Junk Table Population Complete';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Essential dimension tables populated:';
    RAISE NOTICE '✅ rds.dim_races - Race categories';
    RAISE NOTICE '✅ rds.dim_ages - Ages 0-130';
    RAISE NOTICE '✅ rds.dim_dates - Dates 2000-2050';
    RAISE NOTICE '';
    RAISE NOTICE 'Note: Some tables already populated by dimension loader';
    RAISE NOTICE '====================================================';
END $$;