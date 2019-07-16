
SELECT * FROM piws.insert_observation(
	NOW()::DATE, NOW()::TIME,
	'America/Denver',
	'{"dht11_h": 88.8, "dht11_t": 3.1, "ds18b20_t": 3.14}'::JSONB)
;
