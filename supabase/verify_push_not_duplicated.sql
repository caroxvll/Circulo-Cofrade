-- Cofradero · comprobar que el push no se dispara dos veces por notificación
-- Ejecutar en SQL Editor.

-- 1) Trigger SQL en notifications (debe haber SOLO UNO o ninguno si usas webhook)
select tgname as trigger_name
from pg_trigger
where tgrelid = 'public.notifications'::regclass
  and not tgisinternal;

-- Si aparece notifications_send_push Y tienes webhook "notifications-push"
-- en Dashboard → Database → Webhooks, cada INSERT llama send-push DOS veces.
-- Solución: deja solo uno (recomendado: webhook Dashboard, sin trigger SQL):
--   drop trigger if exists notifications_send_push on public.notifications;

-- 2) Tokens duplicados por usuario (cada token = un push extra)
select user_id, count(*) as tokens, array_agg(platform) as platforms
from public.device_tokens
group by user_id
having count(*) > 1
order by tokens desc;

-- 2b) Mismo FCM en varias cuentas → N pushes en un solo móvil
select fcm_token, count(*) as users, array_agg(user_id) as user_ids
from public.device_tokens
group by fcm_token
having count(*) > 1;

-- 3) Limpieza: ver device_tokens_unique.sql (recomendado)
-- Limpieza única antigua: dejar solo el token más reciente por usuario y plataforma
-- (ejecutar si la consulta anterior 2a devuelve filas)
delete from public.device_tokens dt
where dt.id not in (
  select distinct on (user_id, platform) id
  from public.device_tokens
  order by user_id, platform, updated_at desc
);
