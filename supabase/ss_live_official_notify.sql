-- Cofradero · avisos oficiales de hermandad en live SS (push solo a seguidores)
-- Ejecutar después de ss_live_updates.sql / ss_liturgical_days.sql

alter table public.ss_live_updates
  add column if not exists is_official boolean not null default false;

create index if not exists ss_live_updates_official_created_idx
  on public.ss_live_updates (is_official, created_at desc)
  where is_official;

comment on column public.ss_live_updates.is_official is
  'True solo si lo publica una cuenta brotherhood verificada. Dispara push a seguidores.';

-- Marca oficial automáticamente; nadie puede fingir ser hermandad.
create or replace function public.ss_live_updates_mark_official()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_account text;
  v_verified boolean;
  v_name text;
begin
  select p.account_type, p.verified, p.display_name
  into v_account, v_verified, v_name
  from public.profiles p
  where p.id = new.user_id;

  if v_account = 'brotherhood' and coalesce(v_verified, false) then
    new.is_official := true;
    if trim(coalesce(new.hermandad_label, '')) = '' then
      new.hermandad_label := left(coalesce(v_name, 'Hermandad'), 120);
    end if;
  else
    new.is_official := false;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_ss_live_updates_mark_official on public.ss_live_updates;
create trigger trg_ss_live_updates_mark_official
  before insert on public.ss_live_updates
  for each row
  execute function public.ss_live_updates_mark_official();

-- Push solo para avisos oficiales → seguidores del perfil + tablón asignado.
create or replace function public.notify_on_ss_live_official()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_forum_id text;
  v_route text;
  v_title text;
  v_subtitle text;
  v_name text;
begin
  if not coalesce(new.is_official, false) then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select p.display_name into v_name
  from public.profiles p
  where p.id = new.user_id;

  v_title := coalesce(nullif(trim(new.hermandad_label), ''), v_name, 'Hermandad');
  v_subtitle := left(
    regexp_replace(coalesce(new.message, ''), '\s+', ' ', 'g'),
    100
  );

  select t.forum_id
  into v_forum_id
  from public.forum_topics t
  where t.id = 'circulo-semana-santa'
  limit 1;

  v_forum_id := coalesce(v_forum_id, 'semana-santa');
  v_route := '/foros/' || v_forum_id || '/tema/circulo-semana-santa';

  -- Seguidores de la cuenta hermandad
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'ss_live_official',
    'Aviso oficial · ' || left(v_title, 60),
    v_subtitle,
    jsonb_build_object(
      'route', v_route,
      'forumId', v_forum_id,
      'topicId', 'circulo-semana-santa',
      'updateId', new.id::text,
      'profileId', new.user_id::text,
      'isOfficial', true
    )
  from public.follows f
  where f.target_type = 'profile'
    and f.target_id = new.user_id::text
    and f.follower_id is distinct from new.user_id
    and public.notify_pref_enabled(f.follower_id, 'calendar')
    and public.is_not_blocked(f.follower_id, new.user_id);

  -- Seguidores del tablón oficial asignado a esa cuenta
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select distinct
    f.follower_id,
    'ss_live_official',
    'Aviso oficial · ' || left(v_title, 60),
    v_subtitle,
    jsonb_build_object(
      'route', v_route,
      'forumId', v_forum_id,
      'topicId', 'circulo-semana-santa',
      'updateId', new.id::text,
      'profileId', new.user_id::text,
      'isOfficial', true
    )
  from public.hermandad_topic_accounts a
  join public.follows f
    on f.target_type = 'topic'
   and f.target_id = a.topic_id
  where a.profile_id = new.user_id
    and f.follower_id is distinct from new.user_id
    and public.notify_pref_enabled(f.follower_id, 'calendar')
    and public.is_not_blocked(f.follower_id, new.user_id)
    and not exists (
      select 1
      from public.notifications n
      where n.user_id = f.follower_id
        and n.type = 'ss_live_official'
        and n.payload->>'updateId' = new.id::text
        and n.created_at > now() - interval '2 minutes'
    );

  return new;
end;
$$;

drop trigger if exists on_ss_live_official_notify on public.ss_live_updates;
create trigger on_ss_live_official_notify
  after insert on public.ss_live_updates
  for each row
  execute function public.notify_on_ss_live_official();

comment on function public.notify_on_ss_live_official() is
  'Push solo cuando una hermandad verificada publica en el live de Semana Santa.';
