-- Cofradero · listado de seguidores del tablón para la cuenta oficial (portal web)
-- Ejecutar después de topic_follower_count.sql y hermandad_portal_rls.sql

create or replace function public.list_topic_followers_for_organizer(
  p_topic_id text,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  follower_id uuid,
  handle text,
  display_name text,
  avatar_url text,
  followed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1
    from public.hermandad_topic_accounts a
    where a.topic_id = p_topic_id
      and a.profile_id = auth.uid()
  ) then
    raise exception 'not authorized';
  end if;

  return query
  select
    p.id as follower_id,
    p.handle,
    p.display_name,
    p.avatar_url,
    f.created_at as followed_at
  from public.follows f
  join public.profiles p on p.id = f.follower_id
  where f.target_type = 'topic'
    and f.target_id = p_topic_id
  order by f.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 100))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

grant execute on function public.list_topic_followers_for_organizer(text, int, int)
  to authenticated;

comment on function public.list_topic_followers_for_organizer(text, int, int) is
  'Lista seguidores del tablón solo para la cuenta hermandad asignada al topic.';
