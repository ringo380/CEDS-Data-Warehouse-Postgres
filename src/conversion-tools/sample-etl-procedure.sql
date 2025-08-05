CREATE PROCEDURE [Staging].[Staging_To_DimK12Schools]
	@SchoolYear SMALLINT = NULL
AS
BEGIN

	SET NOCOUNT ON;
	
	-- Declare variables for processing
	DECLARE @RecordCount INT = 0
	DECLARE @NewK12SchoolId INT 
	DECLARE @StagingId INT
	DECLARE @SkipErrorLogging BIT = 0

	BEGIN TRY

		-- Log start of procedure
		INSERT INTO app.DataMigrationHistories
		(DataMigrationHistoryDate, DataMigrationTypeId, DataMigrationHistoryMessage) 
		VALUES (GETUTCDATE(), 2, 'Staging to DimK12Schools Started for School Year: ' + CONVERT(VARCHAR, @SchoolYear))

		-- Create temp table for processing
		IF OBJECT_ID('tempdb..#Schools') IS NOT NULL 
			DROP TABLE #Schools

		CREATE TABLE #Schools (
			StagingId INT,
			SchoolName NVARCHAR(100),
			StateCode VARCHAR(2),
			ProcessedFlag BIT DEFAULT 0
		)

		-- Populate temp table from staging
		INSERT INTO #Schools (StagingId, SchoolName, StateCode)
		SELECT 
			s.K12OrganizationId,
			s.Name,
			s.StateAbbreviation  
		FROM Staging.K12Organization s
		WHERE s.SchoolYear = @SchoolYear
		AND s.OrganizationType = 'K12School'

		-- Process each school
		WHILE EXISTS(SELECT TOP 1 * FROM #Schools WHERE ProcessedFlag = 0)
		BEGIN
			-- Get next unprocessed school
			SELECT @StagingId = (SELECT TOP 1 StagingId FROM #Schools WHERE ProcessedFlag = 0)

			-- Merge into dimension table
			MERGE RDS.DimK12Schools AS target
			USING (
				SELECT 
					s.Name,
					s.StateAbbreviation,
					ISNULL(s.OperationalStatus, 'Unknown') AS OperationalStatus
				FROM Staging.K12Organization s
				WHERE s.K12OrganizationId = @StagingId
			) AS source ON (target.SchoolName = source.Name AND target.StateCode = source.StateAbbreviation)
			WHEN MATCHED THEN
				UPDATE SET 
					OperationalStatusCode = source.OperationalStatus,
					RecordEndDateTime = CASE 
						WHEN target.OperationalStatusCode <> source.OperationalStatus THEN GETDATE()
						ELSE target.RecordEndDateTime
					END
			WHEN NOT MATCHED THEN
				INSERT (SchoolName, StateCode, OperationalStatusCode, RecordStartDateTime)
				VALUES (source.Name, source.StateAbbreviation, source.OperationalStatus, GETDATE());

			-- Update processed flag
			UPDATE #Schools SET ProcessedFlag = 1 WHERE StagingId = @StagingId
			SET @RecordCount = @RecordCount + 1

		END

		-- Log completion
		INSERT INTO app.DataMigrationHistories
		(DataMigrationHistoryDate, DataMigrationTypeId, DataMigrationHistoryMessage) 
		VALUES (GETUTCDATE(), 2, 'Staging to DimK12Schools Completed. Records processed: ' + CONVERT(VARCHAR, @RecordCount))

	END TRY
	BEGIN CATCH

		-- Error handling
		DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
		DECLARE @ErrorNumber INT = ERROR_NUMBER()

		-- Log error
		IF @SkipErrorLogging = 0
		BEGIN
			INSERT INTO app.DataMigrationHistories
			(DataMigrationHistoryDate, DataMigrationTypeId, DataMigrationHistoryMessage) 
			VALUES (GETUTCDATE(), 4, 'ERROR in Staging to DimK12Schools: ' + @ErrorMessage)
		END

		-- Re-raise error
		RAISERROR(@ErrorMessage, 16, 1)

	END CATCH

END