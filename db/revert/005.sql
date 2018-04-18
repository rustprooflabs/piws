-- Revert piws:005 from pg

BEGIN;

    DROP TABLE piws.observation_minute;

    DROP FUNCTION piws.load_minute_observations();
COMMIT;
