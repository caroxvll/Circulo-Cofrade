# Vídeo editorial (Círculo Cofrade → Para ti)

Excepción a [`MEDIA.md`](MEDIA.md): **solo Junta**, en publicaciones oficiales. Sin hub de Videos.

## Fase 2a — MP4 en R2 (fallback)

- MP4/MOV/WebM directo en **Cloudflare R2**
- Poster manual (imagen en `topic-covers`)
- Edge Function `editorial-video-upload` → URL firmada PUT
- Máx. **150 MB**

## Fase 2b — HLS con Cloudflare Stream (recomendado)

- Subida a **Cloudflare Stream** (transcodifica a HLS + poster automático)
- Mientras procesa: `video_status = processing` (badge «OPTIMIZANDO» en Para ti)
- Al terminar: `video_url` = manifest HLS, `video_poster_url` = thumbnail
- Máx. **500 MB** / **10 min**
- Si no hay token Stream, la edge function cae al modo R2 (2a)

### Variables nuevas (Edge Functions)

| Variable | Uso |
|----------|-----|
| `CF_STREAM_API_TOKEN` | API token con permiso Stream:Edit |
| `CF_STREAM_ACCOUNT_ID` | Account id (si falta, usa `R2_ACCOUNT_ID`) |
| `CF_STREAM_WEBHOOK_SECRET` | Opcional, para validar el webhook |

Las de R2 (`R2_*`) siguen haciendo falta como fallback.

### SQL

1. `supabase/editorial_video.sql` (si aún no)
2. `supabase/editorial_video_hls.sql` ← **nuevo** (provider, external_id, finalize)

### Deploy functions

```powershell
npx supabase functions deploy editorial-video-upload
npx supabase functions deploy editorial-video-finalize
npx supabase functions deploy editorial-video-webhook
npx supabase functions deploy editorial-video-delete
```

Al **eliminar** una publicación oficial, la app llama a `editorial-video-delete` para quitar el vídeo de Stream/R2 y liberar almacenamiento.

Secrets (ejemplo):

```powershell
npx supabase secrets set CF_STREAM_API_TOKEN=... CF_STREAM_ACCOUNT_ID=...
```

### Webhook Stream (opcional pero útil)

En Cloudflare Dashboard → Stream → Webhooks:

- URL: `https://<project>.supabase.co/functions/v1/editorial-video-webhook`
- El `direct_upload` ya manda `meta.topicId`

Sin webhook, la app llama a `editorial-video-finalize` tras subir (polling breve); si aún no está listo, queda en `processing` hasta el siguiente finalize/webhook.

### App

- Junta: «Añadir vídeo (HLS…)»; portada opcional con Stream
- Para ti: poster + play; si procesa → «OPTIMIZANDO»
- Detalle: reproduce HLS/MP4; autoplay muteado en web
