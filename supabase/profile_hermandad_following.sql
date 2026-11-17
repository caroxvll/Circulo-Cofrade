-- Cofradeo · «Tu hermandad» en Perfil → Siguiendo.
-- off (por defecto): la app muestra «Próximamente».
-- on: se abre el directorio para elegir y seguir hermandades.
-- El interruptor de Junta → Hermandades escribe esta misma clave.

insert into public.app_config (key, value)
values ('profile_hermandad_following', 'off')
on conflict (key) do nothing;
