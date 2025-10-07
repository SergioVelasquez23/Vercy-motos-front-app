# 📋 Guía de Integración Frontend - Sistema de Caja Completo

Esta guía contiene toda la información necesaria para que el frontend implemente correctamente la lógica de ventas, compras, gastos y eliminaciones del sistema de caja.

## 📊 **MODELOS DE DATOS**

### **1. Modelo Pedido**

```typescript
interface Pedido {
  _id: string;
  fecha: string;
  tipo: string; // "normal", "rt", "interno", "cancelado", "cortesia"
  mesa: string;
  cliente: string;
  nombrePedido: string;
  mesero: string;
  items: ItemPedido[];
  total: number;
  descuento: number;
  incluyePropina: boolean;
  notas: string;
  plataforma: string;
  pedidoPor: string;
  guardadoPor: string;
  fechaCortesia: string;
  estado: string; // "activo", "pagado", "cancelado", "completado"

  // ✅ CAMPOS CLAVE PARA PAGOS
  formaPago: string; // "efectivo", "transferencia", "tarjeta", "otro" (fallback)
  totalPagado: number;
  pagosParciales: PagoParcial[]; // 🔥 NUEVO: Para pagos mixtos
  cuadreCajaId: string; // ID del cuadre al que pertenece

  // ✅ CAMPOS PARA HISTORIAL
  historialEdiciones: HistorialEdicion[];
  fechaPago: string;
  pagadoPor: string;
  propina: number;
}

// 🔥 NUEVO: Modelo para pagos mixtos
interface PagoParcial {
  monto: number;
  formaPago: string; // "efectivo", "transferencia", "tarjeta"
  fecha: string;
  procesadoPor: string;
}

interface HistorialEdicion {
  accion: string; // "creado", "producto_agregado", "producto_editado", etc.
  usuario: string;
  fecha: string;
  detalles: string;
  productoAfectado?: string;
}
```

### **2. Modelo Gasto**

```typescript
interface Gasto {
  _id: string;
  cuadreCajaId: string; // ✅ REQUERIDO: ID del cuadre
  tipoGastoId: string;
  tipoGastoNombre: string;
  concepto: string;
  monto: number;
  fechaGasto: string;
  responsable: string;
  estado: string; // "pendiente", "aprobado", "rechazado"

  // 🔥 CAMPO CRÍTICO
  pagadoDesdeCaja: boolean; // ✅ true = afecta efectivo, false = no afecta efectivo
  formaPago: string; // "efectivo", "transferencia", "otro"

  // Campos adicionales
  aprobadoPor?: string;
  fechaAprobacion?: string;
  observaciones?: string;
}
```

### **3. Modelo Factura (Compras)**

```typescript
interface Factura {
  _id: string;
  numero: string;
  fecha: string;
  proveedor: string;
  total: number;
  estado: string;

  // ✅ CAMPOS CLAVE PARA COMPRAS
  tipoFactura: string; // "compra" para facturas de compras
  cuadreCajaId: string; // ID del cuadre

  // 🔥 CAMPO CRÍTICO
  pagadoDesdeCaja: boolean; // ✅ true = afecta efectivo, false = no afecta efectivo
  medioPago: string; // "Efectivo", "Transferencia", "Tarjeta"

  // Items de la factura
  itemsIngredientes: ItemFacturaIngrediente[];

  // Campos adicionales
  observaciones?: string;
  creadoPor: string;
  fechaCreacion: string;
}

interface ItemFacturaIngrediente {
  ingredienteId: string;
  nombreIngrediente: string;
  cantidad: number;
  unidadMedida: string;
  precioUnitario: number;
  subtotal: number;
}
```

### **4. Modelo CuadreCaja**

```typescript
interface CuadreCaja {
  _id: string;
  nombre: string;
  responsable: string;
  fechaApertura: string;
  fechaCierre?: string;
  fondoInicial: number;
  efectivoEsperado: number;
  cerrada: boolean;
  estado: string; // "abierto", "pendiente", "cerrado", "aprobado", "rechazado"

  // ✅ CAMPOS EXTENDIDOS
  identificacionMaquina: string;
  cajeros: string[];
  fondoInicialDesglosado: { [key: string]: number };

  // Información de ventas
  totalVentas: number;
  ventasDesglosadas: { [key: string]: number };
  totalPropinas: number;

  // Información de gastos
  totalGastos: number;
  gastosDesglosados: { [key: string]: number };
  totalPagosFacturas: number;

  // Campos de aprobación
  aprobadoPor?: string;
  fechaAprobacion?: string;
  observaciones?: string;
}
```

### **5. Modelo CierreCaja**

```typescript
interface CierreCaja {
  _id: string;
  fechaInicio: string;
  fechaFin: string;
  responsable: string;
  fechaCierre: string;
  estado: string;

  // Montos iniciales
  efectivoInicial: number;
  transferenciasIniciales: number;
  totalInicial: number;

  // Ventas
  totalVentas: number;
  ventasEfectivo: number;
  ventasTransferencias: number;
  ventasTarjetas: number;
  detalleVentas: { [key: string]: number };
  cantidadFacturas: number;
  cantidadPedidos: number;

  // Gastos
  totalGastos: number;
  gastosPorTipo: { [key: string]: number };

  // 🔥 NUEVOS: Ingresos de caja
  totalIngresos: number;
  ingresosEfectivo: number;
  ingresosTransferencias: number;
  ingresosTarjetas: number;
  ingresosPorTipo: { [key: string]: number };

  // 🔥 NUEVOS: Facturas compras
  totalFacturasCompras: number;
  cantidadFacturasCompras: number;
  facturasComprasEfectivo: number;
  facturasComprasTransferencias: number;
  facturasComprasPagadasDesdeCaja: number;

  // Cálculo final
  debeTener: number;
  totalPropinas: number;
  observaciones?: string;
}
```

---

## 🔗 **ENDPOINTS DISPONIBLES**

### **📦 PEDIDOS**

#### **Crear Pedido**

```http
POST /api/pedidos
Content-Type: application/json

{
  "mesa": "Mesa 1",
  "cliente": "Juan Pérez",
  "items": [...],
  "total": 50000,
  "notas": "Sin cebolla"
}
```

#### **Pagar Pedido (Pago Simple)**

```http
PUT /api/pedidos/{id}/pagar
Content-Type: application/json

{
  "formaPago": "efectivo", // "efectivo", "transferencia", "tarjeta"
  "propina": 5000,
  "pagadoPor": "Cajero 1"
}
```

#### **🔥 NUEVO: Agregar Pago Parcial (Pagos Mixtos)**

```http
POST /api/pedidos/{id}/pagos-parciales
Content-Type: application/json

{
  "monto": 30000,
  "formaPago": "efectivo", // "efectivo", "transferencia", "tarjeta"
  "procesadoPor": "Cajero 1"
}
```

#### **🔥 NUEVO: Eliminar Pago Parcial**

```http
DELETE /api/pedidos/{id}/pagos-parciales/{index}
```

#### **🔥 NUEVO: Obtener Pagos Parciales**

```http
GET /api/pedidos/{id}/pagos-parciales

Response:
[
  {
    "monto": 30000,
    "formaPago": "efectivo",
    "fecha": "2025-10-07T10:30:00",
    "procesadoPor": "Cajero 1"
  },
  {
    "monto": 20000,
    "formaPago": "transferencia",
    "fecha": "2025-10-07T10:35:00",
    "procesadoPor": "Cajero 1"
  }
]
```

#### **Eliminar Pedido**

```http
DELETE /api/pedidos/{id}

✅ Automáticamente:
- Resta los pagos del cuadre de caja activo
- Actualiza el efectivo esperado
- Revierte todos los pagos (mixtos o simples)
```

#### **Obtener Pedidos por Cuadre**

```http
GET /api/pedidos/cuadre/{cuadreId}
GET /api/pedidos/cuadre/{cuadreId}/pagados
```

### **💰 GASTOS**

#### **Crear Gasto**

```http
POST /api/gastos
Content-Type: application/json

{
  "cuadreCajaId": "cuadre123", // ✅ REQUERIDO
  "tipoGastoId": "tipo123",
  "tipoGastoNombre": "Servicios Públicos",
  "concepto": "Pago de luz",
  "monto": 50000,
  "responsable": "Admin",
  "pagadoDesdeCaja": true, // 🔥 CRÍTICO: true = afecta efectivo
  "formaPago": "efectivo" // Si pagadoDesdeCaja = true
}
```

#### **Aprobar Gasto**

```http
PUT /api/gastos/{id}/aprobar
Content-Type: application/json

{
  "aprobadoPor": "Supervisor"
}
```

#### **🔥 Eliminar Gasto**

```http
DELETE /api/gastos/{id}

✅ Si pagadoDesdeCaja = true:
- Devuelve el dinero al fondo inicial del cuadre
- Actualiza los totales de gastos
- Recalcula el efectivo esperado
```

#### **Obtener Gastos por Cuadre**

```http
GET /api/gastos/cuadre/{cuadreId}
```

### **🧾 FACTURAS COMPRAS**

#### **Crear Factura Compra**

```http
POST /api/facturas-compras
Content-Type: application/json

{
  "numero": "FC-001",
  "proveedor": "Proveedor ABC",
  "total": 100000,
  "tipoFactura": "compra", // ✅ REQUERIDO para compras
  "pagadoDesdeCaja": true, // 🔥 CRÍTICO: true = afecta efectivo
  "medioPago": "Efectivo", // Si pagadoDesdeCaja = true
  "itemsIngredientes": [
    {
      "ingredienteId": "ing123",
      "nombreIngrediente": "Pollo",
      "cantidad": 10,
      "unidadMedida": "kg",
      "precioUnitario": 8000,
      "subtotal": 80000
    }
  ]
}

✅ Automáticamente:
- Aumenta el stock de ingredientes descontables
- Resta el dinero del cuadre si pagadoDesdeCaja = true
- Crea movimientos de inventario
```

#### **🔥 Eliminar Factura Compra**

```http
DELETE /api/facturas-compras/{id}

✅ Automáticamente:
- Revierte el stock de ingredientes
- Devuelve el dinero al cuadre si pagadoDesdeCaja = true
- Elimina movimientos de inventario
```

#### **Obtener Facturas Compras**

```http
GET /api/facturas-compras
GET /api/facturas-compras/{id}
```

### **🏦 CUADRE CAJA**

#### **Crear Cuadre**

```http
POST /api/cuadre-caja
Content-Type: application/json

{
  "nombre": "Caja Principal",
  "responsable": "Cajero 1",
  "fondoInicial": 500000,
  "observaciones": "Turno mañana",
  "identificacionMaquina": "PC-01",
  "cajeros": ["Cajero 1", "Cajero 2"],
  "cerrarCaja": false // true para crear y cerrar inmediatamente
}

✅ Automáticamente:
- Migra pedidos pagados sin cuadre asignado
- Calcula efectivo esperado
- Limpia cache si se cierra
```

#### **Obtener Cuadre Activo**

```http
GET /api/cuadre-caja/activo

Response: CuadreCaja | null
```

#### **Obtener Detalles de Ventas**

```http
GET /api/cuadre-caja/detalles-ventas

Response:
{
  "fondoInicial": 500000,
  "totalVentas": 250000,
  "ventasEfectivo": 150000,
  "ventasTransferencias": 80000,
  "ventasTarjetas": 20000,
  "totalPedidos": 15,
  "cantidadEfectivo": 8, // Pedidos que tuvieron pagos en efectivo
  "cantidadTransferencias": 6, // Pedidos que tuvieron pagos por transferencia
  "cantidadTarjetas": 2,
  "totalGastos": 30000,
  "gastosDesdeCaja": 20000, // Solo gastos que salieron de caja
  "gastosNoDesdeCaja": 10000, // Gastos que no afectaron efectivo
  "efectivoEsperadoPorVentas": 130000, // Ventas efectivo - gastos efectivo
  "totalEfectivoEnCaja": 630000 // Fondo + efectivo esperado
}
```

### **📊 CIERRE CAJA**

#### **Generar Cierre**

```http
POST /api/cierre-caja/generar
Content-Type: application/json

{
  "fechaInicio": "2025-10-07T08:00:00",
  "fechaFin": "2025-10-07T18:00:00",
  "responsable": "Supervisor",
  "montosIniciales": {
    "efectivo": 500000,
    "transferencias": 0,
    "cuadreCajaId": "cuadre123" // Opcional: para filtrar por cuadre específico
  }
}

Response: CierreCaja completo con todos los totales
```

#### **Cerrar Caja (Finalizar)**

```http
POST /api/cierre-caja/{id}/cerrar
Content-Type: application/json

{
  "observaciones": "Cierre normal del día"
}
```

#### **Obtener Historial Cierres**

```http
GET /api/cierre-caja/historial?limite=10
GET /api/cierre-caja/ultimo
GET /api/cierre-caja/{id}
```

---

## 🎯 **LÓGICA DE FRONTEND**

### **🔥 1. PAGOS MIXTOS**

#### **Interfaz de Pago**

```typescript
// Estado del componente de pago
interface EstadoPago {
  pedidoId: string;
  totalPedido: number;
  totalPagado: number; // Suma de pagos parciales
  saldoPendiente: number; // totalPedido - totalPagado
  pagosParciales: PagoParcial[];

  // Pago actual siendo agregado
  montoPago: number;
  formaPagoSeleccionada: "efectivo" | "transferencia" | "tarjeta";
}

// Función para agregar pago parcial
async function agregarPagoParcial(
  pedidoId: string,
  monto: number,
  formaPago: string
) {
  const response = await fetch(`/api/pedidos/${pedidoId}/pagos-parciales`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      monto,
      formaPago,
      procesadoPor: usuarioActual.nombre,
    }),
  });

  if (response.ok) {
    // Actualizar estado local y refrescar pagos
    await cargarPagosParciales(pedidoId);
  }
}

// Validación antes de agregar pago
function validarPagoParcial(monto: number, saldoPendiente: number): boolean {
  if (monto <= 0) {
    alert("El monto debe ser mayor que cero");
    return false;
  }

  if (monto > saldoPendiente) {
    alert(
      `El monto no puede ser mayor que el saldo pendiente: $${saldoPendiente}`
    );
    return false;
  }

  return true;
}
```

#### **UI Recomendada para Pagos Mixtos**

```html
<!-- Componente de pago -->
<div class="pago-mixto">
  <h3>
    Pedido: ${{totalPedido}} | Pagado: ${{totalPagado}} | Pendiente:
    ${{saldoPendiente}}
  </h3>

  <!-- Lista de pagos parciales -->
  <div class="pagos-existentes">
    <div v-for="(pago, index) in pagosParciales" :key="index" class="pago-item">
      <span>${{pago.monto}} - {{pago.formaPago}}</span>
      <button @click="eliminarPago(index)">❌</button>
    </div>
  </div>

  <!-- Agregar nuevo pago -->
  <div class="nuevo-pago" v-if="saldoPendiente > 0">
    <input
      v-model="montoPago"
      type="number"
      :max="saldoPendiente"
      placeholder="Monto"
    />
    <select v-model="formaPagoSeleccionada">
      <option value="efectivo">Efectivo</option>
      <option value="transferencia">Transferencia</option>
      <option value="tarjeta">Tarjeta</option>
    </select>
    <button @click="agregarPago()">Agregar Pago</button>
  </div>

  <!-- Finalizar pedido -->
  <div v-if="saldoPendiente === 0" class="finalizar">
    <button @click="finalizarPedido()" class="btn-success">
      ✅ Pedido Completamente Pagado
    </button>
  </div>
</div>
```

### **🔥 2. GASTOS CON CONTROL DE CAJA**

#### **Formulario de Gasto**

```typescript
interface FormularioGasto {
  cuadreCajaId: string; // Automático del cuadre activo
  tipoGastoId: string;
  concepto: string;
  monto: number;
  pagadoDesdeCaja: boolean; // ✅ CAMPO CRÍTICO
  formaPago: string; // Habilitado solo si pagadoDesdeCaja = true
}

// Validación del formulario
function validarGasto(gasto: FormularioGasto): string[] {
  const errores: string[] = [];

  if (!gasto.cuadreCajaId) {
    errores.push("No hay una caja activa para registrar el gasto");
  }

  if (gasto.monto <= 0) {
    errores.push("El monto debe ser mayor que cero");
  }

  if (gasto.pagadoDesdeCaja && !gasto.formaPago) {
    errores.push("Debe seleccionar la forma de pago si sale de caja");
  }

  if (gasto.pagadoDesdeCaja && gasto.formaPago === "efectivo") {
    // Validar que hay suficiente efectivo en caja
    if (efectivoDisponible < gasto.monto) {
      errores.push(
        `No hay suficiente efectivo en caja. Disponible: $${efectivoDisponible}`
      );
    }
  }

  return errores;
}
```

#### **UI para Gastos**

```html
<form @submit="crearGasto">
  <input v-model="gasto.concepto" placeholder="Concepto del gasto" required />
  <input v-model="gasto.monto" type="number" placeholder="Monto" required />

  <!-- Control crítico -->
  <div class="pago-desde-caja">
    <label>
      <input v-model="gasto.pagadoDesdeCaja" type="checkbox" />
      ¿Este gasto se paga desde la caja?
      <small>(Si marca esto, afectará el efectivo disponible)</small>
    </label>
  </div>

  <!-- Solo mostrar si pagadoDesdeCaja = true -->
  <div v-if="gasto.pagadoDesdeCaja" class="forma-pago">
    <select v-model="gasto.formaPago" required>
      <option value="">Seleccione forma de pago</option>
      <option value="efectivo">Efectivo (afecta caja)</option>
      <option value="transferencia">Transferencia</option>
      <option value="otro">Otro</option>
    </select>

    <!-- Alerta para efectivo -->
    <div v-if="gasto.formaPago === 'efectivo'" class="alert-efectivo">
      ⚠️ Este gasto reducirá el efectivo en caja de ${{efectivoDisponible}} a
      ${{efectivoDisponible - gasto.monto}}
    </div>
  </div>

  <button type="submit">Crear Gasto</button>
</form>
```

### **🔥 3. FACTURAS COMPRAS**

#### **Formulario de Factura Compra**

```typescript
interface FormularioFacturaCompra {
  numero: string;
  proveedor: string;
  total: number;
  pagadoDesdeCaja: boolean; // ✅ CAMPO CRÍTICO
  medioPago: string; // Solo si pagadoDesdeCaja = true
  itemsIngredientes: ItemFacturaIngrediente[];
}

// Al crear factura compra
async function crearFacturaCompra(factura: FormularioFacturaCompra) {
  // Validar efectivo disponible si es necesario
  if (factura.pagadoDesdeCaja && factura.medioPago === "Efectivo") {
    const detalles = await obtenerDetallesVentas();
    if (detalles.totalEfectivoEnCaja < factura.total) {
      alert(
        `No hay suficiente efectivo. Disponible: $${detalles.totalEfectivoEnCaja}`
      );
      return;
    }
  }

  const response = await fetch("/api/facturas-compras", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      ...factura,
      tipoFactura: "compra", // ✅ Siempre para compras
    }),
  });

  if (response.ok) {
    alert("Factura creada. Stock actualizado automáticamente.");
    // Refrescar inventario y detalles de caja
  }
}
```

### **🔥 4. DASHBOARD DE CAJA**

#### **Componente Principal**

```typescript
interface DashboardCaja {
  cuadreActivo: CuadreCaja | null;
  detallesVentas: DetallesVentas;
  pedidosActivos: Pedido[];
  gastosHoy: Gasto[];
  facturasComprasHoy: Factura[];
}

// Actualización en tiempo real
function inicializarDashboard() {
  // Cargar datos iniciales
  cargarDatos();

  // Actualizar cada 30 segundos
  setInterval(cargarDatos, 30000);

  // WebSocket para actualizaciones en tiempo real (opcional)
  conectarWebSocket();
}

async function cargarDatos() {
  const [cuadre, detalles, pedidos, gastos, facturas] = await Promise.all([
    fetch("/api/cuadre-caja/activo").then((r) => r.json()),
    fetch("/api/cuadre-caja/detalles-ventas").then((r) => r.json()),
    fetch("/api/pedidos/activos").then((r) => r.json()),
    fetch("/api/gastos/hoy").then((r) => r.json()),
    fetch("/api/facturas-compras/hoy").then((r) => r.json()),
  ]);

  // Actualizar estado
  dashboard.cuadreActivo = cuadre;
  dashboard.detallesVentas = detalles;
  // ... resto de datos
}
```

---

## ⚠️ **VALIDACIONES CRÍTICAS**

### **1. Antes de Crear Gastos/Compras desde Caja**

```typescript
async function validarEfectivoDisponible(monto: number): Promise<boolean> {
  const detalles = await fetch("/api/cuadre-caja/detalles-ventas").then((r) =>
    r.json()
  );

  if (detalles.totalEfectivoEnCaja < monto) {
    alert(
      `❌ Efectivo insuficiente. Disponible: $${detalles.totalEfectivoEnCaja}, Requerido: $${monto}`
    );
    return false;
  }

  return true;
}
```

### **2. Antes de Eliminar Items**

```typescript
async function confirmarEliminacion(
  tipo: "pedido" | "gasto" | "factura",
  id: string
) {
  const confirmacion = confirm(
    `¿Está seguro de eliminar este ${tipo}? Esta acción revertirá los cambios en caja.`
  );

  if (confirmacion) {
    const response = await fetch(`/api/${tipo}s/${id}`, { method: "DELETE" });

    if (response.ok) {
      alert(`${tipo} eliminado y dinero revertido en caja`);
      cargarDatos(); // Refrescar dashboard
    }
  }
}
```

### **3. Validación de Pagos Mixtos**

```typescript
function validarPagoCompleto(pedido: Pedido): boolean {
  const totalPagos =
    pedido.pagosParciales?.reduce((sum, pago) => sum + pago.monto, 0) || 0;

  if (Math.abs(totalPagos - pedido.total) > 0.01) {
    // Tolerancia para decimales
    alert(
      `❌ El pedido no está completamente pagado. Total: $${pedido.total}, Pagado: $${totalPagos}`
    );
    return false;
  }

  return true;
}
```

---

## 🎯 **FLUJOS DE TRABAJO RECOMENDADOS**

### **📱 Flujo: Pago de Pedido Mixto**

1. Usuario selecciona pedido para pagar
2. Sistema muestra: Total, Pagado, Pendiente
3. Usuario ingresa monto parcial y forma de pago
4. Sistema valida monto ≤ saldo pendiente
5. Agregar pago parcial → actualizar totales
6. Repetir hasta saldo = 0
7. Marcar pedido como completamente pagado

### **💰 Flujo: Registro de Gasto**

1. Usuario abre formulario de gasto
2. Sistema valida que hay cuadre activo
3. Usuario llena concepto, monto, tipo
4. **CRÍTICO**: Usuario marca si sale de caja
5. Si sale de caja → validar efectivo disponible
6. Crear gasto → actualizar totales de caja

### **🧾 Flujo: Factura de Compra**

1. Usuario crea factura con items
2. **CRÍTICO**: Usuario marca si se paga de caja
3. Si se paga de caja → validar efectivo
4. Crear factura → automáticamente:
   - Actualizar stock de ingredientes
   - Restar dinero de caja
   - Crear movimientos de inventario

### **🗑️ Flujo: Eliminación**

1. Usuario solicita eliminar item
2. Sistema muestra confirmación con impacto
3. Si confirma → revertir automáticamente:
   - Dinero devuelto a caja
   - Stock revertido (facturas)
   - Totales recalculados

---

## 🚀 **CONFIGURACIÓN RECOMENDADA**

### **Estados de Aplicación (Vuex/Redux)**

```typescript
interface EstadoAplicacion {
  caja: {
    cuadreActivo: CuadreCaja | null;
    detallesVentas: DetallesVentas;
    efectivoDisponible: number;
  };

  pedidos: {
    activos: Pedido[];
    pagados: Pedido[];
    enProcesoPago: string | null; // ID del pedido siendo pagado
  };

  gastos: {
    pendientes: Gasto[];
    aprobados: Gasto[];
  };

  facturas: {
    compras: Factura[];
  };
}
```

### **Interceptors HTTP**

```typescript
// Interceptor para errores de caja
axios.interceptors.response.use(
  (response) => response,
  (error) => {
    if (
      error.response?.status === 400 &&
      error.response?.data?.message?.includes("caja")
    ) {
      // Manejar errores específicos de caja
      alert("❌ Error de caja: " + error.response.data.message);
      // Refrescar datos de caja
      cargarDetallesCaja();
    }
    return Promise.reject(error);
  }
);
```

---

## ✅ **CHECKLIST DE IMPLEMENTACIÓN**

### **Backend ✅ (Ya implementado)**

- [x] Pagos mixtos en pedidos
- [x] Control pagadoDesdeCaja en gastos/facturas
- [x] Eliminación con reversión automática
- [x] Cálculos correctos de efectivo esperado
- [x] Endpoints completos
- [x] Facturas compras en cierre

### **Frontend 📋 (Por implementar)**

- [ ] Modelos TypeScript actualizados
- [ ] Interfaz de pagos mixtos
- [ ] Control pagadoDesdeCaja en formularios
- [ ] Validaciones de efectivo disponible
- [ ] Dashboard de caja en tiempo real
- [ ] Confirmaciones de eliminación
- [ ] Manejo de errores específicos de caja
- [ ] Actualizaciones automáticas de totales

---

## 🎉 **RESULTADO FINAL**

Con esta implementación completa, el sistema manejará correctamente:

✅ **Pagos mixtos** (efectivo + transferencia en mismo pedido)  
✅ **Control preciso de efectivo** (solo gastos/compras marcados afectan caja)  
✅ **Eliminaciones inteligentes** (reversión automática de dinero)  
✅ **Cierres completos** (incluye facturas compras e ingresos)  
✅ **Validaciones en tiempo real** (efectivo disponible)  
✅ **Integridad de datos** (montos siempre cuadran)

El frontend tendrá toda la información necesaria para implementar una interfaz robusta y confiable para el manejo de caja.
