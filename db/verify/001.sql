-- Verify piws:001 on pg

BEGIN;



SELECT observation_id, calendar_id, time_id, timezone, sensor_values
	FROM piws.observation
	WHERE FALSE
;


SELECT datum, hour, quarterhour
    FROM piws.vQuarterHourSummary
    WHERE FALSE;



ROLLBACK;
