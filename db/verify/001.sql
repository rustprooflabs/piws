-- Verify piws:001 on pg

BEGIN;



SELECT observation_id, sensor_id, calendar_id, time_id, timezone, sensor_values
	FROM piws.observation
	WHERE FALSE
;


SELECT datum, hour, quarterhour, observation_cnt
    FROM piws.vQuarterHourSummary
    WHERE FALSE;



ROLLBACK;
