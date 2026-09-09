# PRD — Facturación (POS)

> Basado en `lib/screens/facturacion_screen.dart` (~5100 líneas),
> `lib/providers/facturacion_draft_provider.dart`,
> `lib/widgets/facturacion/*`, `lib/services/{pedido,matias,cotizacion,pedido_asesor,pdf,documento}_service.dart`.

---

## 0. Metadatos

| Campo | Valor |
|---|---|
| **Feature** | Facturación / punto de venta |
| **Slug** | `facturacion` |
| **Autor(es)** | _pendiente_ |
| **Estado** | En desarrollo (en producción, god file con deuda técnica) |
| **Fecha creación** | 2026-09-09 |
| **Última actualización** | 2026-09-09 |
| **Épica / Issue** | _pendiente_ |
| **Rama** | `main` |
| **Ruta app** | `/facturacion` (`FacturacionScreen`); lista en `/facturas` (`FacturasListScreen`) |

---

## 1. Resumen ejecutivo

Facturación es la pantalla de punto de venta: el vendedor arma un carrito de productos,
elige un cliente, define método(s) de pago, retenciones y descuentos, y cierra la venta
como **borrador**, **venta pagada** o **deuda (cuenta por cobrar)**. Según el "tipo de
documento" (LOCAL / Documento POS / Factura Electrónica) la venta puede emitirse ante la
DIAN vía `MatiasService`. El borrador se conserva al navegar entre pantallas mediante
`FacturacionDraftProvider`.

---

## 2. Problema y contexto

- **Problema:** el negocio necesita registrar ventas rápido, con o sin factura electrónica,
  soportando pagos mixtos, clientes registrados o "Consumidor Final", y descontar stock —
  todo sin perder el trabajo si el vendedor cambia de pantalla o si la caja está cerrada.
- **Evidencia:** existe `_guardarBorradorLocalPorFallo` (guarda el borrador en
  `SharedPreferences` cuando falla el guardar/pagar, p. ej. caja cerrada); el draft provider
  persiste el estado; hay integración con cotizaciones y pedidos de asesor.
- **Estado actual:** implementado y en uso; pantalla monolítica de ~5100 líneas con lógica
  de cálculo, red, PDF y DIAN mezclada con la UI.
- **Impacto de no hacerlo:** ventas mal registradas, descuadres de caja e inventario,
  rechazos DIAN, pérdida de borradores.

---

## 3. Objetivos y métricas de éxito

### Objetivos
1. Cerrar una venta simple (1 producto, Consumidor Final, efectivo) en < 20 s.
2. Cero pérdida de borrador ante fallo de red o caja cerrada.
3. Emisión DIAN con estado visible y reintentable.

### Métricas / criterios de éxito
| Métrica | Valor actual | Meta | Cómo se mide |
|---|---|---|---|
| Tiempo de venta simple | _pendiente medir_ | < 20 s | Cronometrar flujo QA |
| Borradores perdidos / semana | _pendiente_ | 0 | Reportes de soporte |
| Ventas con emisión DIAN fallida sin reintento | _pendiente_ | 0 | Estado en Lista documentos |
| Descuadre inventario tras cierre de caja | > 0 (hay conciliación) | tiende a 0 | Excel de conciliación de cierre |

### No-objetivos
- Gestión de catálogo de productos (vive en `/productos`).
- Gestión de clientes (vive en `/clientes`), salvo alta rápida inline.
- Cuentas por cobrar / cobro de deuda (vive en `/cuentas-por-cobrar`, `/cartera`).
- Reimpresión masiva / Lista documentos (pantalla aparte).

---

## 4. Usuarios y casos de uso

- **Perfiles afectados:** vendedor/cajero, admin. (Confirmar matriz exacta de permisos.)
- **Caso de uso principal (venta pagada):**
  1. Buscar y agregar productos (por nombre o código de barras).
  2. Seleccionar cliente o dejar "CONSUMIDOR FINAL".
  3. Elegir tipo de documento (LOCAL / POS / FACTURA).
  4. Ingresar método(s) de pago (`efectivo`, `transferencia`, `tarjeta`, `sistecredito`, `datafono`).
  5. Ajustar IVA/descuento/retenciones si aplica.
  6. **Guardar y pagar** → crea pedido, lo marca pagado, descuenta stock, emite a DIAN si POS/FACTURA, ofrece impresión de PDF.
- **Casos secundarios:**
  - **Guardar borrador:** crea pedido en estado borrador (no descuenta stock).
  - **Guardar como deuda:** crea pedido como cuenta por cobrar (cliente real obligatorio).
  - Facturar desde una **cotización** (`convertirAFactura`) o desde un **pedido de asesor**
    (`marcarComoFacturado`).
  - Editar un borrador de mesa/pedido existente.
- **Casos borde:**
  - Caja cerrada → `_guardarBorradorLocalPorFallo` (persiste local, no se pierde la venta).
  - Rechazo DIAN → mostrar error, permitir reintento de emisión.
  - Producto sin stock suficiente.
  - Pago mixto cuya suma ≠ total.

---

## 5. Requisitos funcionales

| ID | Prioridad | Requisito | Notas |
|---|---|---|---|
| RF-1 | Must | Agregar/editar/eliminar ítems del carrito | `ItemPedido`; búsqueda por nombre y por código de barras |
| RF-2 | Must | Seleccionar cliente registrado o "CONSUMIDOR FINAL" | `ClienteService.buscarClientes`, alta rápida inline |
| RF-3 | Must | Seleccionar tipo de documento LOCAL / POS / FACTURA | `TipoFacturaDropdown` |
| RF-4 | Must | Pagos múltiples con 5 métodos y validación de suma vs. total | `montosPago` en draft provider |
| RF-5 | Must | Acción "Guardar y pagar" | `createPedido` → `pagarPedido` → `updatePedido`; descuenta stock |
| RF-6 | Must | Acción "Guardar borrador" | `createPedido` estado borrador |
| RF-7 | Must | Acción "Guardar como deuda" | requiere cliente real; crea cuenta por cobrar |
| RF-8 | Must | Emitir a DIAN (POS / Factura Electrónica) | `MatiasService.emitirDocumentoPOS` / `emitirFacturaElectronica` |
| RF-9 | Should | Descargar / ver / imprimir PDF del documento | `MatiasService.obtenerURLPDF` / `descargarPDF`, `PDFService` |
| RF-10 | Must | Persistir borrador al navegar entre pantallas | `FacturacionDraftProvider` (singleton) |
| RF-11 | Must | Guardado local de emergencia ante fallo (caja cerrada, red) | `_guardarBorradorLocalPorFallo` → `SharedPreferences` |
| RF-12 | Should | Retenciones (reteFuente, reteIVA, reteICA), AIU, descuento general (valor/%) | draft provider |
| RF-13 | Should | Facturar desde cotización y desde pedido de asesor | `convertirAFactura`, `marcarComoFacturado` |
| RF-14 | Should | Campos extra: orden de compra/servicio/pedido, vendedor, guía, observaciones | draft provider |
| RF-15 | Could | Selección de origen/bodega (`ALMACÉN`, traslados) | `TrasladoService` |
| RF-16 | Must | Invalidar caché de "Lista documentos" al pagar/emitir | `DocumentosCache` — ver [[documentos-cache-invalidacion]] |

---

## 6. Requisitos no funcionales

- **Rendimiento:** cálculo de totales en cliente (`utils/facturacion_calculos.dart`) debe ser
  instantáneo; búsqueda de productos con debounce.
- **Resiliencia:** ninguna acción del usuario debe perder datos; toda falla de red cae al
  guardado local con aviso claro y ruta de recuperación.
- **Idempotencia:** doble-tap en "Guardar y pagar" no debe crear dos pedidos ni doble emisión
  DIAN (revisar `submit_guard` / `SubmitGuard` — se usa en caja, confirmar en facturación).
- **Consistencia:** al pagar se descuenta stock y se afecta la caja del tipo correcto
  (LOCAL/ENVIOS); al emitir se invalida `DocumentosCache`.
- **Seguridad:** token DIAN se toma de `UserProvider.token`; no loguear payloads con datos
  fiscales sensibles.
- **Observabilidad:** registrar resultado de emisión DIAN (CUFE, estado) y fallos de pago.
- **UX:** estados claros para: guardando, pagando, emitiendo, rechazado DIAN, borrador
  recuperado.

---

## 7. Diseño de la solución

### 7.1 Flujo de usuario
Entrada a `/facturacion` (nueva venta, o con `extra` = pedido/cotización/pedido asesor) →
`initState` restaura draft desde `FacturacionDraftProvider` y `DatosCacheProvider` →
usuario arma la venta → `BotonesAccionFacturacion` dispara una de 3 acciones →
en éxito: limpia draft, ofrece PDF, navega a lista o nueva venta → en fallo: guardado local.

### 7.2 UI / componentes
`widgets/facturacion/`: `facturacion_header_section.dart`, `metodo_pago_section.dart`,
`totales_section.dart`, `observaciones_section.dart`, `botones_accion_facturacion.dart`,
`dialogo_editar_iva_descuento.dart`, `tipo_factura_dropdown.dart`, `fecha_picker_field.dart`,
`form_field_label.dart`. Diálogo DIAN: `widgets/facturizacion/confirmacion_dian_dialog.dart`.

### 7.3 Frontend (Flutter)
- **Pantalla:** `lib/screens/facturacion_screen.dart` — **god file ~5100 líneas**, prioridad
  alta de refactor (separar: cálculo, capa de red/pago, emisión DIAN, PDF, UI).
- **Estado:** `FacturacionDraftProvider` (singleton `ChangeNotifier`) + estado local de la
  pantalla + `DatosCacheProvider`.
- **Servicios:** `PedidoService`, `MatiasService` (DIAN), `CotizacionService`,
  `PedidoAsesorService`, `PDFService`, `NegocioInfoService`, `ClienteService`,
  `ProductoService`, `TrasladoService`, `DocumentoService`, `DocumentosCache`.
- **Modelos:** `Pedido`, `ItemPedido`, `Producto`, `Cliente`, `Cotizacion`, `PedidoAsesor`,
  `NegocioInfo`.

### 7.4 Backend / API
| Endpoint (vía servicio) | Método | Notas | Estado |
|---|---|---|---|
| `PedidoService.createPedido` | POST | crea pedido (borrador / a pagar / deuda) | Existe |
| `PedidoService.pagarPedido` | POST/PUT | marca pagado, aplica pagos, descuenta stock | Existe |
| `PedidoService.updatePedido` | PUT | actualiza tras pago | Existe |
| `PedidoService.eliminarPedido` | DELETE | limpieza de borradores/mesa | Existe |
| `MatiasService.emitirDocumentoPOS` | POST | emisión documento POS a DIAN | Existe (externo) |
| `MatiasService.emitirFacturaElectronica` | POST | emisión FE a DIAN | Existe (externo) |
| `MatiasService.obtenerURLPDF` / `descargarPDF` | GET | PDF por CUFE | Existe (externo) |
| `CotizacionService.convertirAFactura` | POST | vincula cotización → pedido | Existe |
| `PedidoAsesorService.marcarComoFacturado` | PUT | cierra pedido de asesor | Existe |
| `ClienteService.buscarClientes` / `obtenerClientePorId` | GET | selección de cliente | Existe |

- **Cambios de contrato pendientes:** _pendiente inventariar_ (payload exacto de pago mixto,
  de retenciones y de emisión DIAN).

### 7.5 Caché e invalidación
- `FacturacionDraftProvider`: estado en memoria (singleton); `clearDraft()` al completar venta.
- Guardado local de emergencia en `SharedPreferences` (`_guardarBorradorLocalPorFallo`).
- `DocumentosCache`: **debe invalidarse al pagar y al emitir** — ver
  [[documentos-cache-invalidacion]] (nota: deuda pagada aún no cubierta).
- `DatosCacheProvider`: catálogo de productos/clientes para armar la venta.

---

## 8. Dependencias y riesgos

| Tipo | Descripción | Mitigación |
|---|---|---|
| Dependencia | Servicio DIAN externo (Matias) | Estado de emisión persistido + reintento; no bloquear el pago |
| Dependencia | Caja abierta del tipo correcto para pagar | Guardado local si cerrada + aviso |
| Riesgo | God file de 5100 líneas | Refactor por capas (skill `frontend-cleanup`) |
| Riesgo | Doble emisión / doble pedido por doble-tap | Aplicar `SubmitGuard` a las 3 acciones |
| Riesgo | Pago mixto que no suma el total | Validación dura antes de pagar |
| Riesgo | Caché de Lista documentos desincronizada | Puntos de invalidación explícitos y testeados |
| Supuesto | `MatiasService` maneja reintentos idempotentes | Confirmar con backend/DIAN |

---

## 9. Plan de entrega

### Fases
- [ ] **Fase 1 — Blindaje:** `SubmitGuard` en las 3 acciones; validación de suma de pagos;
  test del guardado local de emergencia.
- [ ] **Fase 2 — Invalidación de caché:** cubrir pago, emisión y deuda pagada en
  `DocumentosCache` (ver [[documentos-cache-invalidacion]]).
- [ ] **Fase 3 — Emisión DIAN robusta:** estado visible + reintento desde Lista documentos.
- [ ] **Fase 4 — Refactor:** extraer cálculo, red/pago, DIAN y PDF fuera de la pantalla.

### Feature flag / rollout
Sin flag; cambios incrementales. Regresión completa del flujo de venta antes de cada release.

---

## 10. Pruebas y criterios de aceptación

### Criterios de aceptación (Given / When / Then)
1. **Dado** un carrito con 1 producto y Consumidor Final en efectivo, **cuando** el vendedor
   pulsa "Guardar y pagar" con caja abierta, **entonces** se crea un pedido pagado, se
   descuenta stock y (si POS/FACTURA) se emite a DIAN con CUFE visible.
2. **Dado** que la caja está cerrada, **cuando** el vendedor pulsa "Guardar y pagar",
   **entonces** la venta se guarda localmente, se muestra un aviso y no se pierde nada al
   reabrir la pantalla.
3. **Dado** un pago mixto cuya suma ≠ total, **cuando** se intenta pagar, **entonces** se
   bloquea con un mensaje claro.
4. **Dado** doble-tap en "Guardar y pagar", **cuando** se procesa, **entonces** se crea
   exactamente un pedido y una sola emisión DIAN.
5. **Dado** que una venta se paga/emite, **cuando** el usuario abre "Lista documentos",
   **entonces** el nuevo documento aparece sin refresco manual.
6. **Dado** que la emisión DIAN es rechazada, **cuando** vuelve el error, **entonces** el
   pago queda registrado y se ofrece reintentar la emisión.
7. **Dado** "Guardar como deuda" con Consumidor Final, **cuando** se confirma, **entonces**
   se exige seleccionar un cliente real.

### Cobertura de pruebas
- **Unitarias:** `utils/facturacion_calculos.dart` (subtotal, IVA, descuento valor/%, AIU,
  retenciones), `payment_mapping`, `FacturacionDraftProvider` (set/clear/persistencia).
- **Widget:** `MetodoPagoSection` (ya tiene test — `totalAPagar` requerido, commit 3e21cdd),
  `TotalesSection`, `BotonesAccionFacturacion`.
- **Integración:** flujo pagar con mock de `PedidoService` + `MatiasService`; flujo caja
  cerrada → guardado local.
- **Manual / QA:** emisión real POS y FE en ambiente de pruebas DIAN; cuadre con caja.

---

## 11. Impacto en documentación

- Actualizar `docs/analisis_arquitectura_frontend.md` tras el refactor.
- Memoria relacionada: [[documentos-cache-invalidacion]], [[lista-documentos-paginacion-servidor]].

---

## 12. Preguntas abiertas

- [ ] Matriz exacta de permisos por rol para cada acción (borrador / pagar / deuda / emitir).
- [ ] ¿"Documento POS" y "Factura Electrónica" siempre se emiten al pagar, o puede diferirse?
- [ ] ¿"LOCAL" nunca se emite y no afecta reportes de "facturado"? (relación con Dashboard).
- [ ] Política de reintento y de-duplicación en `MatiasService`.
- [ ] ¿El guardado local de emergencia se reconcilia automáticamente al reabrir caja?

---

## 13. Registro de cambios del PRD

| Fecha | Autor | Cambio |
|---|---|---|
| 2026-09-09 | Claude | Creación a partir del código existente |
