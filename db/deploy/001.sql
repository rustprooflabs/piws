-- Deploy piws:001 to pg

BEGIN;


    CREATE SCHEMA piws;


    -------------------------------------------------
    -------------------------------------------------
    -------------------------------------------------

    /*
    Original source for calendar table generation came from
    The PostgreSQL wiki:  https://wiki.postgresql.org/wiki/Date_and_Time_dimensions

    Modified by RustProof Labs
    */

    CREATE TABLE public.calendar
    AS

    SELECT DAY + 1 AS calendar_id,
            datum,
            EXTRACT(YEAR FROM datum)::INT AS YEAR,
            EXTRACT(MONTH FROM datum)::SMALLINT AS MONTH,

            to_char(datum, 'TMMonth') AS MonthName,
            EXTRACT(DAY FROM datum)::SMALLINT AS DAY,
            EXTRACT(doy FROM datum)::INT AS DayOfYear,

            to_char(datum, 'TMDay') AS WeekdayName,

            EXTRACT(week FROM datum)::SMALLINT AS CalendarWeek,
            to_char(datum, 'dd/mm/yyyy') AS FormattedDate,
            'Q' || to_char(datum, 'Q') AS Quartal,
            to_char(datum, 'yyyy/"Q"Q') AS YearQuartal,
            to_char(datum, 'yyyy/mm') AS YearMonth,

            to_char(datum, 'iyyy/IW') AS YearCalendarWeek,

            CASE WHEN EXTRACT(isodow FROM datum) IN (6, 7) THEN 'Weekend' ELSE 'Weekday' END AS Weekend,

            -- ISO start and end of the week of this date
            datum + (1 - EXTRACT(isodow FROM datum))::INTEGER AS CWStart,
            datum + (7 - EXTRACT(isodow FROM datum))::INTEGER AS CWEnd,
            -- Start and end of the month of this date
            datum + (1 - EXTRACT(DAY FROM datum))::INTEGER AS MonthStart,
                (
                (datum + (1 - EXTRACT(DAY FROM datum))::INTEGER + '1 month'::INTERVAL)::DATE - '1 day'::INTERVAL
                )::DATE AS MonthEnd
            FROM (
                SELECT '2018-01-01'::DATE + SEQUENCE.DAY AS datum,
                    SEQUENCE.DAY
                FROM generate_series(0, 28400) AS SEQUENCE(DAY)
                GROUP BY SEQUENCE.DAY
             ) dq
    ORDER BY 1
    ;

    ALTER TABLE public.calendar
        ADD CONSTRAINT PK_calendar_id PRIMARY KEY (calendar_id);

    -------------------------------------------------
    -------------------------------------------------
    -------------------------------------------------

    CREATE TABLE public.time
    AS
    SELECT -- Minute of the day (1 - 1440)
            ROW_NUMBER() OVER(
                ORDER BY MINUTE
            )::INT AS time_id,
            to_char(MINUTE, 'hh24:mi:ss')::TIME AS TimeOfDay,
            EXTRACT(HOUR FROM MINUTE)::SMALLINT AS HOUR,
            EXTRACT(MINUTE FROM MINUTE)::SMALLINT AS MINUTE,
            EXTRACT(SECOND FROM MINUTE)::SMALLINT AS SECOND,
            -- Extract and format quarter hours
            to_char(MINUTE - (EXTRACT(MINUTE FROM MINUTE)::INTEGER % 15 || 'minutes')::INTERVAL, 'hh24:mi') ||
            ' – ' ||
            to_char(MINUTE - (EXTRACT(MINUTE FROM MINUTE)::INTEGER % 15 || 'minutes')::INTERVAL + '14 minutes'::INTERVAL, 'hh24:mi')
                AS QuarterHour,

            -- Names of day periods
            CASE WHEN to_char(MINUTE, 'hh24:mi') BETWEEN '05:00' AND '08:29'
                THEN 'Early Morning'
                 WHEN to_char(MINUTE, 'hh24:mi') BETWEEN '08:30' AND '11:59'
                THEN 'Morning'
                 WHEN to_char(MINUTE, 'hh24:mi') BETWEEN '12:00' AND '17:59'
                THEN 'Afternoon'
                 WHEN to_char(MINUTE, 'hh24:mi') BETWEEN '18:00' AND '22:29'
                THEN 'Evening'
                 ELSE 'Night'
            END AS DaytimeName,
            -- Indicator of day or night
            CASE WHEN to_char(MINUTE, 'hh24:mi') BETWEEN '07:00' AND '19:59' THEN 'Day'
                 ELSE 'Night'
            END AS DayNight
        FROM (SELECT '0:00:00'::TIME + (SEQUENCE.MINUTE || ' seconds')::INTERVAL AS MINUTE
            --FROM generate_series(0,1439) AS SEQUENCE(minute_)
            FROM generate_series(0,86399) AS SEQUENCE(MINUTE)
            GROUP BY SEQUENCE.MINUTE
             ) DQ
        ORDER BY 1
        ;



    ALTER TABLE public.time
        ADD CONSTRAINT PK_time_id PRIMARY KEY (time_id);
    -------------------------------------------------
    -------------------------------------------------
    -------------------------------------------------

    CREATE TABLE piws.observation
    (
        observation_id SERIAL NOT NULL,
        sensor_id INT NOT NULL,
        calendar_id INT NOT NULL,
        time_id INT NOT NULL,
        timezone TEXT NOT NULL,
        sensor_values JSONB NOT NULL,
        CONSTRAINT PK_observation_id PRIMARY KEY (observation_id),
        CONSTRAINT FK_observation_calendar_id
            FOREIGN KEY (calendar_id) REFERENCES public.calendar (calendar_id),
        CONSTRAINT FK_observation_time_id
            FOREIGN KEY (time_id) REFERENCES public.time (time_id)
    );

    -------------------------------------------------
    -------------------------------------------------
    -------------------------------------------------

    CREATE FUNCTION piws.insert_observation (sensor_id INT, obs_date DATE, obs_time TIME, tzone TEXT, sensor_values JSONB)
    RETURNS INT LANGUAGE SQL
    AS $$

        INSERT INTO piws.observation (sensor_id, calendar_id, time_id, timezone, sensor_values)
            SELECT sensor_id, c.calendar_id, t.time_id, tzone, sensor_values
            FROM public.calendar c
            INNER JOIN public.time t ON t.timeofday = obs_time
            WHERE c.datum = obs_date

            RETURNING observation_id

    $$
        SECURITY DEFINER
        SET search_path = piws, pg_temp;

    -------------------------------------------------
    -------------------------------------------------
    -------------------------------------------------
    CREATE VIEW piws.vObservations
    AS

    SELECT (c.datum + t.timeofday)::TIMESTAMP AS tstamp, c.datum, c.formatteddate,
                      c.year, c.month,
            t.timeofday, t.hour, t.minute, t.daytimename, t.daynight,
            t.quarterhour,
            o.timezone, o.sensor_id, o.sensor_values
        FROM piws.observation o
        INNER JOIN public.calendar c ON o.calendar_id = c.calendar_id
        INNER JOIN public.time t ON o.time_id = t.time_id
    ;
    -------------------------------------------------
    -------------------------------------------------
    -------------------------------------------------
    CREATE VIEW piws.vMinuteSummary
    AS
    WITH sensor_values AS (
    SELECT datum, hour, minute,
            (sensor_values ->> 'dht11_t')::NUMERIC AS dht11_t,
            (sensor_values ->> 'dht11_h')::NUMERIC AS dht11_h,
            (sensor_values ->> 'ds18b20_t')::NUMERIC AS ds18b20_t
        FROM piws.vObservations
        WHERE sensor_values ->> 'dht11_t' <> ''
            OR sensor_values ->> 'dht11_h' <> ''
            OR sensor_values ->> 'ds18b20_t' <> ''
    )
    SELECT datum, hour, minute,
            COUNT(*)::SMALLINT AS observation_cnt,
            ROUND(AVG(dht11_t), 1) AS dht11_t,
            ROUND(AVG(dht11_h), 0) AS dht11_h,
            ROUND(AVG(ds18b20_t), 1) AS ds18b20_t
        FROM sensor_values
        GROUP BY datum, hour, minute
        ORDER BY datum, hour, minute
    ;


    -------------------------------------------------
    -------------------------------------------------
    -------------------------------------------------
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


    -------------------------------------------------
    -------------------------------------------------
    -------------------------------------------------


COMMIT;
