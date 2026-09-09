# Informe — Por qué algunas pantallas tardan en responder

**Fecha:** 2026-09-09
**Alcance:** `lib/` (`Vercy-motos-front-app`, Flutter web + móvil).
**Método:** lectura de servicios, providers y pantallas grandes. Cada causa lleva la evidencia en el código.

---

## Resumen en una frase

La lentitud no viene de una sola cosa: viene de **pantallas que descargan listas completas sin paginar**, **parseo de JSON en el hilo de UI**, **cero caché entre pantallas** y **timeouts de hasta 5 minutos** que convierten un fallo de red en una pantalla congelada. Casi todo tiene arreglo incremental sin reescribir la app.

---

## 🔴 Causas de alto impacto

### 1. Pantallas que traen "todo" sin paginación real

| Dónde | Evidencia | Efecto |
|---|---|---|
| Productos | `producto_service.dart:698` y `:735` → `GET /api/productos?page=0&size=10000` | Una sola respuesta con **todos** los productos y sus campos. Descarga + decode + parse de miles de objetos antes de pintar nada. |
| Pedidos | `pedido_service.dart:491` — *"El backend no soporta filtro por días; trae todos y filtra client-side"* (`getPedidosUltimosDias`, `getAllPedidos`) | Se baja el histórico entero y se filtra en el teléfono/navegador. |
| Pedidos de hoy | `getPedidosHoy()` (`:539-575`): si el endpoint de fecha falla, cae a `getAllPedidos()` + filtro en cliente | Un 500 puntual del endpoint bueno = de golpe se descarga todo. |
| Lista documentos | El front ya manda `page`/`size`, pero si el backend los ignora `esPaginado=false` y se pagina en cliente sobre la lista completa (`documentos_cache.dart:56`, memoria `lista-documentos-paginacion-servidor`) | La pantalla "rápida" sigue bajando todo mientras el backend no cumpla. |

**Solución**
- Paginación **de servidor real** en productos y pedidos (page/size + `totalElements`), y que el front pida solo la página visible (patrón que ya existe en `DocumentosCache`).
- Endpoint "ligero" de verdad para las listas: solo los campos que la fila muestra (id, nombre, precio, stock). El detalle completo se pide al abrir el item.
- Filtros (fecha, estado, tipo) **en el query**, no en `.where()` de Dart.
- Mientras el backend se pone al día: bajar `size=10000` a un tope razonable (p. ej. 200) y cargar el resto en segundo plano/scroll.

---

### 2. El JSON se parsea en el hilo principal (no hay isolates)

**Evidencia:** cero usos de `compute()` / `Isolate` en todo `lib/`. `_parseListResponse` (`pedido_service.dart:279`), `_parseListResponseLigero`, `Producto.fromJson` en bucle, etc. corren en el main isolate.

**Efecto:** con listas grandes, `json.decode` + `List.map(fromJson)` bloquea el frame. La pantalla queda "pegada" aunque la red ya haya respondido — se percibe como "la app se colgó".

**Solución**
- Mover el `json.decode` + mapeo de listas grandes a `compute()` / `Isolate.run()` (productos, pedidos, documentos, libro contable).
- Alternativa más barata: parsear en lotes con `await Future.delayed(Duration.zero)` entre lotes para ceder el frame.
- Reducir el tamaño del payload (punto 1) hace que esto importe mucho menos.

---

### 3. Dashboard: cadena secuencial + sin caché + cache-busting

**Evidencia — `reportes_service.dart:16-74` (`getDashboard`)**
1. `await _apiService.get(...dashboard...)`
2. **luego, en serie:** `await _pedidoService.getPedidosHoy()` — que puede degradar a "traer todos los pedidos" (punto 1).
   El camino crítico son **dos llamadas encadenadas**, la segunda pesada, para pintar la primera tarjeta.
3. `forceRefresh` añade `?_t=timestamp` (`:19-25`) → rompe la caché HTTP del navegador y de cualquier proxy.

**Evidencia — `dashboard_screen_v2.dart:217-293`:** `_cargarDatos()` lanza ~8 endpoints (`getDashboard`, `getIngresosVsEgresos`, `getTopProductos`, `getTopClientes`, `getPedidosPorHora`, `getVendedoresDelMes`, `getTopVendidosBajoStock`…). `ReportesService` **no cachea nada**: cada entrada al dashboard vuelve a pedir los 8.

**Solución**
- Quitar el `await getPedidosHoy()` del camino crítico de `getDashboard` — que el backend devuelva `ventasHoy`/`pedidosPagadosHoy` ya calculados en el mismo payload del dashboard, o cargar ese dato en paralelo y no bloquear el render.
- Caché en memoria en `ReportesService` con TTL corto (30-60 s) + `notifyListeners`, para que volver al dashboard sea instantáneo y el refresh sea en segundo plano.
- Quitar `?_t=timestamp`; controlar frescura con TTL en cliente y/o `Cache-Control` del backend.
- Idealmente un único `GET /api/reportes/dashboard-completo` que traiga todo lo de la pantalla en una respuesta.

---

### 4. Timeouts de 60–300 s que alargan cada fallo

**Evidencia:** `producto_service.dart` tiene **25** timeouts de 60 s o más. Ejemplos:
- `getCategorias` → `.timeout(Duration(seconds: 300))` con comentario *"Timeout aumentado para Render"* (`:800`).
- `_getProductosConNombresIngredientes` → `.timeout(300s)` (`:773`).
- `_retryStrategy` con timeouts crecientes y **fallback a otro endpoint que repite la misma cascada** — el propio comentario en `datos_cache_provider.dart:293-302` dice que reintentar *"puede duplicar el tiempo de espera (~2 min)"*.

**Efecto:** cuando el backend está lento o caído, la pantalla no muestra error ni fallback: se queda cargando **hasta 5 minutos**.

**Solución**
- Timeouts realistas: 8–12 s por request, 20–30 s para exportaciones/PDF. El backend en Hetzner (`constants.dart:3`) ya no tiene cold starts de Render.
- Un solo reintento con backoff, y que el fallback **no** repita toda la cascada.
- Mostrar el contenido cacheado (aunque esté vencido) + un banner "actualizando…" en vez de bloquear.

---

## 🟠 Causas estructurales

### 5. No hay caché consistente entre pantallas

**Evidencia:** solo `DatosCacheProvider` (productos/categorías) y `DocumentosCache` cachean. Clientes, gastos, cartera, cuentas por cobrar/pagar, cuadre de caja, libro contable, facturas de compra hacen `_cargarX()` directo en `initState` (p. ej. `facturas_list_screen.dart:92-100`, `cerrar_caja_screen.dart:77-79`).

**Efecto:** salir de una pantalla y volver 5 segundos después = descarga completa otra vez. La navegación se siente lenta en todas partes.

**Solución**
- Un patrón único de "repositorio con caché + TTL + invalidación" reutilizable (generalizar lo que ya hace `DocumentosCache`).
- Pantallas de lista: mostrar caché al instante en `initState`, refrescar en segundo plano, invalidar al crear/editar/borrar.
- `AutomaticKeepAliveClientMixin` o mantener el estado en un provider para las pantallas a las que se vuelve mucho.

### 6. Pantallas gigantes → cada `setState` reconstruye todo

**Evidencia:** `facturacion_screen.dart` ~230 KB (~6K líneas), `productos_screen.dart` ~190 KB, `crear_factura_compra_screen.dart` ~120 KB, `cuadre_caja_screen.dart` ~113 KB. Un `State` único con `setState` masivo (ver auditoría previa, `AUDITORIA_FRONTEND.md` §5).

**Efecto:** un `setState` por teclear en un campo reconstruye toda la pantalla; con árboles de widgets enormes y sin `const`, eso son frames perdidos.

**Solución**
- Extraer sub-árboles a widgets `const` / `StatelessWidget` con su propio `ValueListenableBuilder` o `Selector` (provider), para acotar los rebuilds.
- Listas siempre con `ListView.builder` / `SliverList` (no `Column` dentro de `SingleChildScrollView` para N items).
- Es el mismo trabajo que ya recomienda la auditoría (Rama 4 `refactor/pantallas-grandes`); aquí el beneficio es de rendimiento percibido, no solo de mantenibilidad.

### 7. El token se lee de almacenamiento seguro en cada request

**Evidencia:** `base_api_service.dart:72` `getHeaders()` → `getToken()` (`:36`) hace `_storage.read` (canal de plataforma) o `localStorage` en **cada** llamada. Además hay 5 implementaciones duplicadas de esto (`AUDITORIA_FRONTEND.md` §3).

**Efecto:** una pantalla con 8–10 llamadas hace 8–10 lecturas de canal nativo antes de siquiera abrir el socket. En móvil son milisegundos, pero se acumulan y se serializan.

**Solución**
- Cachear el token en memoria tras el login; releer de disco solo si falta o tras un 401.
- Unificar en un solo `TokenStorage` (ya está en el plan de la auditoría, Rama 2).

### 8. Servicios "anti-Render" que ya no aplican y meten ruido

**Evidencia:** `http_502_hard_reset.dart`, `keep_alive_service.dart`, `network_discovery_service.dart`. Eran para el free tier de Render (cold starts / 502). El backend ahora está en Hetzner (`constants.dart:3`).

**Efecto:** `keep_alive_service` hace pings periódicos que ya no hacen falta; `Http502Tracker` puede **recargar la app entera** (`html.window.location.reload()`) si 8 endpoints distintos dan 502, tirando toda la caché en memoria.

**Solución**
- Revisar si `keep_alive` sigue aportando; si no, quitarlo.
- Subir el umbral del hard-reset o cambiarlo por un aviso no destructivo.

### 9. Cache-busting en imágenes (latente, hoy desactivado)

**Evidencia:** `imagen_producto_widget.dart:30` — la carga de imágenes está **desactivada** (siempre ícono). Pero el código dormido (`_buildImagenNetwork:128`) añade `&_t=${DateTime.now().microsecondsSinceEpoch}` + headers `no-cache` a cada imagen, y no pasa `cacheWidth`/`cacheHeight`.

**Efecto (si se reactiva):** cada imagen se re-descarga siempre, nunca cachea, y se decodifica a resolución completa para pintarla en 50×50.

**Solución**
- Al reactivar: URL estable (sin `_t`), dejar que el navegador/`ImageCache` haga su trabajo, `cacheWidth`/`cacheHeight` = tamaño de pintado, y `cached_network_image` o similar para disco.

---

## Plan sugerido (orden de impacto / esfuerzo)

### Quick wins (días, sin tocar arquitectura)
1. **Bajar timeouts** a 8–12 s en `producto_service` y donde haya 60–300 s (punto 4).
2. **Quitar `?_t=timestamp`** del dashboard y **sacar `getPedidosHoy()` del camino crítico** de `getDashboard` (punto 3).
3. **Caché en memoria en `ReportesService`** con TTL 30–60 s (punto 3/5).
4. **Bajar `size=10000`** a un tope (200) + carga incremental (punto 1).
5. Revisar/retirar `keep_alive_service` y suavizar el hard-reset de 502 (punto 8).

### Impacto medio (1–2 semanas)
6. **Paginación de servidor** en productos y pedidos + endpoint ligero con campos mínimos (punto 1).
7. **Parseo de listas grandes en isolate** (`compute`) o en lotes (punto 2).
8. **Repositorio con caché + TTL reutilizable** y aplicarlo a clientes, gastos, cartera, cuentas (punto 5).
9. **Cachear el token en memoria** (punto 7).

### Estructural (continuo)
10. Trocear `facturacion_screen`, `productos_screen`, `cuadre_caja_screen`: acotar rebuilds con `Selector`/`ValueListenableBuilder`, listas con `builder` (punto 6). Coincide con la Rama 4 de la auditoría.

---

## Notas

- Muchas de estas causas son **front + backend a la vez**: la paginación real y el `dashboard-completo` necesitan cambios de API. Conviene coordinarlo con el mismo criterio que la auditoría (`AUDITORIA_FRONTEND.md`).
- El `http.Client` **sí** se reutiliza en toda la app (`main.dart:27`, `http.runWithClient`), así que la reutilización de conexión/keep-alive TLS no es un problema aquí.
