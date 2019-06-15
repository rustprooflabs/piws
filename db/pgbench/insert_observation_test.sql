
SELECT * FROM piws.insert_observation(1,
	NOW()::DATE, NOW()::TIME,
	'America/Denver',
	'{"dht11_h": 88.8, "dht11_t": 3.1, "ds18b20_t": 3.14}'::JSONB)
;
