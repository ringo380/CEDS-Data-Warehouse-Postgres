-- Converted from SQL Server function: GetFiscalYearStartDate.sql
-- Original T-SQL converted to PostgreSQL PL/pgSQL
-- 
CREATE OR REPLACE FUNCTION staging.get_fiscal_year_start_date(
    school_year SMALLINT
) RETURNS DATE
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN ((school_year - 1)::TEXT || '-07-01')::DATE
END;
$$;