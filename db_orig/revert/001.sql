-- Revert piws:001 from pg

BEGIN;

DROP SCHEMA piws CASCADE;
DROP TABLE public.calendar;
DROP TABLE public.time;

COMMIT;
