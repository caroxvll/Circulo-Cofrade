# Cofradeo — Roadmap por fases

> **Cofradeo** · La mayor comunidad cofrade  
> Documento de planificación para construir el MVP de forma incremental, con fidelidad pixel-perfect al diseño aprobado.

---

## Índice

1. [Visión del producto](#visión-del-producto)
2. [Lo que hay en el diseño (pantalla por pantalla)](#lo-que-hay-en-el-diseño-pantalla-por-pantalla)
3. [Acceso al calendario (decisión UX)](#acceso-al-calendario-decisión-ux)
4. [Sistema de diseño (especificación visual)](#sistema-de-diseño-especificación-visual)
5. [Arquitectura técnica](#arquitectura-técnica)
6. [Fases de desarrollo](#fases-de-desarrollo)
7. [Criterios de aceptación por fase](#criterios-de-aceptación-por-fase)
8. [Qué queda fuera del MVP inicial](#qué-queda-fuera-del-mvp-inicial)
9. [Autenticación (login)](#autenticación-login)
10. [Assets e imágenes (checklist)](#assets-e-imágenes-checklist)

---

## Visión del producto

**Cofradeo** es una aplicación móvil de comunidad para cofrades, hermandades y aficionados a la Semana Santa. Combina foros temáticos, perfiles de hermandades, calendario de eventos cofrades, búsqueda con tendencias y notificaciones en tiempo real.

El diseño transmite **elegancia, tradición y solemnidad**: fondo negro profundo, acentos dorados, burdeos para estados activos y tipografía serif en títulos.

**Principio de construcción:** cada fase entrega pantallas navegables y visualmente idénticas al mockup. Primero UI + datos mock; después backend y lógica real.

**Prioridad de producto:** el calendario cofrade (procesiones, misas, mudas) se considera una de las funciones más usadas de la app. Por eso tendrá **acceso directo y visible** desde la navegación principal y desde atajos en otras pantallas (ver sección dedicada).

---

## Lo que hay en el diseño (pantalla por pantalla)

A continuación se describe **exactamente** lo que aparece en cada una de las 8 imágenes del diseño.

### Pantalla 1 — Lista de Foros (`Foros`)

**Tab activa:** Foros

#### Cabecera (≈40 % superior)
| Elemento | Detalle |
|----------|---------|
| Barra de estado | iOS estándar (hora, señal, Wi‑Fi, batería) |
| Logo | Escudo circular dorado con cruz, esquina superior izquierda |
| Nombre de la app | **FORO COFRADE** en serif dorado, mayúsculas *(en producto final: **Cofradeo**, manteniendo el mismo estilo)* |
| Eslogan | `Fe • Tradición • Hermandad` en dorado, tamaño pequeño |
| Campana | Icono dorado arriba a la derecha con punto rojo (notificación pendiente) |
| Imagen hero | Procesión nocturna: nazarenos con túnica burdeos, paso dorado, Giralda al fondo; degradado oscuro en la parte inferior |
| Título de sección | **Foros** en serif grande |
| Subtítulo | `Participa en la mayor comunidad cofrade.` |

#### Tarjetas de foro (4 categorías)
Cada tarjeta: fondo gris oscuro, bordes redondeados, borde sutil.

| Foro | Icono (círculo burdeos + icono dorado) | Descripción |
|------|----------------------------------------|-------------|
| **Foro Cofradiero** | Cruz | El lugar de encuentro para todos los cofrades. |
| **Pentagrama Cofrade** | Clave de sol | La música que acompaña nuestra Semana Santa. |
| **Martillo y Trabajadera** | Corona | El arte de la talla, el bordado y la orfebrería. |
| **Semana Santa** | Silueta de catedral | Todo sobre la Semana Mayor *(temporada — bloqueable)* |
| **Cuaresma** | — | Cultos y camino hacia la Semana Mayor *(temporada)* |
| **Glorias** | — | Procesiones de gloria *(temporada)* |

> Modelo de pilares, bloqueo y admin: [`docs/FOROS.md`](FOROS.md) · Plan por fases admin: [`docs/ADMIN.md`](ADMIN.md)

**Contenido de cada tarjeta:**
- Título en serif blanco/dorado
- Descripción en gris claro (sans-serif)
- Metadatos: icono temas + contador (ej. `3,245 temas`) · icono mensajes + contador (ej. `27,891 mensajes`)
- Badge **Activo**: pastilla roja con icono de llama + texto `Activo`
- `Último mensaje` + tiempo en rojo (ej. `hace 2 min`)
- Chevron `>` dorado a la derecha

#### Navegación inferior
Cinco ítems con icono + etiqueta. **Foros** resaltado (fondo claro sutil / dorado).

| Calendario | Foros ★ | Buscar | Notificaciones | Perfil |
|------------|---------|--------|----------------|--------|

> En los mockups originales este primer ítem aparece como **Inicio** (icono casa). En implementación se sustituye por **Calendario** (icono calendario) para que el acceso sea explícito e intuitivo. Ver [Acceso al calendario](#acceso-al-calendario-decisión-ux).

---

### Pantalla 2 — Temas de un foro (`Foro Cofradiero`)

**Tab activa:** Foros · Pantalla secundaria (flecha atrás `<`)

#### Cabecera
| Elemento | Detalle |
|----------|---------|
| Fondo | Imagen de catedral/arquitectura religiosa nocturna, desenfocada |
| Flecha atrás | Chevron dorado `<` arriba a la izquierda |
| Logo del foro | Círculo rojo burdeos con cruz dorada ornamentada (Cruz de Guía) |
| Título | **Foro Cofradiero** en serif dorado |
| Subtítulo | `El lugar de encuentro para todos los cofrades` |
| Estadísticas | `3,245 temas \| 27,391 mensajes` en rojo apagado |
| Separador | Línea horizontal roja oscura |

#### Sección «Temas de Discusión»
Título en serif dorado. Lista de tarjetas gris oscuro con esquinas redondeadas.

**Estructura de cada tarjeta de tema:**
| Zona | Contenido |
|------|-----------|
| Avatar | Círculo a la izquierda (Virgen, corona, vela, etc.) |
| Cabecera | `@usuario` en gris + timestamp en naranja/rojo (`hace 2 horas`) |
| Título | Serif blanco, grande (ej. *Nueva ruta de la procesión...*) |
| Extracto | 2 líneas en gris sans-serif |
| Pie | Icono comentarios + número · icono vistas + `X vistas` |
| Badge | Pastilla **Resuelto** (rojo burdeos) en la primera tarjeta |

**Datos de ejemplo visibles:**
- `@cofrade_senior` · `hace 2 horas` · 128 comentarios · 1.540 vistas · Resuelto

---

### Pantalla 3 — Detalle de hilo (`Foro Cofradiero` → tema)

**Tab activa:** Foros

#### Barra superior
- Flecha atrás a la izquierda
- Título centrado **Foro Cofradiero** en serif dorado

#### Post principal
| Elemento | Detalle |
|----------|---------|
| Título | **Nueva ruta de la procesión del Viernes Santo** — serif blanco, grande |
| Autor | Avatar circular (Virgen) + `@cofrade_senior` + `hace 2 horas` (rojo apagado) |
| Cuerpo | Párrafo sans-serif blanco sobre nuevo itinerario por Plaza Mayor a las 18:30 |
| Stats | 128 comentarios · 1.540 vistas |
| Badge | **Resuelto** en pastilla burdeos |
| Separador | Línea roja oscura horizontal |

#### Sección «Respuestas»
Título en serif dorado. Tarjetas de respuesta en gris oscuro.

| Respuesta | Avatar | Usuario | Contenido | Stats |
|-----------|--------|---------|-----------|-------|
| 1 | Cruz marrón sobre blanco | `@jose_carpintero` · hace 1 hora | Pregunta sobre la banda de la procesión | 15 comentarios · corazón |
| 2 | Cáliz plateado | `@maria_dolores` · hace 45 min | Agradecimiento por la información | 8 comentarios · corazón |

---

### Pantalla 4 — Buscar (`Buscar`)

**Tab activa:** Buscar (fondo burdeos redondeado detrás del icono y texto)

#### Barra de búsqueda
- Campo redondeado (≈12–15 px), fondo gris marrón oscuro
- Icono lupa a la izquierda
- Placeholder: `Buscar en el Foro Cofradiero...` en crema

#### Sección «Tendencias»
Título serif dorado. Tarjetas con:
- Avatar circular (Virgen, cruz de madera, cáliz)
- Hashtag en blanco bold (ej. `#ViernesSanto`)
- Contador (ej. `1.5k posts`) en gris
- Botón **Seguir**: pastilla burdeos, texto blanco

#### Sección «Búsquedas Recientes»
Título serif dorado. Lista simple:
- Icono reloj/historial + texto (`nueva ruta`, `itinerario`, `banda de cornetas`)
- Texto en crema/blanco sans-serif

---

### Pantalla 5 — Perfil · Publicaciones (`Perfil`)

**Tab activa:** Perfil (fondo burdeos redondeado)

| Elemento | Detalle |
|----------|---------|
| Título | **Perfil** — serif dorado/beige, arriba a la izquierda |
| Avatar | Circular, pintura clásica de la Virgen |
| Nombre | **Hermandad Sevilla** — blanco, sans-serif bold |
| Handle | `@hermandad_sevilla` — gris claro |
| Bio | `Bienvenidos a la cuenta oficial de la Hermandad. Paz y Misericordia.` |
| Tabs | **Publicaciones** (activo, subrayado rojo) · **Acerca de** |
| Tarjeta stats | Fondo `#1C1C1E`, dividida en dos: `150` Publicaciones \| `15.2K` Seguidores |

---

### Pantalla 6 — Perfil · Acerca de (`Perfil`)

**Tab activa:** Perfil · Tab **Acerca de** activo (línea roja debajo)

Misma cabecera de perfil que la pantalla anterior.

#### Sección «Información»
Título serif dorado. Tres tarjetas gris oscuro con icono circular + etiqueta + valor:

| Tarjeta | Icono | Etiqueta | Valor |
|---------|-------|----------|-------|
| 1 | Pin de ubicación | Dirección | Calle Sierpes, 12, Sevilla |
| 2 | Calendario | Fundación | Fundada en 1565 |
| 3 | Globo | Sitio Web | www.hermandadsevilla.es |

---

### Pantalla 7 — Calendario (`Calendario`)

**Tab activa:** Calendario (fondo burdeos redondeado; primer ítem del bottom nav)

| Elemento | Detalle |
|----------|---------|
| Título | **Calendario** — serif dorado |
| Chips filtro | Scroll horizontal: **Todas** (seleccionado: fondo beige, texto negro), Procesiones, Eventos, Misas, Mudas |
| Mes | `Junio 2026` con flechas `<` `>` |
| Días semana | L · M · X · J · V · S · D |
| Grid | Fechas con eventos rodeadas en círculo dorado (días 2, 6, 8, 12, 24) |
| Etiquetas bajo fecha | Texto pequeño (ej. `Salida de Procesión` bajo el 2, `Misa Solemne` bajo el 8) |

#### Sección «Próximos Eventos»
Tarjetas gris oscuro:
- Título: fecha + nombre (ej. `5 Jun - Salida de Procesión`)
- Subtítulo: imagen/titular + hora (ej. `Ntra. Señora de la Misericordia. 18:00`)
- Avatar circular a la derecha (icono religioso)

---

### Pantalla 8 — Notificaciones (`Notificaciones`)

**Tab activa:** Notificaciones (fondo burdeos redondeado)

| Elemento | Detalle |
|----------|---------|
| Título | **Notificaciones** — serif dorado/beige |

**Tarjetas de notificación** (fondo `#1C1C1E`, esquinas redondeadas):

| # | Icono/avatar | Título | Subtítulo | Tiempo |
|---|--------------|--------|-----------|--------|
| 1 | Retrato Virgen | Nuevo comentario | en #ViernesSanto | Hace 5 min |
| 2 | Corazón crema en círculo rojo | Nuevo seguidor | Te han etiquetado en un post | Ayer |
| 3 | Campana crema en círculo rojo | *(tipo sistema)* | *(detalle)* | *(tiempo)* |
| 4 | Cáliz plateado | *(tipo evento)* | *(detalle)* | *(tiempo)* |

Layout: avatar izquierda · texto centro · timestamp arriba derecha en gris.

---

## Acceso al calendario (decisión UX)

El calendario es la **pantalla de inicio** de la app y, a la vez, una función de alto uso esperado (consultar procesiones, horarios y eventos). Para que sea rápido e intuitivo, no se esconde detrás de un icono de «casa» genérico.

### Mapa de accesos

```
                    ┌─────────────────────────────┐
                    │   Abrir app → Calendario    │  ← pantalla por defecto
                    └──────────────┬──────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         │                         │                         │
         ▼                         ▼                         ▼
  Bottom nav                  Atajo en cabecera         Notificación
  Tab 1: 📅 Calendario        (otras pantallas)         → día/evento
  siempre visible             icono dorado arriba
```

### 1. Tab principal del bottom nav (acceso primario)

| Antes (mockup) | Implementación Cofradeo |
|----------------|-------------------------|
| **Inicio** · icono casa 🏠 | **Calendario** · icono calendario 📅 |
| Ruta `/inicio` | Ruta `/calendario` (alias `/` como home) |
| Usuario no sabe qué hay dentro | Usuario ve de un vistazo que ahí están los eventos |

- **Posición:** primer ítem del bottom nav (misma que «Inicio» en el diseño).
- **Icono:** `Icons.calendar_today_outlined` / `Icons.calendar_month` en dorado; activo con fondo burdeos redondeado (igual que el resto de tabs).
- **Etiqueta:** `Calendario` (no «Inicio»).
- **Comportamiento:** al abrir la app, el usuario cae directamente en esta pantalla.

### 2. Botón de acceso rápido en cabecera (acceso secundario)

En pantallas donde el usuario pasa tiempo (foros, búsqueda, perfil, notificaciones), un **atajo fijo al calendario** sin volver a buscar el tab.

| Pantalla | Ubicación del atajo |
|----------|---------------------|
| Lista de foros | Arriba a la derecha, junto a la campana de notificaciones |
| Temas / hilo del foro | AppBar derecha (icono calendario dorado) |
| Buscar | Arriba a la derecha del campo de búsqueda o en la barra superior |
| Notificaciones | AppBar derecha |
| Perfil | AppBar derecha |

**Componente:** `CalendarQuickAccessButton`

| Propiedad | Valor |
|-----------|-------|
| Icono | Calendario outline, color `gold` |
| Tamaño táctil | Mínimo 44×44 px |
| Fondo al pulsar | Círculo burdeos suave o ripple dorado |
| Acción | `context.go('/calendario')` — siempre lleva al calendario |
| Badge opcional | Punto dorado si hay evento hoy (fase 8+) |

Así, desde cualquier sección de la app el calendario está **a un solo toque**.

### 3. Qué NO haremos (para no recargar la UI)

- **No** añadir un 6.º tab solo para calendario (el bottom nav ya tiene 5 ítems; más saturaría).
- **No** usar un FAB flotante central (compite visualmente con el bottom nav y rompe la estética sobria del diseño).
- **No** duplicar calendario dentro de Foros o Perfil (solo enlaces desde eventos concretos en fases posteriores).

### Rutas actualizadas

```
Shell (BottomNav)
├── /calendario      → Calendario (home por defecto, tab 📅)
├── /foros           → Lista de foros
│   └── /foros/:id   → Temas del foro
│       └── /foros/:id/tema/:topicId → Hilo + respuestas
├── /buscar          → Búsqueda
├── /notificaciones  → Notificaciones
└── /perfil          → Perfil (tabs Publicaciones / Acerca de)
```

### Fases donde se implementa

| Elemento | Fase |
|----------|------|
| Tab Calendario en bottom nav | Fase 0 |
| Pantalla calendario completa | Fase 1 |
| `CalendarQuickAccessButton` en foros, buscar, perfil, notificaciones | Fase 1 (junto al calendario) o Fase 7 (pulido global) |
| Badge «evento hoy» en el atajo | Fase 8 (datos reales) |

---

## Sistema de diseño (especificación visual)

Para que la app sea **exactamente igual** al diseño, estas son las referencias de implementación en Flutter.

### Paleta de colores

| Token | Hex | Uso |
|-------|-----|-----|
| `background` | `#000000` | Fondo principal |
| `backgroundElevated` | `#121212` | Variante cabeceras |
| `surface` | `#1A1A1A` / `#1C1C1E` | Tarjetas, stats, notificaciones |
| `gold` | `#D4AF37` | Títulos, iconos activos, círculos calendario |
| `goldLight` | `#D4C4A8` / `#E5D1B8` | Perfil, textos secundarios dorados |
| `burgundy` | `#7A1111` / `#7B1113` | Badges, tabs activos, botones Seguir |
| `burgundyDark` | `#5C0D0D` | Separadores, líneas divisorias |
| `textPrimary` | `#FFFFFF` | Títulos de contenido, nombres |
| `textSecondary` | `#A1A1A1` | Metadatos, timestamps secundarios |
| `textMuted` | `#8A8A8A` | Descripciones |
| `accentRed` | `#C44B4B` | Tiempos «hace X», stats en rojo |
| `chipSelected` | Beige claro | Chip «Todas» seleccionado (texto negro) |
| `notificationDot` | Rojo vivo | Punto en campana del header |

### Tipografía

| Rol | Fuente sugerida | Uso |
|-----|-----------------|-----|
| Display / títulos | **Cinzel** o **Playfair Display** | Foros, Calendario, Perfil, secciones |
| Body / UI | **Inter** o **Lato** | Descripciones, metadatos, botones |

### Componentes reutilizables

| Componente | Descripción |
|------------|-------------|
| `CofradeoBottomNav` | 5 tabs; **tab 1 = Calendario** (icono 📅); ítem activo con `BoxDecoration` burdeos + `borderRadius` ≈ 8–12 |
| `CalendarQuickAccessButton` | Icono calendario dorado en AppBar; navega a `/calendario` desde cualquier pantalla |
| `CofradeoCard` | Fondo `surface`, `borderRadius` 12–16, borde sutil opcional |
| `CofradeoBadge` | Pastilla burdeos: Activo, Resuelto |
| `ForumCategoryCard` | Tarjeta completa de la lista de foros |
| `TopicCard` | Tarjeta de tema con avatar, stats y badge opcional |
| `ReplyCard` | Respuesta en hilo con likes |
| `TrendCard` | Hashtag + Seguir |
| `InfoCard` | Perfil Acerca de (icono + label + valor) |
| `EventCard` | Próximos eventos del calendario |
| `NotificationCard` | Item de lista de notificaciones |
| `CofradeoSearchBar` | Campo redondeado con lupa |
| `FilterChipRow` | Chips horizontales del calendario |
| `CofradeoCalendar` | Grid mensual con indicadores dorados |

### Espaciado y forma

- **Border radius tarjetas:** 12–16 px  
- **Border radius botones/chips:** 8–20 px (Seguir más pill)  
- **Padding horizontal pantalla:** 16–20 px  
- **Avatar estándar:** 40–48 px · Hero/logo foro: 56–64 px  
- **SliverAppBar / hero:** imagen con `gradient` inferior negro transparente → opaco  

### Navegación

Ver [Acceso al calendario](#acceso-al-calendario-decisión-ux) para la estrategia completa. Resumen de rutas:

```
Shell (BottomNav)
├── /calendario      → Calendario (home, tab 📅)
├── /foros           → Lista de foros  [+ CalendarQuickAccess en AppBar]
│   └── /foros/:id   → Temas del foro
│       └── /foros/:id/tema/:topicId → Hilo + respuestas
├── /buscar          → Búsqueda
├── /notificaciones  → Notificaciones
└── /perfil          → Perfil (tabs Publicaciones / Acerca de)
```

---

## Arquitectura técnica

```
lib/
├── main.dart
├── app.dart                    # MaterialApp + tema + router
├── core/
│   ├── theme/                  # colors, typography, theme_data
│   ├── router/                 # go_router
│   └── widgets/                # componentes compartidos del design system
├── features/
│   ├── shell/                  # Scaffold + BottomNav
│   ├── forums/
│   ├── search/
│   ├── profile/
│   ├── calendar/
│   └── notifications/
└── shared/
    ├── models/
    ├── data/                   # mock → repository → API
    └── repositories/
```

| Capa | Tecnología |
|------|------------|
| UI | Flutter 3.x |
| Navegación | `go_router` |
| Estado | `flutter_riverpod` |
| Fuentes | `google_fonts` |
| Calendario | `table_calendar` (estilizado) |
| Backend (fases tardías) | **Supabase** (auth, BD, storage) |
| Push (Fase 9) | **Firebase FCM** solo envío — ver [`NOTIFICACIONES.md`](NOTIFICACIONES.md) |
| Medios | Solo imágenes — ver [`MEDIA.md`](MEDIA.md) |

---

## Fases de desarrollo

Cada fase es un entregable navegable. **No se pasa a la siguiente fase sin cumplir los criterios de aceptación visual.**

---

### Fase 0 — Fundación y design system

**Duración orientativa:** 1 semana  
**Objetivo:** Proyecto Flutter con identidad visual Cofradeo lista para construir pantallas.

#### Tareas
- [x] Crear proyecto Flutter (`com.cofradeo.cofradeo`)
- [x] Definir `AppColors`, `AppTypography`, `AppTheme` (dark only)
- [x] Integrar Google Fonts (Cinzel + Inter)
- [x] Implementar `CofradeoBottomNav` con los 5 ítems: **Calendario** (icono 📅, no casa), Foros, Buscar, Notificaciones, Perfil
- [x] Implementar `CofradeoShell` con `go_router`; ruta por defecto `/calendario`
- [x] Crear `CalendarQuickAccessButton` (widget reutilizable, listo para Fase 1+)
- [x] Crear widgets base: `CofradeoCard`, `CofradeoBadge`, avatares
- [ ] Añadir assets pendientes → ver [`docs/ASSETS-CHECKLIST.md`](ASSETS-CHECKLIST.md)
- [x] Pantallas placeholder en cada ruta para validar navegación

#### Entregable
App que abre, navega entre 5 tabs y respeta colores/tipografías del diseño.

---

### Fase 1 — Calendario (pantalla principal)

**Duración orientativa:** 1–1,5 semanas  
**Pantalla:** Imagen 6 — Calendario  
**Tab activa:** Calendario (primer ítem del bottom nav, icono 📅)

#### Tareas
- [x] Pantalla `CalendarScreen` fiel al mockup
- [x] Título **Calendario** serif dorado
- [x] `FilterChipRow`: Todas, Procesiones, Eventos, Misas, Mudas (estado seleccionado beige)
- [x] `CofradeoCalendar`: mes Junio 2026, flechas navegación, días L–D
- [x] Círculos dorados en días con evento + etiqueta bajo el día
- [x] Sección **Próximos Eventos** con `EventCard` (datos mock)
- [x] Filtrado local por chip (mock)
- [x] Ruta `/calendario` como home al abrir la app
- [x] Integrar `CalendarQuickAccessButton` en cabecera de Foros (junto a campana) como primer atajo

#### Datos mock mínimos
```dart
// Ejemplos del diseño
Event(date: 2026-06-05, title: 'Salida de Procesión', subtitle: 'Ntra. Señora de la Misericordia. 18:00', type: procesion)
```

---

### Fase 2 — Foros: lista y navegación a temas

**Duración orientativa:** 1,5–2 semanas  
**Pantallas:** Imagen 1 (lista) + Imagen 2 (temas)  
**Tab activa:** Foros

#### Tareas — Lista de foros
- [x] `ForumsScreen` con `CustomScrollView` + `SliverAppBar` o `Stack` para hero
- [x] Header: logo, nombre, eslogan, campana con punto rojo
- [x] Imagen hero procesión + degradado
- [x] Título **Foros** + subtítulo
- [x] 4× `ForumCategoryCard` con iconos, stats, badge Activo, último mensaje, chevron
- [x] Tap en tarjeta → navega a `/foros/:id`

#### Tareas — Temas del foro
- [x] `ForumTopicsScreen` con cabecera blur + logo cruz + stats
- [x] Separador rojo
- [x] Lista **Temas de Discusión** con `TopicCard`
- [x] Badge **Resuelto** en tema correspondiente
- [x] Tap en tema → `/foros/:id/tema/:topicId`
- [x] Botón atrás funcional

#### Datos mock
4 foros del diseño + al menos 5 temas para Foro Cofradiero (incluido el de «Nueva ruta...»).

---

### Fase 3 — Foros: detalle de hilo y respuestas

**Duración orientativa:** 1 semana  
**Pantalla:** Imagen 8 — Hilo  
**Tab activa:** Foros

#### Tareas
- [x] `TopicDetailScreen`: AppBar con atrás + título **Foro Cofradiero**
- [x] Post principal: título serif, autor, cuerpo, stats, badge Resuelto
- [x] Separador rojo
- [x] Sección **Respuestas** con `ReplyCard` (2+ respuestas del mockup)
- [x] Iconos comentarios y corazón en respuestas
- [x] Campo fijo abajo para escribir respuesta (UI only)

---

### Fase 4 — Buscar

**Duración orientativa:** 1 semana  
**Pantalla:** Imagen 3 — Buscar  
**Tab activa:** Buscar

#### Tareas
- [x] `SearchScreen` con `CofradeoSearchBar`
- [x] Sección **Tendencias** con 3+ `TrendCard` (#ViernesSanto, etc.)
- [x] Botón **Seguir** con toggle visual (sin backend); en Fase 8 → notificaciones por hashtag (ver `NOTIFICACIONES.md`)
- [x] Sección **Búsquedas Recientes** con icono reloj
- [x] Tap en búsqueda reciente rellena el campo
- [x] Búsqueda local mock filtra temas por título

---

### Fase 5 — Perfil

**Duración orientativa:** 1–1,5 semanas  
**Pantallas:** Imagen 4 + Imagen 5 — Perfil  
**Tab activa:** Perfil

#### Tareas
- [x] `ProfileScreen` con datos Hermandad Sevilla del mockup
- [x] Título **Perfil**, avatar, nombre, handle, bio
- [x] `TabBar`: Publicaciones · Acerca de (indicador línea roja)
- [x] Tab **Publicaciones**: tarjeta stats 150 / 15.2K (grid vacío o placeholder «Próximamente»)
- [x] Tab **Acerca de**: sección **Información** + 3× `InfoCard`
- [x] Cambio de tab sin perder scroll de cabecera
- [ ] Editar perfil, bloquear y reportar → **Fase 8** (ver [`PERFIL.md`](PERFIL.md))

---

### Fase 6 — Notificaciones

**Duración orientativa:** 3–5 días  
**Pantalla:** Imagen 7 — Notificaciones  
**Tab activa:** Notificaciones

#### Tareas
- [x] `NotificationsScreen` con título **Notificaciones**
- [x] Lista de `NotificationCard` (4 ítems del diseño)
- [x] Incluir tipos acordados: **hashtag** (`#ViernesSanto`) y **usuario/hermandad** (ver `NOTIFICACIONES.md`)
- [x] Layout: avatar · título + subtítulo · timestamp arriba derecha
- [x] Tap en tarjeta → navegar al hilo o publicación (mock)
- [x] Punto rojo en campana del header de Foros cuando hay no leídas (estado global mock)

---

### Fase 7 — Pulido visual y fidelidad pixel-perfect

**Duración orientativa:** 1 semana  
**Objetivo:** La app se ve **exactamente** como las imágenes en dispositivo real.

#### Tareas
- [x] Revisión pantalla a pantalla vs. mockups (iPhone de referencia) — coherencia tema claro aplicada
- [x] `CalendarQuickAccessButton` en todas las pantallas secundarias (buscar, perfil, notificaciones, hilos)
- [x] Componente `ScreenTitleRow` (título + atajo calendario)
- [x] Ajustes menores: ripple atajo calendario, animación bottom nav (280 ms)
- [x] Safe area y status bar en `main.dart` (barra clara, nav oscura)
- [x] Modo oscuro global: **no implementar** (contenido claro beige acordado)
- [ ] Screenshots para stores / presentación (manual)

---

### Fase 8 — Backend y datos reales (post-MVP visual)

**Duración orientativa:** 2–3 semanas  
**Objetivo:** Sustituir mocks por servicios reales sin cambiar la UI.

#### Tareas
- [x] Auth UI: login, registro, Google/Apple (OAuth), email — ver [`AUTH.md`](AUTH.md) · [`SUPABASE.md`](SUPABASE.md)
- [x] Supabase bootstrap + `env.json` (modo invitado sin credenciales)
- [x] Esquema SQL inicial: profiles, follows, notifications, blocks, reports
- [x] Gate login al responder en hilos; banner Perfil invitado/sesión
- [x] Supabase: foros lectura + publicar respuesta (parcial; ver [`SUPABASE.md`](SUPABASE.md))
- [ ] CRUD: crear tema nuevo (persistido)
- [x] **Editar perfil** + avatar (solo imagen) — [`PERFIL.md`](PERFIL.md) · [`MEDIA.md`](MEDIA.md)
- [x] **Bloquear** y **reportar** perfil (menú ···) — [`PERFIL.md`](PERFIL.md)
- [x] Seguimientos persistidos (`follows`) desde Buscar — [`NOTIFICACIONES.md`](NOTIFICACIONES.md)
- [x] Notificaciones in-app reales desde Supabase + trigger al responder
- [x] Seguir perfiles desde Perfil ajeno
- [x] Crear tema nuevo en foro (login + Supabase)
- [ ] Panel admin para revisar reportes — plan por fases en [`ADMIN.md`](ADMIN.md)

#### Fase 8e — Siguiendo y notificaciones (UX social)
- [x] Pestaña **Siguiendo** en Perfil (hashtags + cuentas, dejar de seguir)
- [x] Notificaciones: **Marcar leídas** y **Limpiar** bajo demanda (no al entrar)
- [x] Deslizar para eliminar una notificación
- [x] Handle clicable en respuestas → perfil ajeno → Seguir
- [x] Botón **Responder** con mención `@usuario` en el compositor

#### Fase 8f — Foro social (pendiente)
- [x] **Subrespuestas** anidadas (responder a una respuesta con indentación)
- [x] Notificación **Nuevo seguidor** al seguir un perfil
- [x] Perfil ajeno **dentro del shell** (menú inferior visible)
- [x] **Me gusta** funcional en respuestas
- [x] **Bloquear** y **reportar** perfil (menú ···)

---

### Fase 9 — Beta y lanzamiento

**Duración orientativa:** continuo

- [ ] **Push FCM (Firebase)** — solo envío; datos en Supabase — [`NOTIFICACIONES.md`](NOTIFICACIONES.md) · `notifications_push.sql`
- [ ] Supabase Storage: avatares (solo imagen) — [`MEDIA.md`](MEDIA.md)
- [ ] TestFlight / Play Console internal testing
- [ ] Política de privacidad y términos
- [ ] Onboarding mínimo (3 pantallas opcionales)
- [ ] Analytics (Firebase Analytics / Mixpanel)
- [ ] Feedback de cofrades reales → iteración

---

## Criterios de aceptación por fase

| Fase | Listo cuando… |
|------|----------------|
| 0 | Navegación 5 tabs (tab 1 = **Calendario** 📅) + tema dark + fuentes correctas |
| 1 | Calendario idéntico a imagen 6, chips y eventos funcionan (mock) + atajo en cabecera de Foros |
| 2 | Lista foros = imagen 1; temas = imagen 2; navegación OK |
| 3 | Hilo = imagen 8 con post + 2 respuestas |
| 4 | Buscar = imagen 3 con tendencias y recientes |
| 5 | Perfil ambos tabs = imágenes 4 y 5 |
| 6 | Notificaciones = imagen 7 |
| 7 | Revisión visual ≥ 95 % fidelidad en 5 dispositivos/tamaños |
| 8 | Login + publicar tema real en producción |
| 9 | 20+ beta testers usando la app |

---

## Qué queda fuera del MVP inicial

Para mantener foco y calidad visual, **no** se incluye en fases 0–7:

- Registro/login con flujo completo
- Subida de imágenes en posts
- Chat en tiempo real / mensajería privada
- Mapa de procesiones en vivo
- Versión web
- Modo claro
- Internacionalización (solo español)
- Monetización / anuncios
- Verificación automática de hermandades

---

## Orden de implementación recomendado

```
Fase 0 ──► Fase 1 (Calendario) ──► Fase 2 (Foros lista + temas)
                                        │
                                        ▼
                              Fase 3 (Hilo)
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
              Fase 4 (Buscar)    Fase 5 (Perfil)    Fase 6 (Notificaciones)
                    └───────────────────┬───────────────────┘
                                        ▼
                              Fase 7 (Pulido visual)
                                        ▼
                              Fase 8 (Backend)
                                        ▼
                              Fase 9 (Beta)
```

---

## Notas de marca

- En los mockups aparece **«FORO COFRADE»**; el producto se llama **Cofradeo**. En implementación: mantener tipografía y layout del header, sustituir texto por **COFRADEO** salvo que se indique lo contrario.
- El eslogan **Fe • Tradición • Hermandad** se conserva.
- El tab **Inicio** (icono casa) del mockup pasa a **Calendario** (icono calendario) para acceso directo a la función más consultada. La pantalla de calendario (imagen 6) no cambia.
- Todas las cifras, usuarios y textos del diseño sirven como **datos seed** hasta conectar backend.

---

## Autenticación (login)

Detalle completo en [`docs/AUTH.md`](AUTH.md) y configuración en [`docs/SUPABASE.md`](SUPABASE.md).

| Pregunta | Respuesta |
|----------|-----------|
| ¿Cuándo? | **Fase 8** — no bloquea fases 0–7 |
| ¿Google? | **Sí**, botón principal «Continuar con Google» |
| ¿Email? | **Sí**, registro e inicio con contraseña |
| ¿Apple? | **Sí en iOS** (obligatorio si hay Google en App Store) |
| ¿Backend? | **Supabase Auth** (recomendado) |
| ¿Sin cuenta? | Lectura libre; login al publicar o editar perfil |

---

## Assets e imágenes (checklist)

Cuando quieras **meter imágenes sin tocar código**, usa:

**[`docs/ASSETS-CHECKLIST.md`](ASSETS-CHECKLIST.md)** — recordatorio con casillas `[ ]` / `[x]`

| Ahora mismo pendiente | Ruta |
|-----------------------|------|
| Hero procesión (Foros) | `assets/images/hero_procesion.jpg` |
| Iconos calendario (×6) | `assets/icons/procesion.png`, `gloria.png`, … |

Detalle técnico: [`docs/ASSETS.md`](ASSETS.md)

---

*Última actualización: junio 2026 · Documento vivo — marcar checkboxes según se completen las fases.*
