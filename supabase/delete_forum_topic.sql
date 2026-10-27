-- El admin (o quien modera el foro) borra un tema y, con él, sus respuestas.
-- El delete directo falla si hay comentarios: las políticas de las respuestas
-- no dejan que el borrado en cascada las quite. Esta función sí puede.
-- Ejecutar en el SQL Editor.

create or replace function public.delete_forum_topic(p_topic_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null
     or not public.can_moderate_topic(auth.uid(), p_topic_id) then
    raise exception 'No puedes eliminar este tema';
  end if;

  if not exists (
    select 1 from public.forum_topics where id = p_topic_id
  ) then
    raise exception 'El tema ya no existe';
  end if;

  delete from public.forum_topics where id = p_topic_id;
end;
$$;

grant execute on function public.delete_forum_topic(text) to authenticated;
