-- Encuestas en temas de foro (1 por tema, solo al crear).
-- Ejecutar en SQL Editor.

create table if not exists public.topic_polls (
  id uuid primary key default gen_random_uuid(),
  topic_id text not null unique references public.forum_topics (id) on delete cascade,
  question text not null check (char_length(trim(question)) between 5 and 200),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create table if not exists public.topic_poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.topic_polls (id) on delete cascade,
  label text not null check (char_length(trim(label)) between 1 and 80),
  sort_order int not null default 0,
  unique (poll_id, sort_order)
);

create index if not exists topic_poll_options_poll_idx
  on public.topic_poll_options (poll_id, sort_order);

create table if not exists public.topic_poll_votes (
  poll_id uuid not null references public.topic_polls (id) on delete cascade,
  option_id uuid not null references public.topic_poll_options (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (poll_id, user_id)
);

create index if not exists topic_poll_votes_option_idx
  on public.topic_poll_votes (option_id);

alter table public.topic_polls enable row level security;
alter table public.topic_poll_options enable row level security;
alter table public.topic_poll_votes enable row level security;

drop policy if exists "Polls legibles" on public.topic_polls;
create policy "Polls legibles"
  on public.topic_polls for select
  using (
    public.is_staff_user(auth.uid())
    or exists (
      select 1 from public.forum_topics t
      where t.id = topic_id
        and (t.status = 'published' or t.author_id = auth.uid())
    )
  );

drop policy if exists "Opciones legibles" on public.topic_poll_options;
create policy "Opciones legibles"
  on public.topic_poll_options for select
  using (
    public.is_staff_user(auth.uid())
    or exists (
      select 1
      from public.topic_polls p
      join public.forum_topics t on t.id = p.topic_id
      where p.id = poll_id
        and (t.status = 'published' or t.author_id = auth.uid())
    )
  );

drop policy if exists "Votos legibles" on public.topic_poll_votes;
create policy "Votos legibles"
  on public.topic_poll_votes for select
  using (
    public.is_staff_user(auth.uid())
    or exists (
      select 1
      from public.topic_polls p
      join public.forum_topics t on t.id = p.topic_id
      where p.id = poll_id
        and (t.status = 'published' or t.author_id = auth.uid())
    )
  );

drop policy if exists "Usuario vota" on public.topic_poll_votes;
create policy "Usuario vota"
  on public.topic_poll_votes for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.topic_polls p
      join public.forum_topics t on t.id = p.topic_id
      where p.id = poll_id
        and t.status = 'published'
        and p.closed_at is null
        and exists (
          select 1 from public.topic_poll_options o
          where o.id = option_id and o.poll_id = p.id
        )
    )
  );

drop policy if exists "Usuario cambia voto" on public.topic_poll_votes;
create policy "Usuario cambia voto"
  on public.topic_poll_votes for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.topic_polls p
      where p.id = poll_id
        and p.closed_at is null
        and exists (
          select 1 from public.topic_poll_options o
          where o.id = option_id and o.poll_id = p.id
        )
    )
  );

-- Crear encuesta ligada a un tema propio (justo tras crear el tema).
create or replace function public.create_topic_poll(
  p_topic_id text,
  p_question text,
  p_options text[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_poll_id uuid;
  v_q text := trim(coalesce(p_question, ''));
  v_opt text;
  v_i int := 0;
  v_n int;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;

  if char_length(v_q) < 5 or char_length(v_q) > 200 then
    raise exception 'La pregunta debe tener entre 5 y 200 caracteres';
  end if;

  v_n := coalesce(array_length(p_options, 1), 0);
  if v_n < 2 or v_n > 6 then
    raise exception 'La encuesta necesita entre 2 y 6 opciones';
  end if;

  if not exists (
    select 1 from public.forum_topics
    where id = p_topic_id and author_id = v_uid
  ) then
    raise exception 'Solo el autor del tema puede crear la encuesta';
  end if;

  if exists (select 1 from public.topic_polls where topic_id = p_topic_id) then
    raise exception 'Este tema ya tiene una encuesta';
  end if;

  insert into public.topic_polls (topic_id, question, created_by)
  values (p_topic_id, v_q, v_uid)
  returning id into v_poll_id;

  foreach v_opt in array p_options loop
    v_opt := trim(coalesce(v_opt, ''));
    if char_length(v_opt) < 1 or char_length(v_opt) > 80 then
      raise exception 'Cada opción debe tener entre 1 y 80 caracteres';
    end if;
    insert into public.topic_poll_options (poll_id, label, sort_order)
    values (v_poll_id, v_opt, v_i);
    v_i := v_i + 1;
  end loop;

  return v_poll_id;
end;
$$;

grant execute on function public.create_topic_poll(text, text, text[]) to authenticated;

-- Votar (o cambiar voto).
create or replace function public.vote_topic_poll(p_option_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_poll_id uuid;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión para votar';
  end if;

  select o.poll_id into v_poll_id
  from public.topic_poll_options o
  join public.topic_polls p on p.id = o.poll_id
  join public.forum_topics t on t.id = p.topic_id
  where o.id = p_option_id
    and t.status = 'published'
    and p.closed_at is null;

  if v_poll_id is null then
    raise exception 'No se puede votar en esta encuesta';
  end if;

  insert into public.topic_poll_votes (poll_id, option_id, user_id)
  values (v_poll_id, p_option_id, v_uid)
  on conflict (poll_id, user_id)
  do update set option_id = excluded.option_id, created_at = now();
end;
$$;

grant execute on function public.vote_topic_poll(uuid) to authenticated;

-- Cerrar encuesta (staff / Junta).
create or replace function public.close_topic_poll(p_poll_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_staff_user(auth.uid()) then
    raise exception 'Solo la Junta puede cerrar encuestas';
  end if;

  update public.topic_polls
  set closed_at = coalesce(closed_at, now())
  where id = p_poll_id;

  if not found then
    raise exception 'Encuesta no encontrada';
  end if;
end;
$$;

grant execute on function public.close_topic_poll(uuid) to authenticated;

-- Eliminar encuesta (staff / Junta). Cascada borra opciones y votos.
create or replace function public.delete_topic_poll(p_poll_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_staff_user(auth.uid()) then
    raise exception 'Solo la Junta puede eliminar encuestas';
  end if;

  delete from public.topic_polls where id = p_poll_id;

  if not found then
    raise exception 'Encuesta no encontrada';
  end if;
end;
$$;

grant execute on function public.delete_topic_poll(uuid) to authenticated;
