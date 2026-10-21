-- Cofradero · Hermandades registradas y activas (directorio «Seguir»)
-- Ejecutar en SQL Editor.
--
-- Criterio: tablón en forum hermandades con cuenta oficial vinculada
-- (hermandad_topic_accounts), perfil brotherhood verificado y no suspendido.
-- Usado por la app en Perfil → Siguiendo → directorio de hermandades.

create or replace function public.list_registered_hermandad_topic_ids()
returns table (topic_id text)
language sql
stable
security definer
set search_path = public
as $$
  select distinct a.topic_id
  from public.hermandad_topic_accounts a
  join public.profiles p on p.id = a.profile_id
  join public.forum_topics t on t.id = a.topic_id
  where t.forum_id = 'hermandades'
    and t.status = 'published'
    and p.account_type = 'brotherhood'
    and coalesce(p.verified, false) = true
    and p.suspended_at is null
  order by a.topic_id;
$$;

grant execute on function public.list_registered_hermandad_topic_ids()
  to anon, authenticated;
