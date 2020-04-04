-- Revert piws:008 from pg

BEGIN;

	COMMENT ON SCHEMA piws
			IS NULL
			;
			
	COMMENT ON TABLE public.calendar IS NULL;

	COMMENT ON TABLE public.time IS NULL;

	COMMENT ON TABLE piws.api_quarterhour_submitted IS NULL;
	COMMENT ON TABLE piws.observation IS NULL;
	COMMENT ON TABLE piws.observation_minute IS NULL;


	DELETE FROM dd.meta_table
		WHERE s_name = 'piws' 
			AND t_name IN ('api_quarterhour_submitted',
						'observation',
						'observation_minute')
		;

	DELETE FROM dd.meta_table
		WHERE s_name = 'public' 
			AND t_name IN ('calendar', 'time', '')
		;


	COMMENT ON COLUMN piws.observation.timezone
		IS NULL;		

	COMMENT ON COLUMN piws.observation.sensor_values
		IS NULL;

	COMMENT ON COLUMN piws.api_quarterhour_submitted.sensor_name
		IS NULL;

	COMMENT ON COLUMN piws.api_quarterhour_submitted.node_unique_id
		IS NULL;

	COMMENT ON COLUMN piws.api_quarterhour_submitted.end_15min
		IS NULL;


	COMMENT ON COLUMN piws.observation_minute.node_unique_id
		IS NULL;

	COMMENT ON COLUMN piws.observation_minute.timezone
		IS NULL;

COMMIT;
