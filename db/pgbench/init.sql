/*
	Used to pre-populate the PiWS database with fake data.

	Uses scale:  1 unit = 1 week

	Does **not** clear out data before re-loading
*/


--SELECT * FROM piws.insert_observation(%s::INT, %s::DATE, %s::TIME,  %s::TEXT, %s::JSONB) 

INSERT INTO piws.observation_raw (observe_date, sensor_values)
SELECT '2018-01-01'::TIMESTAMPTZ + (a.a + random() * 1.5 - random())
			* INTERVAL '10 seconds' AS observe_date,
		'{"dht11_h": 88.8, "dht11_t": 3.1, "ds18b20_t": 3.14}'::JSONB
		AS sensor_values
	FROM generate_series(1, 50400 * :scale) a(a) -- 50400 rows simulates one week of observations (avg 5 per minute)
;


SELECT piws.load_raw_observations();
SELECT piws.clean_raw_observations();

VACUUM ANALYZE;
