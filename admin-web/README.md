# Cofradeo · Panel web de Junta (admin-web)

Dashboard Angular para gestionar Cofradeo desde el PC. Misma verdad que la app (Supabase + roles staff). Plan: [`../docs/ADMIN-WEB.md`](../docs/ADMIN-WEB.md).

## Fase 0–3 (hecho)

- Login email/contraseña
- Guard: solo `profiles.role = admin` o hermandad verificada (`account_type = brotherhood` + `verified`)
- Shell escritorio + menú responsive
- **Colas reales:** temas, rechazos, reportes, eventos (admin), cierres
- **Comunidad (admin):** usuarios/altas, moderadores por foro, hermandades
- **Patrocinios (admin):** mapa por zona, CRUD, informe mes/CSV, pack todas las zonas
- **Empresas (admin):** alta de marca (ficha catálogo), cupo (`sponsor_settings`), editar creativos, quitar (cascada), lista de espera
  - SQL: `supabase/sponsor_settings.sql` (+ `sponsor_waitlist.sql` si falta)
- **Finanzas (admin):** cobros por empresa + gastos + resumen neto del mes
- **Foros (admin):** hero FOROS, portadas, textos, temas destacados (temporada)
- **Temporada (admin):** cuenta atrás litúrgica (Ramos / Pascua)
- **Quiz:** crear / aprobar / lanzar rondas + visibilidad y mensaje temporada
- **Notificaciones (admin):** KPIs push, volumen por tipo, diagnóstico por usuario
- **Simulación (admin, PRE):** cargar/limpiar mundo demo (`supabase/demo_world.sql`)
- Resumen con contadores y badges en el menú

**Importante SQL:** ejecuta en Supabase:
- `supabase/finance_sponsor_payments.sql`
- `supabase/sponsor_waitlist.sql`
- `supabase/liturgical_countdown.sql` (si aún no)
- `supabase/staff_notifications_overview.sql`
- PRE: `supabase/demo_world.sql` (simulación)

**Proyecto PRE (vacío):** un solo archivo `supabase/bootstrap_pre.sql`  
(regenerar: `node scripts/build-bootstrap-pre.mjs`). **No** ejecutar en prod.

## Arranque

Requisitos: Node 20+, `env.json` (prod) o `env.pre.json` (pre) en la raíz del repo Flutter.

```powershell
cd admin-web
npm install
npm run sync-env:pre   # → proyecto pre
# npm run sync-env:prod  # → proyecto prod (env.json)
npm start
```

Abre http://localhost:4200 y entra con una cuenta **admin** o **hermandad verificada** **de ese mismo proyecto**.

App Flutter contra pre:
```powershell
flutter run --dart-define-from-file=env.pre.json
```

Si no usas esos JSON, copia:

`src/environments/environment.local.example.ts` → `environment.local.ts`

y pega `SUPABASE_URL` / `SUPABASE_ANON_KEY`.

## Scripts

| Comando | Qué hace |
|---------|----------|
| `npm start` | Dev server (`ng serve`) |
| `npm run sync-env` | Genera `environment.local.ts` desde `../env.json` |
| `npm run sync-env:pre` | Igual, desde `../env.pre.json` (staging) |
| `npm run sync-env:prod` | Igual, desde `../env.json` |
| `npm run build` | Build producción |
| `npm run build:vercel` | Sync env (archivo o `SUPABASE_*`) + build (Vercel) |

## Deploy Vercel (panel Junta / hermandades)

1. [vercel.com](https://vercel.com) → Importar el repo → **Root Directory:** `admin-web`
2. Variables de entorno (Production):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY` (anon, nunca service_role)
3. Deploy. URL tipo `https://….vercel.app`
4. Dominio: en Vercel → Domains → `panel.circulocofrade.es` (recomendado) o el que elijas
5. En Arsys DNS: CNAME `panel` → `cname.vercel-dns.com` (el que indique Vercel)
6. Supabase → Auth → URL Configuration: añade `https://panel.circulocofrade.es/**` a Redirect URLs

### Preview (rama ≠ main)

Con el repo conectado, cualquier push a una rama distinta de `main` genera una URL de preview automática en Vercel (Deployments). No hace falta config extra.

### Analytics / Speed Insights

1. En Vercel → proyecto → **Analytics** → Enable  
2. **Speed Insights** → Enable  
3. El código ya llama a `inject()` / `injectSpeedInsights()` en `src/main.ts` (tras el deploy)

## Seguridad

- Solo **anon key** en el front (nunca `service_role`)
- El acceso web lo cierran guards + `signIn`: solo admin y hermandad verificada (RLS sigue aplicando en datos)
- `meta robots = noindex`

## Próximo

Fase 1: colas de moderación (temas, reportes, eventos, cierres).
