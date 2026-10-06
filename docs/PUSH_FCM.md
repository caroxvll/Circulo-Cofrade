# Push FCM — Cofradero

Guía para activar notificaciones push fuera de la app. La bandeja in-app sigue en Supabase; FCM solo entrega el banner del sistema.

## Arquitectura

Hay **dos colas**:

1. `notification_dispatch_jobs` — crea filas en `notifications` a ritmo (fan-out noticias/temas…).
2. `push_delivery_jobs` — controla el envío a **Google FCM** (el “tubo” al móvil).

```
Evento (noticia, mención…)
        │
        ├─ fan-out masivo → notification_dispatch_jobs → cron → INSERT notifications
        └─ aviso 1:1      → INSERT notifications al momento
                │
                ▼
     trigger (por LOTE) → push_delivery_jobs (pending)
                │
                ▼
     kick / cron cada minuto → Edge Function drain-push
                │  (lotes ~40, hasta ~20 en paralelo)
                ▼
     Google FCM  →  banner en el móvil
```

**Importante:** desactiva el Database Webhook antiguo `notifications-push` si existe.
Con la cola, el disparo va por `push_delivery_queue.sql` + `drain-push`, no por 1 HTTP por fila a `send-push`.

Setup SQL (una vez):

```sql
-- SQL Editor
-- pega supabase/push_delivery_queue.sql
```

Deploy:

```bash
npx supabase functions deploy drain-push
```

`send-push` se puede dejar desplegada para pruebas manuales; el camino de producción es `drain-push`.

## 1. Firebase

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/).
2. Añade apps **Web**, **Android** e **iOS** (misma app, distintos IDs).
3. En **Project settings → Cloud Messaging**:
   - Copia **Sender ID** (`FIREBASE_MESSAGING_SENDER_ID`).
   - En Web, genera un par de claves y copia la **clave pública VAPID** (`FIREBASE_VAPID_KEY`).
4. **Android**: descarga `google-services.json` → `android/app/google-services.json`.
5. **iOS**: descarga `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist` y configura APNs en Apple Developer.
6. **Service account** (para la Edge Function): Project settings → Service accounts → Generate new private key. Guarda el JSON; lo usarás como secreto `FIREBASE_SERVICE_ACCOUNT`.

## 2. Variables en `env.json`

Copia `env.example.json` y rellena (además de Supabase):

| Clave | Origen |
|-------|--------|
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `FIREBASE_API_KEY` | Web app config |
| `FIREBASE_APP_ID` | Web app config |
| `FIREBASE_MESSAGING_SENDER_ID` | Cloud Messaging |
| `FIREBASE_AUTH_DOMAIN` | `proyecto.firebaseapp.com` (web) |
| `FIREBASE_VAPID_KEY` | Web push key pair |

Arranque:

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

Sin claves Firebase la app funciona igual; solo se omite el registro push.

## 3. SQL en Supabase

Si ya ejecutaste `notification_social.sql`, solo necesitas tokens:

```sql
-- SQL Editor
\i supabase/device_tokens.sql
```

(o pega el contenido de [`device_tokens.sql`](../supabase/device_tokens.sql))

La columna `push_enabled` ya existe en `notification_preferences` vía `notification_social.sql`.

**Opt-in:** push viene **desactivado** por defecto. Solo se registra el dispositivo cuando el usuario activa **Avisos push** en Perfil → Avisos. Si tu proyecto se creó antes, ejecuta también [`push_opt_in_default.sql`](../supabase/push_opt_in_default.sql).

## 4. Edge Function `send-push`

```bash
npx supabase login
npx supabase link --project-ref dcsxgppprfedrsrtbatx
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
npx supabase functions deploy send-push
```

**En Windows (PowerShell)** no uses comillas simples alrededor del JSON. Descarga el JSON de Firebase y:

```powershell
# 1. Crea un archivo temporal (sustituye la ruta por tu JSON descargado)
Copy-Item "C:\ruta\circulo-cofrade-firebase-adminsdk.json" ".\firebase-sa.env.json"

# 2. Conviértelo a una sola línea válida para .env
$oneLine = (Get-Content -Raw ".\firebase-sa.env.json") -replace "`r`n", "" -replace "`n", ""
"FIREBASE_SERVICE_ACCOUNT=$oneLine" | Set-Content -Encoding utf8 ".\supabase\.secrets.firebase.env"

# 3. Súbelo a Supabase
npx supabase secrets set --env-file supabase/.secrets.firebase.env

# 4. Borra el archivo local (contiene clave privada)
Remove-Item ".\supabase\.secrets.firebase.env", ".\firebase-sa.env.json"
```

Comprueba que la función responde (sustituye `USER_ID` por tu uuid de `auth.users`):

```powershell
curl.exe -s -X POST "https://dcsxgppprfedrsrtbatx.supabase.co/functions/v1/send-push" `
  -H "Content-Type: application/json" `
  -d "{\"type\":\"INSERT\",\"table\":\"notifications\",\"record\":{\"user_id\":\"USER_ID\",\"type\":\"mention\",\"title\":\"Test\",\"subtitle\":\"Hola\",\"payload\":{}}}"
```

Respuestas esperadas:

| Respuesta | Significado |
|-----------|-------------|
| `{"sent":1,...}` | FCM aceptó el mensaje |
| `{"skipped":"sin tokens"}` | No hay fila en `device_tokens` para ese usuario |
| `{"error":"FIREBASE_SERVICE_ACCOUNT no es JSON válido"}` | Vuelve a subir el secreto (paso anterior) |

`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` las inyecta Supabase automáticamente en funciones desplegadas.

## 5. Cola de entrega (recomendado)

Ejecuta [`push_delivery_queue.sql`](../supabase/push_delivery_queue.sql) y despliega `drain-push`.

| Pieza | Rol |
|-------|-----|
| Trigger `notifications_enqueue_push` | Encola 1 job por notificación (por statement/lote) |
| `kick_push_delivery_drain` | Llama a `drain-push` como máx. 1 vez / 3 s |
| Cron `cofradeo-push-delivery-drain` | Cada minuto, por si quedó cola |
| `drain-push` | Reclama jobs, envía a FCM en paralelo, reintenta, borra tokens muertos |

**Desactiva** el webhook Dashboard `notifications-push` si lo tenías (evita doble envío).

Comprueba cola:

```sql
select status, count(*) from push_delivery_jobs group by status;
select public.staff_push_delivery_overview(); -- solo admin
```

Legacy: [`push_webhook_trigger.sql`](../supabase/push_webhook_trigger.sql) y [`verify_push_not_duplicated.sql`](../supabase/verify_push_not_duplicated.sql).

## 6. Probar

1. Inicia sesión en la app con Firebase configurado.
2. Perfil → **···** → **Avisos** → activa **Avisos push** y acepta permisos.
3. Comprueba en SQL Editor que hay fila en `device_tokens`.
4. **Cierra la pestaña de la app** o cámbiate a otra pestaña del navegador (p. ej. Gmail). En la misma pestaña con la app visible solo verás un SnackBar, no el banner del sistema.
5. Desde otra cuenta, provoca un aviso (mención, etc.).

### Qué deberías ver

| Dónde estás | Qué pasa |
|-------------|----------|
| Otra pestaña / ventana minimizada | Banner de Chrome/Edge |
| Misma pestaña, app visible | SnackBar abajo + bandeja en tiempo real |
| Incógnito u otro navegador | No llega (el token FCM es por navegador) |

## Preferencias

La función respeta `push_enabled` y el tipo:

| Tipo notificación | Preferencia |
|-------------------|-------------|
| `hashtag_activity` | `notify_hashtags` |
| `topic_activity`, `user_reply` | `notify_topics` |
| `user_post` | `notify_profiles` |
| `mention` | `notify_mentions` |
| `new_follower` | `notify_followers` |
| `reply_reaction` | `notify_reactions` |
| `calendar` | `notify_calendar` |
| `quiz` | `notify_quiz` |

Tipos desconocidos (p. ej. moderación admin) se envían si `push_enabled` está activo.

Para reacciones en comentarios, ejecuta también [`reply_reaction_notify.sql`](../supabase/reply_reaction_notify.sql) (columna `notify_reactions`).

Tras cambiar `send-push`, redeploy:

```bash
npx supabase functions deploy send-push
```

Los pushes de reacciones incluyen `forumId`, `topicId`, `replyId` y `officialCategory` en el payload FCM para abrir el hilo (y la sección del tablón si aplica).

## Troubleshooting

| Problema | Qué revisar |
|----------|-------------|
| **Push duplicado (mismo título dos veces)** | Webhook Dashboard **y** cola `push_delivery` a la vez, o webhook + trigger antiguo → deja **solo** `push_delivery_queue.sql` + `drain-push` |
| **Push duplicado solo en Chrome/web** | Service worker mostraba el banner dos veces (FCM + `showNotification` manual); corregido en `web/firebase-messaging-sw.js` |
| **Varios pushes distintos por un reply** | Normal si aplica `user_reply` + `hashtag_activity` (lógica de negocio) |
| No aparece toggle push | `FIREBASE_PROJECT_ID` en `env.json` + hot restart |
| Sin fila en `device_tokens` | Permisos denegados, VAPID en web, o SQL no ejecutado |
| Push no llega | Webhook activo, secretos de función, tokens válidos |
| `FIREBASE_SERVICE_ACCOUNT no es JSON válido` | Vuelve a subir el JSON con `--env-file` (común en Windows) |
| Web en localhost | FCM web requiere HTTPS en producción; en dev Chrome suele funcionar con permiso |

---

*Ver también: [`NOTIFICACIONES.md`](NOTIFICACIONES.md) · [`SUPABASE.md`](SUPABASE.md)*
