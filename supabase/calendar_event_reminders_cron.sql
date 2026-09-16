-- Cofradero · programar recordatorios de calendario (pg_cron)
-- Ejecutar DESPUÉS de calendar_event_reminders.sql
--
-- 1. Supabase Dashboard → Database → Extensions → activar **pg_cron**
-- 2. Pega y ejecuta este script en SQL Editor

create extension if not exists pg_cron with schema extensions;

select cron.unschedule(jobid)
from cron.job
where jobname = 'dispatch-calendar-event-reminders';

select cron.schedule(
  'dispatch-calendar-event-reminders',
  '*/15 * * * *',
  $$ select public.dispatch_calendar_event_reminders(); $$
);

-- Comprobar que el job quedó registrado:
-- select jobid, jobname, schedule, command from cron.job
-- where jobname = 'dispatch-calendar-event-reminders';
