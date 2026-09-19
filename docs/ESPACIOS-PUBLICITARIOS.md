# Cofradeo · Catálogo de espacios publicitarios

**Documento comercial para patrocinadores**  
Versión alineada con la app en producción · Julio 2026

---

## Resumen para el anunciante

Cofradeo ofrece **publicidad nativa** integrada en la experiencia cofrade: sin pop-ups, sin vídeos obligatorios y con etiquetado transparente («Publicidad», «Evento patrocinado»).

Cada espacio se contrata por **ubicación** (`placement`). Si varios anunciantes comparten la misma ubicación, el sistema aplica un **sorteo ponderado por prioridad**: a mayor peso, más probabilidad de salir, pero **nunca garantía del 100 %** salvo exclusividad (ser el único activo).

---

## Inventario de espacios (activos hoy)

| # | Nombre comercial | Clave técnica | Tipo | Pantalla |
|---|------------------|---------------|------|----------|
| 1 | **Banner superior de Foros** | `forums_top` | Banner fijo | Lista principal de foros (`/foros`) |
| 2 | **Evento patrocinado en foro** | `forums_event` | Tarjeta nativa + logo | Dentro de un foro concreto |
| 3 | **Banner en listado de foro** | `forums_middle` | Banner en feed | Dentro de un foro concreto |
| 4 | **Banner en tema destacado** | `featured_topic` | Banner en hub/detalle | Cuaresma, Semana Santa, Glorias |
| 5 | **Banner en Hermandades** | `hermandades` | Banner en feed | Solo foro Hermandades |
| 6 | **Banner en Calendario** | `calendar` | Banner compacto | Calendario cofrade |
| 7 | **Banner en Buscar** | `search` | Banner compacto | Buscar (pantalla inicial) |
| 8 | **Banner en Noticias** | `noticias` | Banner fijo | Canal Noticias (`/foros/noticias`) |

> **Reservados (no activos en comercial):** `home`, `profile`.

---

## 1. Banner superior de Foros (`forums_top`)

| | |
|---|---|
| **Dónde** | Pestaña **Foros**, en la lista de pilares (Círculo Cofradiero, Pentagrama, etc.). Anclado **encima de la barra de navegación inferior**. |
| **Cuándo se ve** | Solo en la lista de foros, no dentro de un foro concreto. |
| **Formato** | Banner horizontal premium. |
| **Creativo** | **1200 × 276 px** (ratio ~4,35:1). Dejar libre la esquina inferior derecha para el botón «Ver más». |
| **Foro destino** | No aplica (es global a la sección Foros). |
| **Ideal para** | Marca ancla, patrocinador principal de la comunidad. |

**Visibilidad:** muy alta en usuarios que entran a Foros. Una sola pieza por sesión en esa zona.

---

## 2. Evento patrocinado en foro (`forums_event`)

| | |
|---|---|
| **Dónde** | Dentro de un foro, **justo después de los temas fijados** y antes del listado de la comunidad. |
| **Formato** | Tarjeta «EVENTO PATROCINADO»: portada del evento del calendario + datos (fecha, hora, templo) + logo del patrocinador. |
| **Vinculación** | Un **evento concreto** del calendario, o **todos los eventos** de hoy/futuros (rota al próximo acto publicado). Los pasados no se muestran. |
| **Logo patrocinador** | Recomendado **520 × 300 px**, PNG/WebP con fondo transparente. |
| **Enlace** | Opcional; si no se indica, abre el calendario. |
| **Foro destino** | Configurable: un foro concreto o todos. |

**Foros disponibles para segmentar:**

| ID | Nombre |
|----|--------|
| `foro-cofradiero` | Círculo Cofradiero |
| `pentagrama-cofrade` | Pentagrama Cofrade |
| `martillo-trabajadera` | Martillo y Trabajadera |
| `hermandades` | Hermandades |

**Ideal para:** patrocinio de un acto, procesión, iguala o evento vinculado al calendario.

**Nota comercial:** si hay evento patrocinado activo en un foro, **no se muestra otro banner justo debajo** (evita saturación). El banner de listado pasa al feed de temas.

---

## 3. Banner en listado de foro (`forums_middle`)

| | |
|---|---|
| **Dónde** | Dentro de un foro, en el listado de temas. |
| **Formato** | Banner horizontal con etiqueta «Publicidad» integrada en el creativo. |
| **Creativo** | **1200 × 300 px** (ratio 4:1). PNG, WebP o JPG. |
| **Foro destino** | Configurable: un foro o todos. |

**Comportamiento (visibilidad sin saturar):**

| Situación | Dónde aparece el banner |
|-----------|-------------------------|
| **Sin** evento patrocinado en ese foro | Un banner **antes** del listado de temas (visible al entrar). |
| **Con** evento patrocinado en ese foro | No arriba; primer banner tras **6 temas** al hacer scroll. |
| Foro con **20+ temas** (sin búsqueda/filtro) | Repetición cada **12 temas** en el scroll. |
| Usuario **buscando o filtrando** en el foro | Solo el banner superior del listado (si aplica); sin repeticiones en medio. |

**Ideal para:** visibilidad sostenida en foros activos (costalerías, talleres, hostelería cofrade).

---

## 3b. Banner en tema destacado (`featured_topic`)

| | |
|---|---|
| **Dónde** | Dentro de **Cuaresma**, **Semana Santa** o **Glorias** (hub / detalle del tema fijado). |
| **Formato** | Banner horizontal «Publicidad» (mismo creativo 1200 × 300 px). |
| **Tema destino** | Un destacado concreto o todos. |
| **Gestión** | Junta → Patrocinios (mapa) o icono megáfono en la tarjeta del tema destacado. |

**Ideal para:** marcas de temporada (hostelería, tiendas, servicios cofrades) ligadas a Cuaresma / Semana Mayor / Glorias.

---

## 4. Banner en Hermandades (`hermandades`)

| | |
|---|---|
| **Dónde** | Foro **Hermandades** (canal oficial por días de procesión). |
| **Formato** | Igual que banner en listado (**1200 × 300 px**). |
| **Segmentación** | Solo este foro (placement dedicado en campañas de Semana Santa / Cuaresma). |
| **Comportamiento** | Misma lógica de posición y repetición que `forums_middle`, pero independiente en el sorteo. |

**Ideal para:** patrocinadores de temporada alta (Semana Santa, Cuaresma, Glorias).

---

## 5. Banner en Calendario (`calendar`)

| | |
|---|---|
| **Dónde** | Pestaña **Calendario**, entre los filtros/búsqueda y el listado de eventos del día. |
| **Cuándo NO se ve** | Mientras el usuario está **buscando eventos** en el calendario. |
| **Formato** | Banner compacto **1200 × 300 px**. |
| **Contexto** | La **cuenta atrás litúrgica** y el **hero del día** son contenido editorial de Cofradeo, no publicidad. El banner no compite con ellos. |

**Ideal para:** marcas que quieren asociarse a la agenda cofrade (hostelería, turismo, comercio local).

---

## 6. Banner en Buscar (`search`)

| | |
|---|---|
| **Dónde** | Pestaña **Buscar**, entre el campo de búsqueda y la sección «Tendencias». |
| **Cuándo se ve** | Solo en la **pantalla inicial** (sin texto en el buscador). |
| **Cuándo NO se ve** | En cuanto el usuario escribe y aparecen resultados. |
| **Formato** | Banner compacto **1200 × 300 px**. |

**Ideal para:** descubrimiento de marca, negocios locales, colaboradores de nicho.

---

## 7. Banner en Noticias (`noticias`)

| | |
|---|---|
| **Dónde** | Canal **Noticias**, anclado **encima de la barra de navegación inferior** (mismo patrón que el banner de Foros). |
| **Cuándo se ve** | Solo en el listado de Noticias (`/foros/noticias`), no dentro de una noticia abierta. |
| **Formato** | Banner horizontal premium. |
| **Creativo** | **1200 × 276 px** (ratio ~4,35:1). Dejar libre la esquina inferior derecha para el botón «Ver más». |
| **Foro destino** | No aplica (zona exclusiva de Noticias). |

**Visibilidad:** alta en usuarios que leen actualidad cofrade. Una sola pieza anclada; **sin** banners adicionales en el feed de noticias (evita saturación).

**Ideal para:** marcas de temporada, hostelería y comercios que quieran asociarse a la actualidad de la Semana Santa sevillana.

---

## Sistema de rotación y probabilidades

### Cómo se elige el anuncio

Cada vez que un usuario abre una ubicación (entra a un foro, abre el calendario, etc.), la app solicita un anuncio al servidor. Si hay **varios anuncios activos** en esa ubicación (y mismo alcance de foro, si aplica), se hace un **sorteo aleatorio ponderado**:

```
Probabilidad de tu anuncio ≈ Tu prioridad / Suma de prioridades de todos los competidores activos
```

- Cada **móvil** hace su propio sorteo → en 5 teléfonos pueden salir anuncios distintos en el mismo momento.
- **No es fijo:** prioridad 50 no significa salir siempre; significa salir **mucho más** que uno con prioridad 10.
- Si eres el **único anuncio activo** en esa ubicación → **100 %** de las apariciones (hasta agotar cupo de impresiones).

### Niveles de prioridad (peso en el sorteo)

| Nivel | Peso | Uso recomendado |
|-------|------|-----------------|
| Baja | 5 | Presencia ocasional, pruebas, marcas locales |
| Normal | 10 | Equilibrio habitual (valor por defecto) |
| Alta | 25 | Campañas con presupuesto medio |
| Premium | 50 | Prioridad clara frente a competencia |
| Máxima | 100 | Máxima exposición dentro del sorteo |
| Personalizada | 1–100 | Acuerdos específicos con la Junta |

### Ejemplos de cuota estimada

**Ejemplo A — Dos anunciantes en Calendario**

| Anunciante | Prioridad | Cuota aproximada |
|------------|-----------|------------------|
| Cervecería Arturo | 50 | **~83 %** |
| D'arte | 10 | **~17 %** |

**Ejemplo B — Cuatro anunciantes en banner de foro (mismo foro o «todos»)**

| Anunciante | Prioridad | Cuota aproximada |
|------------|-----------|------------------|
| Marca A | 50 | **50 %** |
| Marca B | 25 | **25 %** |
| Marca C | 15 | **15 %** |
| Marca D | 10 | **10 %** |

**Ejemplo C — Exclusividad**

| Situación | Cuota |
|-----------|-------|
| Solo tu anuncio activo en `forums_top` | **100 %** |

### Segmentación por foro y competencia

- En `forums_event`, `forums_middle` y `featured_topic` puedes contratar **un destino** (foro o tema) o **todos**.
- Un anuncio con destino «Todos» compite también cuando alguien entra a un foro/tema concreto.
- Un anuncio solo para «Martillo y Trabajadera» solo compite con otros anuncios de ese foro o de «Todos».

### Condiciones para entrar en el sorteo

Un anuncio solo participa si:

- Está **activo**.
- No ha alcanzado el **máximo de impresiones** contratado.
- Está dentro de las fechas de campaña (`start_date` / `end_date`, si se configuran).
- Cumple el filtro de foro (si aplica).

---

## Métricas incluidas

| Métrica | Definición |
|---------|------------|
| **Impresión** | El anuncio se ve al menos **50 %** en pantalla durante **1 segundo**. Máximo **1 impresión por usuario y anuncio cada 24 h**. |
| **Clic** | El usuario pulsa el banner o la tarjeta y abre el enlace destino. |
| **Cupo** | Cada campaña tiene un **máximo de impresiones** (ej. 5 000). Al llegar al límite, deja de mostrarse hasta renovación. |

Los informes se pueden extraer desde el panel de administración (Junta → Patrocinios).

---

## Especificaciones creativas

| Elemento | Especificación |
|----------|----------------|
| Banner superior foros | 1200 × 276 px |
| Banner Noticias | 1200 × 276 px |
| Banner listado / calendario / buscar / Hermandades | 1200 × 300 px (4:1) |
| Logo evento patrocinado | 520 × 300 px, fondo transparente recomendado |
| Formatos | PNG, WebP, JPG (máx. 4 MB) |
| Título | 2–80 caracteres |
| Enlace | HTTPS obligatorio |
| Botón | Texto corto: «Ver más», «Ver evento», etc. |

**No se admiten:** creatividades pixeladas, exceso de texto, estética ajena al entorno cofrade.

---

## Dónde NO hay publicidad

Por diseño, para respetar la lectura y la conversación:

- Interior de un **tema** o hilo (lectura y respuestas)
- Composición de temas y respuestas
- Login, registro y recuperación de contraseña
- **Notificaciones**
- Panel de administración / Junta
- **Búsqueda activa** (con resultados) en Buscar y Calendario

---

## Paquetes comerciales

Detalle comercial completo en [`PATROCINIOS.md`](PATROCINIOS.md). Resumen:

| Paquete | Espacios | Cupo | Precio |
|---------|----------|------|--------|
| **Colaborador Cofradeo** | `search` + `calendar` + `forums_top` | 10 / 5 / 5 · rotación equitativa | **129 €** (1 mes) · **297 €** (trimestre) |
| **Extra · Dentro de un foro** | `forums_middle` (1 foro) | Máx. 3 por foro | **+99 €/mes** · **+89 €/mes** con pack trimestre |
| **Extra · Evento patrocinado** | `forums_event` | 1 por foro en fechas del acto | **89 – 99 €** / campaña |
| **Hermandades / SS** | `hermandades` | — | Fuera de venta hasta activación |

*No se vende sin cupo: plazas limitadas y lista de espera si están llenas.*

---

## Mapa visual simplificado

```text
CALENDARIO
  Cuenta atrás (editorial)
  Hero del día (editorial)
  Mes + semana
  Filtros + búsqueda
  → [calendar] BANNER
  Eventos del día

FOROS (lista)
  Pilares de foros
  → [forums_top] BANNER (fijo sobre bottom nav)

NOTICIAS
  Listado de noticias
  → [noticias] BANNER (fijo sobre bottom nav)

FORO (dentro)
  Temas fijados
  → [forums_event] TARJETA EVENTO (opcional, por foro)
  → [forums_middle] BANNER (antes de temas o cada 12 temas)
  Temas comunidad

HERMANDADES
  (igual que foro, placement hermandades para el banner de pie)

BUSCAR (inicial)
  Buscador
  → [search] BANNER
  Tendencias / Recientes
```

---

## Proceso de alta de campaña

1. Elección de **espacio(s)** y **foro** (si aplica).
2. Definición de **prioridad**, **cupo de impresiones** y **fechas**.
3. Envío de creatividades según especificaciones.
4. Revisión editorial por la Junta.
5. Activación en panel **Junta → Patrocinios** (mapa de espacios).
6. Informe de impresiones y clics al cierre.

---

## Contacto comercial

*(Completar con datos reales de la Comunidad Cofradiero / Cofradeo.)*

| | |
|---|---|
| **Email** | patrocinios@cofradeo.es |
| **App** | Cofradeo — iOS y Android |

---

## Anexo técnico (referencia interna)

| Placement | Valor en base de datos |
|-----------|------------------------|
| Banner superior foros | `forums_top` |
| Banner Noticias | `noticias` |
| Evento patrocinado | `forums_event` |
| Banner listado foro | `forums_middle` |
| Banner Hermandades | `hermandades` |
| Calendario | `calendar` |
| Buscar | `search` |

- Tablas: `ads`, `ad_impressions`, `ad_clicks`
- Almacén de imágenes: bucket `ad-assets`
- Sorteo: función `get_ad_for_placement(placement, forum_id opcional)`

Documentación técnica: [`ADMIN.md`](ADMIN.md) · `supabase/ads.sql` · [`PATROCINIOS.md`](PATROCINIOS.md) (dossier ampliado con precios orientativos).

---

*Cofradeo · Catálogo de espacios publicitarios · Agosto 2026*
