# Vídeo editorial (Círculo Cofrade → Para ti)

Excepción a [`MEDIA.md`](MEDIA.md): **solo Junta**, en publicaciones oficiales. Sin hub de Videos.

## Fase 2a (ahora)

- MP4/MOV/WebM directo en **Cloudflare R2**
- Poster obligatorio (imagen en `topic-covers`)
- Edge Function `editorial-video-upload` → URL firmada PUT
- App: Junta adjunta vídeo; Para ti muestra poster + play; detalle reproduce
- **No** rota «último comentario» en el feed

## Variables de entorno (Edge Function)

| Variable | Ejemplo |
|----------|---------|
| `R2_ACCOUNT_ID` | Cloudflare account id |
| `R2_ACCESS_KEY_ID` | API token R2 |
| `R2_SECRET_ACCESS_KEY` | Secret R2 |
| `R2_BUCKET` | `cofradeo-editorial` (default) |
| `R2_PUBLIC_BASE_URL` | `https://media.tudominio.com` o `*.r2.dev` |

CORS del bucket: permitir `PUT` desde la app / orígenes necesarios.

## Despliegue

1. Ejecutar `supabase/editorial_video.sql` (tras `editorial_posts.sql`)
2. Crear bucket R2 + dominio público
3. `supabase secrets set R2_ACCOUNT_ID=... R2_ACCESS_KEY_ID=... ...`
4. `supabase functions deploy editorial-video-upload`

## Fase 2b (después)

- FFmpeg → HLS + poster automático
- `video_status = processing` mientras transcodifica
- Subir techo de tamaño

## Límites 2a

- Máx. **80 MB**
- MIME: `video/mp4`, `video/quicktime`, `video/webm`
