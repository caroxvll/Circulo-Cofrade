# Cofradero — Publicar en Android e iOS

Guía práctica para subir **Círculo Cofrade** a tiendas. Objetivo: **beta primero** (testers), producción después.

No hace falta saberlo todo de golpe. Sigue el orden: **Android → iOS**.

---

## Datos de la app (ya en el repo)

| Campo | Valor |
|-------|--------|
| Nombre en tienda / launcher | **Círculo Cofrade** |
| Package / Bundle ID | `com.cofradeo.cofradeo` |
| Versión actual (`pubspec.yaml`) | `1.0.0+1` → nombre `1.0.0`, build `1` |
| Deep link OAuth | `cofradeo://login-callback` |
| Supabase / Firebase | vía `--dart-define-from-file=env.json` |

**Importante:** hoy el release de Android firma con la clave **debug** (`android/app/build.gradle.kts`). Eso vale para probar en tu móvil; **no** sirve para Play Store. Hay que crear un keystore de producción (paso Android §3).

---

## Mapa mental (sin miedo)

```
1. Checklist de producto     → docs/PRUEBAS-BETA.md
2. Cuentas de desarrollador  → Google Play (~25 € una vez) + Apple (99 $/año)
3. Beta Android              → Play Console → Prueba interna
4. Beta iOS                  → App Store Connect → TestFlight (hace falta Mac)
5. Producción                → cuando la beta esté estable
```

| Plataforma | Dificultad | Qué necesitas |
|------------|------------|---------------|
| **Android** | Media-baja | Windows vale; Play Console |
| **iOS** | Media-alta | **Mac + Xcode**; Apple Developer |

---

## 0. Antes de construir (común)

Haz esto una sola vez (o cada vez que cambies algo gordo):

- [ ] Pasar [`PRUEBAS-BETA.md`](PRUEBAS-BETA.md) en dispositivo real
- [ ] `env.json` con Supabase (y Firebase si usas push) — **no** subirlo a git
- [ ] Icono y splash OK → [`ASSETS.md`](ASSETS.md)
- [ ] Google login release preparado → [`GOOGLE_AUTH.md`](GOOGLE_AUTH.md) (SHA-1 de **release**)
- [ ] Push (si aplica) → [`PUSH_FCM.md`](PUSH_FCM.md)
- [ ] Subir versión en `pubspec.yaml` cuando toque (ej. `1.0.0+2`, luego `1.0.1+3`)

Cada subida a tienda necesita un **número de build mayor** (`+N`). El nombre de versión (`1.0.x`) lo subes cuando el usuario deba notar un cambio.

### Comando base de build

Siempre con credenciales:

```powershell
# Desde la raíz del repo
flutter build appbundle --dart-define-from-file=env.json
flutter build ipa --dart-define-from-file=env.json
```

Sin `--dart-define-from-file=env.json` la app sale en modo invitado / sin backend real.

---

## 1. Android — beta (Play Console)

### 1.1 Cuenta

1. Entra en [Google Play Console](https://play.google.com/console)
2. Paga la cuota de desarrollador (una vez)
3. Crea la app: nombre **Círculo Cofrade**, idioma español, tipo app / gratis según tu modelo

### 1.2 Keystore de release (hazlo una vez y guárdalo)

En PowerShell (ajusta la ruta de salida si quieres):

```powershell
keytool -genkey -v -keystore "$env:USERPROFILE\cofradeo-release.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias cofradeo
```

Te pedirá contraseñas y datos. **Guarda en un sitio seguro:**

- el archivo `.jks`
- la contraseña del store
- el alias `cofradeo`
- la contraseña del key

Si pierdes el keystore, **no podrás actualizar** la misma app en Play.

Crea `android/key.properties` (ya está en `.gitignore`):

```properties
storePassword=TU_PASSWORD_STORE
keyPassword=TU_PASSWORD_KEY
keyAlias=cofradeo
storeFile=C:\\Users\\TU_USUARIO\\cofradeo-release.jks
```

(Usa la ruta real de tu `.jks`.)

### 1.3 Conectar la firma en Gradle

En `android/app/build.gradle.kts`, sustituye el bloque que firma con debug por algo así:

```kotlin
import java.util.Properties
import java.io.FileInputStream

// ... plugins { ... }

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... namespace, defaultConfig, etc.

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}
```

### 1.4 SHA-1 de release (Google login)

```powershell
cd android
.\gradlew signingReport
```

Copia el **SHA-1** del variant **release** y añádelo al cliente OAuth Android en Google Cloud (`com.cofradeo.cofradeo`). Detalle en [`GOOGLE_AUTH.md`](GOOGLE_AUTH.md).

### 1.5 Generar el AAB

```powershell
flutter clean
flutter pub get
flutter build appbundle --dart-define-from-file=env.json
```

Salida típica:

`build/app/outputs/bundle/release/app-release.aab`

### 1.6 Subir a prueba interna

En Play Console → tu app:

1. **Prueba** → **Prueba interna** (o cerrada)
2. Crear release → subir el `.aab`
3. Completar lo mínimo de ficha (textos, icono 512×512, capturas)
4. Añadir emails de testers
5. Activar el track y compartir el enlace de opt-in

Los testers tienen que aceptar la invitación; a veces tarda unos minutos / horas en aparecer.

### 1.7 Checklist Android

- [ ] Keystore guardado fuera del repo
- [ ] `key.properties` local, no en git
- [ ] AAB firmado con release
- [ ] SHA-1 release en Google Cloud
- [ ] `google-services.json` en `android/app/` si usas FCM
- [ ] Login Google / email en un móvil con el build de prueba
- [ ] Push (si aplica) con app en segundo plano

---

## 2. iOS — beta (TestFlight)

### 2.1 Requisitos

- Mac con **Xcode** actualizado
- Cuenta [Apple Developer Program](https://developer.apple.com) (99 $/año)
- Bundle ID: `com.cofradeo.cofradeo` (ya en el proyecto)

### 2.2 App Store Connect

1. [App Store Connect](https://appstoreconnect.apple.com) → **Mis apps** → **+**
2. Nombre: **Círculo Cofrade**
3. Bundle ID: registra `com.cofradeo.cofradeo` en Certificates / Identifiers si aún no existe
4. SKU interno (ej. `circulo-cofrade-ios`)

### 2.3 Signing en Xcode

1. Abre `ios/Runner.xcworkspace` (no el `.xcodeproj` a pelo)
2. Target **Runner** → **Signing & Capabilities**
3. Team = tu equipo de Apple
4. Bundle Identifier = `com.cofradeo.cofradeo`
5. Deja que Xcode gestione certificados (**Automatically manage signing**)

Capacidades habituales según lo que uses:

- **Push Notifications** (si FCM/APNs)
- **Sign in with Apple** — **obligatorio** si ofreces Google en iOS (política de Apple)

APNs + Firebase: ver [`PUSH_FCM.md`](PUSH_FCM.md).

### 2.4 Privacidad en `Info.plist`

Ya tienes ubicación. Antes de revisión, revisa textos de permisos (foto/cámara si `image_picker` los pide). Si Apple rechaza por falta de usage description, añade las claves que indique el email de rechazo (Photo Library / Camera).

### 2.5 Build IPA

En el Mac, desde la raíz del repo:

```bash
flutter clean
flutter pub get
flutter build ipa --dart-define-from-file=env.json
```

O desde Xcode: **Product → Archive** → **Distribute App** → App Store Connect.

### 2.6 TestFlight

1. El build aparece en App Store Connect (procesado en ~5–30 min)
2. Completa **Export Compliance** / preguntas simples
3. **TestFlight** → añadir testers internos o externos
4. Testers instalan **TestFlight** desde App Store e instalan Círculo Cofrade

### 2.7 Checklist iOS

- [ ] Apple Developer activo
- [ ] Signing OK en Xcode
- [ ] `GoogleService-Info.plist` en `ios/Runner/` si usas Firebase
- [ ] Apple Sign In si hay Google
- [ ] Build en TestFlight instalable
- [ ] Login + deep link `cofradeo://…` en dispositivo real

---

## 3. Ficha de tienda (mínimo razonable)

Prepara esto una vez y reutilízalo:

| Elemento | Nota |
|----------|------|
| Título | Círculo Cofrade |
| Subtítulo / corto | Red cofrade: foros, calendario, hermandades |
| Descripción | Qué es, para quién, qué puede hacer el usuario |
| Icono 512×512 | Sin transparencia (Play) |
| Capturas | 2–8 pantallas reales (Foros, Calendario, Pregunta en vivo…) |
| Política de privacidad | URL pública (obligatoria en ambas tiendas) |
| Clasificación / edad | Según contenido (comunidad, UGC → suele pedir moderación declarada) |
| Contacto | Email de soporte |

**Contenido generado por usuarios (foros):** en las fichas y en App Privacy declara que hay UGC y que hay reportes / moderación (Junta).

---

## 4. Producción (cuando la beta aguante)

### Android

1. Completar cuestionario de contenido, privacidad, target audience
2. Promocionar el release de **prueba interna/cerrada** a **producción** (o subir un AAB nuevo con `+N` mayor)
3. Revisar estado → en revisión → publicado

### iOS

1. En App Store Connect, el build de TestFlight → versión de App Store
2. Rellenar capturas, privacidad, App Privacy questionnaire
3. **Enviar a revisión**
4. Primera revisión suele ser la más lenta; responde rápido si Apple pregunta

---

## 5. Errores típicos (y calma)

| Problema | Qué hacer |
|----------|-----------|
| «App sin Supabase / modo invitado» | Rebuild con `--dart-define-from-file=env.json` |
| Google login falla solo en release | Falta SHA-1 **release** en Google Cloud |
| Play rechaza firma | Estás firmando con debug; crea keystore + `key.properties` |
| Perdiste el `.jks` | No hay magia: hay que publicar app nueva con otro package (evítalo) |
| iOS no abre tras OAuth | Revisar URL scheme `cofradeo` en `Info.plist` |
| Apple exige Sign in with Apple | Añadir provider Apple en Supabase + capability en Xcode |
| Push no llega en iOS | APNs key en Firebase + capability Push |
| Build number duplicado | Sube el `+N` en `pubspec.yaml` |

---

## 6. Orden recomendado esta semana

1. [ ] Cerrar [`PRUEBAS-BETA.md`](PRUEBAS-BETA.md)
2. [ ] Crear keystore + firmar Android de verdad
3. [ ] Subir **prueba interna** en Play (5–10 amigos)
4. [ ] Cuando tengas Mac / cuenta Apple: TestFlight
5. [ ] Solo entonces: producción

---

## Referencias del repo

| Tema | Doc |
|------|-----|
| Checklist funcional | [`PRUEBAS-BETA.md`](PRUEBAS-BETA.md) |
| Supabase / env | [`SUPABASE.md`](SUPABASE.md) |
| Google | [`GOOGLE_AUTH.md`](GOOGLE_AUTH.md) |
| Push | [`PUSH_FCM.md`](PUSH_FCM.md) |
| Iconos / splash | [`ASSETS.md`](ASSETS.md) |
| Roadmap tiendas | [`ROADMAP.md`](ROADMAP.md) (TestFlight / Play) |

Documentación oficial Flutter:

- [Android deployment](https://docs.flutter.dev/deployment/android)
- [iOS deployment](https://docs.flutter.dev/deployment/ios)
