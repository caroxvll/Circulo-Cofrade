-- Paso 3: ¿se creó el push job de Paco aunque ya no exista la notificación?
select jsonb_pretty(
  jsonb_build_object(
    'push_jobs_acto', coalesce((
      select jsonb_agg(to_jsonb(j) order by j.created_at)
      from public.push_delivery_jobs j
      where j.payload->>'replyId' = 'b427957f-7d14-41d3-8454-2a8117ff81ff'
         or j.payload->>'dedupeKey' = 'hermandad_reply:b427957f-7d14-41d3-8454-2a8117ff81ff'
    ), '[]'::jsonb),
    'push_jobs_paco_dia', coalesce((
      select jsonb_agg(to_jsonb(j) order by j.created_at desc)
      from public.push_delivery_jobs j
      where j.user_id = '03a57181-b397-4bc7-ab46-6a1a66bb6b2e'
        and j.created_at > '2026-10-11T00:00:00Z'
    ), '[]'::jsonb),
    'notifs_paco_any', (
      select count(*)::int
      from public.notifications
      where user_id = '03a57181-b397-4bc7-ab46-6a1a66bb6b2e'
    )
  )
);
