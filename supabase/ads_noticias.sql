-- Banner anclado en Noticias (encima de la barra inferior).
-- Placement: noticias · mismo formato que forums_top (1200×276).
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
      'noticias'
    )
  );
