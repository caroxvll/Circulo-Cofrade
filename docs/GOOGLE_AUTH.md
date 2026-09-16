# Login con Google — Cofradero

La app **ya tiene el botón y el código** (`signInWithOAuth`). Para que funcione solo hay que **configurar Google Cloud + Supabase** y, en móvil, los **deep links** (ya añadidos en el proyecto).

## Resumen del flujo

```
Usuario → «Continuar con Google»
    → Supabase abre Google (navegador / pestaña)
    → Google devuelve a Supabase
    → Supabase redirige a la app (deep link o URL web)
    → Se crea sesión + perfil en `profiles`
```

---

## 1. Google Cloud Console

1. [console.cloud.google.com](https://console.cloud.google.com/) → crea o elige un proyecto.
2. **APIs y servicios** → **OAuth consent screen** → tipo **External** → rellena nombre (Cofradero) y email de soporte.
3. **Credentials** → **Create credentials** → **OAuth client ID**:

| Tipo | Uso |
|------|-----|
| **Web application** | Supabase (obligatorio) |
| **Android** | App móvil (opcional pero recomendado) |
| **iOS** | App iPhone (opcional) |

### Cliente Web (el que pide Supabase)

- **Authorized redirect URIs** — copia la de Supabase:
  - Dashboard → **Authentication** → **Providers** → **Google** → ver URL tipo  
    `https://TU_PROYECTO.supabase.co/auth/v1/callback`

Guarda **Client ID** y **Client Secret**.

### Cliente Android (recomendado para el móvil)

- Package name: `com.cofradeo.cofradeo`
- SHA-1: obtén con:

```powershell
cd android
.\gradlew signingReport
```

Copia el SHA-1 de `debug` (desarrollo) y el de `release` (producción).

---

## 2. Supabase Dashboard

### Activar Google

**Authentication** → **Providers** → **Google**:

| Campo | Valor |
|-------|--------|
| Enable | ON |
| Client ID | el de **Web application** |
| Client Secret | el secret del cliente web |

### URLs de redirección

**Authentication** → **URL Configuration**:

| Campo | Ejemplo |
|-------|---------|
| Site URL | `http://localhost:7357` (web dev) o tu dominio |
| Redirect URLs | Añade todas las que uses: |

```
cofradeo://login-callback
cofradeo://reset-password
http://localhost:**
http://localhost:7357/**
http://localhost:7357/#/verificar-email
```

(Sustituye el puerto por el que uses en `flutter run -d chrome`.)

---

## 3. SQL — perfil al primer login Google

Ejecuta en SQL Editor:

[`supabase/google_oauth_profile.sql`](../supabase/google_oauth_profile.sql)

Mejora el trigger `handle_new_user`: nombre y foto de Google, handle único si hay colisión.

---

## 4. Probar

### Web (Chrome)

```powershell
flutter run -d chrome --dart-define-from-file=env.json
```

Perfil → Iniciar sesión → **Continuar con Google**.

### Android

```powershell
flutter run -d TU_DISPOSITIVO --dart-define-from-file=env.json
```

1. Pulsa Google → se abre Chrome/Custom Tabs.
2. Elige cuenta → vuelve a la app sola (`cofradeo://login-callback`).
3. Deberías entrar al calendario (o a la ruta `redirect` si venías de un hilo).

### Si no vuelve a la app

| Síntoma | Revisar |
|---------|---------|
| Se queda en el navegador | Redirect URLs en Supabase incluyen `cofradeo://login-callback` |
| Error «redirect_uri_mismatch» | URI de callback en Google = la de Supabase (`.../auth/v1/callback`) |
| App abre pero sin sesión | Deep link en `AndroidManifest.xml` / `Info.plist` (ya en el repo) |
| «Supabase no configurado» | `env.json` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` |

---

## 5. Qué hace la app (código)

| Archivo | Rol |
|---------|-----|
| `lib/features/auth/data/auth_repository.dart` | `signInWithGoogle()` con PKCE |
| `lib/features/auth/login_screen.dart` | Botón dorado |
| `lib/app.dart` | Al volver del OAuth, navega con sesión |
| `android/.../AndroidManifest.xml` | Intent `cofradeo://login-callback` |
| `ios/Runner/Info.plist` | URL scheme `cofradeo` |

**Nota:** Con Google el email suele venir **ya verificado**; no pasa por la pantalla «Confirma tu email».

---

## 6. Firebase vs Google login

Son cosas distintas:

| | Google login | Firebase (`PUSH_FCM.md`) |
|--|--------------|---------------------------|
| Para qué | Entrar en la app | Notificaciones push |
| Config | Supabase + Google Cloud | Firebase Console |
| Mismo proyecto Google | Puede ser el mismo proyecto GCP, pero credenciales distintas |

---

*Ver también: [`AUTH.md`](AUTH.md) · [`SUPABASE.md`](SUPABASE.md)*
