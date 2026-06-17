# Cofradero — Modelo de foros (pilares)

> Cómo está organizada la comunidad y qué vendrá en el panel de administración.

---

## Jerarquía

```
Pilar (foro)          ← fijo, lo gestiona el admin
  └── Tema            ← lo crea un usuario
        └── Respuestas ← comentarios en el hilo
```

---

## Los 6 pilares

| Orden | Pilar | Estado actual (mock) | Cuándo activarlo |
|-------|-------|----------------------|------------------|
| 1 | **Foro Cofradiero** | Abierto | Siempre |
| 2 | **Pentagrama Cofrade** | Abierto | Siempre |
| 3 | **Martillo y Trabajadera** | Abierto | Siempre |
| 4 | **Semana Santa** | Bloqueado | Semana Santa |
| 5 | **Cuaresma** | Bloqueado | Cuaresma |
| 6 | **Glorias** | Bloqueado | Domingo de Resurrección / glorias |

Los **3 de temporada** aparecen en la lista pero **no se puede entrar** hasta que tú (admin) los actives.

---

## Campos de cada pilar (ya en código)

| Campo | Qué hace |
|-------|----------|
| `sortOrder` | Posición en la lista (menor = más arriba) |
| `isEnabled` | `true` = se puede entrar · `false` = bloqueado |
| `lockedLabel` | Texto bajo la tarjeta, ej. «Se activará en Cuaresma» |
| `isActive` | Muestra badge **Activo** (comunidad viva) |

---

## Qué puedes hacer hoy vs futuro

| Acción | Ahora (Fase 2–7) | Futuro (Fase 8+) |
|--------|------------------|------------------|
| Ver pilares abiertos y bloqueados | Sí | Sí |
| Entrar en pilares abiertos | Sí | Sí |
| Cambiar orden / activar pilares | Editar `mock_forums.dart` | Panel **Admin** en la app |
| Dar permisos a otros admins | No | Roles: `admin`, `moderador` |
| Activar Cuaresma automáticamente por fecha | No | Opcional: reglas por calendario |

**No es fango:** es la decisión correcta. Solo estamos **preparando el modelo**; el panel admin llega cuando haya backend.

---

## Panel administrador

**Implementado (MVP):** Perfil → **Junta** → pestaña **Pilares** (solo `role = admin`):

- Toggle **Foro abierto** por pilar (`is_enabled`)
- Toggle **Badge «Activo»** (`is_active`) — llama en la tarjeta
- Confirmación al cerrar foros permanentes
- SQL: [`admin_forum_pillars.sql`](../supabase/admin_forum_pillars.sql)

**Pendiente (Fase E):**

- Lista con **drag & drop** para ordenar
- Editar nombre, descripción, icono
- (Opcional) Programar activación: «Cuaresma → 1 de marzo»

En Supabase, tabla `forum_pillars`:

```sql
forum_pillars (
  id, name, description, sort_order,
  is_enabled, is_active, locked_label,
  icon_key, ...
)
```

---

## Modificar pilares a mano (fallback sin SQL admin)

Archivo: `lib/features/forums/data/mock_forums.dart`

- Cambiar `sortOrder` para reordenar
- Poner `isEnabled: true` para abrir un pilar de temporada
- Ajustar `lockedLabel` con el mensaje que quieras mostrar

---

*Ver también: [`ROADMAP.md`](ROADMAP.md) · [`AUTH.md`](AUTH.md) · [`ADMIN.md`](ADMIN.md)*
