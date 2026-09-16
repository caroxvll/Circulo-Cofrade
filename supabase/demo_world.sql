  -- Cofradeo · mundo DEMO (simulación) — SOLO PRE / entornos de prueba
  -- Ejecutar en el SQL Editor del proyecto PRE (no en producción).
  --
  -- Activa herramientas de simulación + RPCs:
  --   get_demo_world_status()
  --   seed_demo_world()
  --   wipe_demo_world()
  --
  -- Convención de seguridad:
  --   · Usuarios: email *@demo.cofradeo.local + metadata is_demo + handle demo_*
  --   · Temas: id demo-topic-*
  --   · Eventos: created_by de usuarios demo
  --   · Flag app_config.demo_tools_enabled = 'true' (texto; obligatorio)
  -- El wipe SOLO borra lo marcado como demo. Nunca toca tu admin real.

  create extension if not exists pgcrypto;

insert into public.app_config (key, value)
values ('demo_tools_enabled', 'true')
on conflict (key) do update
set value = 'true',
    updated_at = now();

create or replace function public.demo_tools_are_enabled()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select lower(trim(value)) in ('true', '1', 'yes', 'on')
      from public.app_config
      where key = 'demo_tools_enabled'
    ),
    false
  );
$$;

  create or replace function public.assert_demo_tools_admin()
  returns void
  language plpgsql
  security definer
  set search_path = public
  as $$
  begin
    if auth.uid() is null or not public.is_admin_user(auth.uid()) then
      raise exception 'Solo administradores';
    end if;
    if not public.demo_tools_are_enabled() then
      raise exception
        'Simulación desactivada. En PRE ejecuta demo_world.sql (flag demo_tools_enabled). Nunca en prod.';
    end if;
  end;
  $$;

  -- ---------------------------------------------------------------------------
  -- Helper: crear usuario auth + identidad (dispara trigger → profiles)
  -- ---------------------------------------------------------------------------
create or replace function public._demo_create_user(
  p_handle text,
  p_display_name text,
  p_email text,
  p_password text default 'Demo1234!'
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_id uuid := gen_random_uuid();
  v_encrypted text;
  v_instance uuid := '00000000-0000-0000-0000-000000000000';
begin
  if exists (select 1 from public.profiles where handle = p_handle) then
    select id into v_id from public.profiles where handle = p_handle;
    return v_id;
  end if;

  if exists (select 1 from auth.users where lower(email) = lower(p_email)) then
    select id into v_id from auth.users where lower(email) = lower(p_email);
    update public.profiles
    set handle = p_handle,
        display_name = left(p_display_name, 40),
        updated_at = now()
    where id = v_id;
    return v_id;
  end if;

  begin
    v_encrypted := extensions.crypt(p_password, extensions.gen_salt('bf'));
  exception
    when undefined_function then
      v_encrypted := crypt(p_password, gen_salt('bf'));
  end;

  begin
    select instance_id into v_instance from auth.users where instance_id is not null limit 1;
  exception when others then
    v_instance := '00000000-0000-0000-0000-000000000000';
  end;
  if v_instance is null then
    v_instance := '00000000-0000-0000-0000-000000000000';
  end if;

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change
  ) values (
    v_instance,
    v_id,
    'authenticated',
    'authenticated',
    lower(p_email),
    v_encrypted,
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'handle', p_handle,
      'display_name', p_display_name,
      'is_demo', true
    ),
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

  begin
    insert into auth.identities (
      id,
      user_id,
      identity_data,
      provider,
      provider_id,
      last_sign_in_at,
      created_at,
      updated_at
    ) values (
      gen_random_uuid(),
      v_id,
      jsonb_build_object(
        'sub', v_id::text,
        'email', lower(p_email),
        'email_verified', true
      ),
      'email',
      lower(p_email),
      now(),
      now(),
      now()
    );
  exception
    when others then
      -- Algunas versiones no tienen provider_id o usan otro esquema
      begin
        insert into auth.identities (
          id,
          user_id,
          identity_data,
          provider,
          last_sign_in_at,
          created_at,
          updated_at
        ) values (
          gen_random_uuid(),
          v_id,
          jsonb_build_object('sub', v_id::text, 'email', lower(p_email)),
          'email',
          now(),
          now(),
          now()
        );
      exception
        when others then
          null; -- perfil basta para ver contenido; login demo opcional
      end;
  end;

  update public.profiles
  set handle = p_handle,
      display_name = left(p_display_name, 40),
      role = 'member',
      updated_at = now()
  where id = v_id;

  if not found then
    insert into public.profiles (id, handle, display_name, role)
    values (v_id, p_handle, left(p_display_name, 40), 'member')
    on conflict (id) do update
    set handle = excluded.handle,
        display_name = excluded.display_name;
  end if;

  return v_id;
exception
  when others then
    raise exception 'Demo user % (%): %', p_handle, p_email, sqlerrm
      using errcode = sqlstate;
end;
$$;

  -- ---------------------------------------------------------------------------
  -- Status
  -- ---------------------------------------------------------------------------
  create or replace function public.get_demo_world_status()
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = public, auth
  as $$
  declare
    v_demo_users int;
    v_demo_topics int;
    v_demo_replies int;
    v_demo_events int;
  begin
    perform public.assert_demo_tools_admin();

    select count(*)::int into v_demo_users
    from public.profiles
    where handle like 'demo_%';

    select count(*)::int into v_demo_topics
    from public.forum_topics
    where id like 'demo-topic-%';

    select count(*)::int into v_demo_replies
    from public.forum_replies r
    join public.profiles p on p.id = r.author_id
    where p.handle like 'demo_%'
      or r.topic_id like 'demo-topic-%';

    select count(*)::int into v_demo_events
    from public.calendar_events e
    join public.profiles p on p.id = e.created_by
    where p.handle like 'demo_%';

    return jsonb_build_object(
      'enabled', public.demo_tools_are_enabled(),
      'demoUsers', v_demo_users,
      'demoTopics', v_demo_topics,
      'demoReplies', v_demo_replies,
      'demoEvents', v_demo_events,
      'seeded', v_demo_users > 0
    );
  end;
  $$;

  -- ---------------------------------------------------------------------------
  -- Wipe (solo demo)
  -- ---------------------------------------------------------------------------
  create or replace function public.wipe_demo_world()
  returns jsonb
  language plpgsql
  security definer
  set search_path = public, auth
  as $$
  declare
    v_user_ids uuid[];
    v_topics int := 0;
    v_replies int := 0;
    v_events int := 0;
    v_users int := 0;
    v_likes int := 0;
    v_follows int := 0;
  begin
    perform public.assert_demo_tools_admin();
    perform set_config('row_security', 'off', true);

    select coalesce(array_agg(id), '{}'::uuid[])
    into v_user_ids
    from public.profiles
    where handle like 'demo_%';

    -- Likes / reacciones
    delete from public.forum_topic_likes
    where topic_id like 'demo-topic-%'
      or user_id = any (v_user_ids);
    get diagnostics v_likes = row_count;

    if to_regclass('public.forum_reply_likes') is not null then
      delete from public.forum_reply_likes
      where user_id = any (v_user_ids)
        or reply_id in (
          select r.id from public.forum_replies r
          where r.topic_id like 'demo-topic-%'
              or r.author_id = any (v_user_ids)
        );
    end if;

    -- Respuestas demo
    delete from public.forum_replies
    where topic_id like 'demo-topic-%'
      or author_id = any (v_user_ids);
    get diagnostics v_replies = row_count;

    -- Temas demo
    delete from public.forum_topics
    where id like 'demo-topic-%'
      or author_id = any (v_user_ids);
    get diagnostics v_topics = row_count;

    -- Eventos demo
    delete from public.calendar_events
    where created_by = any (v_user_ids);
    get diagnostics v_events = row_count;

    -- Follows / notificaciones / tokens de demo
    delete from public.follows
    where follower_id = any (v_user_ids)
      or (target_type = 'profile' and target_id = any (
        select unnest(v_user_ids)::text
      ))
      or (target_type = 'topic' and target_id like 'demo-topic-%');
    get diagnostics v_follows = row_count;

    delete from public.notifications where user_id = any (v_user_ids);

    if to_regclass('public.device_tokens') is not null then
      delete from public.device_tokens where user_id = any (v_user_ids);
    end if;

    if to_regclass('public.notification_preferences') is not null then
      delete from public.notification_preferences where user_id = any (v_user_ids);
    end if;

    -- Auth users demo (CASCADE limpia profiles)
    delete from auth.users
    where id = any (v_user_ids)
      or coalesce(raw_user_meta_data ->> 'is_demo', '') = 'true'
      or email ilike '%@demo.cofradeo.local';
    get diagnostics v_users = row_count;

    -- Contadores de pilares
    if exists (
      select 1 from pg_proc where proname = 'refresh_forum_pillar_stats'
    ) then
      perform public.refresh_forum_pillar_stats(id)
      from public.forum_pillars
      where id in (
        'foro-cofradiero',
        'pentagrama-cofrade',
        'martillo-trabajadera',
        'noticias'
      );
    end if;

    return jsonb_build_object(
      'ok', true,
      'usersDeleted', v_users,
      'topicsDeleted', v_topics,
      'repliesDeleted', v_replies,
      'eventsDeleted', v_events,
      'likesDeleted', v_likes,
      'followsDeleted', v_follows
    );
  end;
  $$;

  -- ---------------------------------------------------------------------------
  -- Seed
  -- ---------------------------------------------------------------------------
  create or replace function public.seed_demo_world()
  returns jsonb
  language plpgsql
  security definer
  set search_path = public, auth
  as $$
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
    v_status jsonb;
  begin
    perform public.assert_demo_tools_admin();
    perform set_config('row_security', 'off', true);

    -- Si ya hay demo, limpiar y volver a cargar
    if exists (select 1 from public.profiles where handle like 'demo_%') then
      perform public.wipe_demo_world();
    end if;

    u_maria := public._demo_create_user('demo_maria', 'María del Rocío', 'demo_maria@demo.cofradeo.local');
    u_pepe := public._demo_create_user('demo_pepe', 'Pepe Costalero', 'demo_pepe@demo.cofradeo.local');
    u_lucia := public._demo_create_user('demo_lucia', 'Lucía Bandera', 'demo_lucia@demo.cofradeo.local');
    u_antonio := public._demo_create_user('demo_antonio', 'Antonio Capataz', 'demo_antonio@demo.cofradeo.local');
    u_carmen := public._demo_create_user('demo_carmen', 'Carmen Nazarena', 'demo_carmen@demo.cofradeo.local');
    u_manolo := public._demo_create_user('demo_manolo', 'Manolo del Paso', 'demo_manolo@demo.cofradeo.local');
    u_isa := public._demo_create_user('demo_isa', 'Isa Campanillero', 'demo_isa@demo.cofradeo.local');
    u_rafa := public._demo_create_user('demo_rafa', 'Rafa Tambor', 'demo_rafa@demo.cofradeo.local');
    u_pilar := public._demo_create_user('demo_pilar', 'Pilar Cofrade', 'demo_pilar@demo.cofradeo.local');
    u_juan := public._demo_create_user('demo_juan', 'Juan de Sevilla', 'demo_juan@demo.cofradeo.local');
    u_elena := public._demo_create_user('demo_elena', 'Elena Gloria', 'demo_elena@demo.cofradeo.local');
    u_diego := public._demo_create_user('demo_diego', 'Diego Silencio', 'demo_diego@demo.cofradeo.local');

    -- Preferencias push ON (sin device tokens → no spam FCM)
    insert into public.notification_preferences (user_id, push_enabled)
    select x, true
    from unnest(array[
      u_maria, u_pepe, u_lucia, u_antonio, u_carmen, u_manolo,
      u_isa, u_rafa, u_pilar, u_juan, u_elena, u_diego
    ]) as t(x)
    on conflict (user_id) do update set push_enabled = true;

    -- Temas publicados
    insert into public.forum_topics (
      id, forum_id, author_id, author_handle, title, excerpt, body,
      status, view_count, comment_count, created_at
    ) values
    (
      'demo-topic-001', 'foro-cofradiero', u_maria, 'demo_maria',
      '¿Cómo veis la carrera oficial este año?',
      'Debate abierto sobre tiempos y afluencia en carrera oficial.',
      'Abrimos hilo para comentar sensaciones de la carrera oficial: horarios, público y ambiente. ¿Qué os ha llamado más la atención?',
      'published', 128, 0, now() - interval '2 days'
    ),
    (
      'demo-topic-002', 'foro-cofradiero', u_pepe, 'demo_pepe',
      'Mejores momentos del Viernes Santo',
      'Recopilamos vivencias del Viernes Santo en Sevilla.',
      'Dejad vuestras fotos mentales: una calle, un silencio, un instante. Sin polémicas, solo cofradía.',
      'published', 86, 0, now() - interval '36 hours'
    ),
    (
      'demo-topic-003', 'pentagrama-cofrade', u_lucia, 'demo_lucia',
      'Marchas imprescindibles para Cuaresma',
      'Lista colaborativa de marchas que no pueden faltar.',
      'Proponed marchas (título + agrupación/banda). Intentamos hacer una lista viva para novatos y veteranos.',
      'published', 64, 0, now() - interval '30 hours'
    ),
    (
      'demo-topic-004', 'martillo-trabajadera', u_antonio, 'demo_antonio',
      'Consejos para costaleros primerizos',
      'Trucos de cuadrilla, hidratación y respeto al paso.',
      'Si es tu primera Cuaresma bajo trabajadera, cuéntanos qué te hubiera gustado saber el día uno.',
      'published', 210, 0, now() - interval '5 days'
    ),
    (
      'demo-topic-005', 'foro-cofradiero', u_carmen, 'demo_carmen',
      'Cultos de preparación: ¿cuáles no os perdéis?',
      'Besamanos, triduos y cultos de hermandad.',
      'Compartid cultos que merecen la pena visitar aunque no seáis hermanos. Ambiente, música y recogimiento.',
      'published', 55, 0, now() - interval '20 hours'
    ),
    (
      'demo-topic-006', 'foro-cofradiero', u_manolo, 'demo_manolo',
      'Rutas alternativas para ver pasos sin agobios',
      'Calles tranquilas y rincones con buena vista.',
      'Para familias y gente que evita la masa: ¿qué tramos recomendáis?',
      'published', 97, 0, now() - interval '12 hours'
    ),
    (
      'demo-topic-007', 'pentagrama-cofrade', u_rafa, 'demo_rafa',
      'Cornetas y tambores: ensayos abiertos',
      '¿Conocéis ensayos a los que se pueda asistir?',
      'Buscamos ensayos con buena acústica donde se note el trabajo de la agrupación.',
      'published', 41, 0, now() - interval '8 hours'
    ),
  (
    'demo-topic-008', 'foro-cofradiero', u_juan, 'demo_juan',
    'Tema pendiente de ejemplo (Junta)',
    'Este tema queda pendiente a propósito para probar la cola.',
    'Contenido de prueba: la Junta debería verlo en Temas pendientes.',
    'pending', 3, 0, now() - interval '1 hour'
  )
  on conflict (id) do nothing;

  -- Asegura el hub sistema Cuaresma (por si faltó pinned_topics)
  insert into public.forum_topics (
    id, forum_id, author_handle, title, excerpt, body,
    is_resolved, view_count, comment_count, status,
    is_pinned, pin_sort_order, is_system, season_key, icon_key, created_at
  ) values (
    'circulo-cuaresma', 'foro-cofradiero', '@cofradeo',
    'Cuaresma',
    'Cultos, estaciones, pregones y camino hacia la Semana Mayor.',
    'Espacio para hablar de la Cuaresma: cultos, estaciones de penitencia, pregones, cartelería y camino hacia la Semana Mayor.\n\nComparte noticias, dudas y conversación con la comunidad cofrade.',
    false, 0, 0, 'published',
    true, 1, true, 'cuaresma', 'filter_vintage_outlined', now() - interval '30 days'
  )
  on conflict (id) do update set
    status = 'published',
    is_system = true,
    season_key = 'cuaresma',
    is_pinned = true;

  -- Temas comunidad del apartado Cuaresma (season_key = cuaresma, no sistema)
  insert into public.forum_topics (
    id, forum_id, author_id, author_handle, title, excerpt, body,
    status, season_key, is_system, is_pinned, view_count, comment_count, created_at
  ) values
  (
    'demo-topic-cuaresma-01', 'foro-cofradiero', u_maria, 'demo_maria',
    'Estaciones de penitencia: ¿cuál os ha marcado más?',
    'Compartid vivencias de estaciones en Cuaresma.',
    'Abrimos hilo para hablar de estaciones de penitencia: ambiente, música, silencios y detalles que se os quedan grabados.',
    'published', 'cuaresma', false, false, 74, 0, now() - interval '2 days'
  ),
  (
    'demo-topic-cuaresma-02', 'foro-cofradiero', u_carmen, 'demo_carmen',
    'Pregones y cartelería de este año',
    'Recomendaciones de pregones y carteles de Cuaresma.',
    '¿Qué pregón no os perderíais? ¿Qué cartel os ha gustado más? Dejad enlaces o sitios donde verlos.',
    'published', 'cuaresma', false, false, 52, 0, now() - interval '28 hours'
  ),
  (
    'demo-topic-cuaresma-03', 'foro-cofradiero', u_antonio, 'demo_antonio',
    'Ensayos de cuadrilla: horarios y tips',
    'Organización de ensayos en Cuaresma.',
    'Para costaleros y aficionados: cómo organizáis los ensayos de Cuaresma, hidratación, y qué avisos dais a la cuadrilla.',
    'published', 'cuaresma', false, false, 91, 0, now() - interval '20 hours'
  ),
  (
    'demo-topic-cuaresma-04', 'foro-cofradiero', u_pepe, 'demo_pepe',
    'Cultos de preparación que merecen la pena',
    'Triduos, quinarios y cultos con buen ambiente.',
    'Lista viva de cultos de Cuaresma recomendables aunque no seáis hermanos. Ambiente, música y recogimiento.',
    'published', 'cuaresma', false, false, 63, 0, now() - interval '14 hours'
  ),
  (
    'demo-topic-cuaresma-05', 'foro-cofradiero', u_lucia, 'demo_lucia',
    'Marchas que suenan en los ensayos de Cuaresma',
    'Repertorio típico de estos días.',
    '¿Qué marchas estáis oyendo más en ensayos y cultos esta Cuaresma? Cornetas, bandas y agrupaciones.',
    'published', 'cuaresma', false, false, 48, 0, now() - interval '8 hours'
  ),
  (
    'demo-topic-cuaresma-06', 'foro-cofradiero', u_manolo, 'demo_manolo',
    'Avisos de última hora (Cuaresma)',
    'Cambios de ensayo, calles cortadas, imprevistos.',
    'Hilo rápido para avisos de Cuaresma: cambios de hora, lluvia, desvíos. Sed claros y respetuosos.',
    'published', 'cuaresma', false, false, 35, 0, now() - interval '3 hours'
  )
  on conflict (id) do nothing;

    -- Respuestas
    insert into public.forum_replies (topic_id, author_id, author_handle, content, created_at)
    values
    ('demo-topic-001', u_pepe, 'demo_pepe',
    'La Campana a las 7 de la mañana tenía un silencio especial. Se te pone la piel de gallina.', now() - interval '40 hours'),
    ('demo-topic-001', u_lucia, 'demo_lucia',
    'A mí me gusta más la tarde: el contraste de la luz con el palio es brutal.', now() - interval '38 hours'),
    ('demo-topic-001', u_carmen, 'demo_carmen',
    'Ojo con el tramo de Placentines; este año venía muy justo de tiempo.', now() - interval '30 hours'),
    ('demo-topic-002', u_maria, 'demo_maria',
    'El silencio de la Madrugá en la calle Pureza… eso no se explica, se vive.', now() - interval '28 hours'),
    ('demo-topic-002', u_diego, 'demo_diego',
    'Cuando apagan las luces y solo queda la cera. Ese es mi momento.', now() - interval '26 hours'),
    ('demo-topic-003', u_isa, 'demo_isa',
    '«Amarguras» y «La Saeta» siempre. Para Cuaresma también metería «Pasa la Virgen María».', now() - interval '22 hours'),
    ('demo-topic-003', u_rafa, 'demo_rafa',
    'Sin olvidar las de cornetas: el cambio de tercio en un arco estrecho es magia.', now() - interval '18 hours'),
    ('demo-topic-004', u_manolo, 'demo_manolo',
    'Hidratación, calcetín bueno y no levantar la voz al capataz el primer día. Escucha.', now() - interval '4 days'),
    ('demo-topic-004', u_antonio, 'demo_antonio',
    'Y pregunta sin miedo en la cuadrilla. Mejor una duda que una lesión.', now() - interval '3 days'),
    ('demo-topic-005', u_elena, 'demo_elena',
    'Los cultos de Gloria en mayo tienen una luz preciosa. Merecen más gente.', now() - interval '15 hours'),
    ('demo-topic-006', u_pilar, 'demo_pilar',
    'Alameda y alrededores temprano: menos gente y buen ambiente familiar.', now() - interval '10 hours'),
    ('demo-topic-006', u_juan, 'demo_juan',
    'Desde un balcón amigo en Feria se ve todo sin empujones. El contactazo vale oro.', now() - interval '9 hours'),
  ('demo-topic-007', u_lucia, 'demo_lucia',
   'Si avisáis ensayos, yo me apunto con la cámara (sin flash, claro).', now() - interval '6 hours'),
  ('demo-topic-cuaresma-01', u_pepe, 'demo_pepe',
   'La estación en San Lorenzo me dejó sin palabras. Silencio total.', now() - interval '36 hours'),
  ('demo-topic-cuaresma-01', u_carmen, 'demo_carmen',
   'A mí me marcó la de la madrugada: frío, incienso y la calle vacía.', now() - interval '30 hours'),
  ('demo-topic-cuaresma-02', u_lucia, 'demo_lucia',
   'El cartel de este año tiene una composición preciosa. Muy sobrio.', now() - interval '22 hours'),
  ('demo-topic-cuaresma-03', u_manolo, 'demo_manolo',
   'Ensayo corto pero intenso. Mejor calidad que cantidad con la cuadrilla joven.', now() - interval '16 hours'),
  ('demo-topic-cuaresma-04', u_elena, 'demo_elena',
   'El triduo del martes mereció la pena: templo lleno y buena música.', now() - interval '10 hours'),
  ('demo-topic-cuaresma-05', u_rafa, 'demo_rafa',
   'Cornetas ensayando al atardecer… se te pone la piel de gallina.', now() - interval '5 hours'),
  ('demo-topic-cuaresma-06', u_juan, 'demo_juan',
   'Aviso: ensayo de esta tarde adelantado media hora por la lluvia.', now() - interval '90 minutes');

    -- Contadores de comentarios (el trigger suma; recalculamos por si acaso)
    update public.forum_topics t
    set comment_count = (
      select count(*)::int from public.forum_replies r where r.topic_id = t.id
    )
    where t.id like 'demo-topic-%';

    -- Likes a temas
    insert into public.forum_topic_likes (topic_id, user_id, reaction)
    values
      ('demo-topic-001', u_pepe, '❤️'),
      ('demo-topic-001', u_lucia, '👏'),
      ('demo-topic-001', u_carmen, '❤️'),
      ('demo-topic-002', u_maria, '🤗'),
      ('demo-topic-002', u_diego, '❤️'),
      ('demo-topic-004', u_manolo, '👏'),
      ('demo-topic-004', u_isa, '❤️'),
    ('demo-topic-006', u_pilar, '❤️'),
    ('demo-topic-cuaresma-01', u_pepe, '❤️'),
    ('demo-topic-cuaresma-01', u_carmen, '👏'),
    ('demo-topic-cuaresma-03', u_isa, '❤️'),
    ('demo-topic-cuaresma-05', u_rafa, '🤗')
  on conflict do nothing;

    -- Follows entre demos
    insert into public.follows (follower_id, target_type, target_id)
    values
      (u_pepe, 'profile', u_maria::text),
      (u_lucia, 'profile', u_maria::text),
      (u_carmen, 'profile', u_antonio::text),
      (u_maria, 'topic', 'demo-topic-004'),
      (u_juan, 'topic', 'demo-topic-001'),
      (u_isa, 'hashtag', 'ViernesSanto'),
      (u_rafa, 'hashtag', 'Cuaresma')
    on conflict do nothing;

    -- Eventos calendario (el trigger exige admin/editor; lo saltamos solo en seed)
    alter table public.calendar_events disable trigger on_calendar_event_status;
    begin
      insert into public.calendar_events (
        title, subtitle, event_type, starts_at, location, organizer_label, created_by, status
      ) values
      (
        'Ensayo de costaleros (demo)',
        'Cuadrilla joven · plaza del barrio',
        'ensayo',
        now() + interval '3 days',
        'Sevilla · casco antiguo',
        'Cuadrilla demo',
        u_antonio,
        'published'
      ),
      (
        'Concierto de marchas (demo)',
        'Agrupación musical invitada',
        'concierto',
        now() + interval '6 days',
        'Iglesia de prueba',
        'Agrupación demo',
        u_lucia,
        'published'
      ),
      (
        'Besamanos (demo)',
        'Culto de preparación',
        'evento',
        now() + interval '10 days',
        'Templo demo',
        'Hermandad demo',
        u_carmen,
        'published'
      ),
      (
        'Procesión de gloria (demo)',
        'Salida extraordinaria de ejemplo',
        'gloria',
        now() + interval '20 days',
        'Centro',
        'Junta de simulación',
        u_elena,
        'published'
      ),
      (
        'Iguala pendiente (demo)',
        'Para probar cola de eventos',
        'iguala',
        now() + interval '4 days',
        'Local de hermandad',
        'Colaborador demo',
        u_juan,
        'pending_review'
      ),
      -- Ensayos de HOY → sección «En directo» del hub Cuaresma
      (
        'Ensayo general (demo · en curso)',
        'Cuadrilla · seguimiento en vivo Cuaresma',
        'ensayo',
        now() - interval '25 minutes',
        'Sevilla · Triana',
        'Cuadrilla demo',
        u_antonio,
        'published'
      ),
      (
        'Ensayo de bandera (demo · esta tarde)',
        'Sale en breve · Cuaresma',
        'ensayo',
        now() + interval '45 minutes',
        'Sevilla · centro',
        'Agrupación demo',
        u_lucia,
        'published'
      );
      alter table public.calendar_events enable trigger on_calendar_event_status;
    exception
      when others then
        alter table public.calendar_events enable trigger on_calendar_event_status;
        raise;
    end;

    -- Avisos en vivo del ensayo en curso (si existe la tabla)
    if to_regclass('public.event_live_updates') is not null then
      insert into public.event_live_updates (
        calendar_event_id, user_id, message, place_label, created_at
      )
      select e.id, u_antonio, 'Saliendo del local. Ambiente muy bueno.', 'Local de ensayo', now() - interval '20 minutes'
      from public.calendar_events e
      where e.title = 'Ensayo general (demo · en curso)'
        and e.created_by = u_antonio
      order by e.created_at desc
      limit 1;

      insert into public.event_live_updates (
        calendar_event_id, user_id, message, place_label, created_at
      )
      select e.id, u_pepe, 'Pasando por la plaza. Paso firme.', 'Plaza del barrio', now() - interval '8 minutes'
      from public.calendar_events e
      where e.title = 'Ensayo general (demo · en curso)'
        and e.created_by = u_antonio
      order by e.created_at desc
      limit 1;
    end if;

    if exists (
      select 1 from pg_proc where proname = 'refresh_forum_pillar_stats'
    ) then
      perform public.refresh_forum_pillar_stats(id)
      from public.forum_pillars
      where id in (
        'foro-cofradiero',
        'pentagrama-cofrade',
        'martillo-trabajadera'
      );
    end if;

    v_status := public.get_demo_world_status();
    return jsonb_build_object(
      'ok', true,
      'message', 'Simulación cargada (incluye apartado Cuaresma + ensayos de hoy). Ábrela con env.pre.json.',
      'status', v_status,
      'loginHint', 'Los usuarios demo usan contraseña Demo1234! (emails @demo.cofradeo.local)'
    );
  end;
  $$;

  revoke all on function public.demo_tools_are_enabled() from public;
  revoke all on function public.assert_demo_tools_admin() from public;
  revoke all on function public._demo_create_user(text, text, text, text) from public;
  revoke all on function public.get_demo_world_status() from public;
  revoke all on function public.wipe_demo_world() from public;
  revoke all on function public.seed_demo_world() from public;

  grant execute on function public.get_demo_world_status() to authenticated;
  grant execute on function public.wipe_demo_world() to authenticated;
  grant execute on function public.seed_demo_world() to authenticated;

  comment on function public.seed_demo_world() is
    'Carga usuarios/temas/respuestas/eventos DEMO. Requiere demo_tools_enabled + admin.';
  comment on function public.wipe_demo_world() is
    'Borra SOLO datos demo (handles demo_*, temas demo-topic-*, emails @demo.cofradeo.local).';
