-- Revert piws:005 from pg

BEGIN;

    DROP TABLE piws.observation_minute;

    DROP FUNCTION piws.load_minute_observations();

    ALTER TABLE piws.observation DROP COLUMN imported;


    CREATE OR REPLACE FUNCTION piws.insert_observation(sensor_id integer, obs_date date, obs_time time without time zone, tzone text, sensor_values jsonb)
         RETURNS integer
         LANGUAGE sql
         SECURITY DEFINER
         SET search_path TO piws, pg_temp
        AS $function$

            INSERT INTO piws.observation (sensor_id, calendar_id, time_id, timezone, sensor_values)
                SELECT sensor_id, c.calendar_id, t.time_id, tzone, sensor_values
                FROM public.calendar c
                INNER JOIN public.time t ON t.timeofday = obs_time
                WHERE c.datum = obs_date

                RETURNING observation_id

        $function$;


COMMIT;
