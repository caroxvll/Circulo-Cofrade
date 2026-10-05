-- Cofradeo · Quién puede INFORMAR en Semana Santa (no chat libre)
-- Hermandad verificada + admin + lista de confianza (ss_live_reporters).
-- Cuaresma/ensayos NO se toca.
-- Idempotente.

create table if not exists public.ss_live_reporters (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  assigned_by uuid references public.profiles (id) on delete set null,
  assigned_at timestamptz not null default now(),
  note text not null default '' check (char_length(note) <= 200)
);

create index if not exists ss_live_reporters_assigned_at_idx
  on public.ss_live_reporters (assigned_at desc);

alter table public.ss_live_reporters enable row level security;

drop policy if exists "Reporteros SS legibles autenticados" on public.ss_live_reporters;
create policy "Reporteros SS legibles autenticados"
  on public.ss_live_reporters for select
  to authenticated
  using (true);

drop policy if exists "Admin gestiona reporteros SS" on public.ss_live_reporters;
create policy "Admin gestiona reporteros SS"
  on public.ss_live_reporters for all
  to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

create or replace function public.can_post_ss_live_update(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_user_id is not null
    and exists (
      select 1
      from public.profiles p
      where p.id = p_user_id
        and p.suspended_at is null
        and (
          public.is_admin_user(p.id)
          or (
            p.account_type = 'brotherhood'
            and coalesce(p.verified, false)
          )
          or exists (
            select 1
            from public.ss_live_reporters r
            where r.profile_id = p.id
          )
        )
    );
$$;

grant execute on function public.can_post_ss_live_update(uuid) to authenticated, anon;

drop policy if exists "Cofrade publica aviso SS" on public.ss_live_updates;
create policy "Reporteros publican aviso SS"
  on public.ss_live_updates for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.can_post_ss_live_update(auth.uid())
  );

notify pgrst, 'reload schema';
