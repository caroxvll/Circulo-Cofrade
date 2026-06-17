-- Cofradero · editar / ocultar respuestas (soft delete + auditoría)
-- Ejecutar en SQL Editor después de admin_roles.sql

alter table public.forum_replies
  add column if not exists edited_at timestamptz,
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles (id) on delete set null;

create index if not exists forum_replies_deleted_at_idx
  on public.forum_replies (deleted_at)
  where deleted_at is not null;

-- ---------------------------------------------------------------------------
-- Editar respuesta propia (30 min, sin respuestas hijas)
-- ---------------------------------------------------------------------------
create or replace function public.update_own_forum_reply(
  p_reply_id uuid,
  p_content text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply public.forum_replies%rowtype;
  v_child_count int;
  v_content text := trim(p_content);
begin
  if auth.uid() is null then
    raise exception 'auth_required';
  end if;

  select * into v_reply
  from public.forum_replies
  where id = p_reply_id;

  if not found then
    raise exception 'not_found';
  end if;

  if v_reply.author_id is distinct from auth.uid() then
    raise exception 'forbidden';
  end if;

  if v_reply.deleted_at is not null then
    raise exception 'deleted';
  end if;

  if v_reply.created_at < now() - interval '30 minutes' then
    raise exception 'edit_window_expired';
  end if;

  select count(*)::int into v_child_count
  from public.forum_replies
  where parent_reply_id = p_reply_id
    and deleted_at is null;

  if v_child_count > 0 then
    raise exception 'has_replies';
  end if;

  if char_length(v_content) < 1 or char_length(v_content) > 4000 then
    raise exception 'invalid_content';
  end if;

  update public.forum_replies
  set content = v_content,
      edited_at = now()
  where id = p_reply_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Ocultar respuesta (soft delete): autor o Junta
-- El texto permanece en BD para moderación / reportes
-- ---------------------------------------------------------------------------
create or replace function public.soft_delete_forum_reply(p_reply_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply public.forum_replies%rowtype;
begin
  if auth.uid() is null then
    raise exception 'auth_required';
  end if;

  select * into v_reply
  from public.forum_replies
  where id = p_reply_id;

  if not found then
    raise exception 'not_found';
  end if;

  if v_reply.deleted_at is not null then
    return;
  end if;

  if v_reply.author_id is distinct from auth.uid()
     and not public.is_staff_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  update public.forum_replies
  set deleted_at = now(),
      deleted_by = auth.uid()
  where id = p_reply_id;
end;
$$;

grant execute on function public.update_own_forum_reply(uuid, text) to authenticated;
grant execute on function public.soft_delete_forum_reply(uuid) to authenticated;
