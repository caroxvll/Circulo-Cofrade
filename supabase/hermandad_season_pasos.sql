-- Pasos de la hermandad: 1 (Cristo o Virgen), 2 (Cristo+Virgen) o 3 (2 Cristos + Virgen).
-- Ejecutar en SQL Editor (PRE y PROD).

alter table public.calendar_events
  drop constraint if exists calendar_events_paso_check;
alter table public.calendar_events
  add constraint calendar_events_paso_check
  check (paso in ('ambos', 'cristo', 'cristo2', 'virgen'));

comment on column public.calendar_events.paso is
  'Paso del acto: ambos, cristo, cristo2 o virgen.';

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_calendar_paso_check;
alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_calendar_paso_check
  check (
    calendar_paso is null
    or calendar_paso in ('ambos', 'cristo', 'cristo2', 'virgen')
  );

alter table public.hermandad_season_profile
  add column if not exists pasos_layout text not null default 'cristo_virgen';

alter table public.hermandad_season_profile
  drop constraint if exists hermandad_season_profile_pasos_layout_check;
alter table public.hermandad_season_profile
  add constraint hermandad_season_profile_pasos_layout_check
  check (
    pasos_layout in ('cristo', 'virgen', 'cristo_virgen', 'dos_cristos_virgen')
  );

comment on column public.hermandad_season_profile.pasos_layout is
  'Pasos de la cofradía: un Cristo, una Virgen, Cristo+Virgen o dos Cristos y Virgen.';

notify pgrst, 'reload schema';
