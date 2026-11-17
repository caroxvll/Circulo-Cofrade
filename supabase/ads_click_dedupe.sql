-- Dedupe de clics: 1 por viewer + anuncio cada 15 minutos (evita CTR inflado).
-- Ejecutar en Supabase SQL Editor tras ads.sql.
-- Nota: hay que DROP porque la firma antigua devolvía void y no se puede
-- cambiar el tipo de retorno con CREATE OR REPLACE.

create index if not exists ad_clicks_viewer_recent_idx
  on public.ad_clicks (ad_id, viewer_id, created_at desc);

drop function if exists public.register_ad_click(uuid, text);

create function public.register_ad_click(
  p_ad_id uuid,
  p_viewer_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exists boolean;
begin
  if p_viewer_id is null or length(trim(p_viewer_id)) = 0 then
    raise exception 'viewer_id requerido';
  end if;

  select exists (
    select 1
    from public.ad_clicks
    where ad_id = p_ad_id
      and viewer_id = p_viewer_id
      and created_at >= now() - interval '15 minutes'
  )
  into v_exists;

  if v_exists then
    return false;
  end if;

  insert into public.ad_clicks (ad_id, user_id, viewer_id)
  values (p_ad_id, auth.uid(), p_viewer_id);

  return true;
end;
$$;

grant execute on function public.register_ad_click(uuid, text) to anon, authenticated;
grant execute on function public.register_ad_impression(uuid, text) to anon, authenticated;
