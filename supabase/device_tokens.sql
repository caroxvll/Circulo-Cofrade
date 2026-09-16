-- Cofradero · tokens FCM por dispositivo (Fase 9a)
-- Ejecutar si ya tienes notification_social.sql (notification_preferences ya existe).
-- Ver docs/PUSH_FCM.md

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  fcm_token text not null unique,
  platform text not null check (platform in ('ios', 'android', 'web')),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_id_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

drop policy if exists "Usuario gestiona sus tokens FCM" on public.device_tokens;
create policy "Usuario gestiona sus tokens FCM"
  on public.device_tokens for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
