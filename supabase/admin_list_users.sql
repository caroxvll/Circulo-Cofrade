-- Círculo Cofrade · Listado admin de usuarios con email (auth.users)
-- Ejecutar en SQL Editor. Solo admins.

create or replace function public.admin_list_users(
  p_query text default '',
  p_limit int default 40
)
returns table (
  id uuid,
  handle text,
  display_name text,
  role text,
  account_type text,
  verified boolean,
  suspended_at timestamptz,
  suspended_reason text,
  created_at timestamptz,
  email text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_q text := lower(trim(coalesce(p_query, '')));
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo un admin puede listar usuarios con email';
  end if;

  -- Quitar @ inicial si buscan handle.
  if left(v_q, 1) = '@' then
    v_q := substr(v_q, 2);
  end if;

  return query
  select
    p.id,
    p.handle,
    p.display_name,
    p.role::text,
    p.account_type::text,
    coalesce(p.verified, false) as verified,
    p.suspended_at,
    p.suspended_reason,
    p.created_at,
    coalesce(u.email, '')::text as email
  from public.profiles p
  left join auth.users u on u.id = p.id
  where
    v_q = ''
    or char_length(v_q) < 2
    or p.handle ilike '%' || v_q || '%'
    or p.display_name ilike '%' || v_q || '%'
    or coalesce(u.email, '') ilike '%' || v_q || '%'
  order by p.created_at desc
  limit v_limit;
end;
$$;

revoke all on function public.admin_list_users(text, int) from public;
grant execute on function public.admin_list_users(text, int) to authenticated;
