-- Cofradero · recordatorios de eventos del calendario (24 h y 1 h antes)
-- Ejecutar después de calendar_notify.sql y event_bookmarks.sql
--
-- Requiere extensión pg_cron (Supabase → Database → Extensions → pg_cron)

-- ---------------------------------------------------------------------------
-- Control de envíos (evita duplicados)
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_reminder_dispatches (
  user_id uuid not null references public.profiles (id) on delete cascade,
  event_id uuid not null references public.calendar_events (id) on delete cascade,
  reminder_kind text not null check (reminder_kind in ('24h', '1h')),
  sent_at timestamptz not null default now(),
  primary key (user_id, event_id, reminder_kind)
);

create index if not exists calendar_reminder_dispatches_event_idx
  on public.calendar_reminder_dispatches (event_id);

alter table public.calendar_reminder_dispatches enable row level security;

-- Solo uso interno (triggers/cron); la app no necesita leer esta tabla.
drop policy if exists "Sin acceso cliente a dispatches" on public.calendar_reminder_dispatches;
create policy "Sin acceso cliente a dispatches"
  on public.calendar_reminder_dispatches for all
  using (false)
  with check (false);

-- ---------------------------------------------------------------------------
-- Envía recordatorios pendientes
-- ---------------------------------------------------------------------------
create or replace function public.dispatch_calendar_event_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event record;
  v_kind text;
  v_title text;
  v_window_start interval;
  v_window_end interval;
  v_inserted integer := 0;
  v_batch integer;
begin
  perform set_config('row_security', 'off', true);

  foreach v_kind in array array['24h', '1h'] loop
    if v_kind = '24h' then
      v_window_start := interval '23 hours';
      v_window_end := interval '24 hours';
      v_title := 'Mañana en el calendario';
    else
      v_window_start := interval '55 minutes';
      v_window_end := interval '65 minutes';
      v_title := 'Empieza pronto';
    end if;

    for v_event in
      select
        e.id,
        e.title,
        e.event_type,
        e.starts_at,
        e.organizer_label
      from public.calendar_events e
      where coalesce(e.status, 'published') = 'published'
        and e.starts_at > now()
        and e.starts_at > now() + v_window_start
        and e.starts_at <= now() + v_window_end
    loop
      with recipients as (
        select p.id as user_id
        from public.profiles p
        where p.suspended_at is null
          and public.notify_pref_enabled(p.id, 'calendar')
          and not exists (
            select 1
            from public.calendar_reminder_dispatches d
            where d.user_id = p.id
              and d.event_id = v_event.id
              and d.reminder_kind = v_kind
          )
      ),
      inserted as (
        insert into public.notifications (user_id, type, title, subtitle, payload)
        select
          r.user_id,
          'calendar',
          v_title,
          left(v_event.title, 80),
          jsonb_build_object(
            'route', '/calendario',
            'eventId', v_event.id::text,
            'eventType', v_event.event_type,
            'startsAt', v_event.starts_at,
            'organizerLabel', v_event.organizer_label,
            'reminderKind', v_kind
          )
        from recipients r
        returning user_id
      ),
      logged as (
        insert into public.calendar_reminder_dispatches (
          user_id, event_id, reminder_kind
        )
        select user_id, v_event.id, v_kind
        from inserted
        returning 1
      )
      select count(*)::integer into v_batch from logged;

      v_inserted := v_inserted + coalesce(v_batch, 0);
    end loop;
  end loop;

  return v_inserted;
end;
$$;

-- ---------------------------------------------------------------------------
-- pg_cron: ejecutar cada 15 minutos
-- ---------------------------------------------------------------------------
-- Descomenta tras activar la extensión pg_cron en el dashboard:
--
-- create extension if not exists pg_cron with schema extensions;
--
-- select cron.unschedule('dispatch-calendar-event-reminders')
-- where exists (
--   select 1 from cron.job where jobname = 'dispatch-calendar-event-reminders'
-- );
--
-- select cron.schedule(
--   'dispatch-calendar-event-reminders',
--   '*/15 * * * *',
--   $$ select public.dispatch_calendar_event_reminders(); $$
-- );
--
-- Prueba manual:
-- select public.dispatch_calendar_event_reminders();
