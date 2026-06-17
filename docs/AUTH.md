# Autenticación — Cofradero

Referencia para **Fase 8**. Sin login en fases 0–7 (solo mocks).

## Cuándo hace falta cuenta

| Acción | Sin cuenta | Con cuenta |
|--------|------------|------------|
| Ver calendario, foros, buscar | ✅ | ✅ |
| Leer hilos y perfiles | ✅ | ✅ |
| Publicar tema / responder | ❌ → login | ✅ |
| Editar perfil, subir avatar | ❌ | ✅ |
| Seguir hashtags o usuarios | ❌ (toggle mock en Fase 4) | ✅ |
| Recibir notificaciones reales | ❌ | ✅ |
| Bloquear / reportar | ❌ | ✅ |

Flujo: **modo invitado** para explorar → login al intentar publicar o personalizar perfil.

## Proveedores (MVP)

| Método | Plataforma |
|--------|------------|
| **Google** | Android + iOS + web |
| **Email + contraseña** | Todas |
| **Apple** | iOS (obligatorio si hay Google en App Store) |

Backend recomendado: **Supabase Auth** (JWT, RLS, mismo stack que foros y perfiles).

Configuración paso a paso: [`SUPABASE.md`](SUPABASE.md).

## Tipos de cuenta tras el registro

1. **Cofrade** — registro estándar; elige handle y nombre (con validación, ver `PERFIL.md`)
2. **Hermandad** — registro + **verificación** (admin aprueba nombre oficial y badge)

No mezclar: una hermandad no se crea con el mismo flujo que un cofrade sin revisión.

## Pantallas (Fase 8)

- Bienvenida / login (Google, Apple, email)
- Registro cofrade (handle, nombre, aceptar términos)
- Solicitud cuenta hermandad (nombre legal, documentación — proceso manual al inicio)
- Recuperar contraseña

## Seguridad mínima

- Contraseña ≥ 8 caracteres
- Email verificado para publicar
- RLS en Supabase: solo el dueño edita su `profile`
- Tokens en almacenamiento seguro del dispositivo

---

*Ver también: [`PERFIL.md`](PERFIL.md) · [`NOTIFICACIONES.md`](NOTIFICACIONES.md)*
