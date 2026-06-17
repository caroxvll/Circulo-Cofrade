-- Cofradero · tablas para push FCM (Fase 9)
-- Ejecutar cuando implementes Firebase Cloud Messaging.
-- Ver docs/NOTIFICACIONES.md

-- Tokens FCM por dispositivo
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  fcm_token text not null,
  platform text not null check (platform in ('ios', 'android', 'web')),
  updated_at timestamptz not null default now(),
  unique (user_id, fcm_token)
);

alter table public.device_tokens enable row level security;

create policy "Usuario gestiona sus tokens FCM"
  on public.device_tokens for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Preferencias de notificación
create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  notify_hashtags boolean not null default true,
  notify_profiles boolean not null default true,
  notify_mentions boolean not null default true,
  notify_followers boolean not null default false,
  notify_topics boolean not null default true,
  notify_calendar boolean not null default false,
  push_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

create policy "Usuario lee y edita sus preferencias"
  on public.notification_preferences for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Crear preferencias por defecto al registrar perfil
create or replace function public.handle_new_profile_preferences()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_profile_created_preferences on public.profiles;
create trigger on_profile_created_preferences
  after insert on public.profiles
  for each row execute function public.handle_new_profile_preferences();
