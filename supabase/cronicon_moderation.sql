-- El Cronicón / calendario: comentarios y enlace al tablón.
-- SQL Editor · PRE y PROD.

insert into public.app_config (key, value)
values ('calendar_show_board_link', 'off')
on conflict (key) do nothing;

comment on table public.app_config is
  'Claves de producto. calendar_show_board_link=on muestra «Ver tablón» al abrir un evento.';

drop policy if exists "Autor o Junta borra comentario de historia"
  on public.historia_comments;
drop policy if exists "Solo admin borra comentario de historia"
  on public.historia_comments;
create policy "Solo admin borra comentario de historia"
  on public.historia_comments for delete
  to authenticated
  using (public.is_admin_user(auth.uid()));

notify pgrst, 'reload schema';
