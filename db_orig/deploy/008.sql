-- Deploy piws:008 to pg

BEGIN;

	-- Schema comment
	---------------------------------------
	COMMENT ON SCHEMA piws IS 'Pi Weather Station (PiWS): https://github.com/rustprooflabs/piws';


	-- Table comments
	---------------------------------------
	COMMENT ON TABLE public.calendar IS 'Standard calendar table.  One row per date (datum) with common human friendly grouping columns.  Calendar dates start with 1/1/2018 going out almost 78 years (28400 days) into the future.';

	COMMENT ON TABLE public.time IS 'Standard time table, resolution one (1) day.  Includes common human friendly grouping columns';

	COMMENT ON TABLE piws.api_quarterhour_submitted IS 'Tracks submission of data to API in 15 minute (quarter-hour) increments.';

	COMMENT ON TABLE piws.observation IS 'Stores raw observation data as it comes in to the PiWS database.  Data is queried from here to send data to the API for long term storage and analysis.';

	COMMENT ON TABLE piws.observation_minute IS 'Aggregates sub-minute observations combined in a JSON field to once per minute per sensor per observation.';


	-- Table meta-data
	---------------------------------------
	INSERT INTO dd.meta_table (s_name, t_name, data_source, sensitive)
		VALUES
		('piws', 'api_quarterhour_submitted', 'PiWS API (Python)', False),
		('piws', 'observation', 'PiWS sensor collection (Python)', False),
		('piws', 'observation_minute', 'Aggregated from piws.observation table.', False),
		('public', 'calendar', 'Generated at creation time (delta 001)', False),
		('public', 'time', 'Generated at creation time (delta 001)', False)
	;

	-- Column comments
	---------------------------------------
	COMMENT ON COLUMN piws.observation.timezone IS 'Warning: Will be deprecated with PIWS-58.  Indicates timezone of observation.';

	COMMENT ON COLUMN piws.observation.sensor_values IS 'Raw sensor data from PiWS sensors.  Each JSON reading includes one or more (possibly duplicated) sensor readings.';

	COMMENT ON COLUMN piws.api_quarterhour_submitted.sensor_name IS 'Name of the sensor sending the observation.  Typically a model name.  e.g. DS18B20';

	COMMENT ON COLUMN piws.api_quarterhour_submitted.node_unique_id IS 'Unique ID of sensor node when the sensor itself has such an id embedded.';

	COMMENT ON COLUMN piws.api_quarterhour_submitted.end_15min IS 'Timestamp indicates the end of the 15-minute window of the observation submitted.';


	COMMENT ON COLUMN piws.observation_minute.node_unique_id IS 'Unique ID of sensor node when the sensor itself has such an id embedded.';

	COMMENT ON COLUMN piws.observation_minute.timezone IS 'Warning: Will be deprecated with PIWS-58.  Indicates timezone of observation.';

COMMIT;
