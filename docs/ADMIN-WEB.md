# Panel web de administración — Cofradeo

Documento de planificación (septiembre 2026). Complementa [`ADMIN.md`](ADMIN.md), [`NOTIFICACIONES.md`](NOTIFICACIONES.md), [`ESPACIOS-PUBLICITARIOS.md`](ESPACIOS-PUBLICITARIOS.md) y la Junta in-app (`/perfil/junta`).

**Estado:** Fases 0–5 + Quiz MVP en [`admin-web/`](../admin-web/). Pendiente: métricas de producto. Ver [`admin-web/README.md`](../admin-web/README.md). Requiere `staff_notifications_overview.sql`.

---

## ¿Tiene sentido si ya hay Junta en la app?

**Sí.** No sustituye la Junta móvil: la complementa.

| | App (Junta) | Web (dashboard) |
|--|-------------|-----------------|
| **Para qué** | Operar al vuelo: aprobar un tema, un reporte, un evento | Gestión de mesa: listados largos, filtros, CSV, métricas, altas masivas |
| **Cuándo** | En la calle / con el móvil | En el PC, con teclado y varias pestañas |
| **Quién** | Admin + moderadores (urgencias) | Sobre todo admin / “oficina” de la comunidad |
| **Riesgo** | Pantalla pequeña, fácil equivocarse en lotes | Si se hace mal, superficie de ataque más grande → hay que cerrar bien auth |

Mantener **las dos** es el patrón habitual (Instagram tiene app + Meta Business; Discord app + servidor web, etc.). La app sigue siendo el producto; la web es el **centro de control**.

---

## Principio de producto

> Misma verdad en Supabase. Misma autoridad (`profiles.role` = `admin` / `moderator`).  
> La web **no** es otro backend: es otra UI contra el mismo proyecto.

- Login con cuenta staff (mismo Auth de Supabase).
- RLS y policies actuales; si hace falta más lectura agregada (métricas), RPCs `security definer` solo para staff (como `get_ad_statistics`).
- **Nunca** meter la `service_role` key en el front web.

---

## Carpeta prevista (cuando se arranque)

Propuesta dentro del monorepo (o repo hermano):

```text
cofradeo/
  lib/                 # app Flutter (producto)
  supabase/            # SQL / policies compartidas
  docs/
  admin-web/           # ← panel Angular (o el stack que se elija)
    README.md
    src/
    ...
```

Nombre alternativo: `cofradeo-admin/`. Lo importante es que quede **aparte** de Flutter y no mezcle assets de la app.

---

## Stack (decisión pendiente)

El usuario pidió mentalidad **Angular / dashboard clásico**. Opciones razonables:

| Opción | Pros | Contras |
|--------|------|---------|
| **Angular** | Encaja con “panel de gestión”, estructura clara, tablas, rutas | Más ceremonioso para un MVP pequeño |
| **Next.js / React** | Rápido de montar, buen ecosistema con Supabase JS | Menos “enterprise dashboard” out of the box |
| **Flutter Web** | Reutilizar algo de UI/lógica | Dashboards densos en web suelen ir peor; no recomendado como panel principal |

**Recomendación de arranque:** Angular + Angular Material (o similar) + `@supabase/supabase-js`, mismo proyecto Supabase que la app. Si el equipo prefiere React, el mapa de módulos no cambia.

Hosting sugerido más adelante: Vercel / Netlify / Cloudflare Pages, dominio tipo `admin.cofradeo.app`, acceso solo staff.

---

## Qué debe cubrir (mapa funcional)

Basado en lo que **ya existe** en Junta + huecos típicos de un panel completo.

### 1. Resumen (home)

- Colas: temas pendientes, reportes, eventos, cierres solicitados.
- Altas de usuarios (hoy / 7 días / 30 días).
- Patrocinios: resumen del mes (vistas, clics, CTR) — reutilizar la lógica de periodo.
- Enlaces rápidos a cada módulo.

### 2. Moderación (paridad con la app)

| Módulo app | En web |
|------------|--------|
| Temas pendientes | Lista + aprobar / rechazar + motivo |
| Historial de rechazos | Igual |
| Reportes | Cola agrupada, suspender, resolver |
| Eventos pendientes | Aprobar / rechazar |
| Cierres solicitados | Gestionar |

### 3. Personas y roles

| Capacidad | Notas |
|-----------|--------|
| Listado de usuarios | Buscar por handle, email, nombre; filtros `role`, `account_type`, fecha de alta |
| Altas recientes | Quién se registra (diario / semanal) |
| Moderadores / admins | Asignar o quitar rol (hoy ya hay pestaña Moderadores) |
| Hermandades | Cuentas oficiales (paridad con Junta → Hermandades) |
| Suspensiones / bloqueos de staff | Visibilidad de cuentas sancionadas |

### 4. Notificaciones (visión “quién tiene qué activo”)

Hoy la app gestiona preferencias en el dispositivo del usuario. En web admin se quiere **visión global**:

- Quién tiene push activo (token FCM / preferencias).
- Qué tipos de aviso tiene encendidos (hilos, noticias, seguidores…).
- Volumen de notificaciones generadas por tipo / día.
- (Opcional) reenviar o diagnosticar fallos de push.

Requiere revisar tablas/prefs reales en [`NOTIFICACIONES.md`](NOTIFICACIONES.md) y [`PUSH_FCM.md`](PUSH_FCM.md) al implementar; puede hacer falta alguna vista o RPC agregada solo-staff.

### 5. Contenido y apariencia

- Foros / pilares / portadas / temas destacados (paridad con «Foros y apariencia»).
- Temporada / countdown.
- Noticias (si se opera desde staff).

### 6. Patrocinios

- Mapa de zonas, altas, pack «todas las zonas», quitar de zona.
- Informe por mes / CSV (misma RPC `get_ad_statistics`).
- Vista de ocupación por slot.

### 7. Quiz en vivo

- Paridad con «Pregunta en vivo» (crear, lanzar, cerrar). En móvil es cómodo; en web también para quien opera desde PC.

### 8. Métricas de producto (fase posterior)

- DAU / MAU aproximados.
- Temas / respuestas por foro.
- Retención simple.
- Embudo registro → primer post.

No bloquear el MVP del panel por esto.

---

## Roles en la web

Misma matriz que [`junta_modules.dart`](../lib/features/admin/junta_modules.dart):

- **Admin:** todo.
- **Moderador:** colas de moderación; no necesariamente patrocinios / temporada / altas de hermandad (alineado con la app).
- **Member:** no entra (redirigir / 403).

---

## Fases de construcción

```text
Fase 0 ──► admin-web + Auth Supabase + layout + guard staff   ✅ hecha
Fase 1 ──► Resumen + colas de moderación (temas, reportes, eventos, cierres) ✅ hecha
Fase 2 ──► Usuarios: altas, búsqueda, roles, moderadores, hermandades ✅ hecha
Fase 3 ──► Patrocinios + informe mensual ✅ hecha
         └► Empresas + Finanzas (cobros/gastos) ✅ hecha
Fase 4 ──► Foros (hero/portadas/temas destacados) + Temporada ✅ hecha
Fase 5 ──► Notificaciones globales (prefs / push / diagnóstico) ✅ hecha
Fase 6 ──► Quiz (MVP web) ✅ hecha · métricas de producto pendiente
```

Cada fase debe poder usarse en producción sin esperar a la siguiente.

---

## Relación con la Junta móvil

- **No duplicar lógica de negocio en dos sitios a ciegas:** preferir SQL/RPC compartidos y clientes delgados.
- Features urgentes (aprobar tema a las 23:00) siguen en la **app**.
- Features de mesa (exportar 3 meses de CTR, buscar 200 usuarios) van a la **web**.
- Si un módulo nace en web, valorar un atajo mínimo en app solo si se usa en movilidad.

---

## Seguridad y operación

1. Solo HTTPS; dominio admin separado.
2. Sesión Supabase; refresh tokens; logout claro.
3. Auditoría ligera (quién aprobó / borró) — deseable a medio plazo.
4. Rate limit en RPCs sensibles.
5. Sin `service_role` en el navegador.
6. Checklist de “¿esta query la puede hacer un moderador?” antes de cada pantalla.

---

## Decisiones abiertas (para cuando se meta mano)

- [x] Angular vs Next.js → **Angular 19** en `admin-web/`
- [ ] ¿Misma org GitHub / mismo monorepo? (ahora monorepo)
- [ ] ¿Dominio `admin.cofradeo.app`?
- [ ] ¿Moderadores entran a la web o solo admins al principio? (ahora: admin + moderador de foro)
- [ ] ¿Prioridad Fase 1 (moderación) o Fase 2 (usuarios + notificaciones)?

---

## Resumen

Sí lo veo bien **aunque** el admin se pueda controlar desde la app: la web es el puesto de mando; la app es el mando a distancia. Empezar con este documento basta; cuando se quiera construir, crear `admin-web/`, Fase 0 de auth, y luego ir módulo a módulo según el mapa de arriba.
