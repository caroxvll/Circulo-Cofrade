-- Cofradeo · restaurar comunicado oficial soft-deleted
-- Ejecutar en SQL Editor (idempotente).

create or replace function public.restore_forum_reply(p_reply_id uuid)
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
    return;
  end if;

  if v_reply.author_id is distinct from auth.uid()
     and not public.is_staff_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  update public.forum_replies
  set deleted_at = null,
      deleted_by = null
  where id = p_reply_id;
end;
$$;

revoke all on function public.restore_forum_reply(uuid) from public;
grant execute on function public.restore_forum_reply(uuid) to authenticated;

comment on function public.restore_forum_reply(uuid) is
  'Quita soft-delete de un comunicado. No recrea eventos de calendario ni notificaciones.';

notify pgrst, 'reload schema';
