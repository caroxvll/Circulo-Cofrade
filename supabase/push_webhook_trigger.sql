-- Cofradeo · ANTES usaba 1 HTTP a send-push por cada fila de notifications.
-- Sustituido por push_delivery_queue.sql (cola + drain-push).
--
-- Si aún tienes este trigger activo, ejecuta push_delivery_queue.sql:
-- quita notifications_send_push y monta la cola.
--
-- NO ejecutes este archivo en proyectos nuevos.
-- Se deja solo como referencia histórica / rollback de emergencia.

create extension if not exists pg_net with schema extensions;

-- Rollback de emergencia (NO recomendado si ya usas la cola):
-- drop trigger if exists notifications_enqueue_push on public.notifications;
-- Luego descomenta el bloque antiguo de send-push directo...
--
-- create or replace function public.trigger_send_push_notification() ...
-- Ver historial git si hace falta el cuerpo exacto.

select 'Usa supabase/push_delivery_queue.sql + functions/drain-push' as aviso;
