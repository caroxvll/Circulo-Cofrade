-- Solicitudes de seguimiento (cuentas privadas, estilo Instagram).
-- Flujo: Seguir en privado → pending + notif al dueño → Aceptar/Rechazar.
-- Solo tras aceptar se inserta en public.follows (y entonces se desbloquea el perfil).

create table if not exists public.follow_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (requester_id, target_id),
  check (requester_id <> target_id)
);

create index if not exists follow_requests_target_pending_idx
  on public.follow_requests (target_id, created_at desc)
  where status = 'pending';

create index if not exists follow_requests_requester_pending_idx
  on public.follow_requests (requester_id)
  where status = 'pending';

alter table public.follow_requests enable row level security;

drop policy if exists "Requester gestiona sus solicitudes" on public.follow_requests;
create policy "Requester gestiona sus solicitudes"
  on public.follow_requests for all
  using (auth.uid() = requester_id)
  with check (auth.uid() = requester_id);

drop policy if exists "Target ve solicitudes entrantes" on public.follow_requests;
create policy "Target ve solicitudes entrantes"
  on public.follow_requests for select
  using (auth.uid() = target_id);

-- ---------------------------------------------------------------------------
-- Notificar al dueño al crear solicitud pendiente
-- ---------------------------------------------------------------------------
create or replace function public.notify_on_follow_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_requester record;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select display_name, handle
  into v_requester
  from public.profiles
  where id = new.requester_id;

  if not found then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  values (
    new.target_id,
    'follow_request',
    'Solicitud de seguimiento',
    coalesce(v_requester.display_name, v_requester.handle)
      || ' quiere seguirte',
    jsonb_build_object(
      'profileId', new.requester_id::text,
      'requestId', new.id::text
    )
  );

  return new;
end;
$$;

drop trigger if exists on_follow_request_notify on public.follow_requests;
create trigger on_follow_request_notify
  after insert on public.follow_requests
  for each row execute function public.notify_on_follow_request();

drop trigger if exists on_follow_request_renotify on public.follow_requests;
create trigger on_follow_request_renotify
  after update of status on public.follow_requests
  for each row
  when (new.status = 'pending' and old.status is distinct from 'pending')
  execute function public.notify_on_follow_request();

-- ---------------------------------------------------------------------------
-- Aceptar solicitud → follow real + notif al solicitante
-- ---------------------------------------------------------------------------
create or replace function public.accept_follow_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.follow_requests%rowtype;
  v_target_name text;
begin
  perform set_config('row_security', 'off', true);

  select * into v_req
  from public.follow_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Solicitud no encontrada';
  end if;

  if v_req.target_id <> auth.uid() then
    raise exception 'No autorizado';
  end if;

  if v_req.status <> 'pending' then
    return;
  end if;

  insert into public.follows (follower_id, target_type, target_id)
  values (v_req.requester_id, 'profile', v_req.target_id::text)
  on conflict (follower_id, target_type, target_id) do nothing;

  update public.follow_requests
  set status = 'accepted',
      responded_at = now()
  where id = p_request_id;

  select coalesce(display_name, handle)
  into v_target_name
  from public.profiles
  where id = v_req.target_id;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  values (
    v_req.requester_id,
    'follow_accepted',
    'Solicitud aceptada',
    coalesce(v_target_name, 'Alguien')
      || ' ha aceptado tu solicitud de seguimiento',
    jsonb_build_object(
      'profileId', v_req.target_id::text,
      'requestId', v_req.id::text
    )
  );

  -- Marcar leídas las notifs de solicitud asociadas
  update public.notifications
  set read_at = coalesce(read_at, now())
  where user_id = v_req.target_id
    and type = 'follow_request'
    and payload->>'requestId' = p_request_id::text;
end;
$$;

revoke all on function public.accept_follow_request(uuid) from public;
grant execute on function public.accept_follow_request(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Rechazar solicitud
-- ---------------------------------------------------------------------------
create or replace function public.reject_follow_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.follow_requests%rowtype;
begin
  perform set_config('row_security', 'off', true);

  select * into v_req
  from public.follow_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Solicitud no encontrada';
  end if;

  if v_req.target_id <> auth.uid() then
    raise exception 'No autorizado';
  end if;

  if v_req.status <> 'pending' then
    return;
  end if;

  update public.follow_requests
  set status = 'rejected',
      responded_at = now()
  where id = p_request_id;

  update public.notifications
  set read_at = coalesce(read_at, now())
  where user_id = v_req.target_id
    and type = 'follow_request'
    and payload->>'requestId' = p_request_id::text;
end;
$$;

revoke all on function public.reject_follow_request(uuid) from public;
grant execute on function public.reject_follow_request(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- En cuentas privadas, el follow directo no debe notificar "nuevo seguidor"
-- (ya llegó follow_request; al aceptar se avisa al solicitante).
-- ---------------------------------------------------------------------------
create or replace function public.notify_on_profile_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_follower record;
  v_is_private boolean;
begin
  if new.target_type <> 'profile' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select coalesce(is_private, false)
  into v_is_private
  from public.profiles
  where id = new.target_id::uuid;

  if coalesce(v_is_private, false) then
    return new;
  end if;

  if not public.notify_pref_enabled(new.target_id::uuid, 'followers') then
    return new;
  end if;

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
