-- Deploy piws:003 to pg

BEGIN;

    CREATE OR REPLACE VIEW piws.vQuarterHourSummary
    AS
    WITH sensor_values AS (
    SELECT datum, hour, quarterhour,
            (datum || ' ' || RIGHT(quarterhour, 5))::TIMESTAMP AS end_15min,
            timezone,
            (sensor_values ->> 'dht11_t')::NUMERIC AS dht11_t,
            (sensor_values ->> 'dht11_h')::NUMERIC AS dht11_h,
            (sensor_values ->> 'ds18b20_t')::NUMERIC AS ds18b20_t
        FROM piws.vObservations
        WHERE sensor_values ->> 'dht11_t' <> ''
            OR sensor_values ->> 'dht11_h' <> ''
            OR sensor_values ->> 'ds18b20_t' <> ''
    )
    SELECT sv.datum, sv.hour, sv.quarterhour,
            COUNT(*)::SMALLINT AS observation_cnt,
            ROUND(AVG(sv.dht11_t), 1) AS dht11_t,
            ROUND(AVG(sv.dht11_h), 0) AS dht11_h,
            ROUND(AVG(sv.ds18b20_t), 1) AS ds18b20_t,
             (sv.end_15min || ' ' || sv.timezone)::TIMESTAMP WITH TIME ZONE AS end_15min,
           sv.timezone
        FROM sensor_values sv
        GROUP BY sv.datum, sv.hour, sv.quarterhour, sv.end_15min, sv.timezone
        ORDER BY sv.datum, sv.hour, sv.quarterhour
    ;



    ---------------------------------------------


    CREATE FUNCTION piws.quarterhour_json()
    RETURNS TABLE (observation_data JSON)
    LANGUAGE 'sql'
    VOLATILE SECURITY DEFINER
    ROWS 10
    SET search_path='ui, pg_temp'

    AS $body$

        SELECT row_to_json(r)
            FROM (SELECT *
                    FROM piws.vQuarterHourSummary
                    WHERE now() > end_15min
                    ORDER BY datum ASC, quarterhour ASC
                    LIMIT 10
                ) r

    $body$;

COMMIT;
