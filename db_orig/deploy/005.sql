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
        timezone TEXT NOT NULL,
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
                                    AND to_char(t.timeofday  + '2 minutes'::interval, 'HH24:MI') < to_char(NOW() AT TIME ZONE o.timezone, 'HH24:MI')
                            )
                        )
            ), obs_detail AS (
                SELECT o.sensor_id, o.calendar_id, o.time_id, o.timezone,
                        'dht11_h' AS sensor_name,
                        (o.sensor_values ->> 'dht11_h')::NUMERIC AS sensor_value
                    FROM obs a
                    INNER JOIN piws.observation o ON a.observation_id = o.observation_id
                UNION
                SELECT o.sensor_id, o.calendar_id, o.time_id, o.timezone,
                        'dht11_t' AS sensor_name,
                        (sensor_values ->> 'dht11_t')::NUMERIC AS sensor_value
                    FROM obs a
                    INNER JOIN piws.observation o ON a.observation_id = o.observation_id
                UNION
                SELECT o.sensor_id, o.calendar_id, o.time_id, o.timezone,
                        'ds18b20_t' AS sensor_name,
                        (o.sensor_values ->> 'ds18b20_t')::NUMERIC AS sensor_value
                    FROM obs a
                    INNER JOIN piws.observation o ON a.observation_id = o.observation_id
                        AND (o.sensor_values ->> 'ds18b20_t')::NUMERIC != -127 -- Known bad sensor readings
            ), minute_aggs AS (
            SELECT o.sensor_id, o.calendar_id,
                    to_char(t.timeofday, 'HH24:MI') AS hhmm,
                    o.timezone,
                    o.sensor_name,
                    ROUND(AVG(o.sensor_value), 2) AS sensor_value
                FROM obs_detail o
                INNER JOIN public.calendar c ON o.calendar_id = c.calendar_id
                INNER JOIN public.time t ON o.time_id = t.time_id
               GROUP BY o.sensor_id, o.calendar_id,
                    to_char(t.timeofday, 'HH24:MI'),
                    o.timezone,
                    o.sensor_name
            )
            INSERT INTO piws.observation_minute (sensor_id, calendar_id, time_id, timezone, sensor_name, sensor_value)
            SELECT a.sensor_id, a.calendar_id, t.time_id, a.timezone, a.sensor_name, a.sensor_value
                FROM minute_aggs a
                INNER JOIN public.time t ON a.hhmm = to_char(t.timeofday, 'HH24:MI') AND t.second = 0

            ;


            -----------------------------------------
            -----------------------------------------
            -----------------------------------------

        WITH minute_obs AS (
            SELECT DISTINCT m.sensor_id, c.calendar_id, to_char(t.timeofday, 'HH24:MI') AS hhmm, t.hour, t.minute
                FROM piws.observation_minute m
                INNER JOIN public.time t ON m.time_id = t.time_id
                INNER JOIN public.calendar c ON m.calendar_id = c.calendar_id
        ), not_imported AS (
            -- NOW to convert this to a format matching the above
            SELECT o.observation_id, c.calendar_id, to_char(t.timeofday, 'HH24:MI') AS hhmm, t.hour, t.minute
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
        $BODY$;


------------------------------------------------
------------------------------------------------
------------------------------------------------



    CREATE OR REPLACE FUNCTION piws.insert_observation(sensor_id integer, obs_date date, obs_time time without time zone, tzone text, sensor_values jsonb)
         RETURNS integer
         LANGUAGE sql
         SECURITY DEFINER
         SET search_path TO 'piws, pg_temp'
        AS $function$

            SELECT * FROM piws.load_minute_observations();

            INSERT INTO piws.observation (sensor_id, calendar_id, time_id, timezone, sensor_values)
                SELECT sensor_id, c.calendar_id, t.time_id, tzone, sensor_values
                FROM public.calendar c
                INNER JOIN public.time t ON t.timeofday = obs_time
                WHERE c.datum = obs_date

                RETURNING observation_id

        $function$;


------------------------------------------------
------------------------------------------------
------------------------------------------------

    ALTER TABLE piws.api_quarterhour_submitted ADD sensor_name TEXT;

    UPDATE piws.api_quarterhour_submitted
        SET sensor_name = ''
        WHERE sensor_name IS NULL;

    ALTER TABLE piws.api_quarterhour_submitted
        ALTER COLUMN sensor_name
        SET NOT NULL;

    ALTER TABLE piws.api_quarterhour_submitted
        ADD CONSTRAINT UQ_piws_api_quarterhour_submitted_end_15min_sensor_name
        UNIQUE (end_15min, sensor_name);

------------------------------------------------
------------------------------------------------
------------------------------------------------


    DROP VIEW piws.vQuarterHourSummary;



    CREATE VIEW piws.vQuarterHourSummary AS
    WITH values AS (
        SELECT c.datum, t.hour, t.quarterhour, m.sensor_name, m.timezone,
                ((c.datum || ' '::text) || "right"(t.quarterhour, 5))::timestamp without time zone AS end_15min,
                ROUND(AVG(m.sensor_value),2) AS sensor_value
            FROM piws.observation_minute m
            INNER JOIN public.time t ON m.time_id = t.time_id
            INNER JOIN public.calendar c ON m.calendar_id = c.calendar_id
            GROUP BY c.datum,t.hour, t.quarterhour, sensor_name, m.timezone,
                ((c.datum || ' '::text) || "right"(t.quarterhour, 5))::timestamp without time zone
    )
    SELECT v.*,
            CASE
                WHEN aqs.end_15min IS NOT NULL THEN 1
                ELSE 0
            END AS submitted_to_api
        FROM values v
        LEFT JOIN piws.api_quarterhour_submitted aqs
            ON v.end_15min = aqs.end_15min
                AND v.sensor_name = aqs.sensor_name
        ORDER BY datum DESC, quarterhour DESC
        ;





DROP FUNCTION piws.mark_quarterhour_submitted(timestamp with time zone);

CREATE OR REPLACE FUNCTION piws.mark_quarterhour_submitted(
    end_15min timestamp with time zone,
    sensor_name TEXT
    )
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'piws, pg_temp'
AS $function$
        INSERT INTO piws.api_quarterhour_submitted(end_15min, sensor_name)
            VALUES (end_15min, sensor_name)
        RETURNING api_quarterhour_submitted_id

    $function$
;


COMMIT;
