-- Cofradero · disparar push al insertar en notifications (sin Dashboard Webhooks)
-- Usar si al crear el webhook sale: schema "supabase_functions" does not exist
-- Ejecutar en SQL Editor (una sola vez).

create extension if not exists pg_net with schema extensions;

create or replace function public.trigger_send_push_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://dcsxgppprfedrsrtbatx.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'notifications',
      'record', jsonb_build_object(
        'user_id', new.user_id,
        'type', new.type,
        'title', new.title,
        'subtitle', new.subtitle,
        'payload', coalesce(new.payload, '{}'::jsonb)
      )
    )
  );
  return new;
end;
$$;

drop trigger if exists notifications_send_push on public.notifications;
create trigger notifications_send_push
  after insert on public.notifications
  for each row
  execute function public.trigger_send_push_notification();
