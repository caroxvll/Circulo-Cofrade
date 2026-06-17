# Notificaciones y seguimientos — Cofradero

Decisión de producto acordada (junio 2026). Referencia para Fase 6 (UI), Fase 8 (backend) y Fase 9 (push FCM).

## Idea central

**Un solo apartado: Notificaciones** (tab del bottom nav). Bandeja unificada de todo lo que te importa.

Hay **tres formas de “seguir”**, mismo destino:

| Origen | Dónde se activa | Qué sigues |
|--------|-----------------|------------|
| **Hashtag / tendencia** | Buscar → `TrendCard` → **Seguir** | Tema de conversación, ej. `#ViernesSanto` |
| **Hermandad / usuario** | Perfil ajeno → **Seguir** | Cuenta, ej. `@hermandad_sevilla` |
| **Hilo de foro** | Detalle del tema → **Seguir hilo** | Un tema concreto (solo publicados) |

---

## In-app vs push

| Canal | Cuándo | Dónde se ve |
|-------|--------|-------------|
| **In-app** | Siempre que ocurre el evento | Tab **Notificaciones** + badge campana en Foros |
| **Push (FCM)** | Mismo evento, pero **fuera de la app** (móvil cerrado o en otra app) | Banner del sistema iOS/Android |

Ambos usan la misma tabla `notifications` en Supabase. El push es **entrega adicional**, no un sistema distinto.

---

## ¿Cuándo llega un push?

Solo si se cumplen **todas**:

1. Usuario **logueado**
2. Ha pulsado **Seguir** (hashtag o perfil)
3. Ha **aceptado permisos** push en el dispositivo
4. Tipo de aviso **activo** en preferencias
5. No ha **bloqueado** al autor
6. (Opcional) App **no está abierta** en ese hilo → evitar push redundante

### Por hashtag seguido

| Evento | Título push (ejemplo) |
|--------|------------------------|
| Nuevo comentario/respuesta en `#` | Nuevo comentario en **#ViernesSanto** |
| Nuevo tema con ese hashtag | Nueva conversación en **#Costaleros** |

### Por hilo seguido

| Evento | Título in-app (ejemplo) |
|--------|-------------------------|
| Nueva respuesta en el hilo | Nueva respuesta en un hilo que sigues |

### Por hermandad / usuario seguido

| Evento | Título push (ejemplo) |
|--------|------------------------|
| Nueva publicación | **Hermandad Sevilla** publicó |
| Nueva respuesta suya | **@maria_dolores** respondió |
| Te mencionan | Te han etiquetado en un post |
| Nuevo seguidor | **@jose_carpintero** empezó a seguirte |

### Calendario (opcional, fase posterior)

| Evento | Título push (ejemplo) |
|--------|------------------------|
| Evento mañana / hoy | Salida de procesión · 18:00 |

### No hay push cuando

- Modo invitado (sin cuenta)
- No sigues ese hashtag ni esa cuenta
- Permisos push denegados
- Tipo desactivado en ajustes
- Autor bloqueado

---

## Arquitectura (acordada)

**Supabase** = datos, auth, bandeja, seguimientos.  
**Firebase FCM** = solo envío push al dispositivo. **No** migrar auth ni foros a Firebase.

```
App Flutter
    │
    ├─► Supabase: insert en `notifications` + `follows`
    │
    └─► Edge Function (o webhook)
            │
            └─► Firebase Cloud Messaging (FCM)
                    │
                    └─► iPhone / Android (banner sistema)
```

| Pieza | Tecnología |
|-------|------------|
| Login, foros, perfiles | Supabase |
| Tabla `notifications` | Supabase PostgreSQL |
| Tabla `follows` | Supabase PostgreSQL |
| Token dispositivo | Supabase `device_tokens` |
| Preferencias push | Supabase `notification_preferences` |
| Envío push | **Firebase FCM** (`firebase_messaging` en Flutter) |
| Imágenes (avatar, posts) | Supabase Storage — ver [`MEDIA.md`](MEDIA.md) |

SQL adicional para push: [`supabase/device_tokens.sql`](../supabase/device_tokens.sql) — guía completa en [`PUSH_FCM.md`](PUSH_FCM.md)

---

## Preferencias de usuario

Activar/desactivar por tipo (Fase 8–9):

| Preferencia | Default beta |
|-------------|--------------|
| Hashtags que sigo | ✅ On (`notify_hashtags`) |
| Publicaciones de cuentas que sigo | ✅ On (`notify_profiles`) |
| Hilos que sigo | ✅ On (`notify_topics`) |
| Menciones | ✅ On (`notify_mentions`) |
| Nuevos seguidores | ⚠️ Off (`notify_followers`) |
| Recordatorios calendario | ⚠️ Off (fase posterior) |

---

## Ejemplos de tarjeta in-app

**Hashtag:**

| Campo | Texto |
|-------|-------|
| Título | Nuevo comentario en **#ViernesSanto** |
| Subtítulo | *Nueva ruta del Viernes Santo* · @jose_carpintero |
| Acción | Abrir hilo `/foros/:forumId/tema/:topicId` |

**Hermandad:**

| Campo | Texto |
|-------|-------|
| Título | **Hermandad Sevilla** publicó |
| Subtítulo | Extracto del tema |
| Acción | Abrir publicación o hilo |

---

## Roadmap de implementación

| Fase | Qué |
|------|-----|
| **4** ✅ | Seguir hashtag = toggle visual (mock) |
| **6** ✅ | Pantalla Notificaciones con mock |
| **8a** ✅ (parcial) | Auth, foros, publicar respuesta en Supabase |
| **8b** | `follows` persistido · `notifications` reales · seguir en Perfil |
| **8c** | Editar perfil · avatar (imagen) |
| **9a** | Firebase proyecto + FCM · `device_tokens` · Edge Function |
| **9b** | Push en iOS/Android · preferencias · APNs |

Lectura libre sin cuenta. **Seguir y recibir notificaciones requiere login** — [`AUTH.md`](AUTH.md).

---

## Modelo de datos

```
follows
  follower_id   → uuid (profiles)
  target_type   → 'hashtag' | 'profile' | 'topic'
  target_id     → '#ViernesSanto' | uuid | topic_id

notifications
  user_id
  type          → hashtag_activity | topic_activity | user_post | mention | new_follower | calendar
  title, subtitle
  payload       → { forumId, topicId, route, ... }
  read_at, created_at

device_tokens
  user_id, fcm_token, platform (ios|android|web), updated_at

notification_preferences
  user_id, notify_hashtags, notify_profiles, notify_topics, notify_mentions,
  notify_followers, notify_calendar, push_enabled, updated_at
```

---

## Componentes UI

| Widget | Uso |
|--------|-----|
| `NotificationCard` | Lista Notificaciones |
| `TrendCard` + Seguir | Buscar |
| `TopicFollowButton` | Detalle de hilo publicado |
| Botón Seguir | Perfil ajeno |
| `NotificationsBellButton` | Badge campana en Foros |

---

*Ver también: [`MEDIA.md`](MEDIA.md) · [`AUTH.md`](AUTH.md) · [`SUPABASE.md`](SUPABASE.md) · [`ROADMAP.md`](ROADMAP.md)*
