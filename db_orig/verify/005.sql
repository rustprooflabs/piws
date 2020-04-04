-- Verify piws:005 on pg

BEGIN;

    SELECT *
        FROM piws.observation_minute
        WHERE False
        ;


ROLLBACK;
