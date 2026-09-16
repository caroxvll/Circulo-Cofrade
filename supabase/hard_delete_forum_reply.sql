-- Cofradero · borrar definitivamente respuestas ya ocultas (Junta)
-- Ejecutar en SQL Editor después de forum_reply_edit_delete.sql

create or replace function public.hard_delete_forum_reply(p_reply_id uuid)
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

  if v_reply.deleted_at is null then
    raise exception 'not_soft_deleted';
  end if;

  if not public.is_staff_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  -- Cascada de hijas vía FK parent_reply_id ON DELETE CASCADE
  delete from public.forum_replies
  where id = p_reply_id;
end;
$$;

grant execute on function public.hard_delete_forum_reply(uuid) to authenticated;
