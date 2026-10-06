-- Perfil público / privado + portada personalizable.
alter table public.profiles
  add column if not exists is_private boolean not null default false;

alter table public.profiles
  add column if not exists cover_image_url text;

comment on column public.profiles.is_private is
  'Si true, solo seguidores (y el dueño) ven temas, info y red social del perfil.';

comment on column public.profiles.cover_image_url is
  'URL pública de la portada del perfil. Null = imagen por defecto de la app.';
