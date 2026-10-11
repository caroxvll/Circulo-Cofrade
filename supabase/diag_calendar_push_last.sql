-- Diagnóstico: último aviso de calendario → FCM
-- Ejecutar en SQL Editor y pegar el JSON.

select jsonb_pretty(
  jsonb_build_object(
    'dispatch_job', (
      select to_jsonb(j)
      from public.notification_dispatch_jobs j
      where j.kind = 'calendar_broadcast'
         or j.notif_type = 'calendar'
      order by j.created_at desc
      limit 1
    ),
    'notifications', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', n.id,
        'user_id', n.user_id,
        'handle', p.handle,
        'title', n.title,
        'subtitle', n.subtitle,
        'created_at', n.created_at
      ) order by n.created_at desc)
      from public.notifications n
      left join public.profiles p on p.id = n.user_id
      where n.type = 'calendar'
        and n.created_at > now() - interval '2 hours'
    ), '[]'::jsonb),
    'push_jobs', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', j.id,
        'user_id', j.user_id,
        'handle', p.handle,
        'status', j.status,
        'error', j.last_error,
        'type', j.type,
        'title', j.title,
        'created_at', j.created_at,
        'updated_at', j.updated_at
      ) order by j.created_at desc)
      from public.push_delivery_jobs j
      left join public.profiles p on p.id = j.user_id
      where j.type = 'calendar'
        and j.created_at > now() - interval '2 hours'
    ), '[]'::jsonb),
    'prefs_of_recipients', coalesce((
      select jsonb_agg(jsonb_build_object(
        'handle', p.handle,
        'push_enabled', pref.push_enabled,
        'notify_calendar', pref.notify_calendar,
        'tokens', (
          select count(*)::int
          from public.device_tokens t
          where t.user_id = p.id
        )
      ))
      from public.notifications n
      join public.profiles p on p.id = n.user_id
      left join public.notification_preferences pref on pref.user_id = p.id
      where n.type = 'calendar'
        and n.created_at > now() - interval '2 hours'
    ), '[]'::jsonb)
  )
);
