-- Deploy piws:004 to pg

BEGIN;

    CREATE TABLE piws.api_quarterhour_submitted
    (
        api_quarterhour_submitted_id SERIAL NOT NULL PRIMARY KEY,
        end_15min TIMESTAMP WITH TIME ZONE NOT NULL
    );

    CREATE INDEX IX_piws_api_quarterhour_submitted_end_15min
        ON piws.api_quarterhour_submitted USING BRIN (end_15min);


    -----------------------------------
    -----------------------------------
    -----------------------------------


    CREATE FUNCTION piws.mark_quarterhour_submitted(end_15min TIMESTAMPTZ)
    RETURNS INT
    LANGUAGE 'sql'
    VOLATILE SECURITY DEFINER
    SET search_path='piws, pg_temp'

    AS $body$
        INSERT INTO piws.api_quarterhour_submitted(end_15min)
            VALUES (end_15min)
        RETURNING api_quarterhour_submitted_id

    $body$;


    -----------------------------------
    -----------------------------------
    -----------------------------------





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
              WHERE (vobservations.sensor_values ->> 'dht11_t'::text) <> ''::text
    				OR (vobservations.sensor_values ->> 'dht11_h'::text) <> ''::text
    				OR (vobservations.sensor_values ->> 'ds18b20_t'::text) <> ''::text
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
    	CASE WHEN aqs.end_15min IS NOT NULL THEN 1 ELSE 0 END AS submitted_to_api
       FROM sensor_values sv
       LEFT JOIN piws.api_quarterhour_submitted aqs
       		ON (((sv.end_15min || ' '::text) || sv.timezone)::timestamp with time zone) = aqs.end_15min
      GROUP BY sv.datum, sv.hour, sv.quarterhour, sv.end_15min, sv.timezone,
      	CASE WHEN aqs.end_15min IS NOT NULL THEN 1 ELSE 0 END
      ORDER BY sv.datum, sv.hour, sv.quarterhour;




CREATE OR REPLACE FUNCTION piws.quarterhour_json(
	)
    RETURNS TABLE(observation_data json)
    LANGUAGE 'sql'

    COST 100
    VOLATILE SECURITY DEFINER
    ROWS 10
    SET search_path='"ui, pg_temp"'
AS $BODY$

        SELECT row_to_json(r)
            FROM (SELECT *
                    FROM piws.vQuarterHourSummary
                    WHERE now() > end_15min
                        AND submitted_to_api = 0
                    ORDER BY datum ASC, quarterhour ASC
                    LIMIT 10
                ) r


$BODY$;


COMMIT;


