-- Círculo Cofrade · solicitudes de acceso al portal de hermandades
-- Insert solo vía RPC (security definer). Lectura/gestión: solo admin.
-- No crea cuentas Auth: la Junta aprueba y usa create-hermandad-account.

create table if not exists public.hermandad_access_requests (
  id uuid primary key default gen_random_uuid(),
  hermandad_name text not null
    check (char_length(trim(hermandad_name)) between 2 and 120),
  city text not null default ''
    check (char_length(city) <= 80),
  contact_name text not null
    check (char_length(trim(contact_name)) between 2 and 80),
  contact_email text not null
    check (
      char_length(contact_email) <= 160
      and contact_email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    ),
  contact_phone text not null default ''
    check (char_length(contact_phone) <= 40),
  message text not null default ''
    check (char_length(message) <= 1000),
  client_fingerprint text not null default ''
    check (char_length(client_fingerprint) <= 128),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'spam')),
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  review_notes text not null default ''
    check (char_length(review_notes) <= 500),
  created_profile_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists hermandad_access_requests_status_created_idx
  on public.hermandad_access_requests (status, created_at desc);

create unique index if not exists hermandad_access_requests_pending_email_uidx
  on public.hermandad_access_requests (lower(trim(contact_email)))
  where status = 'pending';

alter table public.hermandad_access_requests enable row level security;

drop policy if exists "Admin lee solicitudes hermandad" on public.hermandad_access_requests;
create policy "Admin lee solicitudes hermandad"
  on public.hermandad_access_requests for select
  using (public.is_admin_user(auth.uid()));

drop policy if exists "Admin actualiza solicitudes hermandad" on public.hermandad_access_requests;
create policy "Admin actualiza solicitudes hermandad"
  on public.hermandad_access_requests for update
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- Sin INSERT/DELETE directos desde el cliente (solo RPC / admin update).

create or replace function public.submit_hermandad_access_request(
  p_hermandad_name text,
  p_city text,
  p_contact_name text,
  p_contact_email text,
  p_contact_phone text default '',
  p_message text default '',
  p_client_fingerprint text default '',
  p_honeypot text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := trim(coalesce(p_hermandad_name, ''));
  v_city text := trim(coalesce(p_city, ''));
  v_contact text := trim(coalesce(p_contact_name, ''));
  v_email text := lower(trim(coalesce(p_contact_email, '')));
  v_phone text := trim(coalesce(p_contact_phone, ''));
  v_message text := trim(coalesce(p_message, ''));
  v_fp text := left(trim(coalesce(p_client_fingerprint, '')), 128);
  v_id uuid;
  v_email_count int;
  v_fp_count int;
begin
  -- Honeypot: bots que rellenan el campo oculto → éxito falso.
  if length(trim(coalesce(p_honeypot, ''))) > 0 then
    return gen_random_uuid();
  end if;

  if char_length(v_name) < 2 or char_length(v_name) > 120 then
    raise exception 'Nombre de hermandad no válido';
  end if;
  if char_length(v_city) > 80 then
    raise exception 'Ciudad demasiado larga';
  end if;
  if char_length(v_contact) < 2 or char_length(v_contact) > 80 then
    raise exception 'Nombre de contacto no válido';
  end if;
  if char_length(v_email) < 5
     or char_length(v_email) > 160
     or v_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Email no válido';
  end if;
  if char_length(v_phone) > 40 then
    raise exception 'Teléfono demasiado largo';
  end if;
  if char_length(v_message) > 1000 then
    raise exception 'Mensaje demasiado largo';
  end if;

  -- Rate limit por email (3 / 24h, cualquier estado).
  select count(*)::int into v_email_count
  from public.hermandad_access_requests
  where lower(trim(contact_email)) = v_email
    and created_at > now() - interval '24 hours';
  if v_email_count >= 3 then
    raise exception 'Demasiadas solicitudes. Inténtalo mañana.';
  end if;

  -- Rate limit por fingerprint (5 / 24h) si viene informado.
  if char_length(v_fp) >= 8 then
    select count(*)::int into v_fp_count
    from public.hermandad_access_requests
    where client_fingerprint = v_fp
      and created_at > now() - interval '24 hours';
    if v_fp_count >= 5 then
      raise exception 'Demasiadas solicitudes. Inténtalo mañana.';
    end if;
  end if;

  if exists (
    select 1
    from public.hermandad_access_requests
    where status = 'pending'
      and lower(trim(contact_email)) = v_email
  ) then
    raise exception 'Ya hay una solicitud pendiente con ese email.';
  end if;

  insert into public.hermandad_access_requests (
    hermandad_name,
    city,
    contact_name,
    contact_email,
    contact_phone,
    message,
    client_fingerprint,
    status
  ) values (
    v_name,
    v_city,
    v_contact,
    v_email,
    v_phone,
    v_message,
    v_fp,
    'pending'
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_hermandad_access_request(
  text, text, text, text, text, text, text, text
) from public;
grant execute on function public.submit_hermandad_access_request(
  text, text, text, text, text, text, text, text
) to anon, authenticated;

create or replace function public.review_hermandad_access_request(
  p_request_id uuid,
  p_status text,
  p_notes text default '',
  p_created_profile_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := lower(trim(coalesce(p_status, '')));
  v_notes text := left(trim(coalesce(p_notes, '')), 500);
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo administradores';
  end if;

  if v_status not in ('approved', 'rejected', 'spam', 'pending') then
    raise exception 'Estado no válido';
  end if;

  update public.hermandad_access_requests
  set
    status = v_status,
    review_notes = v_notes,
    reviewed_by = auth.uid(),
    reviewed_at = now(),
    created_profile_id = coalesce(p_created_profile_id, created_profile_id)
  where id = p_request_id;

  if not found then
    raise exception 'Solicitud no encontrada';
  end if;
end;
$$;

revoke all on function public.review_hermandad_access_request(
  uuid, text, text, uuid
) from public;
grant execute on function public.review_hermandad_access_request(
  uuid, text, text, uuid
) to authenticated;
