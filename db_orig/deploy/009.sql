-- Deploy piws:009 to pg

BEGIN;

	DROP FUNCTION piws.insert_observation(int, date, time without time zone, text, jsonb);


	CREATE FUNCTION piws.insert_observation(obs_date date, obs_time time without time zone,
			tzone text, sensor_values jsonb)
	 RETURNS integer
	 LANGUAGE sql
	 SECURITY DEFINER
	 SET search_path TO 'piws, pg_temp'
	AS $function$

        SELECT * FROM piws.load_minute_observations();

        INSERT INTO piws.observation (calendar_id, time_id, timezone, sensor_values)
            SELECT c.calendar_id, t.time_id, tzone, sensor_values
            FROM public.calendar c
            INNER JOIN public.time t 
            	ON t.timeofday = date_trunc('second', $2::TIME)
            WHERE c.datum = $1

            RETURNING observation_id

        $function$
    ;


	DROP VIEW piws.vminutesummary;
	DROP VIEW piws.vobservations;

	CREATE VIEW piws.vobservations AS
	 SELECT c.datum + t.timeofday AS tstamp,
	    c.datum,
	    c.formatteddate,
	    c.year,
	    c.month,
	    t.timeofday,
	    t.hour,
	    t.minute,
	    t.daytimename,
	    t.daynight,
	    t.quarterhour,
	    o.timezone,
	    o.sensor_values
	   FROM piws.observation o
	     JOIN public.calendar c ON o.calendar_id = c.calendar_id
	     JOIN public."time" t ON o.time_id = t.time_id
	;


	CREATE VIEW piws.vminutesummary AS
	 WITH sensor_values AS (
	         SELECT vobservations.datum,
	            vobservations.hour,
	            vobservations.minute,
	            (vobservations.sensor_values ->> 'dht11_t'::text)::numeric AS dht11_t,
	            (vobservations.sensor_values ->> 'dht11_h'::text)::numeric AS dht11_h,
	            (vobservations.sensor_values ->> 'ds18b20_t'::text)::numeric AS ds18b20_t
	           FROM piws.vobservations
	          WHERE (vobservations.sensor_values ->> 'dht11_t'::text) <> ''::text OR (vobservations.sensor_values ->> 'dht11_h'::text) <> ''::text OR (vobservations.sensor_values ->> 'ds18b20_t'::text) <> ''::text
	        )
	 SELECT sensor_values.datum,
	    sensor_values.hour,
	    sensor_values.minute,
	    count(*)::smallint AS observation_cnt,
	    round(avg(sensor_values.dht11_t), 1) AS dht11_t,
	    round(avg(sensor_values.dht11_h), 0) AS dht11_h,
	    round(avg(sensor_values.ds18b20_t), 1) AS ds18b20_t
	   FROM sensor_values
	  GROUP BY sensor_values.datum, sensor_values.hour, sensor_values.minute
	  ORDER BY sensor_values.datum, sensor_values.hour, sensor_values.minute
	  ;

	ALTER TABLE piws.observation DROP COLUMN sensor_id;

	ALTER TABLE piws.observation_minute DROP COLUMN sensor_id;



	CREATE OR REPLACE FUNCTION piws.load_minute_observations()
	 RETURNS boolean
	 LANGUAGE sql
	 SECURITY DEFINER
	 SET search_path TO 'piws, pg_temp'
	AS $function$


        WITH obs AS (
            SELECT o.observation_id
                FROM piws.observation o
                INNER JOIN public.calendar c ON o.calendar_id = c.calendar_id
                INNER JOIN public.time t ON o.time_id = t.time_id
                WHERE imported = False
                    -- Either older than today...
                    AND (c.datum != (NOW() AT TIME ZONE o.timezone)::DATE
                        OR ( -- or today, but not *this* minute
                            c.datum = (NOW() AT TIME ZONE o.timezone)::DATE
                                AND to_char(t.timeofday  + '2 minutes'::interval, 'HH24:MI') < to_char(NOW() AT TIME ZONE o.timezone, 'HH24:MI')
                        )
                    )
        ), obs_ds18b20_unflatten AS (

			SELECT observation_id, calendar_id, time_id, timezone,
				(observation_rows->>jsonb_object_keys(observation_rows))::NUMERIC AS sensor_value,
				jsonb_object_keys(observation_rows) AS node_unique_id,
				'ds18b20_t'::TEXT AS sensor_name
			    FROM (SELECT o.observation_id, o.calendar_id, o.time_id, o.timezone, 
					jsonb_array_elements(o.sensor_values -> 'ds18b20_t_uq') AS observation_rows
				    FROM piws.observation o
				    INNER JOIN obs a ON o.observation_id = a.observation_id
				    WHERE o.sensor_values ->> 'ds18b20_t_uq' IS NOT NULL
				)
				ds18b20_w_uq

        ), obs_detail AS (
            SELECT o.calendar_id, o.time_id, o.timezone,
                    'dht11_h'::TEXT AS sensor_name,
                    (o.sensor_values ->> 'dht11_h')::NUMERIC AS sensor_value,
                    NULL AS node_unique_id
                FROM obs a
                INNER JOIN piws.observation o ON a.observation_id = o.observation_id
            UNION
            SELECT o.calendar_id, o.time_id, o.timezone,
                    'dht11_t'::TEXT AS sensor_name,
                    (sensor_values ->> 'dht11_t')::NUMERIC AS sensor_value,
                    NULL AS node_unique_id
                FROM obs a
                INNER JOIN piws.observation o ON a.observation_id = o.observation_id
            UNION
            SELECT o.calendar_id, o.time_id, o.timezone,
                    'ds18b20_t'::TEXT AS sensor_name,
                    (o.sensor_values ->> 'ds18b20_t')::NUMERIC AS sensor_value,
                    NULL AS node_unique_id
                FROM obs a
                INNER JOIN piws.observation o ON a.observation_id = o.observation_id
                    AND (o.sensor_values ->> 'ds18b20_t')::NUMERIC != -127 -- Known bad sensor readings
            UNION 
            SELECT  o.calendar_id, o.time_id, o.timezone,
            		o.sensor_name, o.sensor_value,
            		o.node_unique_id
            	FROM obs a 
            	INNER JOIN obs_ds18b20_unflatten o ON a.observation_id = o.observation_id
            		AND o.sensor_value != -127 -- Known bad sensor reading
        ), minute_aggs AS (
        SELECT o.calendar_id,
                to_char(t.timeofday, 'HH24:MI') AS hhmm,
                o.timezone,
                o.sensor_name,
                o.node_unique_id,
                ROUND(AVG(o.sensor_value), 2) AS sensor_value
            FROM obs_detail o
            INNER JOIN public.calendar c ON o.calendar_id = c.calendar_id
            INNER JOIN public.time t ON o.time_id = t.time_id
           GROUP BY o.calendar_id,
                to_char(t.timeofday, 'HH24:MI'),
                o.timezone,
                o.sensor_name,
                o.node_unique_id
        )
        INSERT INTO piws.observation_minute (calendar_id, time_id, timezone, sensor_name, sensor_value, node_unique_id)
        SELECT a.calendar_id, t.time_id, a.timezone, a.sensor_name, a.sensor_value, a.node_unique_id
            FROM minute_aggs a
            INNER JOIN public.time t ON a.hhmm = to_char(t.timeofday, 'HH24:MI') AND t.second = 0
        ;


        -----------------------------------------
        -----------------------------------------
        -----------------------------------------

	    WITH minute_obs AS (
	        SELECT DISTINCT c.calendar_id, to_char(t.timeofday, 'HH24:MI') AS hhmm
	            FROM piws.observation_minute m
	            INNER JOIN public.time t ON m.time_id = t.time_id
	            INNER JOIN public.calendar c ON m.calendar_id = c.calendar_id
	    ), not_imported AS (
	        -- NOW to convert this to a format matching the above
	        SELECT o.observation_id, c.calendar_id, to_char(t.timeofday, 'HH24:MI') AS hhmm
	            FROM piws.observation o
	            INNER JOIN public.time t ON o.time_id = t.time_id
	            INNER JOIN public.calendar c ON o.calendar_id = c.calendar_id
	            WHERE imported = False
	    )
	    UPDATE piws.observation AS o
	        SET imported = True
	        FROM  not_imported n
	        INNER JOIN minute_obs m ON m.calendar_id = n.calendar_id AND m.hhmm = n.hhmm
	        WHERE o.observation_id = n.observation_id
	        ;


	    SELECT True;
	    $function$
	;



COMMIT;
