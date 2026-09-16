# Administración y roles — Cofradero

Plan por fases (junio 2026). Complementa [`FOROS.md`](FOROS.md), [`PERFIL.md`](PERFIL.md), [`NOTIFICACIONES.md`](NOTIFICACIONES.md) y [`ROADMAP.md`](ROADMAP.md).

Objetivo: que la **Junta de Gobierno de la Comunidad Cofradiero** pueda moderar la app sin tocar Supabase a mano para siempre, y que los admins reciban avisos (in-app y luego push) cuando haga falta actuar.

---

## Dos conceptos distintos (no mezclar)

| Concepto | Campo / tabla | Para qué |
|----------|---------------|----------|
| **Tipo de cuenta** | `profiles.account_type` → `cofrade` \| `brotherhood` | Producto: cofrade personal vs hermandad oficial |
| **Rol de permisos** | `profiles.role` (nuevo) → `member` \| `moderator` \| `admin` | Quién puede moderar, aprobar temas, ver reportes |

Un cofrade puede ser admin. Una hermandad también. El rol **no** lo elige el usuario en la app.

---

## Estado actual (lo que ya hay)

| Hecho | Detalle |
|-------|---------|
| Temas con aprobación | `forum_topics.status`: `pending` \| `published` \| `rejected` |
| UI autor | Banner «Pendiente de aprobación de la Junta…», botón «Enviar a la Junta» |
| Lista pública | Solo temas `published` |
| Roles staff | `profiles.role`: `member` \| `moderator` \| `admin` — [`admin_roles.sql`](../supabase/admin_roles.sql) |
| Notif in-app Junta | Temas pendientes + reportes — [`notify_admins_moderation.sql`](../supabase/notify_admins_moderation.sql) |
| Pantalla Junta | `/perfil/junta` — aprobar/rechazar temas, reportes y (solo admin) pilares |
| Reportes / bloqueos | Tablas `reports`, `blocks` + menú en perfil ajeno |
| Notificaciones in-app | Tabla `notifications` + triggers (respuestas, seguidores) |

| Pendiente | Detalle |
|-----------|---------|
| Push FCM a admins | Fase 9 — [`NOTIFICACIONES.md`](NOTIFICACIONES.md) |
| Panel admin completo | Fase E — usuarios, métricas… (pilares MVP ya en Junta). Visión web: [`ADMIN-WEB.md`](ADMIN-WEB.md) |

---

## Visión por fases

```text
Fase A ──► role en BD + asignar admins a mano
    │
Fase B ──► trigger: tema pending → notificación in-app a admins
    │
Fase C ──► pantalla «Junta» en la app (aprobar temas + reportes)
    │
Fase D ──► push FCM a admins (y resto de eventos)
    │
Fase E ──► panel admin amplio (pilares, usuarios, hermandades…)
```

**Recomendación:** hacer **A → B → C** antes del lanzamiento beta; **D** con Fase 9; **E** cuando el volumen de usuarios lo justifique.

---

## Bloquear vs reportar (guía para la Junta)

Son **dos cosas distintas**. Con 25.000 usuarios y miles de bloqueos, la Junta **no debe** enterarse de cada bloqueo.

| Acción | Quién la hace | ¿Llega a la Junta? | ¿Notificación admin? | Efecto |
|--------|---------------|--------------------|----------------------|--------|
| **Bloquear** | Cualquier usuario logueado | **No** | **No** | Solo para quien bloquea: deja de ver respuestas de esa cuenta en foros |
| **Reportar** | Cualquier usuario logueado | **Sí** | **Sí** (1 aviso por objetivo reportado) | Cola en Perfil → **Junta** → pestaña **Reportes** |

Se puede reportar **perfiles**, **temas** y **respuestas** en foros. Los bloqueos siguen siendo solo entre usuarios.

### Dónde lo ve el administrador

1. **Perfil** (cuenta admin) → **Junta** → `/perfil/junta`
2. Pestaña **Reportes** — cola de cuentas/contenido denunciado
3. **Notificaciones** — tipo `Nuevo reporte` → al pulsar abre la Junta

Los **bloqueos** no tienen pantalla en la Junta: son privados (`blocks`: quién bloqueó a quién). No hay 1.000 notificaciones si 1.000 personas bloquean a alguien.

### Flujo recomendado para un reporte

1. Usuario pulsa ⋮ en perfil ajeno → **Reportar**, o bandera en tema/respuesta → motivo + detalles
2. La Junta recibe **una** notificación la primera vez que ese objetivo entra en cola
3. Si 20 usuarios más reportan el mismo perfil, tema o respuesta, **no** hay 20 notificaciones más; en la app se agrupan: «3 reportes · Acoso, Spam»
4. Moderador: **Ver perfil** / **Ver hilo** / **Ver autor** → decide → **Revisar todos** (marca todos los reportes de ese objetivo como revisados)
5. (Futuro Fase E) Panel de métricas: «cuentas más reportadas»
6. **Suspender cuenta** desde Junta (perfil, tema o respuesta) o desde el perfil ajeno si eres staff → [`profile_suspension.sql`](../supabase/profile_suspension.sql)

### Flujo de suspensión

1. Junta → **Reportes** → tarjeta agrupada → **Suspender** (suspende al **autor** del perfil, tema o respuesta)
2. O bien: perfil ajeno → sección **Acciones de la Junta** → **Suspender cuenta** (solo staff, no aplica a admin/moderador)
3. La cuenta deja de publicar (RLS en foros) y su contenido se oculta en listados como con un bloqueo global
4. El usuario recibe notificación in-app `Cuenta suspendida`
5. **Reactivar** desde la misma tarjeta en Junta o desde el perfil ajeno
6. No se puede suspender a admin/moderador

---

| Volumen | Comportamiento actual |
|---------|------------------------|
| 1.000 bloqueos/día | Silencioso para admins (correcto) |
| 50 reportes sobre la misma cuenta | 1 notificación + 1 tarjeta agrupada en Junta |
| 200 reportes distintos | 200 tarjetas en Junta (cuentas distintas); revisar por prioridad (más reportes arriba) |

### SQL a re-ejecutar si ya tenías el trigger antiguo

[`notify_admins_moderation.sql`](../supabase/notify_admins_moderation.sql) — incluye deduplicación de notificaciones por objetivo reportado.

---

## Fase A — Roles en base de datos

**Esfuerzo:** bajo · **Bloqueante para:** B, C, D

### SQL (`supabase/admin_roles.sql`)

```sql
alter table public.profiles
  add column if not exists role text not null default 'member'
  check (role in ('member', 'moderator', 'admin'));

-- El usuario NO puede cambiar su propio role (solo lectura en UPDATE propio)
-- Asignación manual inicial:
-- update public.profiles set role = 'admin' where handle = 'jcaro';
```

### Políticas RLS sugeridas

| Tabla | Regla |
|-------|--------|
| `profiles.role` | SELECT público (o solo self + admin); UPDATE de `role` solo vía service role / SQL manual |
| `forum_topics.status` | UPDATE a `published`/`rejected` solo si `profiles.role in ('admin','moderator')` |
| `reports` | SELECT solo admins/moderadores |

### App (mínimo)

- [x] Leer `role` en `profiles` al cargar sesión
- [x] `isAdminProvider` / `isModeratorProvider` / `isStaffProvider` en Dart
- [ ] Documentar en Supabase quién es admin (lista de handles)

### Criterio de «listo»

- Tu usuario tiene `role = admin` en BD
- La app distingue admin vs member (aunque aún no haya pantalla)

---

## Fase B — Notificar a la Junta (in-app)

**Esfuerzo:** bajo–medio · **Depende de:** Fase A

### Trigger SQL (`supabase/notify_admins_moderation.sql`)

Al `INSERT` en `forum_topics` con `status = 'pending'`:

1. Buscar todos los `profiles` con `role in ('admin', 'moderator')`
2. Insertar en `notifications` para cada uno:
   - `type`: `topic_pending_review`
   - `title`: «Nuevo tema pendiente»
   - `subtitle`: título del tema + autor
   - `payload`: `{ forumId, topicId, authorId }`

### Eventos adicionales (misma fase o B+)

| Evento | Destinatario | type sugerido |
|--------|--------------|---------------|
| Nuevo tema pendiente | Admins | `topic_pending_review` |
| Nuevo reporte | Admins | `new_report` |
| (Opcional) Tema publicado | Autor del tema | `topic_published` |
| (Opcional) Tema rechazado | Autor del tema | `topic_rejected` |

### App

- [x] Nuevo tipo en `AppNotification` + navegación al tema o cola de moderación
- [x] Icono / copy acorde («La Junta debe revisar…»)

### Criterio de «listo»

- Cofrade crea tema → admins ven notificación en tab Notificaciones
- Autor no recibe «publicado» hasta que admin apruebe (Fase C o manual)

---

## Fase C — Pantalla «Junta» (MVP admin en la app)

**Esfuerzo:** medio · **Depende de:** A + B

Pantalla visible **solo** si `role in ('admin', 'moderator')`. Acceso: Perfil → enlace «Junta de Gobierno» o icono en app bar.

### Sección 1 — Temas pendientes

| Acción | Efecto |
|--------|--------|
| **Aprobar** | `status = published` → visible en foro |
| **Rechazar** | `status = rejected` → autor ve banner |
| Ver detalle | Abre el hilo en preview |

### Sección 2 — Reportes

- Lista `reports` con `status = pending`
- Motivo, autor del reporte, enlace al perfil/contenido
- Acciones: marcar revisado, (futuro) suspender usuario

### Sección 3 — Pilares (solo admin)

- Pestaña **Pilares** visible solo si `role = admin`
- Toggle **Foro abierto** (`is_enabled`) — abre/cierra Cuaresma, Semana Santa, Glorias u otros
- Toggle **Badge «Activo»** (`is_active`) — llama en la tarjeta del foro
- Confirmación al cerrar foros permanentes (General, Hermandades…)
- SQL: [`admin_forum_pillars.sql`](../supabase/admin_forum_pillars.sql)

```text
AdminRepository.fetchPillars()
AdminRepository.updatePillar(pillarId, isEnabled?, isActive?)
```

Moderadores **no** ven esta pestaña ni pueden actualizar pilares (RLS).

### Repositorio / RPC

```text
ModerationRepository.fetchPendingTopics()
ModerationRepository.setTopicStatus(topicId, published|rejected)
ModerationRepository.fetchPendingReports()
ModerationRepository.resolveReport(reportId)
```

RLS debe permitir SELECT/UPDATE solo a admin/moderator.

### Criterio de «listo»

- No hace falta entrar en Supabase Table Editor para aprobar temas del día a día
- Reportes visibles y gestionables desde la app

---

## Fase D — Push FCM a administradores (Fase 9)

**Esfuerzo:** medio–alto · **Depende de:** A, B, infra FCM

Misma arquitectura que [`NOTIFICACIONES.md`](NOTIFICACIONES.md):

```text
Trigger → notifications (in-app)
       → Edge Function → FCM → device_tokens de usuarios con role admin/moderator
```

### SQL adicional

- [`supabase/notifications_push.sql`](../supabase/notifications_push.sql) — `device_tokens`, preferencias
- Filtro en Edge Function: si `notification.type` es de moderación → solo tokens de admins

### Tipos push prioritarios para admins

| type | Push |
|------|------|
| `topic_pending_review` | «Nuevo tema esperando la Junta» |
| `new_report` | «Nuevo reporte de moderación» |

### App

- [ ] `firebase_messaging` + permisos
- [ ] Registrar token en `device_tokens` al login
- [ ] Preferencia «Avisos de moderación» (admins)

### Criterio de «listo»

- Admin con app cerrada recibe push al crear un tema pendiente

---

## Fase E — Panel admin amplio (post-lanzamiento)

**Esfuerzo:** alto · **Cuándo:** volumen de usuarios o varios moderadores

No es necesario para el primer beta. Incluiría:

| Módulo | Funciones |
|--------|-----------|
| **Pilares** | ✅ MVP en Junta (activar/desactivar, badge) — ver abajo |
| **Usuarios** | Buscar, suspender, cambiar `role`, verificar hermandad |
| **Hermandades** | Cola de verificación, reservar handles oficiales |
| **Métricas** | Temas/día, reportes, usuarios activos |
| **Config** | Términos prohibidos, límites de publicación |

Alternativa intermedia: **panel web** (Retool, Supabase Studio custom, o mini Next.js) solo para ti, sin meter todo en Flutter.

---

## Matriz rol × permiso

| Acción | member | editor | moderator | admin |
|--------|--------|--------|-----------|-------|
| Crear tema (→ pending) | ✅ | ✅ | ✅ | ✅ |
| Aprobar / rechazar tema | ❌ | ❌ | ✅ | ✅ |
| Ver reportes | ❌ | ❌ | ✅ | ✅ |
| Ban / suspender cuenta | ❌ | ❌ | ⚠️ opcional | ✅ |
| Gestionar pilares | ❌ | ❌ | ❌ | ✅ |
| Publicar eventos calendario | ❌ | ✅ | ❌ | ✅ |
| Asignar roles | ❌ | ❌ | ❌ | ✅ (SQL / panel E) |

---

## Orden de ejecución recomendado

| # | Tarea | Archivos / notas |
|---|--------|------------------|
| 1 | Ejecutar `topic_moderation.sql` si falta | Ya en repo |
| 2 | Crear y ejecutar `admin_roles.sql` | Fase A |
| 3 | `update profiles set role = 'admin' where …` | Tu cuenta |
| 4 | Dart: leer `role`, providers | `auth_provider`, `user_profile` |
| 5 | Trigger notif admins tema pending | Fase B SQL + `notifications` type |
| 6 | Pantalla Junta + repo moderación | Fase C |
| 7 | FCM + device_tokens | Fase D — [`NOTIFICACIONES.md`](NOTIFICACIONES.md) |
| 8 | Panel pilares (MVP) | Junta → Pilares + `admin_forum_pillars.sql` |
| 9 | Panel usuarios / métricas | Fase E restante |

---

## Checklist resumido

### Fase A — Roles
- [x] Columna `profiles.role`
- [x] RLS: usuario no puede auto-promoverse
- [ ] Al menos un admin asignado en BD
- [x] App lee rol en sesión

### Fase B — Avisos in-app
- [x] Trigger tema `pending` → notif admins
- [x] Trigger reporte → notif admins
- [x] Tipos nuevos en modelo `AppNotification`
- [x] Navegación desde notificación al tema

### Fase C — Pantalla Junta
- [x] Ruta `/perfil/junta` (solo admin/moderator)
- [x] Lista temas pendientes + aprobar/rechazar
- [x] Lista reportes pendientes
- [x] Pestaña Pilares (solo admin): abrir/cerrar foros y badge activo
- [x] Sin Table Editor para el día a día

### Fase D — Push
- [ ] `device_tokens` + FCM
- [ ] Edge Function filtra admins en eventos de moderación
- [ ] Preferencias push

### Fase E — Panel completo
- [x] Pilares MVP (Junta → activar/desactivar, badge)
- [ ] Usuarios, métricas, reordenar pilares (o panel web externo)

---

## ¿Es mucho jaleo?

| Alcance | Jaleo | ¿Cuándo? |
|---------|-------|----------|
| Solo Fase A + B | **Poco** | Esta semana si quieres |
| + Fase C (Junta mínima) | **Razonable** | Antes de beta con usuarios reales |
| + Fase D (push) | **Medio** | Fase 9 del roadmap |
| Fase E completa | **Mucho** | Cuando duela no tenerlo |

**Conclusión:** no montes el «modo admin» entero de golpe. Con **rol en BD + notificaciones a admins + pantalla Junta** tienes un sistema profesional y cofrade sin meses de desarrollo.

---

*Ver también: [`FOROS.md`](FOROS.md) · [`PERFIL.md`](PERFIL.md) · [`NOTIFICACIONES.md`](NOTIFICACIONES.md) · [`SUPABASE.md`](SUPABASE.md)*
