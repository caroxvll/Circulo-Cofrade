-- Cofradero · subrespuestas + notificación al seguir perfil (Fase 8f parcial)
-- Ejecutar en SQL Editor

-- Subrespuestas (responder a una respuesta concreta)
alter table public.forum_replies
  add column if not exists parent_reply_id uuid
  references public.forum_replies (id) on delete cascade;

create index if not exists forum_replies_parent_id_idx
  on public.forum_replies (parent_reply_id);

-- Notificar al usuario cuando alguien le sigue
create or replace function public.notify_on_profile_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_follower record;
begin
  if new.target_type <> 'profile' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select display_name, handle
  into v_follower
  from public.profiles
  where id = new.follower_id;

  if not found then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  values (
    new.target_id::uuid,
    'new_follower',
    'Nuevo seguidor',
    coalesce(v_follower.display_name, v_follower.handle) || ' empezó a seguirte',
    jsonb_build_object('profileId', new.follower_id::text)
  );

  return new;
end;
$$;

drop trigger if exists on_profile_follow_notify on public.follows;
create trigger on_profile_follow_notify
  after insert on public.follows
  for each row execute function public.notify_on_profile_follow();
