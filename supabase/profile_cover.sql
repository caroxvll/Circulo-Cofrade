-- Portada personalizable del perfil (header).
-- Reutiliza el bucket `avatars` con ruta `{userId}/cover.*`
-- (mismas policies de carpeta por usuario).

alter table public.profiles
  add column if not exists cover_image_url text;

comment on column public.profiles.cover_image_url is
  'URL pública de la portada del perfil. Null = Fondoperfil por defecto.';
