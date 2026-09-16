-- Cofradero · contenido «Acerca del foro» editable
-- Ejecutar después de forum_pillar_covers.sql. Idempotente.

alter table public.forum_pillars
  add column if not exists about_tagline text;

alter table public.forum_pillars
  add column if not exists about_body text;

alter table public.forum_pillars
  add column if not exists forum_rules text;

-- Los moderadores son visibles en la ficha pública del foro.
do $$
begin
  if to_regclass('public.forum_moderators') is null then
    return;
  end if;
  drop policy if exists "Moderadores visibles publicamente" on public.forum_moderators;
  create policy "Moderadores visibles publicamente"
    on public.forum_moderators for select
    using (true);
end $$;

-- Texto por defecto del apartado Hermandades (canal oficial, no foro).
update public.forum_pillars
set
  about_tagline = coalesce(
    nullif(trim(about_tagline), ''),
    'Noticias, cultos, actos y patrimonio de las hermandades de Sevilla.'
  ),
  about_body = coalesce(
    nullif(trim(about_body), ''),
    'Este apartado no es un foro de debate. Aquí cada hermandad publica de forma oficial sus noticias, cultos, actos y patrimonio a través de su cuenta verificada.' || E'\n\n' ||
    'Los cofrades pueden consultar y seguir la actualidad, pero no es posible abrir temas ni comentar: el contenido lo gestionan exclusivamente las cuentas verificadas de cada hermandad.'
  ),
  forum_rules = coalesce(
    nullif(trim(forum_rules), ''),
    'Solo las hermandades con cuenta verificada pueden publicar.' || E'\n' ||
    'No está permitido abrir temas ni comentar en este apartado.' || E'\n' ||
    'El contenido es informativo: noticias, cultos, actos y patrimonio.' || E'\n' ||
    'Cada publicación es responsabilidad de la hermandad que la emite.' || E'\n' ||
    'Para dudas concretas, contacta con la hermandad por sus canales oficiales.'
  )
where id = 'hermandades';
