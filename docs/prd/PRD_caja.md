# PRD — Caja (apertura, cierre y cuadre)

> Basado en `lib/screens/{abrir_caja,cerrar_caja,cuadre_caja,contador_efectivo,ingresos_caja}_screen.dart`,
> `lib/services/cuadre_caja_service.dart`, `lib/models/cuadre_caja.dart`,
> `lib/services/resumen_cierre_completo_service.dart`, `lib/services/backup_inventario_service.dart`.

---

## 0. Metadatos

| Campo | Valor |
|---|---|
| **Feature** | Caja: apertura, cierre y cuadre |
| **Slug** | `caja` |
| **Autor(es)** | _pendiente_ |
| **Estado** | En desarrollo (en producción, con lógica de fallback compleja) |
| **Fecha creación** | 2026-09-09 |
| **Última actualización** | 2026-09-09 |
| **Épica / Issue** | _pendiente_ |
| **Rama** | `main` |
| **Rutas app** | `/cuadre_caja`, `/abrir_caja`, `/cerrar_caja`, `/ingresos-caja`, contador de efectivo (push) |

---

## 1. Resumen ejecutivo

El módulo de Caja controla el ciclo diario de dinero del negocio: **abrir** una caja con un
fondo inicial, operar durante el día (las ventas pagadas se asocian a la caja abierta de su
tipo), y **cerrar** declarando el efectivo real contra el efectivo esperado, detectando
descuadre. Existen dos cajas simultáneas por tipo: **LOCAL** y **ENVIOS**. Al cerrar se
genera además una **conciliación de inventario** (Excel) comparando stock esperado vs. real.
`/cuadre_caja` es la pantalla índice: lista histórico, filtros y accesos a abrir/cerrar.

---

## 2. Problema y contexto

- **Problema:** el dueño necesita saber cada día cuánto efectivo debería haber en caja,
  cuánto hay realmente, y por qué difiere; y que las ventas/gastos/compras queden atadas a
  un período de caja para poder auditarlas.
- **Evidencia:** `CuadreCajaService` tiene múltiples endpoints de reporte y **cascadas de
  fallback** (`_calcularEfectivoManual`, varios `try/catch` anidados en
  `cerrar_caja_screen.dart`) → señal de que el backend no siempre entrega el dato y el
  cliente improvisa. Comentarios sobre doble-tap y `SubmitGuard` en abrir/cerrar.
- **Estado actual:** funcional; soporta 2 cajas simultáneas (LOCAL/ENVIOS); cierre dispara
  limpieza de caché de pedidos/mesas en backend (`cerrarCaja: true`) + backup de inventario.
- **Impacto de no hacerlo:** robo/errores no detectados, reportes de "facturado" que no
  cuadran, inventario a la deriva.

---

## 3. Objetivos y métricas de éxito

### Objetivos
1. El "efectivo esperado" al cerrar viene siempre del backend (una sola fórmula), sin
   recálculo en cliente.
2. Cierre de caja en < 60 s incluyendo declaración de efectivo y descarga de conciliación.
3. Imposible abrir dos cajas del mismo tipo, o cerrar dos veces la misma caja.

### Métricas / criterios de éxito
| Métrica | Valor actual | Meta | Cómo se mide |
|---|---|---|---|
| Cierres que usan fallback de cálculo en cliente | frecuente (`_calcularEfectivoManual`) | 0 | Logs / telemetría |
| Descuadre promedio absoluto por cierre | _pendiente medir_ | ↓ tendencia | Historial de cuadres |
| Cierres con conciliación de inventario descargada | _pendiente_ | 100 % | Backend backup |
| Incidencias de "doble caja" / "doble cierre" | _pendiente_ | 0 | Soporte |

### No-objetivos
- Gestión de gastos y compras (módulos aparte, aunque impactan el efectivo esperado).
- Aprobación/rechazo de cuadres por un supervisor (existe en servicio, UI fuera de alcance
  de esta iteración — confirmar).
- Arqueo por denominaciones como fuente de verdad (el contador de efectivo es auxiliar).

---

## 4. Usuarios y casos de uso

- **Perfiles afectados:** `admin` (la pantalla `/cuadre_caja` exige `isAdmin`). Cajeros se
  registran como lista dentro del cuadre pero el acceso es admin. Confirmar si cajero debe
  poder abrir/cerrar.
- **Caso de uso — abrir:**
  1. `/abrir_caja` → elegir tipo (LOCAL/ENVIOS) → ingresar monto inicial + ID máquina + obs.
  2. `createCuadre` → si ya hay una caja abierta de ese tipo, error explícito.
- **Caso de uso — operar:** las ventas pagadas (Facturación) se asocian a la caja abierta de
  su tipo; los ingresos de caja se registran en `/ingresos-caja`.
- **Caso de uso — cerrar:**
  1. `/cerrar_caja` → seleccionar cuál caja (si hay LOCAL y ENVIOS abiertas).
  2. Ver resumen (movimientos de efectivo, ventas, gastos, compras).
  3. Diálogo "Declarar efectivo en caja" → mostrar descuadre si lo hay.
  4. Confirmar → `updateCuadre(cerrarCaja: true, estado: 'cerrada')` → backend limpia caché
     de pedidos/mesas + genera backup de inventario.
  5. Descarga automática del Excel de conciliación; si hay discrepancias, diálogo de alerta.
- **Caso de uso — cuadre/histórico:** `/cuadre_caja` lista cuadres con filtros (fecha, tipo,
  responsable, estado), muestra cajas abiertas ahora, y permite ver el resumen detallado
  (`ResumenCierreDetalladoScreen`).
- **Casos borde:**
  - Backend no envía `efectivoEsperado` → cascada de fallbacks.
  - Se cambia de caja (LOCAL↔ENVIOS) en la pantalla de cierre → deben limpiarse los valores
    de la caja anterior (ya se maneja en `_cargarEfectivoEsperado`).
  - "La caja ya está cerrada" → refrescar estado.
  - Backup de inventario aún no listo en backend → reintento tras 2 s.

---

## 5. Requisitos funcionales

| ID | Prioridad | Requisito | Notas |
|---|---|---|---|
| RF-1 | Must | Abrir caja por tipo (LOCAL / ENVIOS) con fondo inicial | `POST /api/cuadres-caja` (`efectivoInicial`, `tipoCaja`, `responsable`, `tolerancia`) |
| RF-2 | Must | Impedir 2 cajas abiertas del mismo tipo | Error "Ya existe una caja …" → refrescar estado |
| RF-3 | Must | Listar cuadres con filtros (fecha, tipo, responsable, estado) + paginación | `GET /api/cuadres-caja`; filtros en cliente; `PaginacionMixin` (20/pág) |
| RF-4 | Must | Mostrar cajas abiertas ahora mismo con acceso a su resumen | `GET /api/cuadres-caja/abiertas` (fallback: filtrar `getAllCuadres`) |
| RF-5 | Must | Cargar resumen de cierre: efectivo esperado, ventas, gastos, compras, domicilios | `GET /api/cuadres-caja/reportes/cuadre-completo?tipoCaja=` + `resumen-cierre` |
| RF-6 | Must | Efectivo esperado = ventas efectivo + fondo inicial, calculado por el **backend** | hoy con fallback `_calcularEfectivoManual` — **eliminar fallback** |
| RF-7 | Must | Declarar efectivo real y calcular descuadre (falta/sobra) | diálogo con tolerancia mínima 0.01 |
| RF-8 | Must | Cerrar caja: `updateCuadre(cerrarCaja: true)` en una sola transacción | backend limpia caché pedidos/mesas + historial |
| RF-9 | Must | Generar y descargar Excel de conciliación de inventario al cerrar | `BackupInventarioService.descargarExcelConciliacion` |
| RF-10 | Should | Alertar discrepancias de inventario (faltantes/sobrantes) tras el cierre | `getConciliacion` + `contarDiscrepancias` |
| RF-11 | Should | Contador de efectivo por denominaciones como auxiliar de llenado | `ContadorEfectivoScreen`, callback a los campos |
| RF-12 | Should | Registrar ingresos de caja | `/ingresos-caja` (`IngresoCajaService`) |
| RF-13 | Could | Editar/actualizar un cuadre existente sin cerrarlo | `updateCuadre` estado `pendiente` |
| RF-14 | Must | Guard anti doble-tap en "Abrir caja" y "Cerrar caja" | `SubmitGuard.runGuarded` |
| RF-15 | Could | Aprobar / rechazar cuadre | endpoints existen (`/operaciones/{id}/aprobar|rechazar`); UI _pendiente_ |

---

## 6. Requisitos no funcionales

- **Consistencia:** una sola definición de "efectivo esperado" y de "ventas por método de
  pago", compartida con el Dashboard y con Facturación. Las ventas se asocian a la caja del
  **tipo** correcto (LOCAL/ENVIOS), no "la primera abierta".
- **Resiliencia:** el cierre no debe quedar a medias; si falla la descarga del Excel, la
  caja igual queda cerrada y se puede reintentar la conciliación.
- **Idempotencia:** abrir/cerrar protegidos con `SubmitGuard`; el backend rechaza segundo
  cierre ("La caja ya está cerrada").
- **Rendimiento:** `getCajasAbiertas` con timeout 60 s (alto — revisar); listado paginado.
- **Seguridad:** acceso admin; `_loadUsuariosDisponibles` usa `GET /api/users` con fallback
  a lista fija — **falta enviar token** (TODO en `_getHeaders` de la pantalla).
- **Observabilidad:** hay `appLog` extenso del cálculo de efectivo esperado — conservar como
  telemetría estructurada, quitar ruido.
- **UX:** siempre visible qué caja se está cerrando (LOCAL/ENVIOS); estados de carga, error
  y "no hay caja abierta" bien diferenciados.

---

## 7. Diseño de la solución

### 7.1 Flujo de usuario
`/cuadre_caja` (índice: histórico + cajas abiertas + filtros) → botón "Abrir Caja"
(`/abrir_caja`) o "Cerrar Caja" (`/cerrar_caja`). Cierre: cargar resumen → declarar efectivo
→ confirmar → limpieza backend + Excel conciliación + alerta discrepancias → volver.

### 7.2 UI / componentes
- `widgets/caja/`: `caja_ya_abierta_widget.dart`, `formulario_abrir_caja_widget.dart`,
  `caja_ui_helpers.dart`.
- `cerrar_caja_screen.dart`: secciones de resumen (`_buildMovimientosEfectivoSection`,
  `_buildResumenVentasSection`, `_buildResumenGastosSection`, `_buildResumenComprasSection`).
- `cuadre_caja_screen.dart`: tarjetas de cajas abiertas, filtros, tabla paginada,
  formulario de cuadre (medios de pago + contador).
- `ResumenCierreDetalladoScreen`, `ContadorEfectivoScreen`.

### 7.3 Frontend (Flutter)
- **Pantallas:** `abrir_caja_screen.dart` (~340 líneas, OK), `cerrar_caja_screen.dart`
  (~2130 líneas — **god file**), `cuadre_caja_screen.dart` (~2680 líneas — **god file**).
- **Servicios:** `CuadreCajaService` (singleton, implementa `ICuadreCajaService` para poder
  inyectar fakes en test), `ResumenCierreCompletoService`, `BackupInventarioService`,
  `PedidoService`, `IngresoCajaService`.
- **Modelos:** `CuadreCaja` (`efectivoInicial`/`fondoInicial`, `efectivoEsperado`,
  `efectivoDeclarado`, `descuadre`, `tipoCaja`, `cerrada`, `estado`, totales por método),
  `ResumenCierreCompleto`.
- **Deuda:** `cuadre_caja_screen.dart` mezcla `http` directo (`_loadUsuariosDisponibles`)
  con el servicio; unificar en `CuadreCajaService` + auth.

### 7.4 Backend / API
| Endpoint | Método | Notas | Estado |
|---|---|---|---|
| `/api/cuadres-caja` | GET | lista (List o Page `content`) | Existe |
| `/api/cuadres-caja` | POST | crear (201) | Existe |
| `/api/cuadres-caja/{id}` | GET / PUT / DELETE | detalle / actualizar / eliminar | Existe |
| `/api/cuadres-caja/abiertas` | GET | cajas abiertas | Existe |
| `/api/cuadres-caja/hoy` | GET | cuadres del día | Existe |
| `/api/cuadres-caja/responsable/{r}` · `/estado/{e}` | GET | filtros server-side (hoy no usados por la UI) | Existe |
| `/api/cuadres-caja/reportes/cuadre-completo` | GET | `tipoCaja?` — efectivo esperado, ventas, gastos, contadores | Existe |
| `/api/cuadres-caja/reportes/detalles-ventas` | GET | fallback de ventas | Existe |
| `/api/cuadres-caja/reportes/efectivo-esperado` | GET | `tipoCaja?` | Existe |
| `/api/cuadres-caja/reportes/{id}/resumen-cierre` | GET | resumen por método de pago | Existe |
| `/api/cuadres-caja/reportes/todos-pedidos-hoy` · `/debug-pedidos` | GET | diagnóstico | Existe |
| `/api/cuadres-caja/operaciones/{id}/aprobar` · `/rechazar` | PUT | flujo de aprobación | Existe (sin UI) |
| `/api/pedidos/consultas/cuadre/{id}/pagados` | GET | ventas de la caja para cálculo manual | Existe |
| `/api/reportes/cuadre-caja` | GET | informe temporal sin guardar | Existe |
| Conciliación / backup de inventario (`BackupInventarioService`) | GET | Excel + JSON de discrepancias por `cajaId` | Existe |

- **Cambios de contrato pendientes:**
  - `cuadre-completo` debe **siempre** devolver `efectivoEsperado`, `ventasEfectivo`,
    `ventasTransferencias`, contadores — para poder borrar `_calcularEfectivoManual` y las
    cascadas de fallback del cliente.
  - Que la UI use `GET /estado/{e}` y `/responsable/{r}` en vez de filtrar en cliente
    (relacionado con la paginación server-side, ver [[lista-documentos-paginacion-servidor]]).

### 7.5 Caché e invalidación
- Al cerrar (`cerrarCaja: true`) el **backend** limpia caché de pedidos y mesas y registra
  el cierre — es un efecto secundario contractual, documentarlo.
- El Dashboard usa `ignorarCaja=true`; el cierre de caja **no** debe alterar el "facturado"
  histórico del Dashboard.
- `getDashboard` reacciona a eventos de pedido, no al cierre de caja → evaluar si el cierre
  debe emitir un evento para refrescar Dashboard/Lista documentos
  ([[documentos-cache-invalidacion]]).

---

## 8. Dependencias y riesgos

| Tipo | Descripción | Mitigación |
|---|---|---|
| Dependencia | `cuadre-completo` fiable del backend | Contrato firme + tests; quitar fallbacks |
| Dependencia | Servicio de backup/conciliación de inventario listo tras el cierre | Reintento; permitir descarga diferida desde el histórico |
| Riesgo | God files en cerrar/cuadre (~2000–2700 líneas) | Refactor por secciones a `widgets/caja/` |
| Riesgo | `_loadUsuariosDisponibles` sin token → 401/lista fija | Migrar a `CuadreCajaService` con headers autenticados |
| Riesgo | Dos cajas abiertas: operación asignada a la caja equivocada | Siempre resolver por `tipoCaja`, nunca "la primera" |
| Riesgo | Cierre parcial si falla a mitad | Transacción atómica en backend; estado idempotente |
| Supuesto | `tolerancia` por defecto 5.0 es la política del negocio | Confirmar (en un sitio es `5.0`, en otro `5000.0`) |

---

## 9. Plan de entrega

### Fases
- [ ] **Fase 1 — Contrato de datos:** `cuadre-completo` completo y fiable; eliminar
  `_calcularEfectivoManual` y cascadas de fallback en `cerrar_caja_screen.dart`.
- [ ] **Fase 2 — Auth y limpieza:** unificar llamadas en `CuadreCajaService` con token;
  quitar `http` directo de las pantallas.
- [ ] **Fase 3 — Filtros server-side + paginación** en `/cuadre_caja`.
- [ ] **Fase 4 — Refactor UI** de cierre y cuadre.
- [ ] **Fase 5 (opcional) — Flujo de aprobación** de cuadres (UI para aprobar/rechazar).

### Feature flag / rollout
Sin flag. Cambios incrementales; regresión del ciclo abrir→operar→cerrar antes de release.

---

## 10. Pruebas y criterios de aceptación

### Criterios de aceptación (Given / When / Then)
1. **Dado** que ya hay una caja LOCAL abierta, **cuando** el admin intenta abrir otra LOCAL,
   **entonces** se muestra "Ya existe una caja Local abierta" y no se crea nada.
2. **Dado** una caja LOCAL y una ENVIOS abiertas, **cuando** el admin abre `/cerrar_caja` y
   elige ENVIOS, **entonces** todos los importes (efectivo esperado, ventas, transferencias)
   corresponden a ENVIOS, no a LOCAL.
3. **Dado** un efectivo esperado de $X del backend, **cuando** el admin declara $X−$5000,
   **entonces** el diálogo muestra "Falta $5.000" y permite cerrar con descuadre.
4. **Dado** un cierre confirmado, **cuando** termina, **entonces** la caja queda `cerrada`,
   se descarga el Excel de conciliación y, si hay faltantes/sobrantes, aparece el diálogo de
   discrepancias.
5. **Dado** doble-tap en "CERRAR CAJA", **cuando** se procesa, **entonces** se ejecuta un
   solo `updateCuadre(cerrarCaja: true)`.
6. **Dado** que el backend responde "La caja ya está cerrada", **cuando** ocurre,
   **entonces** la pantalla refresca el estado y no muestra un error genérico confuso.
7. **Dado** que `cuadre-completo` no trae `efectivoEsperado`, **cuando** carga el cierre,
   **entonces** (meta) no debería ocurrir; hasta entonces, se muestra aviso claro y valor 0
   en vez de un número inventado silenciosamente.

### Cobertura de pruebas
- **Unitarias:** `CuadreCaja.fromJson` (alias `efectivoInicial`/`fondoInicial`, estados
  `CERRADA`/`cerrada`/`cerrado`), cálculo de descuadre, `contarDiscrepancias`.
- **Widget / secuencia:** doble-tap en abrir/cerrar (ya hay `ICuadreCajaService` inyectable
  y `SubmitGuard`), selector LOCAL/ENVIOS, estado "no hay caja abierta".
- **Integración:** abrir → pagar venta (Facturación) → cerrar y verificar que la venta entra
  en el efectivo esperado de la caja correcta.
- **Manual / QA:** cuadre del efectivo esperado contra ventas reales del día; verificación
  del Excel de conciliación.

---

## 11. Impacto en documentación

- Documentar el efecto secundario de `cerrarCaja: true` (limpieza de caché backend + backup).
- Actualizar `docs/analisis_arquitectura_frontend.md` tras el refactor.
- Memoria relacionada: [[documentos-cache-invalidacion]], [[lista-documentos-paginacion-servidor]].

---

## 12. Preguntas abiertas

- [ ] ¿Los cajeros (no admin) deben poder abrir/cerrar caja, o solo el admin?
- [ ] Valor correcto de `tolerancia` por defecto y política de descuadre aceptable.
- [ ] ¿Se implementa el flujo de aprobación/rechazo de cuadres en esta app?
- [ ] ¿El cierre de caja debe emitir un evento para refrescar Dashboard / Lista documentos?
- [ ] ¿Qué pasa con el guardado local de emergencia de Facturación cuando se reabre la caja?
- [ ] ¿"Ingresos de caja" y "Gastos" cómo entran exactamente en el efectivo esperado?

---

## 13. Registro de cambios del PRD

| Fecha | Autor | Cambio |
|---|---|---|
| 2026-09-09 | Claude | Creación a partir del código existente |
