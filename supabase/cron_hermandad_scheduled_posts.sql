-- Publica posts programados de hermandad cada minuto.
-- Idempotente: si el job ya existe, no falla.

do $$
begin
  perform cron.unschedule('publish-hermandad-scheduled-posts');
exception
  when others then null;
end $$;

select cron.schedule(
  'publish-hermandad-scheduled-posts',
  '* * * * *',
  $$select public.publish_due_hermandad_scheduled_posts();$$
);

-- Verificar:
-- select jobname, schedule, command, active
-- from cron.job
-- where jobname = 'publish-hermandad-scheduled-posts';
