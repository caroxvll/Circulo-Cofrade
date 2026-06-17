# Medios — imágenes sin vídeo

Decisión de producto acordada (junio 2026). Complementa [`PERFIL.md`](PERFIL.md) y Fase 8–9.

## Principio

**Solo imágenes. Sin vídeos** en MVP y beta.

Motivos: menor coste (storage + ancho de banda), moderación más simple, enfoque cofrade (texto + foto puntual, no red de vídeo).

**Storage:** Supabase Storage (mismo proyecto). **No** Firebase Storage.

---

## Quién puede subir qué

| Tipo cuenta | Puede subir | Límites |
|-------------|-------------|---------|
| **Cofrade** | Avatar · imágenes en posts (fase posterior) | Avatar 2 MB · hasta 3 imgs/post |
| **Hermandad** | Logo · imágenes en publicaciones oficiales | Logo 2 MB · hasta 5 imgs/post |
| **Todos** | Solo JPG, PNG, WebP | **Vídeo prohibido** |
| **Nadie (MVP)** | GIF animados pesados, PDF en posts, audio | — |

No restringir imágenes **solo** a hermandades: cofrades necesitan avatar; hermandades pueden subir un poco más por ser cuenta oficial.

---

## Límites técnicos (servidor)

| Regla | Valor |
|-------|-------|
| MIME permitidos | `image/jpeg`, `image/png`, `image/webp` |
| Tamaño avatar/logo | máx. **2 MB** |
| Tamaño imagen en post | máx. **5 MB** |
| Dimensiones | Redimensionar a máx. **1920 px** lado largo |
| Vídeo | Rechazar en policy + validación MIME |

Validación en **tres capas**:

1. **App** — selector solo imágenes, comprimir antes de subir
2. **Supabase Storage policy** — solo MIME imagen en buckets
3. **Edge Function** (opcional) — magic bytes + tamaño

---

## Buckets Supabase Storage (plan)

| Bucket | Ruta | Acceso |
|--------|------|--------|
| `avatars` | `{user_id}/avatar.jpg` | Público lectura · solo dueño escribe |
| `posts` | `{post_id}/{uuid}.jpg` | Público lectura · autor escribe |

Campo en `profiles`: `avatar_url` (URL pública del bucket).

---

## Coste orientativo

- Imágenes comprimidas: bajo en plan Free/Pro de Supabase para beta
- Vídeos: 10–100× storage y egress; moderación costosa → **excluidos**

---

## Orden de implementación

1. **Fase 8c** — Subir avatar (cofrade + hermandad)
2. **Fase 9+** — Imágenes adjuntas en temas/respuestas del foro
3. **Nunca en beta** — vídeo

---

*Ver también: [`PERFIL.md`](PERFIL.md) · [`NOTIFICACIONES.md`](NOTIFICACIONES.md)*
