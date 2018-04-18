-- Deploy piws:005 to pg
BEGIN;


    ALTER TABLE piws.observation ADD imported BOOLEAN NOT NULL DEFAULT False;

    ------------------------------------------
    ------------------------------------------
    ------------------------------------------


    CREATE TABLE piws.observation_minute
    (
        observation_minute_id SERIAL NOT NULL,
        sensor_id integer NOT NULL,
        calendar_id integer NOT NULL,
        time_id integer NOT NULL,
        sensor_name TEXT,
        sensor_value NUMERIC(12, 6)
    );

    ALTER TABLE piws.observation_minute ADD CONSTRAINT pk_observation_minute_id
        PRIMARY KEY (observation_minute_id);

    ALTER TABLE piws.observation_minute ADD CONSTRAINT fk_observation_minute_calendar_id
        FOREIGN KEY (calendar_id) REFERENCES public.calendar (calendar_id);

    ALTER TABLE piws.observation_minute ADD CONSTRAINT fk_observation_minute_time_id
        FOREIGN KEY (time_id) REFERENCES public."time" (time_id);

    ALTER TABLE piws.observation_minute ADD CONSTRAINT uq_observation_minute_
        UNIQUE (sensor_id, calendar_id, time_id, sensor_name);




    ------------------------------------------
    ------------------------------------------
    ------------------------------------------


    CREATE FUNCTION piws.load_minute_observations()
        RETURNS BOOLEAN
        LANGUAGE 'sql'
        VOLATILE SECURITY DEFINER
        SET search_path='piws, pg_temp'
        AS $BODY$


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
                                    AND to_char(t.timeofday, 'HH24:MI') <> to_char(NOW() AT TIME ZONE o.timezone, 'HH24:MI')
                            )
                        )

            ), obs_detail AS (
                SELECT o.sensor_id, o.calendar_id, o.time_id,
                        'dht11_h' AS sensor_name,
                        (o.sensor_values ->> 'dht11_h')::NUMERIC AS sensor_value
                    FROM obs a
                    INNER JOIN piws.observation o ON a.observation_id = o.observation_id
                UNION
                SELECT o.sensor_id, o.calendar_id, o.time_id,
                        'dht11_t' AS sensor_name,
                        (sensor_values ->> 'dht11_t')::NUMERIC AS sensor_value
                    FROM obs a
                    INNER JOIN piws.observation o ON a.observation_id = o.observation_id
                UNION
                SELECT o.sensor_id, o.calendar_id, o.time_id,
                        'ds18b20_t' AS sensor_name,
                        (o.sensor_values ->> 'ds18b20_t')::NUMERIC AS sensor_value
                    FROM obs a
                    INNER JOIN piws.observation o ON a.observation_id = o.observation_id
                        AND (o.sensor_values ->> 'ds18b20_t')::NUMERIC != -127 -- Known bad sensor readings
            ), minute_aggs AS (
            SELECT o.sensor_id, o.calendar_id,
                    to_char(t.timeofday, 'HH24:MI') AS hhmm,
                    o.sensor_name,
                    ROUND(AVG(o.sensor_value), 2) AS sensor_value
                FROM obs_detail o
                INNER JOIN public.calendar c ON o.calendar_id = c.calendar_id
                INNER JOIN public.time t ON o.time_id = t.time_id
               GROUP BY o.sensor_id, o.calendar_id,
                    to_char(t.timeofday, 'HH24:MI'),
                    o.sensor_name
            )
            INSERT INTO piws.observation_minute (sensor_id, calendar_id, time_id, sensor_name, sensor_value)
            SELECT a.sensor_id, a.calendar_id, t.time_id, a.sensor_name, a.sensor_value
                FROM minute_aggs a
                INNER JOIN public.time t ON a.hhmm = to_char(t.timeofday, 'HH24:MI') AND t.second = 0
                ORDER BY to_char(t.timeofday, 'HH24:MI') DESC
            ;



            SELECT True;
        $BODY$;


COMMIT;
