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



    CREATE INDEX ix_observation_minute_calendar_id
        ON piws.observation_minute (calendar_id);
    CREATE INDEX ix_observation_minute_time_id
        ON piws.observation_minute (time_id);



    ------------------------------------------
    ------------------------------------------
    ------------------------------------------



COMMIT;
