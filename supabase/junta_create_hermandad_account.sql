-- Cofradero · Alta de cuentas hermandad desde Junta
-- Ejecutar en SQL Editor (después de schema.sql / profile_verification.sql).
--
-- La creación de auth.users la hace la Edge Function `create-hermandad-account`
-- (service role). Este SQL deja el trigger listo para metadata brotherhood.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  raw_handle text;
  raw_account_type text;
  raw_verified boolean;
begin
  raw_handle := coalesce(
    new.raw_user_meta_data ->> 'handle',
    split_part(new.email, '@', 1)
  );
  raw_handle := lower(regexp_replace(raw_handle, '[^a-z0-9_]', '', 'g'));
  if raw_handle = '' then
    raw_handle := 'user_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  raw_account_type := coalesce(
    new.raw_user_meta_data ->> 'account_type',
    'cofrade'
  );
  if raw_account_type not in ('cofrade', 'brotherhood') then
    raw_account_type := 'cofrade';
  end if;

  raw_verified := coalesce(
    (new.raw_user_meta_data ->> 'verified')::boolean,
    false
  );

  insert into public.profiles (
    id,
    handle,
    display_name,
    account_type,
    verified
  )
  values (
    new.id,
    raw_handle,
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      split_part(new.email, '@', 1)
    ),
    raw_account_type,
    raw_verified
  );
  return new;
end;
$$;

-- Despliegue Edge Function:
--   supabase functions deploy create-hermandad-account
-- Secretos: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
-- (normalmente ya inyectados en el runtime de Functions).
