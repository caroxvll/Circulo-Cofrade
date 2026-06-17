# Perfil, edición y bloqueos — Cofradero

Decisión de producto (junio 2026). Complementa Fase 5 (UI mock) y Fase 8 (cuentas reales).

## ¿Te estás metiendo en camisa de once varas?

**No.** Editar perfil, validar nombres y bloquear usuarios es lo normal en cualquier red (Instagram, X, foros). La clave es **no hacerlo todo a la vez**:

| Cuándo | Qué |
|--------|-----|
| **Fases 0–7** | Ver perfiles mock, sin editar ni bloquear |
| **Fase 8** | Login + editar perfil + bloquear/reportar (MVP social) |
| **Post-lanzamiento** | Verificación de hermandades, moderación avanzada |

---

## Dos tipos de cuenta

| | **Cofrade** (personal) | **Hermandad** (oficial) |
|--|------------------------|-------------------------|
| Ejemplo | `@jose_carpintero` | `@hermandad_sevilla` |
| Nombre visible | Editable con reglas | **Verificado** — no libre al gusto |
| Handle `@` | Editable (límite de cambios) | Asignado o verificado por admin |
| Avatar | Sí, sube foto | Logo oficial de la hermandad |
| Bio, web, dirección | Bio sí · resto opcional | Todos — solo admins de la cuenta |
| Badge | — | «Cuenta verificada» (opcional) |

Así evitas que alguien ponga **«Pedro por su casa»** como nombre de **Hermandad de la Macarena**. Los nombres sensibles quedan protegidos.

---

## Editar perfil (estilo Instagram, con límites)

Pantalla **Editar perfil** (Fase 8), accesible desde el propio perfil (icono lápiz o «Editar perfil»).

### Campos editables

| Campo | Cofrade | Hermandad | Validación |
|-------|---------|-----------|------------|
| **Foto / avatar** | ✅ | ✅ (logo) | Tamaño máx., formatos JPG/PNG; moderación manual o filtro básico |
| **Nombre visible** | ✅ | ⚠️ Solo con verificación | Longitud 2–40, sin vacío, lista de palabras prohibidas, sin suplantar hermandades |
| **Handle `@`** | ✅ (p. ej. 1 cambio / 30 días) | 🔒 Admin | Solo `a-z`, números, `_`; único en BD |
| **Bio** | ✅ | ✅ | Máx. ~160 caracteres; filtro de insultos |
| **Dirección, fundación, web** | Opcional | ✅ | Web con formato URL; textos con longitud máx. |

### Qué NO se puede hacer

- Usar nombres de hermandades reales sin verificación
- Handles ofensivos o que imiten cuentas oficiales (`@hermandad_sevilla2`)
- Dejar nombre vacío o solo emojis/símbolos
- Cambiar el **tipo** de cuenta (cofrade ↔ hermandad) sin proceso admin

### Validación técnica (Fase 8)

1. **Cliente**: longitud, caracteres permitidos, feedback inmediato
2. **Servidor** (Supabase Edge Function o trigger): mismas reglas + lista de términos bloqueados
3. **Opcional**: cola de revisión si el nombre contiene palabras «grises» o si la cuenta es hermandad

---

## Bloquear usuarios y hermandades

**Sí, tiene sentido** — sobre todo para hermandades que reciben spam o acoso.

### Qué hace «Bloquear»

| Efecto | Detalle |
|--------|---------|
| No ves su contenido | Posts, respuestas y perfil ocultos en feed y búsqueda |
| No te notifican | Sin avisos de quien bloqueaste |
| No interactúan contigo | No comentan en tus hilos (cuando exista permiso por cuenta) |
| Siguen sin saberlo | No mostramos «Te ha bloqueado» (estándar Instagram) |

### Dónde aparece la opción

- Perfil ajeno → menú `···` → **Bloquear** / **Reportar**
- Hermandades: mismas opciones; una hermandad puede bloquear a un cofrade (y viceversa)

### Bloquear ≠ Reportar

| Acción | Para qué |
|--------|----------|
| **Bloquear** | Protegerte tú (inmediato, privado) |
| **Reportar** | Avisar a moderación (contenido, acoso, suplantación) |

Ambas conviven. Reportar puede escalar a ban global (admin).

### Lista de bloqueados

Ajustes → **Cuentas bloqueadas** → desbloquear.

---

## Moderación básica (Fase 8, mínimo viable)

- [ ] Validación de nombre y bio en servidor
- [ ] **Reportar** perfil o post (motivo + opcional texto)
- [ ] Panel admin simple (web o Supabase): ver reportes, suspender cuenta
- [ ] Reservar handles/nombres de hermandades conocidas para cuentas verificadas

No hace falta IA al inicio; reglas + reportes manuales bastan para una beta cofrade.

---

## Modelo de datos (orientativo)

```
profiles
  id, type ('user' | 'brotherhood'), handle, display_name, bio, avatar_url,
  verified, address, founded_label, website, updated_at

blocks
  blocker_id, blocked_id, created_at

reports
  reporter_id, target_type, target_id, reason, status, created_at
```

---

## Relación con otras funciones

- **Seguir** (`NOTIFICACIONES.md`): al bloquear, dejar de seguir automáticamente y no generar más notificaciones
- **Foros**: contenido de bloqueados oculto; pueden seguir existiendo hilos pero tú no los ves
- **Login** (`AUTH.md`): editar perfil y bloquear **requieren cuenta**

---

## UI por fase

| Fase | Perfil |
|------|--------|
| **5** ✅ | Ver perfil mock Hermandad Sevilla, tabs Publicaciones / Acerca de |
| **8** | Editar perfil, foto, menú Bloquear/Reportar en perfil ajeno |
| **9+** | Verificación hermandades, moderación ampliada |

---

*Ver también: [`NOTIFICACIONES.md`](NOTIFICACIONES.md) · [`AUTH.md`](AUTH.md) · [`ROADMAP.md`](ROADMAP.md)*
