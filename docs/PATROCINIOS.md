# Cofradeo · Dossier de patrocinios

**La app de referencia de la cofradía sevillana**  
Patrocinios selectos · Audiencia cofrade · Sin saturación publicitaria

---

## Propuesta de valor

Cofradeo concentra a cofrades, hermandades, capataces, costaleros y aficionados en un único espacio digital: calendario litúrgico, foros temáticos, búsqueda y comunidad.

Los patrocinios no son «banners genéricos»: son **colaboraciones visibles** con marcas del ecosistema cofrade de Sevilla, presentadas con el mismo lenguaje visual de la app (burdeos, dorado, tipografía serif).

**Principios:**

- Pocas marcas, bien elegidas (curación editorial y **cupos por zona**).
- Máximo **1–2 puntos de contacto** por sesión de uso.
- Contenido actualizable **sin que el usuario actualice la app**.
- Métricas de impresiones y clics para el patrocinador.
- Plazas con **cupo publicado** (Buscar 10 · Calendario 5 · Foros top 5): quien está dentro forma parte de una red curada.

---

## Carta comercial (producto de venta)

### Colaborador Cofradeo

Presencia en **Buscar**, **Calendario** y **banner principal de Foros**.  
Rotación equitativa. **Cupos públicos (no se amplían a la ligera):**

- Buscar: **máx. 10** colaboradores  
- Calendario: **máx. 5**  
- Lista de Foros: **máx. 5**  

Si el cupo está completo → lista de espera.

| Modalidad | Precio |
|-----------|--------|
| **1 mes** | **129 €** |
| **Trimestre** (recomendado) | **297 €** (99 €/mes) |

**Resumen de zonas**

| Zona | Placement | Cupo máx. |
|------|-----------|-----------|
| Buscar | `search` | **10** |
| Calendario | `calendar` | **5** |
| Lista de Foros (banner) | `forums_top` | **5** |

Al acabar el periodo, el colaborador renueva si le interesa. Informe de impresiones y clics.

---

### Extra · Dentro de un foro

Banner en el listado de temas de **un foro concreto** (`forums_middle`).  
Cupo máximo: **3 por foro** · rotación equitativa.

| Modalidad | Precio |
|-----------|--------|
| Mes suelto (añadido al Colaborador) | **+99 €/mes** |
| Unido al pack trimestre del Colaborador | **+89 €/mes** |

Varios foros: se cobra por cada foro (o acuerdo «2 foros» bajo petición).

---

### Extra · Evento patrocinado

Tarjeta destacada ligada a un acto del calendario (`forums_event`: iguala, concierto, pregón…).  
**Pago único por campaña** (no suscripción). Cupo: **1 por foro** en las fechas del acto.

| Modalidad | Precio |
|-----------|--------|
| Campaña (aprox. 2–4 semanas alrededor del evento) | **89 – 99 €** |

---

### Próximamente

| Producto | Notas |
|----------|-------|
| **Hermandades / temporada SS** | Placement `hermandades` deshabilitado en venta hasta activación. Paquete Cuaresma–Semana Santa a definir. |
| **`home` / `profile`** | Reservados; no se activan sin patrocinador y diseño acordado. |

*Estrategia: red curada con cupo (seriedad y privilegio de plaza) + extras para subir ticket. No saturamos la app ni diluimos la presencia vendiendo sin límite.*

---

## Catálogo de ubicaciones (referencia)

| Placement | Pantalla | En producto |
|-----------|----------|-------------|
| **`search`** | Buscar (estado inicial) | Incluido en Colaborador |
| **`calendar`** | Calendario cofrade | Incluido en Colaborador |
| **`forums_top`** | Lista principal de Foros | Incluido en Colaborador |
| **`forums_middle`** | Listado de temas dentro de un foro | Extra · Dentro de un foro |
| **`forums_event`** | Tarjeta evento en un foro | Extra · Evento patrocinado |
| **`hermandades`** | Foro Hermandades | Próximamente (fuera de venta) |

---


## Qué incluye cada patrocinio

- Diseño integrado en la app (no pop-ups ni intersticiales).
- Etiqueta clara: «Publicidad», «Evento patrocinado» o «Colaborador destacado».
- Enlace a web, tienda o ficha de evento.
- Logo e imagen en alta calidad (revisión editorial).
- Activación y desactivación en tiempo real desde el panel de administración.
- Registro de **impresiones** (visibilidad ≥ 50 % durante 1 s) y **clics**.

---

## Requisitos creativos (calidad premium)

Para mantener la sensación «top de Sevilla»:

| Requisito | Detalle |
|-----------|---------|
| Imagen banner | Mín. 1200×300 px (ratio ~4:1), JPG/PNG/WebP |
| Logo patrocinador | Fondo transparente o sobre burdeos, mín. 400×400 px |
| Copy | Título ≤ 80 caracteres · Descripción ≤ 180 |
| Botón | Texto corto: «Visitar tienda», «Ver evento», «Conocer» |
| Enlace | URL HTTPS válida |

**Se rechazan:** creatividades pixeladas, exceso de texto, estética ajena al entorno cofrade.

---

## Cupos y exclusividad

**Modelo comercial:** no se vende probabilidad opaca. Se vende **plaza en una red con cupo** y rotación equitativa. Si el cupo de una zona está lleno → lista de espera.

**Exclusividad de categoría** (recomendado en acuerdos premium / misma zona sin rotación amplia):

| Categoría | Ejemplo | Máx. simultáneo |
|-----------|---------|-----------------|
| Costalería | Costales, mantillas | 1 |
| Sastrería / estreno | Túnicas, complementos | 1 |
| Taller artístico | Imaginería, dorado | 1 |
| Floristería cofrade | Palmas, centros | 1 |
| Evento / espectáculo | Iguala, concierto | Por evento (`forums_event`) |

---

## Zonas donde NO hay publicidad

Por diseño, para respetar la experiencia:

- Lectura de un tema o hilo de conversación
- Redacción de temas y respuestas
- Login, registro y recuperación de contraseña
- Notificaciones
- Panel de la Junta / administración

---

## Funcionamiento técnico (para el patrocinador)

1. Cofradeo carga el anuncio desde **servidor** (Supabase) al abrir cada pantalla.
2. **No hace falta** que los usuarios actualicen la app en la tienda para ver un anuncio nuevo.
3. Al cambiar imagen, texto o activar/desactivar el anuncio, el cambio se refleja al **reentrar en la pantalla** (o al reiniciar la app).
4. Las imágenes se alojan en **almacenamiento en la nube**, no van embebidas en la instalación.

---

## Mapa de la app (dónde aparece cada placement)

```text
┌─────────────────────────────────────┐
│  CALENDARIO (tab principal)         │
│  · Countdown litúrgico              │
│  · [calendar] Patrocinador          │
│  · Hero eventos del día             │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  FOROS · Lista de pilares           │
│  · Tarjetas de foros                │
│  · [forums_top] Banner inferior     │
└─────────────────────────────────────┘
         │
         ▼ Entrar a un foro
┌─────────────────────────────────────┐
│  FOROS · Temas                      │
│  · Destacados                       │
│  · [forums_middle] Evento patroc.   │
│  · Temas de la comunidad            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  HERMANDADES (temporada SS)         │
│  · [hermandades] Evento patroc.     │
│  · Temas por día de procesión       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  BUSCAR                             │
│  · [search] Colaborador destacado   │
│  · Tendencias / recientes           │
└─────────────────────────────────────┘
```

---

## Proceso de contratación

1. **Contacto** — interés en paquete o placement concreto.
2. **Brief** — categoría, fechas, objetivo (marca vs. evento), exclusividad.
3. **Creatividades** — envío de materiales según requisitos.
4. **Revisión editorial** — aprobación por la Junta / equipo Cofradeo.
5. **Alta en panel** — placement, fechas `start_date` / `end_date`, `max_impressions`.
6. **Informe** — impresiones y clics al cierre del periodo.

---

## Contacto comercial

*(Completar con email, teléfono y persona de contacto de la Comunidad Cofradiero / Cofradeo.)*

| | |
|---|---|
| **Email** | patrocinios@cofradeo.es *(ejemplo)* |
| **Web** | https://cofradeo.es *(ejemplo)* |
| **App** | Cofradeo — iOS y Android |

---

## Anexo · Claves técnicas (admin / desarrollo)

| Placement (BD) | Valor `placement` | Pantalla en app |
|----------------|-------------------|-----------------|
| Foros banner | `forums_top` | `ForumsShellAdBar` |
| Foro temas | `forums_middle` | `ForumTopicsScreen` |
| Hermandades | `hermandades` | `ForumTopicsScreen` (foro hermandades) |
| Calendario | `calendar` | `CalendarScreen` |
| Buscar | `search` | `SearchScreen` |

Tablas: `ads`, `ad_impressions`, `ad_clicks` · Bucket: `ad-assets`  
RPC: `get_ad_for_placement(p_placement)`

Ver también: [`ADMIN.md`](ADMIN.md) · `supabase/ads.sql`

---

*Documento v1.3 — Agosto 2026 · Cofradeo · Colaborador (129 € / 297 € trimestre) + extras foro y evento*
