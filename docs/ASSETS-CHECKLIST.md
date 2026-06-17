# Cofradero — Checklist de assets (recordatorio)

> **Para qué sirve este documento:** lista rápida de **qué imagen meter, dónde y cuándo**.  
> Marca `[x]` cuando lo tengas. **No hace falta tocar código** en la mayoría de casos: solo copiar el archivo y `flutter run`.

**Guía detallada (tamaños, Canva, colores):** [`ASSETS.md`](ASSETS.md)  
**Rutas en código (referencia técnica):** `lib/core/constants/app_assets.dart`

---

## Después de añadir cualquier imagen

```bash
flutter pub get
flutter run
```

(Si la app ya estaba abierta, hot restart con `R` o reinicia.)

---

## Regla general

| Pregunta | Respuesta |
|----------|-----------|
| ¿Dónde pongo las imágenes? | `assets/images/` o `assets/icons/` |
| ¿Tengo que programar algo? | **No**, si respetas el **nombre exacto** del archivo |
| ¿Qué MD leo para más detalle? | [`ASSETS.md`](ASSETS.md) |
| ¿Qué pasa si falta una imagen? | La app usa **fallback** (degradado o icono Material) |

---

## Ya en el proyecto

| Estado | Archivo | Pantalla / uso |
|--------|---------|----------------|
| [x] | `assets/images/logo.png` | Logo Cofradero (foros, placeholders, login futuro) |

---

## Pendiente ahora (mejora visual inmediata)

### Calendario — iconos de eventos

**Carpeta:** `assets/icons/`  
**Detalle:** [`ASSETS.md` § Iconos de eventos](ASSETS.md#6-iconos-de-eventos--assetsicons-calendario)  
**Código:** `EventTypeIcon` → `AppAssets.eventIconPath()`

| Estado | Copiar aquí | Para qué |
|--------|-------------|----------|
| [ ] | `assets/icons/procesion.png` | Tipo **Procesiones** en tarjetas del calendario |
| [ ] | `assets/icons/gloria.png` | Tipo **Glorias** |
| [ ] | `assets/icons/ensayo.png` | Tipo **Ensayos** |
| [ ] | `assets/icons/iguala.png` | Tipo **Igualás** |
| [ ] | `assets/icons/concierto.png` | Tipo **Conciertos** |
| [ ] | `assets/icons/evento.png` | Tipo **Eventos** (genérico) |

**Canva:** 512×512 px, PNG transparente, mismo estilo en los 6.

---

### Foros — foto hero procesión

**Archivo:** `assets/images/hero_procesion.jpg`  
**Detalle:** [`ASSETS.md` § Hero procesión](ASSETS.md#5-hero-procesión---assetsimageshero_procesionjpg-fase-2)  
**Código:** `ForumsScreen` → `AppAssets.heroProcesion`

| Estado | Qué meter | Dónde se ve |
|--------|-----------|-------------|
| [ ] | Foto nocturna de procesión (JPG/WebP, 16:9, ~1920×1080) | Cabecera de la pestaña **Foros** (detrás del logo COFRADERO) |

> Sin este archivo la app muestra un **degradado burdeos** (funciona, pero la foto queda más profesional).

---

## Opcional (cuando quieras pulir)

| Estado | Archivo | Para qué | Fase |
|--------|---------|----------|------|
| [ ] | `assets/images/logo_icon.png` | Logo pequeño (AppBar, sitios estrechos) | Pulido |
| [ ] | Icono launcher (ver `ASSETS.md` § 3) | Icono de la app en el móvil | Pre-lanzamiento |
| [ ] | Splash nativo (ver `ASSETS.md` § 4) | Pantalla al abrir la app | Pre-lanzamiento |

---

## Por fase del roadmap (futuro)

Cuando lleguemos a cada fase, estos son los assets que probablemente querrás. **Aún no están cableados todos** — esta tabla es tu recordatorio.

| Fase | Asset sugerido | Ruta | Notas |
|------|----------------|------|-------|
| **2 Foros** ✓ | Hero procesión | `assets/images/hero_procesion.jpg` | ↑ Pendiente arriba |
| **3 Hilo** | Avatares de usuario (mock) | `assets/images/avatars/` | PNG 256×256, opcional; ahora usa iconos |
| **4 Buscar** | Imágenes tendencias (#hashtags) | `assets/images/trends/` | Virgen, cruz, cáliz… |
| **5 Perfil** | Avatar hermandad | `assets/images/avatars/hermandad_sevilla.png` | Foto oficial o icono |
| **6 Notificaciones** | Iconos tipo notificación | `assets/icons/notif_*.png` | Corazón, campana, etc. |
| **7 Pulido** | Misma lista + revisar nitidez | — | Comprobar en móvil real |
| **8 Login** | Solo logo (ya lo tienes) | `assets/images/logo.png` | — |

---

## Mapa rápido: carpeta → pantalla

```
assets/
├── images/
│   ├── logo.png              ✅  Logo (varias pantallas)
│   ├── logo_icon.png         ⬜  Logo compacto
│   └── hero_procesion.jpg    ⬜  Foros (hero superior)
│
└── icons/
    ├── procesion.png         ⬜  Calendario
    ├── gloria.png            ⬜  Calendario
    ├── ensayo.png            ⬜  Calendario
    ├── iguala.png            ⬜  Calendario
    ├── concierto.png         ⬜  Calendario
    └── evento.png            ⬜  Calendario
```

---

## Si añades un asset nuevo que no está en la lista

1. Copia el archivo a `assets/images/` o `assets/icons/`.
2. Si es carpeta nueva, regístrala en `pubspec.yaml` → sección `flutter: assets:`.
3. Añade la ruta en `lib/core/constants/app_assets.dart`.
4. **Actualiza este checklist** y, si hace falta, [`ASSETS.md`](ASSETS.md).

---

## Enlaces útiles del proyecto

| Documento | Contenido |
|-----------|-----------|
| [`ASSETS.md`](ASSETS.md) | Tamaños, formatos, Canva, launcher, splash |
| [`ROADMAP.md`](ROADMAP.md) | Fases de desarrollo de la app |
| [`AUTH.md`](AUTH.md) | Login Google / Apple (Fase 8) |

---

*Última actualización: junio 2026 · Marca `[ ]` → `[x]` cuando subas cada archivo.*
