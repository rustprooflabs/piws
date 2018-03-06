-- Verify piws:003 on pg

BEGIN;


SELECT end_15min
    FROM piws.vQuarterHourSummary
    WHERE FALSE;


SELECT * FROM piws.quarterhour_json();

ROLLBACK;
