-- Deploy piws:007 to pg

BEGIN;

	ALTER TABLE piws.observation_minute ADD node_unique_id TEXT NULL;

    ALTER TABLE piws.observation_minute 
        DROP CONSTRAINT uq_observation_minute_datetime_sensor;
    
    ALTER TABLE piws.observation_minute 
        ADD CONSTRAINT uq_observation_minute_datetime_sensor_with_id
        UNIQUE (sensor_id, calendar_id, time_id, sensor_name, node_unique_id);





	CREATE OR REPLACE FUNCTION piws.load_minute_observations()
	 RETURNS boolean
	 LANGUAGE sql
	 SECURITY DEFINER
	 SET search_path TO "piws, pg_temp"
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

			SELECT observation_id, sensor_id, calendar_id, time_id, timezone,
				(observation_rows->>jsonb_object_keys(observation_rows))::NUMERIC AS sensor_value,
				jsonb_object_keys(observation_rows) AS node_unique_id,
				'ds18b20_t'::TEXT AS sensor_name
			    FROM (SELECT o.observation_id, o.sensor_id, o.calendar_id, o.time_id, o.timezone, 
					jsonb_array_elements(o.sensor_values -> 'ds18b20_t_uq') AS observation_rows
				    FROM piws.observation o
				    INNER JOIN obs a ON o.observation_id = a.observation_id
				    WHERE o.sensor_values ->> 'ds18b20_t_uq' IS NOT NULL
				)
				ds18b20_w_uq

        ), obs_detail AS (
            SELECT o.sensor_id, o.calendar_id, o.time_id, o.timezone,
                    'dht11_h'::TEXT AS sensor_name,
                    (o.sensor_values ->> 'dht11_h')::NUMERIC AS sensor_value,
                    NULL AS node_unique_id
                FROM obs a
                INNER JOIN piws.observation o ON a.observation_id = o.observation_id
            UNION
            SELECT o.sensor_id, o.calendar_id, o.time_id, o.timezone,
                    'dht11_t'::TEXT AS sensor_name,
                    (sensor_values ->> 'dht11_t')::NUMERIC AS sensor_value,
                    NULL AS node_unique_id
                FROM obs a
                INNER JOIN piws.observation o ON a.observation_id = o.observation_id
            UNION
            SELECT o.sensor_id, o.calendar_id, o.time_id, o.timezone,
                    'ds18b20_t'::TEXT AS sensor_name,
                    (o.sensor_values ->> 'ds18b20_t')::NUMERIC AS sensor_value,
                    NULL AS node_unique_id
                FROM obs a
                INNER JOIN piws.observation o ON a.observation_id = o.observation_id
                    AND (o.sensor_values ->> 'ds18b20_t')::NUMERIC != -127 -- Known bad sensor readings
            UNION 
            SELECT  o.sensor_id, o.calendar_id, o.time_id, o.timezone,
            		o.sensor_name, o.sensor_value,
            		o.node_unique_id
            	FROM obs a 
            	INNER JOIN obs_ds18b20_unflatten o ON a.observation_id = o.observation_id
            		AND o.sensor_value != -127 -- Known bad sensor reading
        ), minute_aggs AS (
        SELECT o.sensor_id, o.calendar_id,
                to_char(t.timeofday, 'HH24:MI') AS hhmm,
                o.timezone,
                o.sensor_name,
                o.node_unique_id,
                ROUND(AVG(o.sensor_value), 2) AS sensor_value
            FROM obs_detail o
            INNER JOIN public.calendar c ON o.calendar_id = c.calendar_id
            INNER JOIN public.time t ON o.time_id = t.time_id
           GROUP BY o.sensor_id, o.calendar_id,
                to_char(t.timeofday, 'HH24:MI'),
                o.timezone,
                o.sensor_name,
                o.node_unique_id
        )
        INSERT INTO piws.observation_minute (sensor_id, calendar_id, time_id, timezone, sensor_name, sensor_value, node_unique_id)
        SELECT a.sensor_id, a.calendar_id, t.time_id, a.timezone, a.sensor_name, a.sensor_value, a.node_unique_id
            FROM minute_aggs a
            INNER JOIN public.time t ON a.hhmm = to_char(t.timeofday, 'HH24:MI') AND t.second = 0
        ON CONFLICT (sensor_id, calendar_id, time_id, sensor_name, node_unique_id)
            DO
            UPDATE
                SET sensor_value = EXCLUDED.sensor_value
        ;


        -----------------------------------------
        -----------------------------------------
        -----------------------------------------

	    WITH minute_obs AS (
	        SELECT DISTINCT m.sensor_id, c.calendar_id, to_char(t.timeofday, 'HH24:MI') AS hhmm
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



    ------------------------------------------
    -----------------------------------------
    -- Remove the old constraint looking at just two columns
    ALTER TABLE piws.api_quarterhour_submitted
        DROP CONSTRAINT  "uq_piws_api_quarterhour_submitted_end_15min_sensor_name"
    ;

    -- Add new column and updated UNIQUE index
    ALTER TABLE piws.api_quarterhour_submitted
        ADD node_unique_id TEXT NULL;
    ALTER TABLE piws.api_quarterhour_submitted
        ADD CONSTRAINT  "uq_piws_api_quarterhour_submitted_end_15min_unique_sensor"
        UNIQUE (end_15min, sensor_name, node_unique_id)
    ;





    -----------------------------------------------
    DROP VIEW piws.vquarterhoursummary;
    CREATE VIEW piws.vquarterhoursummary AS
     WITH "values" AS (
             SELECT c.datum,
                t.hour,
                t.quarterhour,
                m.sensor_name,
                m.timezone,
                ((c.datum || ' '::text) || "right"(t.quarterhour, 5))::timestamp without time zone AS end_15min,
                round(avg(m.sensor_value), 2) AS sensor_value,
                m.node_unique_id
               FROM observation_minute m
                 JOIN "time" t ON m.time_id = t.time_id
                 JOIN calendar c ON m.calendar_id = c.calendar_id
              GROUP BY c.datum, t.hour, t.quarterhour, m.sensor_name, m.timezone, (((c.datum || ' '::text) || "right"(t.quarterhour, 5))::timestamp without time zone),
                m.node_unique_id
            )
     SELECT v.datum,
        v.hour,
        v.quarterhour,
        v.sensor_name,
        v.node_unique_id,
        v.timezone,
        v.end_15min,
        v.sensor_value,
            CASE
                WHEN aqs.end_15min IS NOT NULL THEN 1
                ELSE 0
            END AS submitted_to_api
       FROM "values" v
         LEFT JOIN piws.api_quarterhour_submitted aqs 
            ON v.end_15min = aqs.end_15min AND v.sensor_name = aqs.sensor_name
               AND COALESCE(v.node_unique_id, '') = COALESCE(aqs.node_unique_id, '')
      ORDER BY v.datum DESC, v.quarterhour DESC
      ;




    CREATE FUNCTION piws.mark_quarterhour_submitted(
        end_15min timestamp with time zone, sensor_name text, node_unique_id TEXT)
     RETURNS integer
     LANGUAGE sql
     SECURITY DEFINER
     SET search_path TO "piws, pg_temp"
    AS $function$
            INSERT INTO piws.api_quarterhour_submitted(end_15min, sensor_name, node_unique_id)
                VALUES (end_15min, sensor_name, node_unique_id)
            RETURNING api_quarterhour_submitted_id

        $function$
    ;


COMMIT;
