-- Banner anclado en el en directo de Semana Santa (encima de la barra inferior).
-- Placement: semana_santa · mismo formato que noticias (1200×276).
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
      'hermandades',
      'featured_topic',
      'noticias',
      'semana_santa'
    )
  );
