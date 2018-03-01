-- Revert piws:002 from pg

BEGIN;

-- XXX Add DDLs here.
DROP INDEX IX_piws_observation_calendar_id;
DROP INDEX IX_piws_observation_time_id;
DROP INDEX IX_piws_observation_sensor_id;


COMMIT;
