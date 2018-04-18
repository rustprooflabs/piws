-- Revert piws:005 from pg

BEGIN;

    DROP TABLE piws.observation_minute;

COMMIT;
