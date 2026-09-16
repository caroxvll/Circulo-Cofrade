-- Cofradero · comprobaciones tras desplegar calendario + OAuth
-- Ejecutar en SQL Editor (solo lectura; no modifica datos salvo la prueba opcional al final).

-- ═══════════════════════════════════════════════════════════════════════════
-- A) PRE-FLIGHT (antes de calendar_notify.sql)
-- ═══════════════════════════════════════════════════════════════════════════

select 'profiles' as check_name,
  exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'profiles'
  ) as ok;

select 'calendar_events' as check_name,
  exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'calendar_events'
  ) as ok;

select 'notification_preferences.notify_calendar' as check_name,
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notification_preferences'
      and column_name = 'notify_calendar'
  ) as ok;

select 'notify_pref_enabled (reactions)' as check_name,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'notify_pref_enabled'
      and pg_get_functiondef(p.oid) ilike '%reactions%'
  ) as ok;

-- ═══════════════════════════════════════════════════════════════════════════
-- B) POST calendar_notify.sql
-- ═══════════════════════════════════════════════════════════════════════════

select 'trigger on_calendar_published_notify_users' as check_name,
  exists (
    select 1 from pg_trigger
    where tgname = 'on_calendar_published_notify_users'
  ) as ok;

select 'notify_pref_enabled (calendar)' as check_name,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'notify_pref_enabled'
      and pg_get_functiondef(p.oid) ilike '%calendar%'
  ) as ok;

-- ═══════════════════════════════════════════════════════════════════════════
-- C) POST calendar_event_reminders.sql
-- ═══════════════════════════════════════════════════════════════════════════

select 'calendar_reminder_dispatches' as check_name,
  exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'calendar_reminder_dispatches'
  ) as ok;

select 'dispatch_calendar_event_reminders()' as check_name,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'dispatch_calendar_event_reminders'
  ) as ok;

-- pg_cron: ejecuta solo tras calendar_event_reminders_cron.sql
-- (si la extensión no está activa, esta consulta fallará — es normal antes del paso cron)
-- select jobname, schedule from cron.job
-- where jobname = 'dispatch-calendar-event-reminders';

-- ═══════════════════════════════════════════════════════════════════════════
-- D) POST google_oauth_profile.sql
-- ═══════════════════════════════════════════════════════════════════════════

select 'handle_new_user (Google avatar)' as check_name,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'handle_new_user'
      and pg_get_functiondef(p.oid) ilike '%picture%'
  ) as ok;

select 'on_auth_user_created trigger' as check_name,
  exists (
    select 1 from pg_trigger
    where tgname = 'on_auth_user_created'
  ) as ok;

-- ═══════════════════════════════════════════════════════════════════════════
-- E) PRUEBAS MANUALES (opcional)
-- ═══════════════════════════════════════════════════════════════════════════

-- Recordatorios: devuelve cuántas notificaciones insertó (0 si no hay eventos en ventana).
-- select public.dispatch_calendar_event_reminders();

-- Publicar evento de prueba (como admin/editor) y comprobar notificaciones type=calendar:
-- select id, user_id, type, title, created_at
-- from public.notifications
-- where type = 'calendar'
-- order by created_at desc
-- limit 10;
