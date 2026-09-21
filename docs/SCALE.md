# Escala · Cofradeo

## Orden en SQL Editor

1. `scale_hardening_v1.sql`  
2. `scale_hardening_v2.sql`  
3. `notification_dispatch_cron.sql` ← Cron automático + reintentos  
4. `notification_dispatch_admin.sql` ← panel web admin  

(Al final de cada script ya va `notify pgrst, 'reload schema';` — no hace falta un paso aparte.)

En admin-web → **Notificaciones → Cola de envío**: resumen en vivo (5s), procesar ahora, reintentar fallidos.

## Cron: una vez y listo

No lo lanzas a mano cada vez.  
`notification_dispatch_cron.sql` lo **programa solo** cada minuto. Tú no vuelves a tocarlo.

Si la cola está vacía, el Cron pregunta y se va (casi cero carga).

## Fallos: también solos

Si un lote falla (red, timeout…):
- vuelve a `pending` y el Cron lo **reintenta solo** (hasta 5 veces)
- solo tras 5 fallos seguidos queda `failed` (caso raro)
- si se queda a medias en `processing`, a los 5 minutos se recupera solo

**No tienes que “reprocesar a mano” en el día a día.**

## Qué va a la cola

Noticias, hilos seguidos, hashtags, perfiles, hermandad oficial, calendario, quiz.

## Qué sigue al momento

Autor del hilo, @menciones, reacciones, “te siguen”, junta.
