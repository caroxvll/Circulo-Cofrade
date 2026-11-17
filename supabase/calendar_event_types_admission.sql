-- Culto, besamanos, quinario, triduo, pregón y traslado, más la entrada.
-- Ejecutar en el SQL Editor de Supabase.

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
      'traslado'
    )
  );

alter table public.calendar_events
  add column if not exists admission_label text;

alter table public.calendar_events
  drop constraint if exists calendar_events_admission_label_check;

alter table public.calendar_events
  add constraint calendar_events_admission_label_check
  check (
    admission_label is null
    or char_length(btrim(admission_label)) between 1 and 40
  );

comment on column public.calendar_events.admission_label is
  'Texto corto de entrada, si la hay: "12 €", "Desde 8 €", "Donativo". Null = no se muestra.';

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
      'traslado'
    )
  );

-- El directo también vale para culto, pregón y traslado.
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
          and e.starts_at <= now()
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
      )
  );
$$;

grant execute on function public.can_post_event_live_update(uuid) to authenticated;
