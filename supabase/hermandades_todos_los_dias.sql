-- Cofradero · Hermandades por día (Sevilla)
-- Ejecutar después de schema.sql. Es idempotente y no duplica temas existentes.

insert into public.forum_pillars (
  id, name, description, icon_key, sort_order,
  topic_count, message_count, is_enabled, is_active, locked_label
) values (
  'hermandades',
  'Hermandades',
  'Sigue las noticias y avisos de cada hermandad por día.',
  'groups_outlined',
  4,
  0,
  0,
  true,
  true,
  null
)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  icon_key = excluded.icon_key,
  sort_order = excluded.sort_order,
  is_enabled = excluded.is_enabled,
  is_active = excluded.is_active,
  locked_label = excluded.locked_label;

update public.forum_pillars
set sort_order = case id
  when 'semana-santa' then 5
  when 'cuaresma' then 6
  when 'glorias' then 7
  else sort_order
end
where id in ('semana-santa', 'cuaresma', 'glorias');

insert into public.forum_topics (
  id, forum_id, author_handle, title, excerpt, body,
  is_resolved, view_count, comment_count, status, created_at
)
select
  day_slug || '-' || hermandad_slug,
  'hermandades',
  '@cofradeo',
  day_label || ' · ' || hermandad_name,
  'Espacio para noticias, horarios, avisos e información oficial de ' || hermandad_name || '.',
  'Este es el espacio de seguimiento de ' || hermandad_name || ' para ' || day_label || '.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
  false,
  0,
  0,
  'published',
  now() - (sort_order || ' minutes')::interval
from (values
  ('Viernes de Dolores', 'viernes-dolores', 'Bendición y Esperanza', 'bendicion-esperanza', 1),
  ('Viernes de Dolores', 'viernes-dolores', 'Pino Montano', 'pino-montano', 2),
  ('Viernes de Dolores', 'viernes-dolores', 'La Misión', 'la-mision', 3),
  ('Viernes de Dolores', 'viernes-dolores', 'Bellavista', 'bellavista', 4),
  ('Viernes de Dolores', 'viernes-dolores', 'La Corona', 'la-corona', 5),
  ('Viernes de Dolores', 'viernes-dolores', 'Pasión y Muerte', 'pasion-y-muerte', 6),
  ('Sábado de Pasión', 'sabado-pasion', 'Padre Pío', 'padre-pio', 7),
  ('Sábado de Pasión', 'sabado-pasion', 'La Milagrosa', 'la-milagrosa', 8),
  ('Sábado de Pasión', 'sabado-pasion', 'Torreblanca', 'torreblanca', 9),
  ('Sábado de Pasión', 'sabado-pasion', 'San José Obrero', 'san-jose-obrero', 10),
  ('Sábado de Pasión', 'sabado-pasion', 'Divino Perdón', 'divino-perdon', 11),
  ('Domingo de Ramos', 'domingo-ramos', 'La Borriquita', 'la-borriquita', 12),
  ('Domingo de Ramos', 'domingo-ramos', 'La Cena', 'la-cena', 13),
  ('Domingo de Ramos', 'domingo-ramos', 'Jesús Despojado', 'jesus-despojado', 14),
  ('Domingo de Ramos', 'domingo-ramos', 'La Hiniesta', 'la-hiniesta', 15),
  ('Domingo de Ramos', 'domingo-ramos', 'La Paz', 'la-paz', 16),
  ('Domingo de Ramos', 'domingo-ramos', 'San Roque', 'san-roque', 17),
  ('Domingo de Ramos', 'domingo-ramos', 'La Estrella', 'la-estrella', 18),
  ('Domingo de Ramos', 'domingo-ramos', 'La Amargura', 'la-amargura', 19),
  ('Domingo de Ramos', 'domingo-ramos', 'El Amor', 'el-amor', 20),
  ('Lunes Santo', 'lunes-santo', 'San Pablo', 'san-pablo', 21),
  ('Lunes Santo', 'lunes-santo', 'La Redención', 'la-redencion', 22),
  ('Lunes Santo', 'lunes-santo', 'Santa Genoveva', 'santa-genoveva', 23),
  ('Lunes Santo', 'lunes-santo', 'Santa Marta', 'santa-marta', 24),
  ('Lunes Santo', 'lunes-santo', 'San Gonzalo', 'san-gonzalo', 25),
  ('Lunes Santo', 'lunes-santo', 'Vera Cruz', 'vera-cruz', 26),
  ('Lunes Santo', 'lunes-santo', 'Las Penas', 'las-penas', 27),
  ('Lunes Santo', 'lunes-santo', 'Las Aguas', 'las-aguas', 28),
  ('Lunes Santo', 'lunes-santo', 'El Museo', 'el-museo', 29),
  ('Martes Santo', 'martes-santo', 'El Cerro', 'el-cerro', 30),
  ('Martes Santo', 'martes-santo', 'San Esteban', 'san-esteban', 31),
  ('Martes Santo', 'martes-santo', 'La Candelaria', 'la-candelaria', 32),
  ('Martes Santo', 'martes-santo', 'San Benito', 'san-benito', 33),
  ('Martes Santo', 'martes-santo', 'Los Javieres', 'los-javieres', 34),
  ('Martes Santo', 'martes-santo', 'El Dulce Nombre', 'el-dulce-nombre', 35),
  ('Martes Santo', 'martes-santo', 'Los Estudiantes', 'los-estudiantes', 36),
  ('Martes Santo', 'martes-santo', 'Santa Cruz', 'santa-cruz', 37),
  ('Miércoles Santo', 'miercoles-santo', 'El Carmen Doloroso', 'el-carmen-doloroso', 38),
  ('Miércoles Santo', 'miercoles-santo', 'El Buen Fin', 'el-buen-fin', 39),
  ('Miércoles Santo', 'miercoles-santo', 'La Sed', 'la-sed', 40),
  ('Miércoles Santo', 'miercoles-santo', 'San Bernardo', 'san-bernardo', 41),
  ('Miércoles Santo', 'miercoles-santo', 'La Lanzada', 'la-lanzada', 42),
  ('Miércoles Santo', 'miercoles-santo', 'El Baratillo', 'el-baratillo', 43),
  ('Miércoles Santo', 'miercoles-santo', 'Los Panaderos', 'los-panaderos', 44),
  ('Miércoles Santo', 'miercoles-santo', 'Cristo de Burgos', 'cristo-de-burgos', 45),
  ('Miércoles Santo', 'miercoles-santo', 'Las Siete Palabras', 'las-siete-palabras', 46),
  ('Jueves Santo', 'jueves-santo', 'Los Negritos', 'los-negritos', 47),
  ('Jueves Santo', 'jueves-santo', 'La Exaltación', 'la-exaltacion', 48),
  ('Jueves Santo', 'jueves-santo', 'Las Cigarreras', 'las-cigarreras', 49),
  ('Jueves Santo', 'jueves-santo', 'Montesión', 'montesion', 50),
  ('Jueves Santo', 'jueves-santo', 'La Quinta Angustia', 'la-quinta-angustia', 51),
  ('Jueves Santo', 'jueves-santo', 'El Valle', 'el-valle', 52),
  ('Jueves Santo', 'jueves-santo', 'Pasión', 'pasion', 53),
  ('Madrugá', 'madruga', 'El Silencio', 'el-silencio', 54),
  ('Madrugá', 'madruga', 'El Gran Poder', 'el-gran-poder', 55),
  ('Madrugá', 'madruga', 'La Macarena', 'la-macarena', 56),
  ('Madrugá', 'madruga', 'El Calvario', 'el-calvario', 57),
  ('Madrugá', 'madruga', 'La Esperanza de Triana', 'la-esperanza-de-triana', 58),
  ('Madrugá', 'madruga', 'Los Gitanos', 'los-gitanos', 59),
  ('Viernes Santo', 'viernes-santo', 'La Carretería', 'la-carreteria', 60),
  ('Viernes Santo', 'viernes-santo', 'Soledad de San Buenaventura', 'soledad-san-buenaventura', 61),
  ('Viernes Santo', 'viernes-santo', 'El Cachorro', 'el-cachorro', 62),
  ('Viernes Santo', 'viernes-santo', 'La O', 'la-o', 63),
  ('Viernes Santo', 'viernes-santo', 'San Isidoro', 'san-isidoro', 64),
  ('Viernes Santo', 'viernes-santo', 'Montserrat', 'montserrat', 65),
  ('Viernes Santo', 'viernes-santo', 'La Mortaja', 'la-mortaja', 66),
  ('Sábado Santo', 'sabado-santo', 'El Sol', 'el-sol', 67),
  ('Sábado Santo', 'sabado-santo', 'Los Servitas', 'los-servitas', 68),
  ('Sábado Santo', 'sabado-santo', 'La Trinidad', 'la-trinidad', 69),
  ('Sábado Santo', 'sabado-santo', 'El Santo Entierro', 'el-santo-entierro', 70),
  ('Sábado Santo', 'sabado-santo', 'La Soledad de San Lorenzo', 'la-soledad-de-san-lorenzo', 71),
  ('Domingo de Resurrección', 'domingo-resurreccion', 'La Resurrección', 'la-resurreccion', 72)
) as hermandades(day_label, day_slug, hermandad_name, hermandad_slug, sort_order)
on conflict (id) do nothing;

do $$
begin
  if to_regprocedure('public.refresh_forum_pillar_stats(text)') is not null then
    execute 'select public.refresh_forum_pillar_stats($1)' using 'hermandades';
  end if;
end;
$$;
