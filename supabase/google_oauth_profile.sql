-- Cofradero · perfil al registrarse con Google (OAuth)
-- Ejecutar una vez en SQL Editor si ya tienes schema.sql desplegado.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  raw_handle text;
  display text;
  avatar text;
begin
  display := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    split_part(new.email, '@', 1)
  );
  display := left(display, 40);
  if char_length(display) < 2 then
    display := left(coalesce(nullif(split_part(new.email, '@', 1), ''), 'Cofrade'), 40);
  end if;

  avatar := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'avatar_url'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'picture'), '')
  );

  raw_handle := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'handle'), ''),
    split_part(new.email, '@', 1)
  );
  raw_handle := lower(regexp_replace(raw_handle, '[^a-z0-9_]', '', 'g'));
  if raw_handle = '' then
    raw_handle := 'user_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;
  if char_length(raw_handle) < 3 then
    raw_handle := raw_handle || '_' || substr(replace(new.id::text, '-', ''), 1, 4);
  end if;

  -- Evita choque si el handle ya existe (p. ej. dos cuentas gmail parecidas).
  while exists (select 1 from public.profiles where handle = raw_handle) loop
    raw_handle := raw_handle || '_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 4);
  end loop;

  insert into public.profiles (id, handle, display_name, avatar_url)
  values (new.id, raw_handle, display, avatar)
  on conflict (id) do nothing;

  return new;
end;
$$;
