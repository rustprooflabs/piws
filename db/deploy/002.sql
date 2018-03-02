-- Deploy piws:002 to pg
-- requires: 001

BEGIN;

CREATE INDEX IX_piws_observation_calendar_id ON piws.observation (calendar_id);
CREATE INDEX IX_piws_observation_time_id ON piws.observation (time_id);
CREATE INDEX IX_piws_observation_sensor_id ON piws.observation (sensor_id);

COMMIT;
