-- Asegura que DELETE de reacciones traiga el emoji en Realtime.
-- Sin FULL, oldRecord solo trae la PK y la otra sesión no puede restar el contador.
-- Idempotente.

alter table public.ss_live_update_likes replica identity full;
alter table public.ss_live_update_replies replica identity full;
