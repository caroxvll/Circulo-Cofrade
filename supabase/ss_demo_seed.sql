-- Cofradeo · datos demo Semana Santa (PRE)
-- Ejecutar en SQL Editor DESPUÉS de:
--   1) ss_live_updates.sql
--   2) ss_live_engagement.sql  (reacciones + respuestas)
-- Ideal si ya tienes usuarios demo_* (seed_demo_world). Si no, usa perfiles reales.
--
-- Idempotente: borra solo IDs demo-ss-* / avisos marcados y vuelve a cargar.

do $$
declare
  u_maria uuid;
  u_pepe uuid;
  u_lucia uuid;
  u_antonio uuid;
  u_carmen uuid;
  u_manolo uuid;
  u_isa uuid;
  u_rafa uuid;
  u_pilar uuid;
  u_juan uuid;
  u_elena uuid;
  u_diego uuid;
  h_maria text;
  h_pepe text;
  h_lucia text;
  h_antonio text;
  h_carmen text;
  h_manolo text;
  h_isa text;
  h_rafa text;
  h_pilar text;
  h_juan text;
  h_elena text;
  h_diego text;
  v_users uuid[];
  v_i int;
begin
  perform set_config('row_security', 'off', true);

  -- Resolver usuarios demo (fallback: cualquier profile)
  select id into u_maria from public.profiles where handle in ('demo_maria', 'maria') limit 1;
  select id into u_pepe from public.profiles where handle in ('demo_pepe', 'pepe') limit 1;
  select id into u_lucia from public.profiles where handle in ('demo_lucia', 'lucia') limit 1;
  select id into u_antonio from public.profiles where handle in ('demo_antonio', 'antonio') limit 1;
  select id into u_carmen from public.profiles where handle in ('demo_carmen', 'carmen') limit 1;
  select id into u_manolo from public.profiles where handle in ('demo_manolo', 'manolo') limit 1;
  select id into u_isa from public.profiles where handle in ('demo_isa', 'isa') limit 1;
  select id into u_rafa from public.profiles where handle in ('demo_rafa', 'rafa') limit 1;
  select id into u_pilar from public.profiles where handle in ('demo_pilar', 'pilar') limit 1;
  select id into u_juan from public.profiles where handle in ('demo_juan', 'juan') limit 1;
  select id into u_elena from public.profiles where handle in ('demo_elena', 'elena') limit 1;
  select id into u_diego from public.profiles where handle in ('demo_diego', 'diego') limit 1;

  -- Completar huecos con perfiles existentes
  v_users := array(
    select id from public.profiles order by created_at nulls last limit 20
  );
  if coalesce(array_length(v_users, 1), 0) = 0 then
    raise exception 'No hay perfiles en PRE. Crea al menos un usuario o ejecuta seed_demo_world().';
  end if;

  v_i := 1;
  if u_maria is null then u_maria := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_pepe is null then u_pepe := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_lucia is null then u_lucia := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_antonio is null then u_antonio := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_carmen is null then u_carmen := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_manolo is null then u_manolo := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_isa is null then u_isa := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_rafa is null then u_rafa := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_pilar is null then u_pilar := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_juan is null then u_juan := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_elena is null then u_elena := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;
  if u_diego is null then u_diego := v_users[((v_i - 1) % array_length(v_users, 1)) + 1]; v_i := v_i + 1; end if;

  select handle into h_maria from public.profiles where id = u_maria;
  select handle into h_pepe from public.profiles where id = u_pepe;
  select handle into h_lucia from public.profiles where id = u_lucia;
  select handle into h_antonio from public.profiles where id = u_antonio;
  select handle into h_carmen from public.profiles where id = u_carmen;
  select handle into h_manolo from public.profiles where id = u_manolo;
  select handle into h_isa from public.profiles where id = u_isa;
  select handle into h_rafa from public.profiles where id = u_rafa;
  select handle into h_pilar from public.profiles where id = u_pilar;
  select handle into h_juan from public.profiles where id = u_juan;
  select handle into h_elena from public.profiles where id = u_elena;
  select handle into h_diego from public.profiles where id = u_diego;

  -- Limpieza previa de este seed
  delete from public.forum_replies
  where topic_id like 'demo-topic-ss-%';

  delete from public.forum_topics
  where id like 'demo-topic-ss-%';

  if to_regclass('public.ss_live_updates') is not null then
    delete from public.ss_live_updates
    where place_label like 'DEMO-SS%'
       or message like '%[demo-ss]%';
  end if;

  -- Hub sistema Semana Santa
  insert into public.forum_topics (
    id, forum_id, author_handle, title, excerpt, body,
    is_resolved, view_count, comment_count, status,
    is_pinned, pin_sort_order, is_system, season_key, icon_key, created_at
  ) values (
    'circulo-semana-santa', 'foro-cofradiero', '@cofradeo',
    'Semana Santa',
    'En directo desde la calle: retrasos, posición de hermandades y avisos.',
    'Espacio de Semana Santa para seguir la calle en directo: retrasos, por dónde van las hermandades, incidentes, curiosidades y ubicación en mapa.\n\nAbre temas para horarios, itinerarios y conversación cofrade de la Semana Mayor.',
    false, 1840, 0, 'published',
    true, 2, true, 'semana_santa', 'account_balance', now() - interval '29 days'
  )
  on conflict (id) do update set
    status = 'published',
    is_system = true,
    season_key = 'semana_santa',
    is_pinned = true,
    pin_sort_order = 2,
    excerpt = excluded.excerpt,
    body = excluded.body,
    title = excluded.title;

  -- Temas comunidad Semana Santa
  insert into public.forum_topics (
    id, forum_id, author_id, author_handle, title, excerpt, body,
    status, season_key, is_system, is_pinned, view_count, comment_count, created_at
  ) values
  (
    'demo-topic-ss-01', 'foro-cofradiero', u_maria, h_maria,
    'Carrera oficial: ¿cómo lo veis esta Madrugá?',
    'Tiempos, afluencia y ambiente en Campana / Sierpes.',
    'Abrimos hilo de carrera oficial: retrasos, ambiente y tramos recomendables. Sed respetuosos y contrastad rumores.',
    'published', 'semana_santa', false, false, 312, 0, now() - interval '18 hours'
  ),
  (
    'demo-topic-ss-02', 'foro-cofradiero', u_pepe, h_pepe,
    'Mejores sitios para ver sin agobios (familia)',
    'Tramos tranquilos y rincones con buena vista.',
    'Para ir con niños o gente mayor: ¿qué calles recomendáis hoy? Evitad zonas de apretón y sed concretos.',
    'published', 'semana_santa', false, false, 267, 0, now() - interval '15 hours'
  ),
  (
    'demo-topic-ss-03', 'foro-cofradiero', u_carmen, h_carmen,
    'Retrasos del día: hilo rápido',
    'Avisos cortos de retraso por hermandad.',
    'Dejad solo avisos claros: hermandad + tramo + minutos aprox. Sin debates largos aquí; para eso abrid otro tema.',
    'published', 'semana_santa', false, false, 498, 0, now() - interval '10 hours'
  ),
  (
    'demo-topic-ss-04', 'foro-cofradiero', u_antonio, h_antonio,
    'Costal y trabajadera: sensaciones de la calle',
    'Cómo se está llevando el día bajo el costal.',
    'Costaleros y aficionados: ritmo, calor, cambios de tercio… Contad sin filtrar nombres si no toca.',
    'published', 'semana_santa', false, false, 189, 0, now() - interval '8 hours'
  ),
  (
    'demo-topic-ss-05', 'foro-cofradiero', u_lucia, h_lucia,
    'Música en la calle: marchas que están sonando',
    'Repertorio que se oye hoy en los recorridos.',
    '¿Qué marchas estáis pillando en vivo? Banda, agrupación y momento (salida, arco, carrera…).',
    'published', 'semana_santa', false, false, 221, 0, now() - interval '6 hours'
  ),
  (
    'demo-topic-ss-06', 'foro-cofradiero', u_manolo, h_manolo,
    'Incidencias y cortes de tráfico (confirmar)',
    'Calles cortadas, desvíos y avisos oficiales.',
    'Si veis un corte o desvío, dejad fuente si podéis. Mejor confirmar dos veces antes de alarmar.',
    'published', 'semana_santa', false, false, 356, 0, now() - interval '4 hours'
  ),
  (
    'demo-topic-ss-07', 'foro-cofradiero', u_isa, h_isa,
    'Triana en directo: ambiente y recorridos',
    'Puente, Pureza, Altozano y alrededores.',
    'Hilo de Triana: por dónde van, ambiente en el puente y tips para cruzar sin volverse loco.',
    'published', 'semana_santa', false, false, 278, 0, now() - interval '3 hours'
  ),
  (
    'demo-topic-ss-08', 'foro-cofradiero', u_diego, h_diego,
    'Silencios que merecen la pena esta Semana Mayor',
    'Momentos de recogimiento en la calle.',
    'Compartid esos minutos en los que la ciudad se calla: una esquina, una iglesia, un tramo concreto.',
    'published', 'semana_santa', false, false, 164, 0, now() - interval '90 minutes'
  )
  on conflict (id) do update set
    status = 'published',
    season_key = 'semana_santa',
    title = excluded.title,
    excerpt = excluded.excerpt,
    body = excluded.body,
    view_count = excluded.view_count,
    created_at = excluded.created_at;

  -- Respuestas / comentarios (muchos, tono real)
  insert into public.forum_replies (topic_id, author_id, author_handle, content, created_at)
  values
  -- ss-01 carrera oficial
  ('demo-topic-ss-01', u_pepe, h_pepe,
   'Campana va justa. Si venís de atrás, no apretéis en Sierpes que hoy hay mucha gente.', now() - interval '17 hours'),
  ('demo-topic-ss-01', u_lucia, h_lucia,
   'El silencio cuando entra por Placentines… se te pone la piel de gallina. Merece la pena esperar.', now() - interval '16 hours 20 minutes'),
  ('demo-topic-ss-01', u_carmen, h_carmen,
   'Ojo: rumor de 25–30 min de retraso en El Silencio. Lo confirmo desde Francos.', now() - interval '15 hours 40 minutes'),
  ('demo-topic-ss-01', u_juan, h_juan,
   'Desde un balcón en Alfalfa se ve de lujo y sin empujones. El contactazo vale oro.', now() - interval '14 hours'),
  ('demo-topic-ss-01', u_rafa, h_rafa,
   'Las cornetas en Arfe se oyen clarísimas. Ambiente brutal sin llegar a ser peligroso.', now() - interval '12 hours 30 minutes'),
  ('demo-topic-ss-01', u_elena, h_elena,
   'Si vais con niños, mejor no os plantéis en la esquina de la Campana a última hora.', now() - interval '11 hours'),
  ('demo-topic-ss-01', u_antonio, h_antonio,
   'Paso firme en Constitucion. La cuadrilla va muy compacta, se nota el ensayo.', now() - interval '9 hours 15 minutes'),
  ('demo-topic-ss-01', u_pilar, h_pilar,
   'Acabo de ver a la Macarena en la puerta de la Basílica. Aplauso cerrado, sin gritos feos.', now() - interval '2 hours 10 minutes'),

  -- ss-02 sitios sin agobios
  ('demo-topic-ss-02', u_maria, h_maria,
   'Alameda temprano sigue siendo oro. Luego se llena, pero a primera hora se respira.', now() - interval '14 hours 30 minutes'),
  ('demo-topic-ss-02', u_manolo, h_manolo,
   'Tramo de San Luis hacia San Marcos: menos masa y buena perspectiva del palio.', now() - interval '13 hours'),
  ('demo-topic-ss-02', u_isa, h_isa,
   'En Triana, Altozano lateral (no el centro del puente) se está bastante bien con carrito.', now() - interval '11 hours 45 minutes'),
  ('demo-topic-ss-02', u_diego, h_diego,
   'Evitar Alfalfa a partir de las 20h si no os gusta el apretón. Mejor un poco más arriba.', now() - interval '7 hours'),
  ('demo-topic-ss-02', u_carmen, h_carmen,
   'Plaza del Salvador laterales: se ve y se puede salir rápido si hace falta.', now() - interval '5 hours 20 minutes'),
  ('demo-topic-ss-02', u_juan, h_juan,
   'Familia con abuela: nos ha ido genial en un tramo de Feria casi vacío a media tarde.', now() - interval '3 hours'),

  -- ss-03 retrasos
  ('demo-topic-ss-03', u_pepe, h_pepe,
   'El Silencio · ~20 min · Campana.', now() - interval '9 hours 50 minutes'),
  ('demo-topic-ss-03', u_lucia, h_lucia,
   'Gran Poder · a tiempo · entrada a carrera oficial.', now() - interval '9 hours 20 minutes'),
  ('demo-topic-ss-03', u_antonio, h_antonio,
   'Esperanza de Triana · +15 min · Pureza (gente cruzando el puente).', now() - interval '8 hours 40 minutes'),
  ('demo-topic-ss-03', u_rafa, h_rafa,
   'Los Gitanos · +10 min · San Juan de la Palma.', now() - interval '7 hours 55 minutes'),
  ('demo-topic-ss-03', u_pilar, h_pilar,
   'Macarena · sin retraso · Basílica / salida consolidada.', now() - interval '6 hours 30 minutes'),
  ('demo-topic-ss-03', u_manolo, h_manolo,
   'Cristo de la Expiración · +25 min · puente (viento lateral, van con cuidado).', now() - interval '5 hours 10 minutes'),
  ('demo-topic-ss-03', u_elena, h_elena,
   'La Estrella · a tiempo · San Jacinto.', now() - interval '4 hours'),
  ('demo-topic-ss-03', u_diego, h_diego,
   'El Calvario · +5 min · Jesús del Gran Poder (tramo corto).', now() - interval '2 hours 45 minutes'),
  ('demo-topic-ss-03', u_juan, h_juan,
   'CONFIRMADO El Silencio sigue con ~20–25 en Francos. No es invent.', now() - interval '90 minutes'),
  ('demo-topic-ss-03', u_maria, h_maria,
   'Amarguras · +30 aprox · hacia Campana. Va lenta pero sin problema.', now() - interval '40 minutes'),

  -- ss-04 costal
  ('demo-topic-ss-04', u_pepe, h_pepe,
   'Calor pegajoso bajo trabajadera. Hidratación cada oportunidad, no os paséis de héroes.', now() - interval '7 hours 30 minutes'),
  ('demo-topic-ss-04', u_antonio, h_antonio,
   'Cambio de tercio en arco estrecho limpio. Se nota cuadrilla hecha.', now() - interval '6 hours 15 minutes'),
  ('demo-topic-ss-04', u_manolo, h_manolo,
   'El viento en el puente obliga a ir más recogidos. Bien hecho por no forzar.', now() - interval '4 hours 50 minutes'),
  ('demo-topic-ss-04', u_rafa, h_rafa,
   'Desde fuera: se oye el coste y se ve el paso muy asentado. Bonito de verdad.', now() - interval '3 hours 20 minutes'),
  ('demo-topic-ss-04', u_carmen, h_carmen,
   'Respeto máximo a quien va debajo. Menos gritos y más silencio en los cambios.', now() - interval '1 hour 50 minutes'),

  -- ss-05 música
  ('demo-topic-ss-05', u_lucia, h_lucia,
   '«Amarguras» en plena carrera. La gente se para y se nota.', now() - interval '5 hours 40 minutes'),
  ('demo-topic-ss-05', u_isa, h_isa,
   'Cornetas en un arco de Triana… eso no se explica, se vive.', now() - interval '4 hours 25 minutes'),
  ('demo-topic-ss-05', u_rafa, h_rafa,
   'Tambores muy limpios en San Lorenzo. Sin atropellos, ritmo perfecto.', now() - interval '3 hours 5 minutes'),
  ('demo-topic-ss-05', u_elena, h_elena,
   'Una saeta desde un balcón en Feria. Corto, sentido, sin postureo.', now() - interval '2 hours 15 minutes'),
  ('demo-topic-ss-05', u_juan, h_juan,
   'Banda de música en la salida: volumen bien medido, no tapa el paso.', now() - interval '70 minutes'),
  ('demo-topic-ss-05', u_pilar, h_pilar,
   'Cuando paran y solo queda cera + una marcha suave… se me cae el alma.', now() - interval '35 minutes'),

  -- ss-06 incidencias
  ('demo-topic-ss-06', u_manolo, h_manolo,
   'Corte temporal en acceso a Alfonso XII. Desvío por laterales. Fuente: policía local in situ.', now() - interval '3 hours 40 minutes'),
  ('demo-topic-ss-06', u_pepe, h_pepe,
   'Rumores de rotura: de momento NO confirmo nada en Esperanza. Esperad fuentes.', now() - interval '3 hours 10 minutes'),
  ('demo-topic-ss-06', u_antonio, h_antonio,
   'Varal rozado en un arco (nada grave). Han parado 2 minutos y siguen.', now() - interval '2 hours 30 minutes'),
  ('demo-topic-ss-06', u_lucia, h_lucia,
   'Ambulancia pasando por Constitucion sin sirena. Sitio libre enseguida.', now() - interval '2 hours'),
  ('demo-topic-ss-06', u_diego, h_diego,
   'Gente subida a farolas otra vez. Peligroso y tapa a los niños. Un poco de cabeza.', now() - interval '80 minutes'),
  ('demo-topic-ss-06', u_carmen, h_carmen,
   'Actualizo: el rumor de “caída” era falso. Solo un alto más largo de lo normal.', now() - interval '55 minutes'),

  -- ss-07 Triana
  ('demo-topic-ss-07', u_isa, h_isa,
   'Puente lleno pero fluído. Mejor cruzar por el lateral del Altozano si podéis.', now() - interval '2 hours 50 minutes'),
  ('demo-topic-ss-07', u_manolo, h_manolo,
   'Esperanza ya en Pureza. Ambiente de barrio, aplausos y mucho respeto.', now() - interval '2 hours 20 minutes'),
  ('demo-topic-ss-07', u_rafa, h_rafa,
   'El viento en el Guadalquivir se nota. Van con cuidado, bien.', now() - interval '110 minutes'),
  ('demo-topic-ss-07', u_maria, h_maria,
   'San Jacinto se está poniendo precioso con la luz de esta hora.', now() - interval '75 minutes'),
  ('demo-topic-ss-07', u_juan, h_juan,
   'Si venís del Centro, no os metáis todos a la vez en el puente. Alternad.', now() - interval '45 minutes'),
  ('demo-topic-ss-07', u_pilar, h_pilar,
   'Capilla del Carmen: sitio chulo para esperar sin ir al centro del tumulto.', now() - interval '20 minutes'),

  -- ss-08 silencios
  ('demo-topic-ss-08', u_diego, h_diego,
   'Calle Pureza a oscuras, solo cera. Eso es Semana Santa.', now() - interval '80 minutes'),
  ('demo-topic-ss-08', u_elena, h_elena,
   'Entrada a un templo: ni un móvil en alto. Se agradece.', now() - interval '55 minutes'),
  ('demo-topic-ss-08', u_lucia, h_lucia,
   'Un minuto entero sin nadie hablando delante del paso. Me quedo con eso del día.', now() - interval '30 minutes'),
  ('demo-topic-ss-08', u_antonio, h_antonio,
   'Cuando paran en una esquina y solo se oye el coste… se te olvida la ciudad.', now() - interval '12 minutes');

  -- Recalcular comment_count (por si el trigger no corre con RLS off / bulk)
  update public.forum_topics t
  set comment_count = (
    select count(*)::int from public.forum_replies r where r.topic_id = t.id
  )
  where t.id like 'demo-topic-ss-%';

  -- Avisos en directo (radar)
  if to_regclass('public.ss_live_updates') is null then
    raise notice 'Tabla ss_live_updates no existe. Ejecuta ss_live_updates.sql primero.';
  else
    insert into public.ss_live_updates (
      user_id, kind, hermandad_label, message, place_label, latitude, longitude, created_at
    ) values
    (u_antonio, 'posicion', 'Jesús del Gran Poder',
     'Entrando en carrera oficial. Paso muy asentado. [demo-ss]',
     'DEMO-SS Campana', 37.3925, -5.9942, now() - interval '95 minutes'),
    (u_carmen, 'retraso', 'El Silencio',
     'Retraso de unos 20 minutos. Francos muy cargada. [demo-ss]',
     'DEMO-SS Calle Francos', 37.3889, -5.9935, now() - interval '88 minutes'),
    (u_pepe, 'posicion', 'La Esperanza de Triana',
     'Cruzando el puente. Ritmo bueno, sin agobios. [demo-ss]',
     'DEMO-SS Puente de Triana', 37.3862, -5.9998, now() - interval '82 minutes'),
    (u_lucia, 'curiosidad', 'La Macarena',
     'Aplauso cerrado en la puerta de la Basílica. Ambiente brutal. [demo-ss]',
     'DEMO-SS Basílica de la Macarena', 37.4024, -5.9894, now() - interval '76 minutes'),
    (u_manolo, 'incidente', 'Cristo de la Expiración',
     'Parón de 2 minutos por viento lateral en el puente. Siguen. [demo-ss]',
     'DEMO-SS Puente de Triana', 37.3860, -5.9995, now() - interval '70 minutes'),
    (u_rafa, 'posicion', 'Los Gitanos',
     'Pasando San Juan de la Palma. Cornetas clarísimas. [demo-ss]',
     'DEMO-SS San Juan de la Palma', 37.3968, -5.9901, now() - interval '64 minutes'),
    (u_isa, 'retraso', 'La Amargura',
     '+30 min aprox hacia Campana. Va lenta pero sin problema. [demo-ss]',
     'DEMO-SS hacia Campana', 37.3918, -5.9940, now() - interval '58 minutes'),
    (u_diego, 'curiosidad', 'El Calvario',
     'Un silencio de esos que se te quedan. Solo cera. [demo-ss]',
     'DEMO-SS Calle Jesús del Gran Poder', 37.3975, -5.9958, now() - interval '52 minutes'),
    (u_juan, 'general', 'La Estrella',
     'San Jacinto precioso con esta luz. Merece esperar. [demo-ss]',
     'DEMO-SS San Jacinto', 37.3839, -6.0025, now() - interval '47 minutes'),
    (u_elena, 'posicion', 'Santa Marta',
     'Ya en el entorno de la Catedral. Público contenido. [demo-ss]',
     'DEMO-SS Avenida de la Constitución', 37.3858, -5.9931, now() - interval '42 minutes'),
    (u_pilar, 'retraso', 'El Silencio',
     'CONFIRMO sigue con 20–25 min. No es rumor. [demo-ss]',
     'DEMO-SS Francos / Placentines', 37.3886, -5.9932, now() - interval '38 minutes'),
    (u_antonio, 'incidente', 'La Esperanza de Triana',
     'Rumores de rotura: de momento NO hay nada. Solo alto largo. [demo-ss]',
     'DEMO-SS Pureza', 37.3832, -6.0021, now() - interval '34 minutes'),
    (u_pepe, 'posicion', 'Jesús del Gran Poder',
     'Salida consolidada. Cuadrilla muy compacta. [demo-ss]',
     'DEMO-SS Plaza de San Lorenzo', 37.3992, -5.9969, now() - interval '30 minutes'),
    (u_carmen, 'curiosidad', 'La Macarena',
     'Saeta desde un balcón. Corta y sentida. [demo-ss]',
     'DEMO-SS Calle San Luis', 37.3998, -5.9889, now() - interval '26 minutes'),
    (u_lucia, 'general', '',
     'Alameda lateral todavía se respira. Buena opción con niños. [demo-ss]',
     'DEMO-SS Alameda de Hércules', 37.3995, -5.9948, now() - interval '22 minutes'),
    (u_manolo, 'retraso', 'Los Negritos',
     '+10 min en el entorno de San Bartolomé. [demo-ss]',
     'DEMO-SS San Bartolomé', 37.3881, -5.9869, now() - interval '19 minutes'),
    (u_rafa, 'posicion', 'San Gonzalo',
     'Ambiente de barrio en Triana. Mucho respeto. [demo-ss]',
     'DEMO-SS Pagés del Corro', 37.3815, -6.0062, now() - interval '16 minutes'),
    (u_isa, 'incidente', '',
     'Corte temporal en acceso a Alfonso XII. Desvío por laterales. [demo-ss]',
     'DEMO-SS Alfonso XII', 37.3936, -5.9978, now() - interval '13 minutes'),
    (u_diego, 'posicion', 'El Silencio',
     'Entrando por Placentines. Silencio casi total. [demo-ss]',
     'DEMO-SS Placentines', 37.3869, -5.9924, now() - interval '10 minutes'),
    (u_juan, 'curiosidad', 'La Esperanza de Triana',
     'Aplausos al paso del palio en Pureza. Sin gritos feos. [demo-ss]',
     'DEMO-SS Calle Pureza', 37.3835, -6.0024, now() - interval '8 minutes'),
    (u_elena, 'retraso', 'La Amargura',
     'Actualizo: siguen con retraso, pero ya más cerca de carrera. [demo-ss]',
     'DEMO-SS cerca Campana', 37.3920, -5.9941, now() - interval '6 minutes'),
    (u_pilar, 'posicion', 'La Macarena',
     'Subiendo por San Luis. Ritmo constante. [demo-ss]',
     'DEMO-SS San Luis', 37.4005, -5.9892, now() - interval '4 minutes'),
    (u_antonio, 'general', 'Gran Poder',
     'Si venís de atrás, no apretéis en Sierpes. Hoy hay mucha gente. [demo-ss]',
     'DEMO-SS Calle Sierpes', 37.3898, -5.9946, now() - interval '3 minutes'),
    (u_pepe, 'incidente', 'Cristo de la Expiración',
     'Varal rozado en arco (leve). Pararon un momento y siguen. [demo-ss]',
     'DEMO-SS arco Triana', 37.3858, -6.0002, now() - interval '2 minutes'),
    (u_carmen, 'posicion', 'Santa Marta',
     'Ya casi en el entorno catedralicio. Público contenido. [demo-ss]',
     'DEMO-SS Constitución', 37.3856, -5.9930, now() - interval '90 seconds'),
    (u_lucia, 'curiosidad', 'El Calvario',
     'Un minuto entero sin nadie hablando delante del paso. [demo-ss]',
     'DEMO-SS Jesús del Gran Poder', 37.3978, -5.9959, now() - interval '45 seconds');

    -- Rastros (varias posiciones de la misma hermandad → línea en el mapa)
    insert into public.ss_live_updates (
      user_id, kind, hermandad_label, message, place_label, latitude, longitude, created_at
    ) values
    (u_pepe, 'posicion', 'La Esperanza de Triana',
     'En Pureza, subiendo. [demo-ss]',
     'DEMO-SS Pureza', 37.3835, -6.0024, now() - interval '100 minutes'),
    (u_antonio, 'posicion', 'La Esperanza de Triana',
     'Altozano, hacia el puente. [demo-ss]',
     'DEMO-SS Altozano', 37.3850, -6.0010, now() - interval '90 minutes'),
    (u_manolo, 'posicion', 'Jesús del Gran Poder',
     'San Lorenzo, salida. [demo-ss]',
     'DEMO-SS San Lorenzo', 37.3992, -5.9969, now() - interval '55 minutes'),
    (u_rafa, 'posicion', 'Jesús del Gran Poder',
     'Subiendo hacia Campana. [demo-ss]',
     'DEMO-SS Jesús del Gran Poder', 37.3960, -5.9955, now() - interval '40 minutes'),
    (u_diego, 'posicion', 'Jesús del Gran Poder',
     'Ya en Campana. [demo-ss]',
     'DEMO-SS Campana', 37.3928, -5.9945, now() - interval '25 minutes'),
    (u_elena, 'posicion', 'Santa Marta',
     'Plaza Nueva. [demo-ss]',
     'DEMO-SS Plaza Nueva', 37.3880, -5.9955, now() - interval '55 minutes');

    -- Engagement demo (reacciones + respuestas) si existen las tablas
    if to_regclass('public.ss_live_update_likes') is not null then
      delete from public.ss_live_update_likes l
      using public.ss_live_updates u
      where l.update_id = u.id
        and (u.message like '%[demo-ss]%' or u.place_label like 'DEMO-SS%');

      insert into public.ss_live_update_likes (update_id, user_id, reaction, created_at)
      select u.id, reactor, emoji, now() - (mins || ' minutes')::interval
      from (
        select id,
          row_number() over (order by created_at desc) as rn
        from public.ss_live_updates
        where message like '%[demo-ss]%'
        order by created_at desc
        limit 12
      ) u
      cross join lateral (
        values
          (1, u_maria, '❤️', 25),
          (1, u_pepe, '👏', 22),
          (2, u_lucia, '❤️', 20),
          (2, u_antonio, '🤗', 18),
          (3, u_carmen, '👏', 16),
          (3, u_manolo, '❤️', 14),
          (4, u_isa, '😢', 12),
          (5, u_rafa, '❤️', 10),
          (5, u_pilar, '👏', 8),
          (6, u_juan, '❤️', 6)
      ) as r(target_rn, reactor, emoji, mins)
      where u.rn = r.target_rn
        and r.reactor is not null
      on conflict do nothing;
    end if;

    if to_regclass('public.ss_live_update_replies') is not null then
      delete from public.ss_live_update_replies r
      using public.ss_live_updates u
      where r.update_id = u.id
        and (u.message like '%[demo-ss]%' or u.place_label like 'DEMO-SS%');

      insert into public.ss_live_update_replies (update_id, user_id, message, created_at)
      select u.id, author, body, now() - (mins || ' minutes')::interval
      from (
        select id,
          row_number() over (order by created_at desc) as rn
        from public.ss_live_updates
        where message like '%[demo-ss]%'
        order by created_at desc
        limit 8
      ) u
      cross join lateral (
        values
          (1, u_pepe, 'Confirmado, estoy ahí y se nota.', 20),
          (1, u_maria, 'Gracias por el aviso.', 12),
          (2, u_lucia, 'Voy hacia allí ahora.', 18),
          (3, u_antonio, 'Desde aquí también se ve el retraso.', 15),
          (4, u_carmen, 'Qué bonito. Gracias.', 10),
          (5, u_diego, 'Cuidado con el viento en esa zona.', 8)
      ) as r(target_rn, author, body, mins)
      where u.rn = r.target_rn
        and r.author is not null;
    end if;
  end if;

  if exists (select 1 from pg_proc where proname = 'refresh_forum_pillar_stats') then
    perform public.refresh_forum_pillar_stats('foro-cofradiero');
  end if;

  raise notice 'Semana Santa demo cargada: temas demo-topic-ss-*, replies y avisos ss_live_updates.';
end $$;
