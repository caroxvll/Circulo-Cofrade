-- Cofradero · motivo de rechazo de temas (Junta → autor)
-- Ejecutar después de topic_moderation.sql y notify_admins_moderation.sql

alter table public.forum_topics
  add column if not exists rejection_reason text;

alter table public.forum_topics
  add column if not exists rejected_at timestamptz;

alter table public.forum_topics
  drop constraint if exists forum_topics_rejection_reason_len;

alter table public.forum_topics
  add constraint forum_topics_rejection_reason_len
  check (
    rejection_reason is null
    or char_length(btrim(rejection_reason)) between 3 and 280
  );

-- Historial: ordenar por fecha de rechazo (relleno para filas antiguas)
update public.forum_topics
set rejected_at = created_at
where status = 'rejected'
  and rejected_at is null;

create index if not exists forum_topics_rejected_at_idx
  on public.forum_topics (rejected_at desc nulls last)
  where status = 'rejected';

-- Cambio de estado → avisar al autor (con motivo si rechazan)
create or replace function public.notify_author_topic_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text;
begin
  if old.status = new.status then
    return new;
  end if;

  if new.author_id is null then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  if new.status = 'published' then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      new.author_id,
      'topic_published',
      'Tema publicado',
      'La Junta ha aprobado: ' || left(new.title, 80),
      jsonb_build_object('forumId', new.forum_id, 'topicId', new.id)
    );
  elsif new.status = 'rejected' then
    v_reason := nullif(btrim(coalesce(new.rejection_reason, '')), '');
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      new.author_id,
      'topic_rejected',
      'Tema no publicado',
      coalesce(
        left(v_reason, 120),
        'La Junta no ha publicado: ' || left(new.title, 80)
      ),
      jsonb_build_object(
        'forumId', new.forum_id,
        'topicId', new.id,
        'topicTitle', left(new.title, 120),
        'rejectionReason', v_reason
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists on_topic_status_notify_author on public.forum_topics;
create trigger on_topic_status_notify_author
  after update of status on public.forum_topics
  for each row execute function public.notify_author_topic_status();
