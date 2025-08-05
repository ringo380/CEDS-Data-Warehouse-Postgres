-- Converted from SQL Server view: vwUnduplicatedRaceMap.sql
-- Original SQL Server view converted to PostgreSQL
-- 
CREATE OR REPLACE VIEW rds.unduplicated_race_map AS
SELECT 
        StudentIdentifierState
        , LeaIdentifierSeaAccountability
	    , SchoolIdentifierSea
        , RaceMap
        , SchoolYear
    FROM (
        SELECT 
            StudentIdentifierState
            , LeaIdentifierSeaAccountability
            , SchoolIdentifierSea
            , CASE 
                WHEN COUNT(InputCode) > 1 
                    THEN (select max(inputcode)
                                   from staging.source_system_reference_data where TableName = 'refRace'
                                   and schoolyear = spr.SchoolYear
                                   and outputcode = 'TwoOrMoreRaces'
                            )
                    ELSE max(sssrd.InputCode)
            END as RaceMap
            , spr.SchoolYear
        FROM staging.k12_person_race spr
        JOIN staging.source_system_reference_data sssrd
            ON spr.RaceType = sssrd.InputCode
            AND spr.SchoolYear = sssrd.SchoolYear
            AND sssrd.TableName = 'RefRace'
        GROUP BY
            StudentIdentifierState
            , LeaIdentifierSeaAccountability
            , SchoolIdentifierSea
            , spr.SchoolYear
    ) stagingRaces;