-- Bloquear solicitudes si el email ya existe en Auth + asegurar RPC completa.
-- Ejecutar entero en SQL Editor (idempotente).

create extension if not exists pgcrypto with schema extensions;

alter table public.hermandad_access_requests
  add column if not exists password_enc bytea;

alter table public.hermandad_access_requests
  add column if not exists has_requested_password boolean not null default false;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to postgres, service_role;

create table if not exists private.hermandad_crypto (
  id int primary key default 1 check (id = 1),
  pwd_key text not null
);

revoke all on table private.hermandad_crypto from public;
alter table private.hermandad_crypto enable row level security;

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

-- Helper: ¿email ya registrado en Auth?
create or replace function public.hermandad_email_already_registered(p_email text)
returns boolean
language sql
stable
security definer
set search_path = auth, public
as $$
  select exists (
    select 1
    from auth.users u
    where lower(trim(coalesce(u.email, ''))) = lower(trim(coalesce(p_email, '')))
  );
$$;

revoke all on function public.hermandad_email_already_registered(text) from public;
grant execute on function public.hermandad_email_already_registered(text) to postgres, service_role;

-- Quitar firmas antiguas que confunden a PostgREST
drop function if exists public.submit_hermandad_access_request(
  text, text, text, text, text, text, text, text, text, text
);
drop function if exists public.submit_hermandad_access_request(
  text, text, text, text, text, text, text, text, text, text, text
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

  -- Un email = una cuenta (evita suplantación / doble registro).
  if public.hermandad_email_already_registered(v_email) then
    raise exception 'Ese email ya está en uso. Usa otro correo.';
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
    v_phone,          -- NOT NULL: vacío = ''
    v_message,        -- NOT NULL: vacío = ''
    v_fp,             -- NOT NULL: vacío = ''
    v_kind,
    nullif(v_day, ''),
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

-- Refrescar caché de PostgREST (por si había firmas duplicadas)
notify pgrst, 'reload schema';
