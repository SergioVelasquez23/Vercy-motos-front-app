# PRD — Dashboard

> Basado en `lib/screens/dashboard_screen_v2.dart`, `lib/services/reportes_service.dart`,
> `lib/models/dashboard_data.dart`. Documenta el estado actual + huecos pendientes.

---

## 0. Metadatos

| Campo | Valor |
|---|---|
| **Feature** | Dashboard (panel principal admin) |
| **Slug** | `dashboard` |
| **Autor(es)** | _pendiente_ |
| **Estado** | En desarrollo (pantalla en producción, con deuda técnica) |
| **Fecha creación** | 2026-09-09 |
| **Última actualización** | 2026-09-09 |
| **Épica / Issue** | _pendiente_ |
| **Rama** | `main` |
| **Ruta app** | `/dashboard` (`DashboardScreenV2`) |

---

## 1. Resumen ejecutivo

El Dashboard es la pantalla de aterrizaje para administradores y superadministradores.
Consolida en una sola vista los KPIs del negocio (facturado por período vs. objetivo,
ventas por día/mes, ingresos vs. egresos, top productos, top clientes, vendedores del
mes, inventario en alerta) para que el dueño evalúe el estado del negocio sin entrar a
cada módulo. Se refresca solo cada 15 minutos y ante eventos de pedidos.

---

## 2. Problema y contexto

- **Problema:** el administrador necesita una lectura rápida y confiable de "cómo va el
  negocio hoy / esta semana / este mes / este año" y detectar problemas (stock bajo,
  facturas pendientes de pago, caída de ventas) sin navegar módulo por módulo.
- **Evidencia:** la pantalla ya existe y es el destino por defecto tras login; la lógica
  de "totales corregidos" (`_calcularTotalesCorregidos`, `facturasReconstruidasManual`)
  evidencia que hubo descuadres reportados entre el Dashboard y el Excel de "Lista
  documentos".
- **Estado actual:** implementado con `fl_chart`; múltiples endpoints de reportes; parches
  de corrección de totales en cliente.
- **Impacto de no hacerlo:** decisiones de compra/precio/personal a ciegas; pérdida de
  confianza en las cifras del sistema.

---

## 3. Objetivos y métricas de éxito

### Objetivos
1. Mostrar KPIs del negocio con datos que cuadren con "Lista documentos" y con Caja.
2. Tiempo de carga inicial percibido < 3 s en conexión normal.
3. Cero cálculos de negocio en el cliente: el backend es la única fuente de verdad.

### Métricas / criterios de éxito
| Métrica | Valor actual | Meta | Cómo se mide |
|---|---|---|---|
| Diferencia Dashboard vs. Lista documentos | > $0 (se parchea en cliente) | $0 sin parche | Comparar "Facturado" del período contra suma de Lista documentos |
| Tiempo a primer contenido | _pendiente medir_ | < 3 s | Perf trace / logs |
| Nº de endpoints por carga | 11 llamadas en paralelo | ≤ 5 (endpoint agregador) | Revisión de red |
| Errores silenciosos por carga | varios `catchError` que devuelven `[]` | 0 sin feedback al usuario | QA |

### No-objetivos
- Edición de datos del negocio desde el Dashboard (salvo objetivos de venta).
- Dashboard para roles no-admin (asesor se redirige a `/asesor-pedidos`).
- Exportación de reportes (vive en `/reportes` y `/exportar-mensual`).

---

## 4. Usuarios y casos de uso

- **Perfiles afectados:** `admin`, `superadmin` (contenido completo). `asesor` se redirige.
  Otros roles ven "Acceso Restringido".
- **Caso de uso principal:**
  1. El admin inicia sesión y llega a `/dashboard`.
  2. Ve las 4 tarjetas de facturado (hoy / 7 días / 30 días / año) con % de objetivo.
  3. Revisa gráficos de ventas por día y por mes.
  4. Detecta stock bajo / clientes top / vendedores top.
  5. Opcional: edita el objetivo de un período (diálogo → `PUT /reportes/objetivo`).
- **Casos borde:**
  - Cambio de día / semana mientras la pantalla está abierta (timers a 5 min que fuerzan refresh).
  - App vuelve del segundo plano (hoy NO refresca, decisión explícita).
  - Backend de un KPI caído → ese widget muestra estado vacío, el resto sigue.

---

## 5. Requisitos funcionales

| ID | Prioridad | Requisito | Notas |
|---|---|---|---|
| RF-1 | Must | Mostrar facturado por período (hoy/7d/30d/año) con objetivo y % | `GET /api/reportes/dashboard?ignorarCaja=true&soloElectronicos=true` |
| RF-2 | Must | Gráfico de ventas por día (últimos 7) | `GET /ventas-por-dia?ultimosDias=7` |
| RF-3 | Must | Gráfico de facturado por mes (últimos 6–12) | `GET /ventas-por-mes?ultimosMeses=N` |
| RF-4 | Must | Ingresos vs. egresos (12 meses) | `GET /reportes/ingresos-egresos?ultimosMeses=12` |
| RF-5 | Should | Top 5 productos del mes | `GET /reportes/top-productos?limite=5` |
| RF-6 | Should | Top 5 clientes del mes (excluye Consumidor Final) | `GET /api/reportes/top-clientes?limite=5&excluirConsumidorFinal=true` |
| RF-7 | Should | Vendedores del mes | `GET /vendedores-mes?dias=30` |
| RF-8 | Should | Pedidos por hora | `GET /reportes/pedidos-por-hora` |
| RF-9 | Should | Top vendidos con stock bajo (reabastecimiento) | `GET /api/top-vendidos-bajo-stock?dias=7&limite=10` |
| RF-10 | Should | Editar objetivo de ventas por período | `PUT /reportes/objetivo` `{periodo, objetivo}` |
| RF-11 | Must | Auto-refresh cada 15 min + refresh ante `onPedidoCompletado` / `onPedidoPagado` | Timers en `initState` |
| RF-12 | Must | Pull-to-refresh manual | `RefreshIndicator` |
| RF-13 | Must | Restringir acceso por rol | admin/superadmin ven todo; asesor redirige; resto "Acceso Restringido" |
| RF-14 | Could | Detección de cambio de día/semana para forzar refresh | Timers a 5 min |

---

## 6. Requisitos no funcionales

- **Rendimiento:** carga de 11 futures en paralelo con `Future.wait`; cada KPI falla de
  forma aislada. Objetivo: reducir a un endpoint agregador.
- **Consistencia de datos:** el "Facturado" debe cuadrar con Lista documentos y con Caja.
  Hoy se suma en cliente `facturasReconstruidasManual` (facturas aceptadas por DIAN sin
  Pedido) — **deuda a resolver en backend**. Ver [[lista-documentos-paginacion-servidor]].
- **Offline / conectividad:** sin caja de datos offline; si falla la red, spinner y luego
  widgets vacíos. Falta un estado de error global claro.
- **Seguridad y permisos:** solo admin/superadmin. La verificación es en cliente
  (`userProvider.isAdmin`) + `ignorarCaja=true` para no filtrar por cuadre.
- **Observabilidad:** hoy `print`/`debugPrint`. Falta telemetría de tiempos de carga y de
  fallos por KPI.
- **Accesibilidad / UX:** estados de carga por widget; estados vacíos con icono + texto.
  Falta manejo consistente de error (algunos `catchError` son silenciosos).

---

## 7. Diseño de la solución

### 7.1 Flujo de usuario
Login → `/dashboard` → `initState` verifica rol → si admin: `_cargarDatos()` +
`_precargarDatos()` + suscripción a streams de pedidos + timers. Render: scroll vertical
con tarjetas y gráficos. Editar objetivo: tap en tarjeta → diálogo → guardar → recarga.

### 7.2 UI / componentes
- **Tarjetas de estadística:** `_buildStatCard` (título, valor, objetivo, % , color).
- **Gráficos:** `fl_chart` — barras (ventas/día, ventas/mes, ingresos-egresos), pastel
  (top productos, top clientes).
- **Secciones:** `widgets/dashboard/stats_cards_section.dart`, `stat_card.dart`,
  `legend_item.dart`.
- **Estados:** cargando (spinner central + spinner por widget), vacío (`_buildEmptyChartState`),
  error (parcial / inconsistente — mejorar).

### 7.3 Frontend (Flutter)
- **Pantalla:** `lib/screens/dashboard_screen_v2.dart` (~3400 líneas — **god file, candidato a
  refactor**, ver skill `frontend-cleanup`).
- **Estado:** `StatefulWidget` con ~20 campos de estado + `WidgetsBindingObserver`.
- **Servicios:** `ReportesService` (singleton), `PedidoService` (streams).
- **Modelos:** `DashboardData` (`ventasSemana`, `ventasMes`, `ventasAño`, `ventasHoy`,
  `facturacion`, `inventario`, `pedidosHoy`), `VentasPeriodo`, `VentasHoy`.

### 7.4 Backend / API
| Endpoint | Método | Notas | Estado |
|---|---|---|---|
| `/api/reportes/dashboard` | GET | `ignorarCaja`, `soloElectronicos`, `_t` anti-cache | Existe |
| `/ventas-por-dia` | GET | `ultimosDias` | Existe |
| `/ventas-por-mes` | GET | `ultimosMeses` | Existe |
| `/reportes/ingresos-egresos` | GET | `ultimosMeses` | Existe |
| `/reportes/top-productos` | GET | `limite` | Existe |
| `/api/reportes/top-clientes` | GET | `limite`, `excluirConsumidorFinal` | Existe |
| `/vendedores-mes` | GET | `dias` | Existe |
| `/reportes/pedidos-por-hora` | GET | `fecha?` | Existe |
| `/api/top-vendidos-bajo-stock` | GET | `dias`, `limite` | Existe |
| `/reportes/objetivo` | PUT | `{periodo, objetivo}` — con fallback a guardado local | Parcial (fallback local) |
| **`/api/reportes/dashboard-completo`** | GET | **Propuesto:** un solo endpoint que devuelva todos los KPIs ya calculados y cuadrados | Por crear |

- **Cambios de contrato pendientes:**
  - El backend debe incluir las "facturas reconstruidas" en los totales de venta para
    eliminar `_calcularTotalesCorregidos` y `facturasReconstruidasManual` del cliente.
  - Persistir de verdad `PUT /reportes/objetivo` (hoy cae a guardado local si falla).
- **Inconsistencia de rutas:** conviven prefijos `/api/reportes/...` y `/reportes/...` y
  `/ventas-por-dia` sin prefijo — normalizar.

### 7.5 Caché e invalidación
- HTTP: se añade `_t=timestamp` en `forceRefresh` para evitar caché.
- `ReportesService` es singleton pero **no cachea** en memoria (cada llamada va a red).
- El Dashboard reacciona a `PedidoService.onPedidoCompletado` / `onPedidoPagado`.
- Relación con [[documentos-cache-invalidacion]]: al emitir/cobrar debería refrescar KPIs.

---

## 8. Dependencias y riesgos

| Tipo | Descripción | Mitigación |
|---|---|---|
| Dependencia | Backend debe unificar el cálculo de ventas (incluir facturas sin pedido) | Endpoint agregador + tests de cuadre |
| Riesgo | God file de 3400 líneas dificulta el mantenimiento | Refactor por secciones a `widgets/dashboard/` |
| Riesgo | 11 llamadas paralelas en cada refresh (cada 15 min + eventos) | Endpoint agregador; backoff |
| Riesgo | Errores silenciosos ocultan datos faltantes al usuario | Estado de error por widget + banner global |
| Supuesto | `soloElectronicos=true` = criterio correcto de "facturado" | Confirmar con negocio |

---

## 9. Plan de entrega

### Fases
- [ ] **Fase 1 — Cuadre de datos:** backend incluye facturas reconstruidas; eliminar
  parche del cliente; test de cuadre Dashboard = Lista documentos.
- [ ] **Fase 2 — Endpoint agregador:** `dashboard-completo`; reducir llamadas.
- [ ] **Fase 3 — Refactor UI:** partir el god file; estados de error consistentes.
- [ ] **Fase 4 — Objetivos:** persistencia real en backend.

### Feature flag / rollout
No aplica flag; cambios incrementales sobre la pantalla existente. Reversible por commit.

---

## 10. Pruebas y criterios de aceptación

### Criterios de aceptación (Given / When / Then)
1. **Dado** que existe una factura aceptada por DIAN sin pedido asociado en el rango de
   "hoy", **cuando** el admin abre el Dashboard, **entonces** "Facturado Hoy" la incluye
   sin necesidad del parche de cliente.
2. **Dado** un usuario con rol `asesor`, **cuando** entra a `/dashboard`, **entonces** es
   redirigido a `/asesor-pedidos` sin ver pantalla en blanco.
3. **Dado** que el endpoint de top-productos falla, **cuando** carga el Dashboard,
   **entonces** el resto de KPIs se muestran y el widget de productos muestra estado vacío
   (no un crash ni un spinner infinito).
4. **Dado** un objetivo editado a $X, **cuando** el admin recarga la app días después,
   **entonces** el objetivo sigue siendo $X (persistido en backend).
5. **Dado** que pasa la medianoche con la pantalla abierta, **cuando** transcurren ≤ 5 min,
   **entonces** los KPIs se recalculan para el nuevo día.

### Cobertura de pruebas
- **Unitarias:** `DashboardData.fromJson` con payloads parciales/nulos; mapeo de
  `_ventasPorDia` / `_ventasPorMes`.
- **Widget:** render con `_dashboardData == null`, con datos, con rol no-admin.
- **Manual / QA:** cuadre contra Lista documentos y contra Cierre de caja del día.

---

## 11. Impacto en documentación

- Actualizar `docs/analisis_arquitectura_frontend.md` tras el refactor.
- Nota de memoria: [[lista-documentos-paginacion-servidor]], [[documentos-cache-invalidacion]].

---

## 12. Preguntas abiertas

- [ ] ¿"Facturado" debe ser solo POS+FE o también incluir ventas LOCAL?
- [ ] ¿Los objetivos son por negocio o por sede/caja?
- [ ] ¿Se necesita rango de fechas personalizado en el Dashboard o basta con reportes?
- [ ] ¿Qué política de caché en memoria es aceptable (TTL) para no golpear al backend?

---

## 13. Registro de cambios del PRD

| Fecha | Autor | Cambio |
|---|---|---|
| 2026-09-09 | Claude | Creación a partir del código existente |
