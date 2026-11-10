-- Tipo de calendario «desarma» para el desmonte del paso.
-- Ejecutar en el SQL Editor después de calendar_event_types_muda_retranqueo.sql.

do $$
declare
  r record;
begin
  for r in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'calendar_events'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%event_type%'
  loop
    execute format(
      'alter table public.calendar_events drop constraint %I',
      r.conname
    );
  end loop;
end $$;

alter table public.calendar_events
  add constraint calendar_events_event_type_check
  check (
    event_type in (
      'procesion',
      'gloria',
      'ensayo',
      'iguala',
      'concierto',
      'evento',
      'culto',
      'besamanos',
      'quinario',
      'triduo',
      'pregon',
      'traslado',
      'muda',
      'desarma',
      'retranqueo',
      'via_crucis',
      'via_crucis_consejo'
    )
  );

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_calendar_type_check;

alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_calendar_type_check
  check (
    calendar_event_type is null
    or calendar_event_type in (
      'procesion',
      'gloria',
      'ensayo',
      'iguala',
      'concierto',
      'evento',
      'culto',
      'besamanos',
      'quinario',
      'triduo',
      'pregon',
      'traslado',
      'muda',
      'desarma',
      'retranqueo',
      'via_crucis',
      'via_crucis_consejo'
    )
  );

create or replace function public.can_post_event_live_update(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.calendar_events e
    where e.id = p_event_id
      and e.status = 'published'
      and e.event_type in (
        'ensayo',
        'iguala',
        'procesion',
        'concierto',
        'gloria',
        'evento',
        'culto',
        'besamanos',
        'quinario',
        'triduo',
        'pregon',
        'traslado',
        'muda',
        'desarma',
        'retranqueo',
        'via_crucis',
        'via_crucis_consejo'
      )
      and (
        e.live_force_state = 'open'
        or (
          e.live_force_state = 'auto'
          and (
            (
              e.starts_at <= now()
              and coalesce(
                e.ends_at,
                e.starts_at + case e.event_type
                  when 'procesion' then interval '4 hours'
                  when 'ensayo' then interval '4 hours'
                  when 'iguala' then interval '4 hours'
                  when 'gloria' then interval '2 hours'
                  when 'concierto' then interval '2 hours'
                  else interval '2 hours'
                end
              ) > now()
            )
            or exists (
              select 1
              from jsonb_array_elements(coalesce(e.time_slots, '[]'::jsonb)) as slot
              where jsonb_typeof(slot) = 'object'
                and (slot->>'start') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
                and (
                  (timezone('Europe/Madrid', e.starts_at))::date
                    + (slot->>'start')::time
                ) <= timezone('Europe/Madrid', now())
                and timezone('Europe/Madrid', now()) < (
                  (timezone('Europe/Madrid', e.starts_at))::date
                  + coalesce(
                      case
                        when (slot->>'end') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
                          and (slot->>'end') > (slot->>'start')
                        then (slot->>'end')::time
                        else null
                      end,
                      (slot->>'start')::time + case e.event_type
                        when 'procesion' then interval '4 hours'
                        when 'ensayo' then interval '4 hours'
                        when 'iguala' then interval '4 hours'
                        else interval '2 hours'
                      end
                    )
                )
            )
          )
        )
      )
  );
$$;

grant execute on function public.can_post_event_live_update(uuid) to authenticated;
