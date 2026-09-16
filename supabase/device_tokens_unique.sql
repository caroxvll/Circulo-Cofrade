-- Cofradero · un FCM token = un solo usuario (evita 3 pushes en el mismo móvil)
-- Ejecutar en SQL Editor.

-- 1) Limpiar duplicados: deja solo la fila más reciente por token
delete from public.device_tokens dt
where dt.id not in (
  select distinct on (fcm_token) id
  from public.device_tokens
  order by fcm_token, updated_at desc
);

-- 2) Unicidad global del token
alter table public.device_tokens
  drop constraint if exists device_tokens_user_id_fcm_token_key;

alter table public.device_tokens
  drop constraint if exists device_tokens_fcm_token_key;

alter table public.device_tokens
  add constraint device_tokens_fcm_token_key unique (fcm_token);

-- 3) RPC: al registrar, reclama el token (quita otras cuentas)
create or replace function public.claim_device_token(
  p_fcm_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;
  if p_fcm_token is null or length(trim(p_fcm_token)) < 10 then
    raise exception 'Token inválido';
  end if;
  if p_platform not in ('ios', 'android', 'web') then
    raise exception 'Plataforma inválida';
  end if;

  delete from public.device_tokens
  where fcm_token = p_fcm_token
    and user_id <> v_uid;

  delete from public.device_tokens
  where user_id = v_uid
    and platform = p_platform
    and fcm_token <> p_fcm_token;

  insert into public.device_tokens (user_id, fcm_token, platform, updated_at)
  values (v_uid, p_fcm_token, p_platform, now())
  on conflict (fcm_token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.claim_device_token(text, text) from public;
grant execute on function public.claim_device_token(text, text) to authenticated;
