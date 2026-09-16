-- Cofradero · Noticias asociadas a un foro (etiqueta)
-- Ejecutar después de noticias_forum.sql. Idempotente.

alter table public.forum_topics
  add column if not exists related_forum_id text
  references public.forum_pillars (id) on delete set null;

create index if not exists forum_topics_related_forum_id_idx
  on public.forum_topics (related_forum_id)
  where related_forum_id is not null;

create or replace function public.validate_related_forum_on_topic()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.related_forum_id is null then
    return new;
  end if;

  if new.forum_id is distinct from 'noticias' then
    raise exception 'Solo las noticias pueden asociarse a un foro';
  end if;

  if new.related_forum_id = 'noticias' then
    raise exception 'No se puede asociar una noticia al propio canal Noticias';
  end if;

  if new.related_forum_id = new.forum_id then
    raise exception 'El foro asociado no puede ser el mismo del tema';
  end if;

  return new;
end;
$$;

drop trigger if exists on_forum_topic_related_forum on public.forum_topics;
create trigger on_forum_topic_related_forum
  before insert or update of related_forum_id, forum_id
  on public.forum_topics
  for each row execute function public.validate_related_forum_on_topic();
