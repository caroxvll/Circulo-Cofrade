-- El Cronicón: solo libro y artículo.
-- Anécdota y crónica existentes pasan a artículo.
-- Ejecutar en SQL Editor (PRE y PROD).

update public.historias
set kind = 'articulo'
where kind is distinct from 'libro';

alter table public.historias
  alter column kind set default 'articulo';

alter table public.historias drop constraint if exists historias_kind_check;
alter table public.historias
  add constraint historias_kind_check
  check (kind in ('libro', 'articulo'));

notify pgrst, 'reload schema';
