-- Noticias: etiqueta temática (opción A) en related_forum_id.
-- Deja de apuntar a foros; guarda claves: consejo, hermandades, musica, costaleros, cultura.
-- Ejecutar en SQL Editor.

-- 1) Quitar FK a forum_pillars
alter table public.forum_topics
  drop constraint if exists forum_topics_related_forum_id_fkey;

alter table public.noticias_scheduled
  drop constraint if exists noticias_scheduled_related_forum_id_fkey;

-- 2) Migrar valores antiguos (id de foro → clave temática)
update public.forum_topics
set related_forum_id = case related_forum_id
  when 'foro-cofradiero' then 'consejo'
  when 'hermandades' then 'hermandades'
  when 'pentagrama-cofrade' then 'musica'
  when 'martillo-trabajadera' then 'costaleros'
  else related_forum_id
end
where forum_id = 'noticias'
  and related_forum_id in (
    'foro-cofradiero',
    'hermandades',
    'pentagrama-cofrade',
    'martillo-trabajadera'
  );

update public.noticias_scheduled
set related_forum_id = case related_forum_id
  when 'foro-cofradiero' then 'consejo'
  when 'hermandades' then 'hermandades'
  when 'pentagrama-cofrade' then 'musica'
  when 'martillo-trabajadera' then 'costaleros'
  else related_forum_id
end
where related_forum_id in (
  'foro-cofradiero',
  'hermandades',
  'pentagrama-cofrade',
  'martillo-trabajadera'
);

-- 3) Validación: solo claves temáticas (o null)
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
    raise exception 'Solo las noticias pueden llevar etiqueta temática';
  end if;

  if new.related_forum_id not in (
    'consejo',
    'hermandades',
    'musica',
    'costaleros',
    'cultura'
  ) then
    raise exception 'Etiqueta de noticia no válida';
  end if;

  return new;
end;
$$;

alter table public.noticias_scheduled
  drop constraint if exists noticias_scheduled_related_check;

alter table public.noticias_scheduled
  add constraint noticias_scheduled_related_check
  check (
    related_forum_id is null
    or related_forum_id in (
      'consejo',
      'hermandades',
      'musica',
      'costaleros',
      'cultura'
    )
  );
