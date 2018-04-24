-- Revert piws:005 from pg

BEGIN;

    DROP VIEW piws.vQuarterHourSummary;

    DROP TABLE piws.observation_minute;

    DROP FUNCTION piws.load_minute_observations();

    ALTER TABLE piws.observation DROP COLUMN imported;

    ALTER TABLE piws.api_quarterhour_submitted DROP COLUMN sensor_name;


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





    --
    -- Type: VIEW ; Name: vquarterhoursummary; Owner: piws
    --



    CREATE OR REPLACE VIEW piws.vquarterhoursummary AS
     WITH sensor_values AS (
             SELECT vobservations.datum,
                vobservations.hour,
                vobservations.quarterhour,
                ((vobservations.datum || ' '::text) || "right"(vobservations.quarterhour, 5))::timestamp without time zone AS end_15min,
                vobservations.timezone,
                (vobservations.sensor_values ->> 'dht11_t'::text)::numeric AS dht11_t,
                (vobservations.sensor_values ->> 'dht11_h'::text)::numeric AS dht11_h,
                (vobservations.sensor_values ->> 'ds18b20_t'::text)::numeric AS ds18b20_t
               FROM vobservations
              WHERE (vobservations.sensor_values ->> 'dht11_t'::text) <> ''::text OR (vobservations.sensor_values ->> 'dht11_h'::text) <> ''::text OR (vobservations.sensor_values ->> 'ds18b20_t'::text) <> ''::text
            )
     SELECT sv.datum,
        sv.hour,
        sv.quarterhour,
        count(*)::smallint AS observation_cnt,
        round(avg(sv.dht11_t), 1) AS dht11_t,
        round(avg(sv.dht11_h), 0) AS dht11_h,
        round(avg(sv.ds18b20_t), 1) AS ds18b20_t,
        ((sv.end_15min || ' '::text) || sv.timezone)::timestamp with time zone AS end_15min,
        sv.timezone,
            CASE
                WHEN aqs.end_15min IS NOT NULL THEN 1
                ELSE 0
            END AS submitted_to_api
       FROM sensor_values sv
         LEFT JOIN piws.api_quarterhour_submitted aqs ON (((sv.end_15min || ' '::text) || sv.timezone)::timestamp with time zone) = aqs.end_15min
      GROUP BY sv.datum, sv.hour, sv.quarterhour, sv.end_15min, sv.timezone, (
            CASE
                WHEN aqs.end_15min IS NOT NULL THEN 1
                ELSE 0
            END)
      ORDER BY sv.datum, sv.hour, sv.quarterhour;



DROP FUNCTION piws.mark_quarterhour_submitted(timestamp with time zone, text);

CREATE OR REPLACE FUNCTION piws.mark_quarterhour_submitted(end_15min timestamp with time zone)
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO "piws, pg_temp"
AS $function$
        INSERT INTO piws.api_quarterhour_submitted(end_15min)
            VALUES (end_15min)
        RETURNING api_quarterhour_submitted_id

    $function$
;




COMMIT;
