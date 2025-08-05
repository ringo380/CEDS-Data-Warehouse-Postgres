-- Converted from SQL Server function: Get_Age.sql
-- Original T-SQL converted to PostgreSQL PL/pgSQL
-- 
CREATE OR REPLACE FUNCTION rds.get__age(
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