# Cofradero — Dónde colocar imágenes y logo

> **Checklist rápido (qué falta, dónde copiarlo):** [`ASSETS-CHECKLIST.md`](ASSETS-CHECKLIST.md)  
> Este documento (`ASSETS.md`) tiene los **detalles** (tamaños, Canva, launcher…).

Guía para añadir el logo y el resto de assets visuales al proyecto Flutter.

---

## Carpeta de assets

Todos los archivos van aquí:

```
cofradeo/
└── assets/
    └── images/
        ├── logo.png              ← TU LOGO (obligatorio)
        ├── logo_icon.png         ← opcional, versión recortada
        └── hero_procesion.jpg    ← opcional, hero pantalla Foros
```

Después de añadir o cambiar archivos, ejecuta:

```bash
flutter pub get
flutter run
```

---

## 1. Logo principal — `assets/images/logo.png`

**Qué es:** el logo completo (C morada + ángeles + Giralda dorada).

**Ya está copiado** en el proyecto. Si quieres sustituirlo, sobrescribe ese archivo con tu PNG.

**Recomendaciones:**
- Formato: **PNG** con fondo negro (como el original) o transparente
- Tamaño: **1024×1024 px** mínimo para que se vea nítido
- Nombre exacto: `logo.png` (minúsculas)

**Dónde se usa en la app:**

| Ubicación | Widget | Tamaño orientativo |
|-----------|--------|-------------------|
| Pantallas placeholder / splash interno | `AppLogo()` | 120 px |
| Cabecera Foros (junto a COFRADERO) | `AppLogo(size: 48)` | 48 px |
| Login (Fase 8) | `AppLogo(size: 160)` | 160 px |
| Onboarding | `AppLogo(size: 140)` | 140 px |

---

## 2. Logo icono — `assets/images/logo_icon.png` (opcional)

**Qué es:** versión simplificada solo con la **C** o el símbolo central, para sitios pequeños.

**Dónde se usará:**

| Ubicación | Tamaño |
|-----------|--------|
| AppBar compacta | 32–40 px |
| Notificaciones push (icono pequeño) | 24 px |

En código: `AppLogo(size: 36, useIconVariant: true)`.

Si no lo tienes aún, la app usa el logo completo.

---

## 3. Icono de la app (launcher) — Android e iOS

El logo en `assets/images/` **no sustituye** el icono del móvil en la pantalla de inicio. Para eso:

### Opción fácil (recomendada)

1. Instala el paquete: `flutter pub add dev:flutter_launcher_icons`
2. Añade en `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/logo.png"
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "assets/images/logo.png"
```

3. Ejecuta: `dart run flutter_launcher_icons`

### Manual

| Plataforma | Ruta |
|------------|------|
| Android | `android/app/src/main/res/mipmap-*/ic_launcher.png` |
| iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |

Herramienta online útil: [appicon.co](https://www.appicon.co)

---

## 4. Splash screen (pantalla de arranque)

Cuando implementemos splash nativo:

| Plataforma | Configuración |
|------------|---------------|
| Flutter | Paquete `flutter_native_splash` |
| Imagen | `assets/images/logo.png` centrado sobre fondo `#000000` |

Comando futuro:

```bash
flutter pub add dev:flutter_native_splash
dart run flutter_native_splash:create
```

---

## 5. Hero procesión — `assets/images/hero_procesion.jpg` (Fase 2)

Foto nocturna de procesión para la cabecera de **Foros**.

- Formato: JPG o WebP
- Proporción: **16:9** o más ancha
- Resolución: 1920×1080 px recomendado

---

## Mapa visual de la app

```
┌─────────────────────────────────┐
│  [logo 48px]  COFRADERO    🔔   │  ← Foros (Fase 2)
│  Fe • Tradición • Hermandad     │
│  [hero_procesion.jpg]           │
├─────────────────────────────────┤
│  ... contenido ...              │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│         [logo 160px]            │  ← Login (Fase 8)
│         COFRADERO               │
│   Fe • Tradición • Hermandad    │
│   [Continuar con Google]        │
└─────────────────────────────────┘

📱 Icono launcher → logo.png (adaptado)
🚀 Splash → logo.png sobre negro
```

---

## Cambio de nombre: Cofradero

El producto se llama **Cofradero** (no Cofradeo). El paquete Dart sigue siendo `cofradeo` por compatibilidad del proyecto; el nombre visible en la app es **Cofradero**.

---

## 6. Iconos de eventos — `assets/icons/` (calendario)

Iconos personalizados para cada tipo de evento en las tarjetas del calendario.

### Dónde copiarlos

```
assets/icons/
├── procesion.png    ← cruz, paso, nazareno…
├── gloria.png       ← sol, luz, procesión de gloria…
├── ensayo.png       ← banda, tambor, grupo…
├── iguala.png       ← manos, sorteo, hermanos…
├── concierto.png    ← corneta, pentagrama…
└── evento.png       ← genérico (traslados, actos varios)
```

**No hace falta tocar código.** El widget `EventTypeIcon` carga la imagen; si falta, usa el icono Material de respaldo.

### Recomendaciones para que se vean profesionales

| Criterio | Recomendación |
|----------|---------------|
| **Formato** | **PNG** con fondo transparente (ideal) |
| **Tamaño** | **128×128 px** o **256×256 px** |
| **Estilo** | Mismo estilo en los 6: línea dorada, silueta burdeos, o ilustración acorde al logo |
| **Grosor** | Trazos legibles a 52 px en pantalla (no demasiado fino) |
| **Color** | Dorado `#D4AF37` + burdeos `#7A1111` encajan con la app |
| **Padding** | Deja ~10 % de margen dentro del cuadrado (no pegado al borde) |

### Alternativa: SVG

Si tus iconos son vectoriales (`.svg`), dímelo y activamos `flutter_svg` para cargarlos con la misma nitidez en cualquier tamaño.

### Dónde se usan

- Tarjetas de **Próximos Eventos**
- Detalle al pulsar un día en el calendario
- Panel **Ver todos del mes**
- (Futuro) Filtros del calendario, notificaciones de eventos

### Ejemplo visual en tarjeta

```
┌──────────────────────────────────────┐
│ [Procesiones]  2 jun · Salida…       │
│ Hermandad de la Macarena             │
│ 20:30                    ( 🏛️ )    │  ← tu PNG aquí
└──────────────────────────────────────┘
```

---

*Si sustituyes `logo.png`, no hace falta tocar código: el widget `AppLogo` lo carga automáticamente.*
