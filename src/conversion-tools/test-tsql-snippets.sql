-- Test T-SQL code snippets for conversion testing
-- These are real patterns from CEDS stored procedures

-- 1. Variable declarations with initialization
DECLARE @StagingSchoolYear INT, @MaxSchoolYearInSSRD INT = 0

-- 2. Simple variable assignment
SELECT @MaxSchoolYearInSSRD = MAX(SchoolYear) FROM Staging.SourceSystemReferenceData

-- 3. Conditional logic with temp tables
IF OBJECT_ID(N'tempdb..#SchoolYearsInStaging') IS NOT NULL DROP TABLE #SchoolYearsInStaging

-- 4. WHILE loop pattern
WHILE EXISTS(SELECT TOP 1 * FROM #SchoolYearsInStaging)
BEGIN
    SELECT @StagingSchoolYear = (SELECT TOP 1 SchoolYear FROM #SchoolYearsInStaging)
    DELETE TOP(1) FROM #SchoolYearsInStaging
END

-- 5. String concatenation with functions
INSERT INTO app.DataMigrationHistories (DataMigrationHistoryDate, DataMigrationTypeId, DataMigrationHistoryMessage) 
VALUES (GETUTCDATE(), 4, 'ERROR: Failed for ' + CONVERT(VARCHAR, @StagingSchoolYear))

-- 6. NULL checking with ISNULL
SELECT @StateName = ISNULL(StateName, 'Unknown') FROM DimStates WHERE StateId = @StateCode

-- 7. Date arithmetic
SELECT @EndDate = DATEADD(YEAR, 1, @StartDate)

-- 8. System functions
SELECT @@ROWCOUNT, @@ERROR