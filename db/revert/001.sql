-- Revert PiWS:001 from pg

BEGIN;

DROP SCHEMA piws CASCADE;
DROP SCHEMA sensor CASCADE;

COMMIT;
