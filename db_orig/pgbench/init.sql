/*
	Used to pre-populate the PiWS database with fake data.

	Uses scale:  1 unit = 1 week

	Does **not** clear out data before re-loading
*/


--SELECT * FROM piws.insert_observation(%s::INT, %s::DATE, %s::TIME,  %s::TEXT, %s::JSONB) 



INSERT INTO piws.observation (calendar_id, time_id, timezone, sensor_values)
SELECT 
	FLOOR( (random() * 365) + 1 )::INT AS calendar_id,
	FLOOR( (random() * 86398) + 1 )::INT AS time_id,
	'America/Denver' AS timezone,
	 '{"dht11_h": 88.8, "dht11_t": 3.1, "ds18b20_t": 3.14}'::JSONB AS sensor_values
	FROM generate_series(1, 50400 * :scale) -- 50400 rows simulates one week of observations (avg 5 per minute)
;

SELECT * FROM piws.load_minute_observations();

