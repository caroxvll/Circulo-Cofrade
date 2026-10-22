-- Portal hermandad: subir/cambiar portada (header) y escudo (logo) del tablón.
-- Ejecutar en SQL Editor.

create or replace function public.is_hermandad_board_manager(
  p_user_id uuid,
  p_topic_id text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.hermandad_topic_accounts a on a.profile_id = p.id
    join public.forum_topics t on t.id = a.topic_id
    where p.id = p_user_id
      and a.topic_id = p_topic_id
      and t.forum_id = 'hermandades'
      and p.verified = true
      and p.suspended_at is null
  );
$$;

revoke all on function public.is_hermandad_board_manager(uuid, text) from public;
grant execute on function public.is_hermandad_board_manager(uuid, text) to authenticated;

-- Solo actualiza cover/icon (no título ni cuerpo).
create or replace function public.update_hermandad_board_images(
  p_topic_id text,
  p_cover_image_url text default null,
  p_set_cover boolean default false,
  p_icon_image_url text default null,
  p_set_icon boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'No autenticado';
  end if;

  if not (
    public.is_hermandad_board_manager(auth.uid(), p_topic_id)
    or public.is_staff_user(auth.uid())
  ) then
    raise exception 'No autorizado a cambiar las imágenes de este tablón';
  end if;

  if not exists (
    select 1 from public.forum_topics
    where id = p_topic_id and forum_id = 'hermandades'
  ) then
    raise exception 'Tablón no válido';
  end if;

  if not p_set_cover and not p_set_icon then
    return;
  end if;

  update public.forum_topics
  set
    cover_image_url = case
      when p_set_cover then nullif(trim(coalesce(p_cover_image_url, '')), '')
      else cover_image_url
    end,
    icon_image_url = case
      when p_set_icon then nullif(trim(coalesce(p_icon_image_url, '')), '')
      else icon_image_url
    end
  where id = p_topic_id
    and forum_id = 'hermandades';
end;
$$;

revoke all on function public.update_hermandad_board_images(text, text, boolean, text, boolean) from public;
grant execute on function public.update_hermandad_board_images(text, text, boolean, text, boolean)
  to authenticated;

-- Storage topic-covers: cuentas hermandad asignadas
drop policy if exists "Titular o staff sube portadas temas" on storage.objects;
create policy "Titular o staff sube portadas temas"
  on storage.objects for insert
  with check (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(auth.uid(), (storage.foldername(name))[1])
      or public.is_hermandad_board_manager(auth.uid(), (storage.foldername(name))[1])
    )
  );

drop policy if exists "Titular o staff actualiza portadas temas" on storage.objects;
create policy "Titular o staff actualiza portadas temas"
  on storage.objects for update
  using (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(auth.uid(), (storage.foldername(name))[1])
      or public.is_hermandad_board_manager(auth.uid(), (storage.foldername(name))[1])
    )
  )
  with check (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(auth.uid(), (storage.foldername(name))[1])
      or public.is_hermandad_board_manager(auth.uid(), (storage.foldername(name))[1])
    )
  );

drop policy if exists "Titular o staff borra portadas temas" on storage.objects;
create policy "Titular o staff borra portadas temas"
  on storage.objects for delete
  using (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(auth.uid(), (storage.foldername(name))[1])
      or public.is_hermandad_board_manager(auth.uid(), (storage.foldername(name))[1])
    )
  );

notify pgrst, 'reload schema';
