-- Color de acento del panel web de hermandad (persistente en la cuenta).
-- Ejecutar en SQL Editor de Supabase.

alter table public.profiles
  add column if not exists panel_accent text
  check (
    panel_accent is null
    or panel_accent ~ '^#[0-9a-fA-F]{6}$'
  );

comment on column public.profiles.panel_accent is
  'Color de acento (#RRGGBB) del panel privado web de la hermandad.';
