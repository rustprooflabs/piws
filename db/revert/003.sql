-- Revert piws:003 from pg

BEGIN;

    DROP VIEW piws.vQuarterHourSummary;


    CREATE VIEW piws.vQuarterHourSummary
    AS
    WITH sensor_values AS (
    SELECT datum, hour, quarterhour,
            (sensor_values ->> 'dht11_t')::NUMERIC AS dht11_t,
            (sensor_values ->> 'dht11_h')::NUMERIC AS dht11_h,
            (sensor_values ->> 'ds18b20_t')::NUMERIC AS ds18b20_t
        FROM piws.vObservations
        WHERE sensor_values ->> 'dht11_t' <> ''
            OR sensor_values ->> 'dht11_h' <> ''
            OR sensor_values ->> 'ds18b20_t' <> ''
    )
    SELECT datum, hour, quarterhour,
            COUNT(*)::SMALLINT AS observation_cnt,
            ROUND(AVG(dht11_t), 1) AS dht11_t,
            ROUND(AVG(dht11_h), 0) AS dht11_h,
            ROUND(AVG(ds18b20_t), 1) AS ds18b20_t
        FROM sensor_values
        GROUP BY datum, hour, quarterhour
        ORDER BY datum, hour, quarterhour
    ;


    DROP FUNCTION piws.quarterhour_json();

COMMIT;
