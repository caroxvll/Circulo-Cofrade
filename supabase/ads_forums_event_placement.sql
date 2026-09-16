-- Añade el placement forums_event (evento patrocinado en listados de foro).
-- Ejecutar en Supabase → SQL Editor.

alter table public.ads drop constraint if exists ads_placement_check;

alter table public.ads
  add constraint ads_placement_check check (
    placement in (
      'home',
      'forums_top',
      'forums_middle',
      'forums_event',
      'calendar',
      'search',
      'profile',
      'hermandades'
    )
  );
