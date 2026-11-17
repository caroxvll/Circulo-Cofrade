-- Fix: read/clear password sin comprobar auth.role() (fallaba con service key).
-- Ejecutar en SQL Editor si ya aplicaste hermandad_access_request_password.sql.

create or replace function public.read_hermandad_request_password(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_enc bytea;
begin
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

create or replace function public.clear_hermandad_request_password(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
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
