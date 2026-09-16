# Cofradero — Pruebas antes de la beta

Checklist manual para comprobar que la app y Supabase funcionan bien con usuarios reales. Marca cada casilla cuando lo hayas probado.

**Tiempo estimado:** 45–90 min (con 2 cuentas de prueba).

---

## Antes de empezar

### Cuentas recomendadas

| Cuenta | Rol | Para qué |
|--------|-----|----------|
| **A** | Usuario normal (`member`) | Flujos de cofrade |
| **B** | Usuario normal (`member`) | Seguir, notificaciones, bloqueos |
| **Admin** | `admin` o `moderator` | Junta, calendario, moderación |

### SQL que debe estar desplegado

Orden en [`SUPABASE.md`](SUPABASE.md) (pasos 20–20d):

- [ ] `calendar_notify.sql`
- [ ] `calendar_event_reminders.sql`
- [ ] Extensión **pg_cron** activa en Supabase
- [ ] `calendar_event_reminders_cron.sql`
- [ ] `google_oauth_profile.sql`
- [ ] `verify_calendar_oauth_deploy.sql` → todas las filas con `ok = true`

### Entorno

- [ ] App apuntando al proyecto Supabase correcto (`env.json`)
- [ ] Probar en **dispositivo real** o emulador (no solo web), al menos una pasada
- [ ] `flutter test` pasa en local (41 tests)

---

## 1. Supabase — verificación SQL

Ejecuta en **SQL Editor** el archivo [`supabase/verify_calendar_oauth_deploy.sql`](../supabase/verify_calendar_oauth_deploy.sql).

- [ ] `profiles` → ok
- [ ] `calendar_events` → ok
- [ ] `notification_preferences.notify_calendar` → ok
- [ ] `trigger on_calendar_published_notify_users` → ok
- [ ] `notify_pref_enabled (calendar)` → ok
- [ ] `calendar_reminder_dispatches` → ok
- [ ] `dispatch_calendar_event_reminders()` → ok
- [ ] `handle_new_user (Google avatar)` → ok
- [ ] `on_auth_user_created trigger` → ok

**Cron (opcional, tras activar pg_cron):**

```sql
select jobname, schedule from cron.job
where jobname = 'dispatch-calendar-event-reminders';
```

- [ ] El job existe y el schedule es `*/15 * * * *`

---

## 2. Calendario — aviso al publicar

**Objetivo:** cuando se publica un evento, los usuarios con «Avisos importantes» reciben notificación in-app.

1. Cuenta **A** → Perfil → **Notificaciones** → activar **Avisos importantes del calendario**
2. Cuenta **Admin/editor** → crear evento y dejarlo en estado **publicado** (`published`)
3. Cuenta **A** → campana → debe aparecer notificación tipo calendario
4. Pulsar la notificación → abre el calendario / el evento

- [ ] Llega la notificación a A
- [ ] No llega al autor del evento (quien lo creó)
- [ ] Si A tiene desactivado «Avisos importantes», **no** llega
- [ ] Editar un evento ya publicado **no** duplica el aviso masivo

**Comprobar en SQL (opcional):**

```sql
select user_id, type, title, created_at
from public.notifications
where type = 'calendar'
order by created_at desc
limit 10;
```

---

## 3. Calendario — recordatorios 24 h y 1 h

**Objetivo:** avisos automáticos antes del evento (cron cada 15 min).

### Opción A — evento de prueba

1. Cuenta **A** con «Avisos importantes» activado
2. Admin crea evento que empiece en **~1 hora**
3. Espera hasta 15 min (o ejecuta manualmente en SQL):

```sql
select public.dispatch_calendar_event_reminders();
```

4. Cuenta **A** debe recibir notificación **«Empieza pronto»**

- [ ] Recordatorio 1 h funciona
- [ ] Segunda ejecución **no** duplica (tabla `calendar_reminder_dispatches`)

### Opción B — evento mañana

- [ ] Evento en ventana 23–24 h → notificación **«Mañana en el calendario»**

### UI del calendario

- [ ] Abrir un día con eventos → se ven títulos y portadas
- [ ] Evento sin imagen → fallback con icono de tipo (no pantalla rota)
- [ ] Volver al calendario tras visitar un evento → imágenes cargan rápido (caché)

---

## 4. Google OAuth

Guía de configuración: [`GOOGLE_AUTH.md`](GOOGLE_AUTH.md)

1. Cerrar sesión
2. **Continuar con Google** con cuenta **nueva** (o borrar usuario de prueba en Auth antes)
3. Comprobar perfil creado automáticamente

- [ ] Entra sin error
- [ ] Tiene **nombre** visible (no solo email)
- [ ] Tiene **foto** de Google (si Google la proporciona)
- [ ] Tiene **@handle** válido (3–20 caracteres, sin choque)
- [ ] Si el nombre de Google es muy largo, no falla (máx. 40 caracteres)
- [ ] Con nombre real de Google (p. ej. «Juan García») → **no** aparece «Completar perfil», va directo al calendario
- [ ] Segundo login con la misma cuenta Google → **tampoco** pide completar perfil (`onboarding_completed` se marca solo)

---

## 5. Auth y registro (email)

- [ ] Registro con email + contraseña (con nombre y @handle en el formulario) → **no** pide completar perfil
- [ ] Login de vuelta con esa cuenta → entra directo al calendario
- [ ] Verificación de email (si está activa en Supabase)
- [ ] Login / logout
- [ ] Recuperar contraseña (si está configurado)
- [ ] Sin sesión: Perfil pide login (no muestra datos mock)
- [ ] Cuenta con email `juan@gmail.com` y perfil genérico (handle/nombre = juan) → **sí** muestra completar perfil hasta personalizar
- [ ] En completar perfil aparece el bloque **«¿Por qué te pedimos esto?»** con el motivo (handle del email, nombre genérico, etc.)

---

## 6. Perfil

### Propio

- [ ] Editar nombre, bio, datos de hermandad
- [ ] Subir **avatar** → se optimiza y se ve al instante
- [ ] Tras subir avatar, **no** se recarga todo el foro (solo el perfil)
- [ ] Menú **Tu cuenta** con rol Junta → scroll si hay muchas opciones (no overflow)

### Público / seguir

- [ ] Ver perfil de otro usuario
- [ ] Seguir / dejar de seguir
- [ ] Contador **Siguiendo** en header = solo personas (no foros)
- [ ] Pestaña **Siguiendo** → filtros Personas / Foros
- [ ] Pestaña **Información** → sin bloque «Estadísticas» duplicado (stats solo en header)

### Bloquear / reportar

- [ ] Bloquear cuenta → deja de ver su contenido en foros
- [ ] Reportar perfil / tema / respuesta → llega a Junta (cuenta admin)

---

## 7. Foros

- [ ] Lista de foros carga (hero, pilares, temas)
- [ ] Abrir un hilo → respuestas visibles
- [ ] Crear respuesta (cuenta verificada si aplica)
- [ ] Reacciones en respuestas
- [ ] Imagen de cartel en post oficial → carga, zoom «Ver completa»
- [ ] Scroll en lista de temas → volver → imágenes desde caché (sin parpadeo largo)
- [ ] Hermandad: crear comunicado con imagen (si tienes permiso)

**Fuera de alcance beta (no bloquear lanzamiento):**

- Mejoras específicas foros Cuaresma / Semana Santa

---

## 8. Junta (admin / moderador)

Ruta: Perfil → **Junta** (`/perfil/junta`)

- [ ] Pestaña **Temas pendientes** → aprobar / rechazar
- [ ] Pestaña **Reportes** → ver y marcar revisados
- [ ] Pestaña **Pilares** → títulos con badges (sin texto vertical roto)
- [ ] **Moderadores** → buscar `@handle` al escribir
- [ ] **Hermandades** → misma búsqueda por handle
- [ ] Notificación «Nuevo tema pendiente» / «Nuevo reporte» → abre Junta

---

## 9. Notificaciones

- [ ] Bandeja carga con distintos tipos (foro, calendario, menciones…)
- [ ] Al pulsar una notificación, navega al sitio correcto
- [ ] Preferencias: activar/desactivar cada tipo y comprobar que se respeta
- [ ] Punto rojo en campana desaparece al leer

**Push FCM** (solo si ya desplegaste [`PUSH_FCM.md`](PUSH_FCM.md)):

- [ ] Token en `device_tokens`
- [ ] Push llega al móvil con app en segundo plano

---

## 10. Buscar

- [ ] Buscar por texto → filtra temas
- [ ] Historial / recientes
- [ ] Tendencias (si `search_trends.sql` está desplegado)
- [ ] Atajo al calendario desde resultados

---

## 11. Rendimiento e imágenes (smoke test rápido)

- [ ] Scroll largo en foros + calendario → sin cuelgues evidentes
- [ ] Volver a una pantalla ya visitada → avatares y carteles casi instantáneos
- [ ] Subir avatar grande → snackbar de optimización o subida correcta
- [ ] Modo avión tras haber cargado imágenes → se ven las cacheadas donde aplique

---

## 12. Anuncios / patrocinios (si activos)

- [ ] Tarjeta de anuncio muestra logo e imagen
- [ ] Enlace externo abre navegador
- [ ] Junta → pestaña anuncios: preview de imagen remota

---

## 13. Build de release (antes de enviar a testers)

Guía completa paso a paso: [`PUBLICAR.md`](PUBLICAR.md).

- [ ] `flutter build apk` o `appbundle` sin errores
- [ ] `flutter build ios` / TestFlight (si aplica)
- [ ] Probar build **release** en un dispositivo (no solo `flutter run` debug)
- [ ] Variables sensibles solo en `env.json` / CI, no en el repo
- [ ] Android: firma **release** (no debug) antes de Play Store

---

## Registro de incidencias

Anota aquí lo que falle para no perderlo:

| Fecha | Pantalla / flujo | Qué pasó | Severidad (bloqueante / menor) |
|-------|------------------|----------|--------------------------------|
| | | | |
| | | | |

**Severidad:**

- **Bloqueante:** no se puede registrar, publicar, o la app crashea en flujo principal → arreglar antes de beta
- **Menor:** UI rara, texto, edge case → puede ir en siguiente iteración

---

## Referencias

| Tema | Documento |
|------|-----------|
| **Publicar Android / iOS** | [`PUBLICAR.md`](PUBLICAR.md) |
| Despliegue SQL | [`SUPABASE.md`](SUPABASE.md) |
| Google login | [`GOOGLE_AUTH.md`](GOOGLE_AUTH.md) |
| Junta y moderación | [`ADMIN.md`](ADMIN.md) |
| Notificaciones | [`NOTIFICACIONES.md`](NOTIFICACIONES.md) |
| Push | [`PUSH_FCM.md`](PUSH_FCM.md) |
| Verificación SQL calendario/OAuth | [`verify_calendar_oauth_deploy.sql`](../supabase/verify_calendar_oauth_deploy.sql) |
