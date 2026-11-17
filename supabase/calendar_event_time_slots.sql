-- Varios tramos horarios en el mismo día de un evento.
-- Ejecutar en el SQL Editor de Supabase, después de calendar_event_types_admission.sql.

alter table public.calendar_events
  add column if not exists time_slots jsonb;

alter table public.calendar_events
  drop constraint if exists calendar_events_time_slots_check;

alter table public.calendar_events
  add constraint calendar_events_time_slots_check
  check (
    time_slots is null
    or (
      jsonb_typeof(time_slots) = 'array'
      and jsonb_array_length(time_slots) between 1 and 6
    )
  );

comment on column public.calendar_events.time_slots is
  'Tramos del mismo día que starts_at (Europe/Madrid). Cada elemento: {"start":"HH:MM","end":"HH:MM"}. end es opcional. Null = una sola hora, la de starts_at.';

-- El directo también vale dentro de un tramo posterior.
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
        'traslado'
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
