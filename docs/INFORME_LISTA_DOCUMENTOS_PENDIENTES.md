# Informe — "Lista documentos": registros en PENDIENTE con Abono $0, Saldo = Total y N. Factura / Expedición en "N/A"

**Fecha:** 2026-09-09
**Pantalla:** `FacturasListScreen` (`lib/screens/facturas_list_screen.dart`, título "Lista documentos").
**Repos revisados:** `Vercy-motos-front-app` (Flutter) y `Vercy-motos-app` (backend Spring/Mongo).

---

## 1. Causa raíz (en una frase)

**No es un problema de pagos ni de la DIAN: es un desajuste de contrato entre el frontend y el backend.** La pantalla mezcla dos entidades distintas —`Pedido` y `Factura`— y para las filas de tipo `Factura` lee campos que **el backend nunca ha enviado** (`estadoPago`, `fechaCreacion`, `descuento`). Al no venir, el frontend cae a sus valores por defecto: `estadoPago → "PENDIENTE"`, `fechaCreacion → null` ("N/A"), `descuento → 0`. Resultado: **toda** fila de tipo `Factura` se pinta como PENDIENTE / Abono $0 / Saldo = Total / Expedición N/A, sea cual sea su estado real.

Encima, desde el flujo de facturación electrónica cada venta FE genera **dos** filas (el `Pedido` y su `Factura`), así que la misma venta aparece una vez bien (PAGADO) y otra mal (PENDIENTE).

---

## 2. Qué son realmente esas filas

La pantalla arma la lista con **dos fuentes** (`_cargarDocumentos`, `facturas_list_screen.dart:130`):

| Fuente | Endpoint backend | Tipo en el front | Cómo se pinta |
|---|---|---|---|
| Pedidos pagados | `GET /api/documentos/todos/pagados` → `pedidoRepository.findByEstado("pagado")` | `Pedido` | Nº sintético `FE-`/`POS-`/`LC-` + 8 hex del id; **siempre** `isPagado=true`, `abono=total`, `saldo=0` |
| Facturas de venta | `GET /api/facturas` → `facturaRepository.findFacturasVenta()` (solo en la **página 0**) | `Factura` | `numero` real (o `N/A`); estado/abono/saldo **derivados de campos inexistentes** |

En `_buildTableRow` (`facturas_list_screen.dart:877`), rama `Factura`:

```dart
numero  = documento.numero ?? 'N/A';
isPagado = documento.estadoPago == 'PAGADO';        // estadoPago SIEMPRE es null
abono    = isPagado ? total : 0;                     // ⇒ 0
saldo    = isPagado ? 0 : total - (documento.descuento ?? 0); // ⇒ total
fecha    = documento.fechaCreacion;                  // SIEMPRE null ⇒ "N/A" en Expedición
```

Y en `Factura.fromJson` (`lib/models/factura.dart:300-306`):

```dart
estadoPago: json['estadoPago'] ?? 'PENDIENTE',       // el backend no manda 'estadoPago'
fechaCreacion: parseDateTime(json['fechaCreacion']), // el backend manda 'fecha', no 'fechaCreacion'
descuento: json['descuento']?.toDouble() ?? 0.0,     // el backend manda 'descuentoGeneral'/'totalDescuentos'
```

**El modelo `Factura` del backend NO tiene `estadoPago` ni `fechaCreacion`** (`Vercy-motos-app/.../models/facturacion/Factura.java`). Verificado: `grep -rn "estadoPago" src/main/java` → **cero resultados** en todo el backend. El campo de fecha se llama `fecha`.

Las filas "PAGADO con FE-XXXXXXX" que el usuario ve bien **son `Pedido`**, no `Factura` — por eso se ven distintas. No hay ninguna fila `Factura` que pueda salir "PAGADO" hoy.

---

## 3. Respuesta punto por punto

### 3.1 Lógica de asignación de estado — ¿qué mueve de PENDIENTE a PAGADO?

- **En el `Pedido`** (fuente real de la plata): sí hay lógica. `recalcularEstadoPedido` (`PedidoService.java:543`): `estado = "pagado"` cuando `totalPagado >= total`, si no `"pendiente"`. Es un campo derivado de abono vs total y **funciona**.
- **En la `Factura`**: **no existe** `estado` ni `estadoPago`. La única señal de "pagada" que usa el backend es *"tiene `medioPago` no vacío"* — ver `findFacturasVentaPendientesPago` (`{ medioPago: { $in: [null, ''] } }`) y `findFacturasVentaPagadasByCuadreCajaId` (`{ medioPago: { $nin: [null, ''] } }`).
- **El frontend** ignora todo eso y compara `estadoPago == 'PAGADO'`, string que nunca llega. → siempre PENDIENTE.

No es "abono >= total", no es "existe numero", no es un campo de estado que no se actualiza. Es **un campo que no existe en el payload**, con un default engañoso en el front.

### 3.2 Proceso de facturación electrónica (DIAN) — ¿falló para los "N/A"?

El `numero` de una `Factura` solo se asigna aquí:
- `crearFacturaDesdeAutoIncrement` (`MatiasIntegrationService.java:745`): `if (response.getNumber() != null) factura.setNumero("FE-" + response.getNumber())`.
- `crearFacturaLegalDesdeRespuesta` (`:1248`): idem.

Ambos solo se ejecutan en la **rama de éxito** de `procesarFacturaEnDIAN` (`MatiasInvoiceController.java:130-133`). Si DIAN rechaza, se lanza `BusinessException` y **no se crea ninguna Factura**. Por lo tanto una `Factura` con `numero == null` **no** viene de un rechazo por este flujo; viene de:
1. **Datos legacy**: los endpoints `POST /api/facturas` y `POST /api/facturas/desde-pedido` (hoy devuelven `410 Gone`, `FacturaController.java`) crearon facturas sin CUFE ni numero antes de bloquearse.
2. `crearFacturaDesdeAutoIncrement` cuando DIAN aceptó (`success=true`) pero devolvió `number == null` (raro, pero el código lo permite: la Factura se guarda igual sin `numero`).
3. El flujo `facturarDocumento(documentoId)` (`MatiasIntegrationService.java:1085`) está **roto**: `construirRequestDesdeDocumento` (`:1232`) hace `throw new UnsupportedOperationException("transformarPedidosAFactura no está implementado aún")`. Nunca llega a crear Factura.

**Para confirmar en datos** cuáles fallaron de verdad, mirar en esos documentos: `cufe` (null = no legal), `estadoDIAN` (`RECHAZADA`/`ERROR`/`NO_ENVIADA`), `motivoRechazo`. Y en el `Pedido` origen: `errorFacturacionElectronica` (el front lo guarda vía `setErrorFacturacionElectronica`, `facturas_list_screen.dart:1565`, y lo muestra como ícono rojo junto al estado).

### 3.3 Registro de abonos/pagos — ¿se conecta Caja con Documentos/Cartera?

- El pago **sí** se registra, pero **sobre el `Pedido`** (`totalPagado`, `estado`, `formaPago`) — no sobre la `Factura`.
- La `Factura` hereda `medioPago` **una sola vez, al crearse**, de `pedido.getFormaPago()` / `doc.getFormaPago()` (`MatiasIntegrationService.java:740` y `:1275`). No hay endpoint de abono real: `PUT /api/facturas/{id}/pagar` solo hace `factura.setMedioPago(...)` (`FacturaController.java`).
- **La desconexión real:** la pantalla "Lista documentos" no consulta cartera (`CuentaPorCobrar`) para nada. Si una venta FE fue a **crédito**, el saldo pendiente vive en `CuentaPorCobrar`, no en la `Factura`; la fila `Factura` muestra "Saldo = Total" por el bug del punto 3.1, no porque esté leyendo un saldo real. Coincide a veces, por el motivo equivocado.
- No es "solo se registra si pasa por pasarela/tarjeta": efectivo/caja también setean `formaPago`. El problema es que el front no lee `medioPago`.

### 3.4 Consulta / vista detrás de la pantalla — ¿estado en tiempo real o campo estático?

- `GET /api/facturas` → `findFacturasVenta()` → `{ tipoFactura: { $in: [null, 'venta', 'Venta'] } }`. **Sin cálculo de estado, sin filtro de pago, sin paginación.** Devuelve *todas* las facturas de venta que existan.
- El estado se calcula **en tiempo real en el cliente**, en `_buildTableRow`, a partir de `documento.estadoPago == 'PAGADO'` — un campo que siempre es `null`.
- No hay trigger ni vista materializada. No hay nada "que no se está disparando". Simplemente el cálculo cliente-side parte de un campo ausente.
- Nota adicional de UX: al ordenar (`_aplicarFiltros`, `:264`), las `Factura` usan `fechaCreacion ?? DateTime(1970)`; como siempre es null, **todas las facturas se van al fondo de la lista con fecha 1970** → el usuario baja y encuentra un bloque de filas PENDIENTE.

### 3.5 Casos "CONSUMIDOR FINAL"

- **No es la causa.** El `MatiasTransformer` (`:1085-1123`) ya maneja consumidor final: si el nombre es el placeholder "CONSUMIDOR FINAL" o no hay NIT, usa `dni = "222222222222"` e `identification_document_id` para consumidor final sin RUT. La emisión **no se bloquea** por falta de datos del cliente.
- El nombre "CONSUMIDOR FINAL" que se ve en esas filas es solo el fallback del front (`documento.cliente ?? 'CONSUMIDOR FINAL'`, `:896`) o el `clienteNombre` real de la factura. No impide nada.

---

## 4. Corrección

### ✅ Aplicado (2026-09-09) — quitar las filas `Factura` de esta pantalla

`_aplicarFiltros` (`facturas_list_screen.dart:212`) ya **no agrega las `Factura` de `GET /api/facturas` como filas propias**. Toda venta FE ya aparece aquí como su `Pedido` (categoría FE, "PAGADO", con su fecha real); la `Factura` gemela era una copia duplicada que —por el desajuste de contrato del §2— siempre se pintaba PENDIENTE / $0 / Saldo=Total / Expedición N/A.

`_facturas` se sigue cargando en segundo plano porque `_exportarExcel` lo usa como lookup por `pedidoId` para resolver el número real de FE (`_extraerNumeroDian` / `_numeroRealDocumento`). Solo se dejó de renderizar.

Con esto el síntoma reportado desaparece por completo: en "Lista documentos" ya no hay filas en PENDIENTE con N/A.

### Pendiente / opcional — arreglo de fondo

Si en el futuro se quiere volver a mostrar `Factura` de venta que **no** tengan un `Pedido` detrás (flujo Documento, legacy), antes hay que cerrar el desajuste de contrato:

- **Frontend:** en `Factura.fromJson` mapear `json['fecha']` (no `fechaCreacion`); derivar pagado de `cufe`/`estadoDIAN=='ACEPTADA'`/`medioPago` no vacío.
- **Backend (recomendado):** getters derivados en `Factura.java`, sin migración —
  `getEstadoPago()` → `medioPago` no vacío ? "PAGADO" : "PENDIENTE"; `getFechaExpedicion()` → `fecha`.

### Datos — solo si el §5 revela emisiones fallidas

Para `Factura` de venta con `cufe == null` **y** sin `Pedido` pagado detrás: re-emitir con `POST /api/matias/invoices/auto-increment` si el pedido existe y está pagado, o depurar si es basura de los endpoints legacy deshabilitados.

---

### (Referencia) Otras opciones evaluadas

- **Dedup en vez de ocultar:** en `_aplicarFiltros`, `Set<String>` con los `id` de `_pedidosPagados` y saltar toda `Factura` cuyo `pedidoId` esté en ese set — mostraría las `Factura` "huérfanas" (sin pedido). Se descartó porque hoy no hay ninguna `Factura` legítima sin pedido (el flujo Documento está roto, `construirRequestDesdeDocumento` lanza `UnsupportedOperationException`), así que solo sumaría filas legacy rotas.
- **Arreglar el pintado de la fila `Factura`** (`_buildTableRow:877`): `isPagado = cufe no vacío || estadoDIAN=='ACEPTADA' || metodoPago no vacío`; `fecha = fechaCreacion ?? fecha`. Correcto, pero seguiría duplicando cada venta FE (una como `Pedido`, otra como `Factura`).

---

## 5. Cómo confirmarlo en la base de datos

```js
// ¿Cuántas facturas de venta y en qué estado DIAN?
db.factura.aggregate([
  { $match: { tipoFactura: { $in: [null, "venta", "Venta"] } } },
  { $group: { _id: { estadoDIAN: "$estadoDIAN",
                      tieneCufe: { $gt: ["$cufe", null] },
                      tieneNumero: { $gt: ["$numero", null] },
                      tieneMedioPago: { $gt: ["$medioPago", null] } },
              n: { $sum: 1 } } }
])

// Duplicación: facturas cuyo pedidoId ya está pagado
db.factura.find({ pedidoId: { $ne: null } }, { _id:1, numero:1, pedidoId:1, cufe:1 }).forEach(f => {
  const p = db.pedido.findOne({ _id: f.pedidoId }, { estado:1 });
  if (p && p.estado === "pagado") print(`DUP  factura ${f._id} (${f.numero}) ~ pedido ${f.pedidoId}`);
})
```

- Si casi todas las de venta tienen `cufe` y `pedidoId` de un pedido pagado → el problema es **100% de display + duplicación** (arreglos A + B).
- Si hay un bloque con `estadoDIAN` en `RECHAZADA`/`NO_ENVIADA` y sin `cufe` → además hay emisiones fallidas que resolver (arreglo D), y conviene revisar los logs de `MatiasIntegrationService` / `WebhookService` de esas fechas (`log.error("  DIAN rechazó...")`, `marcarRechazado`).
