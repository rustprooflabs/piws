-- Verify piws:004 on pg

BEGIN;


SELECT end_15min
    FROM piws.api_quarterhour_submitted
    WHERE FALSE;

ROLLBACK;
