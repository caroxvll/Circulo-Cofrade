-- Círculo Cofrade · Contraseña elegida en la solicitud (cifrada hasta el alta)
-- Ejecutar en SQL Editor (después de hermandad_access_request_kind.sql).
-- La Junta no ve la clave: solo create-hermandad-account (service role) la consume una vez.

create extension if not exists pgcrypto with schema extensions;

alter table public.hermandad_access_requests
  add column if not exists password_enc bytea;

alter table public.hermandad_access_requests
  add column if not exists has_requested_password boolean not null default false;

-- Clave simétrica en schema privado (no legible vía API pública).
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to postgres, service_role;

create table if not exists private.hermandad_crypto (
  id int primary key default 1 check (id = 1),
  pwd_key text not null
);

revoke all on table private.hermandad_crypto from public;
alter table private.hermandad_crypto enable row level security;
-- Sin policies: ni anon ni authenticated pueden leerla vía API.

insert into private.hermandad_crypto (id, pwd_key)
values (1, encode(extensions.gen_random_bytes(32), 'hex'))
on conflict (id) do nothing;

create or replace function public._hermandad_request_pwd_key()
returns text
language sql
stable
security definer
set search_path = public, private, extensions
as $$
  select coalesce(
    (select nullif(trim(pwd_key), '') from private.hermandad_crypto where id = 1),
    'cofradeo-hermandad-request-fallback-key'
  );
$$;

revoke all on function public._hermandad_request_pwd_key() from public;

-- Firma 10 args → 11 (añade p_password).
drop function if exists public.submit_hermandad_access_request(
  text, text, text, text, text, text, text, text, text, text
);

create or replace function public.submit_hermandad_access_request(
  p_hermandad_name text,
  p_city text,
  p_contact_name text,
  p_contact_email text,
  p_contact_phone text default '',
  p_message text default '',
  p_client_fingerprint text default '',
  p_honeypot text default '',
  p_board_kind text default 'semana_santa',
  p_procession_day text default '',
  p_password text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_name text := trim(coalesce(p_hermandad_name, ''));
  v_city text := trim(coalesce(p_city, ''));
  v_contact text := trim(coalesce(p_contact_name, ''));
  v_email text := lower(trim(coalesce(p_contact_email, '')));
  v_phone text := trim(coalesce(p_contact_phone, ''));
  v_message text := trim(coalesce(p_message, ''));
  v_fp text := left(trim(coalesce(p_client_fingerprint, '')), 128);
  v_kind text := lower(trim(coalesce(p_board_kind, 'semana_santa')));
  v_day text := trim(coalesce(p_procession_day, ''));
  v_password text := coalesce(p_password, '');
  v_id uuid;
  v_email_count int;
  v_fp_count int;
  v_enc bytea;
begin
  if length(trim(coalesce(p_honeypot, ''))) > 0 then
    return gen_random_uuid();
  end if;

  if v_kind not in ('semana_santa', 'glorias') then
    raise exception 'Tipo de hermandad no válido';
  end if;

  if v_kind = 'glorias' then
    v_day := '';
  else
    if v_day not in (
      'Viernes de Dolores',
      'Sábado de Pasión',
      'Domingo de Ramos',
      'Lunes Santo',
      'Martes Santo',
      'Miércoles Santo',
      'Jueves Santo',
      'Madrugá',
      'Viernes Santo',
      'Sábado Santo',
      'Domingo de Resurrección'
    ) then
      raise exception 'Indica el día de salida de Semana Santa';
    end if;
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
  if char_length(v_password) < 8 or char_length(v_password) > 72 then
    raise exception 'La contraseña debe tener entre 8 y 72 caracteres';
  end if;

  select count(*)::int into v_email_count
  from public.hermandad_access_requests
  where lower(trim(contact_email)) = v_email
    and created_at > now() - interval '24 hours';
  if v_email_count >= 3 then
    raise exception 'Demasiadas solicitudes. Inténtalo mañana.';
  end if;

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

  v_enc := extensions.pgp_sym_encrypt(
    v_password,
    public._hermandad_request_pwd_key()
  );

  insert into public.hermandad_access_requests (
    hermandad_name,
    city,
    contact_name,
    contact_email,
    contact_phone,
    message,
    client_fingerprint,
    board_kind,
    procession_day,
    password_enc,
    has_requested_password,
    status
  ) values (
    v_name,
    v_city,
    v_contact,
    v_email,
    v_phone,
    v_message,
    v_fp,
    v_kind,
    v_day,
    v_enc,
    true,
    'pending'
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_hermandad_access_request(
  text, text, text, text, text, text, text, text, text, text, text
) from public;
grant execute on function public.submit_hermandad_access_request(
  text, text, text, text, text, text, text, text, text, text, text
) to anon, authenticated;

-- Lee la clave sin borrarla (solo service_role / Edge Function).
create or replace function public.read_hermandad_request_password(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_enc bytea;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authorized';
  end if;

  select password_enc into v_enc
  from public.hermandad_access_requests
  where id = p_request_id
    and status = 'pending'
    and password_enc is not null;

  if v_enc is null then
    return null;
  end if;

  return extensions.pgp_sym_decrypt(
    v_enc,
    public._hermandad_request_pwd_key()
  );
end;
$$;

-- Borra el secreto tras crear la cuenta correctamente.
create or replace function public.clear_hermandad_request_password(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authorized';
  end if;

  update public.hermandad_access_requests
  set
    password_enc = null,
    has_requested_password = false
  where id = p_request_id;
end;
$$;

revoke all on function public.read_hermandad_request_password(uuid) from public;
revoke all on function public.clear_hermandad_request_password(uuid) from public;
grant execute on function public.read_hermandad_request_password(uuid) to service_role;
grant execute on function public.clear_hermandad_request_password(uuid) to service_role;

-- Compat: take = read + clear (por si quedó referenciada).
create or replace function public.take_hermandad_request_password(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plain text;
begin
  v_plain := public.read_hermandad_request_password(p_request_id);
  if v_plain is not null then
    perform public.clear_hermandad_request_password(p_request_id);
  end if;
  return v_plain;
end;
$$;

revoke all on function public.take_hermandad_request_password(uuid) from public;
grant execute on function public.take_hermandad_request_password(uuid) to service_role;

-- Al rechazar / spam, borrar secreto residual.
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
    created_profile_id = coalesce(p_created_profile_id, created_profile_id),
    password_enc = case
      when v_status in ('rejected', 'spam') then null
      else password_enc
    end,
    has_requested_password = case
      when v_status in ('rejected', 'spam') then false
      else has_requested_password
    end
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
