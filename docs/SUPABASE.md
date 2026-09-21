# Supabase — Cofradero (Fase 8)

Guía para conectar la app con backend real.

## Checklist rápido

- [ ] Crear proyecto en [supabase.com](https://supabase.com)
- [ ] Copiar `env.example.json` → `env.json` con URL y anon key
- [ ] Ejecutar `supabase/schema.sql` en SQL Editor
- [ ] Ejecutar `supabase/seed.sql` (datos iniciales de foros)
- [ ] Auth → Email: activar (dev: desactivar confirmación email)
- [ ] Auth → Google/Apple (opcional, para OAuth)
- [ ] Arrancar: `flutter run -d chrome --dart-define-from-file=env.json`

---

## 1. Crear proyecto

1. [supabase.com](https://supabase.com) → **New project**
2. Anota **Project URL** y **anon public key** (Settings → API)

## 2. Configurar la app

Copia `env.example.json` → `env.json` (no se sube a git):

```json
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbG..."
}
```

```powershell
flutter run -d chrome --dart-define-from-file=env.json
```

Sin `env.json`: **modo invitado** con mocks (sin login real ni publicar).

## 3. Esquema SQL

En Supabase → **SQL Editor**:

1. Ejecuta [`supabase/schema.sql`](../supabase/schema.sql)  
   Tablas: `profiles`, `follows`, `notifications`, `blocks`, `reports`, `forum_pillars`, `forum_topics`, `forum_replies`

2. Ejecuta [`supabase/seed.sql`](../supabase/seed.sql)  
   Pilares, temas y respuestas iguales a los mocks de la app

3. Ejecuta [`supabase/notifications_triggers.sql`](../supabase/notifications_triggers.sql)  
   Notificaciones automáticas al publicar una respuesta (autor del tema + seguidores del hashtag)

4. Ejecuta [`supabase/storage_avatars.sql`](../supabase/storage_avatars.sql)  
   Bucket `avatars` + políticas Storage + contador de seguidores al seguir perfiles

5. Ejecuta [`supabase/notifications_delete_policy.sql`](../supabase/notifications_delete_policy.sql)  
   Permite limpiar notificaciones desde la app (Fase 8e)

6. Ejecuta [`supabase/forum_subreplies_and_follow_notify.sql`](../supabase/forum_subreplies_and_follow_notify.sql)  
   Subrespuestas anidadas + notificación «Nuevo seguidor»

7. Ejecuta [`supabase/reply_likes_and_moderation.sql`](../supabase/reply_likes_and_moderation.sql)  
   Me gusta en respuestas (tabla `forum_reply_likes`)

7b. Ejecuta [`supabase/reply_reactions.sql`](../supabase/reply_reactions.sql) y después  
    [`supabase/reply_reactions_emoji.sql`](../supabase/reply_reactions_emoji.sql)  
    Reacciones múltiples (❤️ 👏 🤗 …) + Realtime entre pantallas. **Sin el segundo script la app no guarda emojis.**  
    Si `reply_reactions.sql` falla con **23514**, ejecuta solo [`supabase/reply_reactions_fix.sql`](../supabase/reply_reactions_fix.sql).  
    Luego [`supabase/reply_reaction_notify.sql`](../supabase/reply_reaction_notify.sql) — aviso al autor, listado de quién reaccionó y **agrupación** («3 personas reaccionaron…»). Vuelve a ejecutarlo si ya lo tenías: actualiza el trigger.

8. Ejecuta [`supabase/topic_views_dedup.sql`](../supabase/topic_views_dedup.sql)  
   Visitas: tabla `topic_views` + **1 visita por usuario/invitado y día**  
   (sustituye la función simple de `topic_view_counter.sql`)

9. Ejecuta [`supabase/sync_topic_comment_counts.sql`](../supabase/sync_topic_comment_counts.sql)  
   Recalcula `comment_count` desde `forum_replies` (corrige el 138 del seed)

10. Ejecuta [`supabase/topic_moderation.sql`](../supabase/topic_moderation.sql)  
    Aprobación de temas: columna `status` (`pending` / `published` / `rejected`)

11. Ejecuta [`supabase/admin_roles.sql`](../supabase/admin_roles.sql)  
    Roles `member` / `moderator` / `admin` + RLS para moderación  
    Luego asigna tu cuenta: `update public.profiles set role = 'admin' where handle = 'jcaro';`

12. Ejecuta [`supabase/notify_admins_moderation.sql`](../supabase/notify_admins_moderation.sql)  
    Notificaciones in-app a la Junta (temas pendientes, reportes) y al autor al aprobar/rechazar

13. Ejecuta [`supabase/topic_follows.sql`](../supabase/topic_follows.sql)  
    Seguir hilos concretos + notificación `topic_activity` a seguidores del hilo

14. Ejecuta [`supabase/sync_forum_pillar_stats.sql`](../supabase/sync_forum_pillar_stats.sql)  
    Contadores reales, `last_activity_at` y **último hilo activo** (`last_topic_id` / `last_topic_title`)

15. Ejecuta [`supabase/profile_suspension.sql`](../supabase/profile_suspension.sql)  
    Suspender/reactivar cuentas desde la Junta + bloqueo de publicación en foros

16. Ejecuta [`supabase/notification_social.sql`](../supabase/notification_social.sql)  
    Aviso al seguir perfil que publica (`user_post`), menciones `@handle`, preferencias in-app

17. Ejecuta [`supabase/admin_forum_pillars.sql`](../supabase/admin_forum_pillars.sql)  
    Solo **admin** puede activar/desactivar pilares desde Junta → pestaña **Pilares**

18. Ejecuta [`supabase/mention_reply_scroll.sql`](../supabase/mention_reply_scroll.sql)  
    Si ya tenías `notification_social.sql`: añade `replyId` al payload para scroll a la respuesta al pulsar mención

19. Ejecuta [`supabase/calendar_events.sql`](../supabase/calendar_events.sql)  
    Calendario real + rol **`editor`** (hermandades / colaboradores). Solo `editor` y `admin` publican eventos.

    ```sql
    -- Hermandad o colaborador de confianza:
    update public.profiles set role = 'editor' where handle = 'hermandad_ejemplo';
    ```

20. Ejecuta [`supabase/calendar_notify.sql`](../supabase/calendar_notify.sql)  
    Avisos a usuarios cuando un evento del calendario queda **publicado/aprobado**. Respeta la preferencia **Avisos importantes** (`notify_calendar`).

20b. Ejecuta [`supabase/calendar_event_reminders.sql`](../supabase/calendar_event_reminders.sql)  
    Recordatorios **24 h** y **1 h** antes del evento. Activa **pg_cron** y ejecuta [`calendar_event_reminders_cron.sql`](../supabase/calendar_event_reminders_cron.sql).

20c. Ejecuta [`supabase/google_oauth_profile.sql`](../supabase/google_oauth_profile.sql)  
    Perfil automático al registrarse con Google (nombre, foto, handle único).

20d. Comprueba el despliegue con [`verify_calendar_oauth_deploy.sql`](../supabase/verify_calendar_oauth_deploy.sql)  
    Todas las filas deben mostrar `ok = true` (pg_cron solo tras el paso 20b).  
    Pruebas manuales en app: [`PRUEBAS-BETA.md`](PRUEBAS-BETA.md).

21. Ejecuta [`supabase/search_trends.sql`](../supabase/search_trends.sql)  
    Tendencias reales en Buscar: función `fetch_trending_hashtags` (#hashtags en temas y respuestas publicados). Sin SQL nuevo en tablas.

22. Ejecuta [`supabase/forum_reply_edit_delete.sql`](../supabase/forum_reply_edit_delete.sql)  
    Editar respuesta (30 min, sin hijos) + ocultar (soft delete) conservando texto para moderación/reportes.

23. **Push FCM** — ejecuta [`supabase/device_tokens.sql`](../supabase/device_tokens.sql) y sigue [`PUSH_FCM.md`](PUSH_FCM.md)  
24. **Escala (miles de usuarios)** — ejecuta [`supabase/scale_hardening_v1.sql`](../supabase/scale_hardening_v1.sql) y sigue [`SCALE.md`](SCALE.md)  
    Tabla `device_tokens`, Edge Function `send-push`, webhook en `notifications` INSERT, claves Firebase en `env.json`.

24. Ejecuta [`supabase/noticias_forum.sql`](../supabase/noticias_forum.sql)  
    Foro fijo **Noticias**: solo admin/moderadores crean; admin publica directo; moderador → pendiente Junta; avisos `news_published` + preferencia `notify_news`.  
    Tras el SQL, redeploy de la Edge Function `send-push` (mapea `news_published` → `notify_news`).

25. Ejecuta [`supabase/noticias_related_forum.sql`](../supabase/noticias_related_forum.sql)  
    Etiqueta opcional `related_forum_id` en noticias (asocia a Círculo / Pentagrama / Martillo / Hermandades sin duplicar el hilo).

26. Ejecuta [`supabase/noticias_forum_follow.sql`](../supabase/noticias_forum_follow.sql)  
    Botón **Seguir noticias**: `follows.target_type = 'forum'`. Los avisos `news_published` llegan **solo a quien sigue** Noticias (y tiene `notify_news`).

> Pantalla Junta en la app: Perfil → **Junta** (solo admin/moderator). Plan completo en [`ADMIN.md`](ADMIN.md)

## 4. Auth en Dashboard

**Authentication → Providers:**

| Provider | Acción |
|----------|--------|
| **Email** | Activar. **Confirm email: ON** (obligatorio en producción; ver nota abajo) |
| **Google** | Client ID/Secret — guía completa en [`GOOGLE_AUTH.md`](GOOGLE_AUTH.md) |
| **Apple** | Service ID + key (iOS) |

#### Confirmación de email (importante)

Si al registrarte **no llega el correo** y puedes entrar sin confirmar, casi seguro tienes **Confirm email desactivado**:

1. **Authentication** → **Providers** → **Email**
2. Activa **Confirm email** (confirmación de dirección)
3. Guarda

Comportamiento esperado con la opción **ON**:

- Registro → pantalla **Confirma tu email** (no entras aún al calendario)
- Llega el correo con plantilla **Confirm signup**
- Tras pulsar el enlace → login o sesión con email verificado
- Sin confirmar: puedes **explorar** la app si ya hay sesión, pero **no publicar ni seguir**

Con la opción **OFF** (solo dev rápido): no se envía confirmación y el login funciona al momento.

**Authentication → URL Configuration:**

- Site URL: `http://localhost:7357` (Flutter web) o tu dominio
- Redirect URLs: `cofradeo://login-callback`, `cofradeo://reset-password`, `http://localhost:**`, y la URL de tu app con `/#/verificar-email` (confirmación de email)

### Plantillas de email en español (recomendado)

Los correos de confirmación y recuperación **no salen del código Flutter**: los envía Supabase.

> **Si los campos Subject/Body están bloqueados** (aviso *«Set up custom SMTP to edit templates»*), primero debes configurar SMTP. Sin eso Supabase solo permite la plantilla en inglés por defecto.

#### Paso 1 — Configurar SMTP (obligatorio para editar)

**Opción A — Resend (recomendada, plan gratis para empezar)**

1. Cuenta en [resend.com](https://resend.com) → crea una **API Key**
2. Supabase → **Authentication** → **Emails** → **SMTP Settings** (o el botón **Set up SMTP**)
3. Rellena:

| Campo | Valor |
|-------|--------|
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | tu API key de Resend (`re_...`) |
| Sender email | `onboarding@resend.dev` *(solo pruebas; solo a tu email)* o `noreply@tudominio.com` *(producción, dominio verificado en Resend)* |
| Sender name | `Cofradero` |

4. **Save**

**Opción B — Integración directa:** [resend.com/supabase](https://resend.com/supabase) → *Connect to Supabase* (configura SMTP automáticamente).

También valen Brevo, SendGrid, Postmark, etc. — cualquier SMTP sirve.

#### Paso 2 — Editar plantillas

**Authentication** → **Emails** → **Reset password** / **Confirm signup**

| Plantilla | Asunto sugerido |
|-----------|-----------------|
| **Confirm signup** | `Confirma tu email — Cofradero` |
| **Reset password** | `Restablece tu contraseña — Cofradero` |

**Reset password** (cuerpo HTML):

```html
<h2>Restablece tu contraseña</h2>
<p>Hola,</p>
<p>Hemos recibido una solicitud para cambiar la contraseña de tu cuenta en <strong>Cofradero</strong>.</p>
<p><a href="{{ .ConfirmationURL }}">Elegir nueva contraseña</a></p>
<p>Si no fuiste tú, ignora este mensaje. El enlace caduca al poco tiempo.</p>
<p style="color:#888;font-size:12px;">Fe · Tradición · Hermandad</p>
```

**Confirm signup** (cuerpo HTML):

```html
<h2>Confirma tu cuenta</h2>
<p>Hola,</p>
<p>Gracias por unirte a <strong>Cofradero</strong>, la comunidad cofrade.</p>
<p><a href="{{ .ConfirmationURL }}">Confirmar mi email</a></p>
<p>Si no creaste esta cuenta, puedes ignorar este correo.</p>
<p style="color:#888;font-size:12px;">Fe · Tradición · Hermandad</p>
```

Variables: `{{ .ConfirmationURL }}`, `{{ .Email }}`, `{{ .SiteURL }}`.

#### Paso 3 — Probar

Guarda las plantillas y vuelve a usar «¿Olvidaste tu contraseña?» o un registro nuevo. El remitente debería ser **Cofradero** (ya no «Supabase Auth») y el texto en español.

**Producción:** verifica tu dominio en Resend (`noreply@cofradero.com` o similar). `onboarding@resend.dev` solo sirve para pruebas limitadas.

#### Error «Error sending confirmation email» al registrarse

Causa habitual con Resend en modo prueba:

- **Sender** `onboarding@resend.dev` → solo puedes enviar **al mismo email con el que creaste la cuenta Resend**
- Si registras `otro@gmail.com`, Resend rechaza el envío y Supabase muestra ese error

**Solución para beta real:**

1. Resend → **Domains** → añade tu dominio (ej. `cofradero.com`) y configura DNS
2. Supabase SMTP → **Sender email** `noreply@tudominio.com` (dominio verificado)
3. Vuelve a probar el registro

**Prueba rápida sin dominio:** regístrate usando **el mismo email** de tu cuenta Resend.

## 5. Probar flujo completo

1. `flutter run --dart-define-from-file=env.json`
2. **Perfil** → **Iniciar sesión** → registro con email
3. **Foros** → tema → escribir respuesta (se guarda en Supabase)
4. **Perfil** → **Editar** → cambiar bio y guardar

### Probar notificaciones (requiere 2 cuentas)

El trigger **no te notifica a ti mismo** si eres quien publica la respuesta. Con una sola cuenta no verás filas en `notifications` aunque todo funcione.

1. **Cuenta A** → Buscar → Seguir `#ViernesSanto`
2. **Cuenta B** (otro email) → Foros → tema *Viernes Santo* → publicar respuesta
3. **Cuenta A** → Notificaciones → debe aparecer «Nuevo comentario en #ViernesSanto»

### Probar seguir hilo (requiere 2 cuentas)

1. **Cuenta A** → Foros → hilo publicado → **Seguir hilo**
2. **Cuenta B** → mismo hilo → publicar respuesta
3. **Cuenta A** → Notificaciones → «Nueva respuesta en un hilo que sigues»

Comprueba en Table Editor: tabla `follows` (cuenta A) y `notifications` (user_id de cuenta A).

## 6. Qué usa Supabase ya

| Función | Estado |
|---------|--------|
| Login / registro email | ✅ |
| Google / Apple OAuth | ✅ UI (config en dashboard) |
| Perfil leer/editar + avatar | ✅ |
| Foros pilares/temas/respuestas | ✅ lectura + publicar respuesta + crear tema |
| Seguir hashtags (Buscar) | ✅ con login + Supabase · tendencias reales con `search_trends.sql` |
| Seguir perfiles | ✅ desde `/perfil/usuario/:id` |
| Notificaciones in-app | ✅ marcar leídas, limpiar, deslizar para borrar |
| Calendario | ✅ con Supabase |
| Búsqueda (temas + perfiles + eventos) | ✅ con Supabase · mock sin `env.json` |
| Bloquear, push | Push en Fase 9 — ver [`NOTIFICACIONES.md`](NOTIFICACIONES.md) |

## 7. Deep links móvil

Para Google/Apple en iOS/Android configura el scheme `cofradeo://login-callback`.  
[Docs Supabase + Flutter](https://supabase.com/docs/guides/auth/native-mobile-deep-linking)

---

*Ver también: [`AUTH.md`](AUTH.md) · [`PERFIL.md`](PERFIL.md) · [`NOTIFICACIONES.md`](NOTIFICACIONES.md)*
