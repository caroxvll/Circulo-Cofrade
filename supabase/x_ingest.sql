-- Pulmón X de hermandades: cuentas, job (on/off + intervalo) y borradores.
-- SQL Editor · PRE y PROD.
-- Después:
--   npx supabase functions deploy x-ingest-pull
--   Dashboard → Edge Functions → x-ingest-pull → Secrets → X_BEARER_TOKEN
-- El cron (opcional) llama cada 5 min; la función respeta enabled + interval_minutes.

create table if not exists public.x_ingest_settings (
  id int primary key default 1 check (id = 1),
  enabled boolean not null default false,
  interval_minutes int not null default 60
    check (interval_minutes between 5 and 1440),
  max_posts_per_account int not null default 8
    check (max_posts_per_account between 1 and 20),
  last_run_at timestamptz,
  last_run_started_at timestamptz,
  last_run_status text,
  last_run_error text,
  last_run_new_posts int not null default 0,
  last_run_accounts int not null default 0,
  last_run_forced boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

insert into public.x_ingest_settings (id)
values (1)
on conflict (id) do nothing;

comment on table public.x_ingest_settings is
  'Job de ingesta X: apagado no corre solo; Lanzar ahora sí (force).';

create table if not exists public.x_ingest_accounts (
  id uuid primary key default gen_random_uuid(),
  topic_id text not null references public.forum_topics (id) on delete cascade,
  handle text not null,
  x_user_id text,
  since_id text,
  ingest_enabled boolean not null default true,
  last_error text,
  last_pulled_at timestamptz,
  last_capped boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (topic_id),
  unique (handle)
);

comment on column public.x_ingest_accounts.ingest_enabled is
  'Pausa una hermandad (p. ej. traslado) sin apagar el job global.';

create table if not exists public.x_ingest_drafts (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.x_ingest_accounts (id) on delete cascade,
  topic_id text not null references public.forum_topics (id) on delete cascade,
  handle text not null,
  x_post_id text not null,
  body text not null default '',
  source_url text,
  media jsonb not null default '[]'::jsonb,
  posted_at timestamptz,
  status text not null default 'pending'
    check (status in ('pending', 'published', 'discarded')),
  suggested_category text not null default 'noticia'
    check (suggested_category in ('noticia', 'culto', 'acto', 'patrimonio')),
  published_reply_id uuid,
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (x_post_id)
);

create index if not exists x_ingest_drafts_status_idx
  on public.x_ingest_drafts (status, created_at desc);

create index if not exists x_ingest_drafts_topic_idx
  on public.x_ingest_drafts (topic_id, status);

alter table public.x_ingest_settings enable row level security;
alter table public.x_ingest_accounts enable row level security;
alter table public.x_ingest_drafts enable row level security;

drop policy if exists "Admin lee ajustes X" on public.x_ingest_settings;
create policy "Admin lee ajustes X"
  on public.x_ingest_settings for select
  using (public.is_admin_user(auth.uid()));

drop policy if exists "Admin actualiza ajustes X" on public.x_ingest_settings;
create policy "Admin actualiza ajustes X"
  on public.x_ingest_settings for update
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "Admin lee cuentas X" on public.x_ingest_accounts;
create policy "Admin lee cuentas X"
  on public.x_ingest_accounts for select
  using (public.is_admin_user(auth.uid()));

drop policy if exists "Admin gestiona cuentas X" on public.x_ingest_accounts;
create policy "Admin gestiona cuentas X"
  on public.x_ingest_accounts for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "Admin lee borradores X" on public.x_ingest_drafts;
create policy "Admin lee borradores X"
  on public.x_ingest_drafts for select
  using (public.is_admin_user(auth.uid()));

drop policy if exists "Admin gestiona borradores X" on public.x_ingest_drafts;
create policy "Admin gestiona borradores X"
  on public.x_ingest_drafts for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

create or replace function public.x_ingest_normalize_handle(p_handle text)
returns text
language sql
immutable
as $$
  select lower(regexp_replace(coalesce(p_handle, ''), '^@+', ''));
$$;

create or replace function public.x_ingest_guard_account()
returns trigger
language plpgsql
as $$
begin
  new.handle := public.x_ingest_normalize_handle(new.handle);
  if length(new.handle) < 1 or length(new.handle) > 40 then
    raise exception 'Handle de X no válido';
  end if;
  if new.handle !~ '^[a-z0-9_]+$' then
    raise exception 'Handle de X no válido';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists x_ingest_accounts_guard on public.x_ingest_accounts;
create trigger x_ingest_accounts_guard
  before insert or update on public.x_ingest_accounts
  for each row execute function public.x_ingest_guard_account();

create or replace function public.x_ingest_publish_draft(
  p_draft_id uuid,
  p_topic_id text,
  p_category text,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_draft public.x_ingest_drafts%rowtype;
  v_author_id uuid;
  v_author_handle text;
  v_body text;
  v_image text;
  v_reply_id uuid;
  v_category text;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo un admin puede publicar borradores de X';
  end if;

  v_category := coalesce(nullif(trim(p_category), ''), 'noticia');
  if v_category not in ('noticia', 'culto', 'acto', 'patrimonio') then
    raise exception 'Sección no válida';
  end if;

  v_body := trim(coalesce(p_body, ''));
  if char_length(v_body) < 3 then
    raise exception 'Escribe al menos unas líneas de contenido';
  end if;
  if char_length(v_body) > 4000 then
    v_body := left(v_body, 3999);
  end if;

  select * into v_draft
  from public.x_ingest_drafts
  where id = p_draft_id
  for update;

  if not found then
    raise exception 'Borrador no encontrado';
  end if;
  if v_draft.status <> 'pending' then
    raise exception 'Este borrador ya no está pendiente';
  end if;

  select a.profile_id, p.handle
    into v_author_id, v_author_handle
  from public.hermandad_topic_accounts a
  join public.profiles p on p.id = a.profile_id
  where a.topic_id = p_topic_id
  order by a.created_at
  limit 1;

  if v_author_id is null then
    raise exception 'Ese tablón no tiene cuenta oficial de hermandad';
  end if;

  select elem ->> 'url'
    into v_image
  from jsonb_array_elements(coalesce(v_draft.media, '[]'::jsonb)) as elem
  where coalesce(elem ->> 'type', '') in ('photo', 'image')
    and coalesce(elem ->> 'url', '') <> ''
  limit 1;

  if v_image is null then
    select coalesce(nullif(elem ->> 'url', ''), elem ->> 'previewUrl')
      into v_image
    from jsonb_array_elements(coalesce(v_draft.media, '[]'::jsonb)) as elem
    where coalesce(elem ->> 'previewUrl', elem ->> 'url', '') <> ''
    limit 1;
  end if;

  insert into public.forum_replies (
    topic_id,
    author_id,
    author_handle,
    content,
    is_official,
    official_category,
    image_url
  )
  values (
    p_topic_id,
    v_author_id,
    case
      when v_author_handle like '@%' then v_author_handle
      else '@' || v_author_handle
    end,
    v_body,
    true,
    v_category,
    v_image
  )
  returning id into v_reply_id;

  update public.x_ingest_drafts
  set
    status = 'published',
    topic_id = p_topic_id,
    body = v_body,
    suggested_category = v_category,
    published_reply_id = v_reply_id,
    reviewed_by = auth.uid(),
    reviewed_at = now()
  where id = p_draft_id;

  return v_reply_id;
end;
$$;

revoke all on function public.x_ingest_publish_draft(uuid, text, text, text) from public;
grant execute on function public.x_ingest_publish_draft(uuid, text, text, text) to authenticated;

create or replace function public.x_ingest_discard_draft(p_draft_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo un admin puede descartar borradores de X';
  end if;

  update public.x_ingest_drafts
  set
    status = 'discarded',
    reviewed_by = auth.uid(),
    reviewed_at = now()
  where id = p_draft_id
    and status = 'pending';

  if not found then
    raise exception 'Borrador no encontrado o ya revisado';
  end if;
end;
$$;

revoke all on function public.x_ingest_discard_draft(uuid) from public;
grant execute on function public.x_ingest_discard_draft(uuid) to authenticated;

create or replace function public.kick_x_ingest_pull()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  fn_url text;
  service_key text;
begin
  fn_url := current_setting('app.settings.x_ingest_url', true);
  if fn_url is null or length(trim(fn_url)) = 0 then
    fn_url := current_setting('app.settings.drain_push_url', true);
    if fn_url is not null and position('/drain-push' in fn_url) > 0 then
      fn_url := replace(fn_url, '/drain-push', '/x-ingest-pull');
    else
      fn_url := 'https://dcsxgppprfedrsrtbatx.supabase.co/functions/v1/x-ingest-pull';
    end if;
  end if;

  service_key := current_setting('app.settings.service_role_key', true);

  perform net.http_post(
    url := fn_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', coalesce('Bearer ' || nullif(service_key, ''), '')
    ),
    body := jsonb_build_object('force', false)
  );
end;
$$;

do $$
begin
  perform cron.unschedule('cofradeo-x-ingest-pull');
exception
  when others then null;
end $$;

do $$
begin
  perform cron.schedule(
    'cofradeo-x-ingest-pull',
    '*/5 * * * *',
    $cron$select public.kick_x_ingest_pull();$cron$
  );
exception
  when others then
    raise notice 'pg_cron no disponible: programa el job a mano o actívalo en Extensions';
end $$;

notify pgrst, 'reload schema';
