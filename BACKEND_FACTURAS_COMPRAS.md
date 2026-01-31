# 📦 Especificación Backend - Facturas de Compras

## 📋 Descripción General

Este documento especifica los modelos, DTOs y endpoints necesarios para el módulo de **Facturas de Compras** para que el backend (Spring Boot/Java) sea compatible con el frontend Flutter.

---

## 🗃️ Modelos de Base de Datos (MongoDB)

### 1. FacturaCompra (Colección: `facturas_compras`)

```java
@Document(collection = "facturas_compras")
public class FacturaCompra {
    
    @Id
    private String id;                          // MongoDB ObjectId
    
    // === DATOS BÁSICOS ===
    private String numero;                      // "COMP-XXXXXXX" - Número único de factura
    private String numeroFacturaProveedor;      // Número de factura del proveedor (opcional)
    private LocalDateTime fecha;                // Fecha de la factura
    private LocalDateTime fechaVencimiento;     // Fecha de vencimiento (opcional)
    private String tipoFactura;                 // Siempre "compra"
    
    // === DATOS DEL PROVEEDOR ===
    private String proveedorNit;                // NIT/Documento del proveedor
    private String proveedorNombre;             // Nombre del proveedor
    private String proveedorTelefono;           // Teléfono (opcional)
    private String proveedorDireccion;          // Dirección (opcional)
    
    // === ITEMS DE LA FACTURA (⚠️ CRÍTICO) ===
    private List<ItemIngrediente> itemsIngredientes;  // ⬅️ LISTA DE PRODUCTOS/INGREDIENTES
    private List<ItemIngrediente> items;              // ⬅️ Backup/Alias (usar itemsIngredientes)
    
    // === TOTALES Y CÁLCULOS DIAN ===
    private Double subtotal;                    // Suma de subtotales de items (sin impuestos)
    private Double totalDescuentos;             // Total de descuentos aplicados
    private Double baseGravable;                // Base para calcular impuestos
    private Double totalImpuestos;              // Suma de impuestos (IVA)
    private Double total;                       // ⬅️ TOTAL FINAL = subtotal + impuestos - descuentos - retenciones
    
    // === RETENCIONES ===
    private Double totalRetenciones;            // Suma de todas las retenciones
    private Double porcentajeRetencion;         // % Retención en la fuente
    private Double valorRetencion;              // Valor retención en la fuente
    private Double porcentajeReteIva;           // % Retención de IVA
    private Double valorReteIva;                // Valor retención de IVA
    private Double porcentajeReteIca;           // % Retención de ICA
    private Double valorReteIca;                // Valor retención de ICA
    
    // === FORMA DE PAGO ===
    private String medioPago;                   // "Efectivo", "Transferencia", "Tarjeta", etc.
    private String formaPago;                   // "Contado", "Crédito"
    private Boolean pagadoDesdeCaja;            // Si se pagó desde el cuadre de caja
    
    // === METADATOS ===
    private String registradoPor;               // Usuario que registró
    private String descripcion;                 // Descripción general (opcional)
    private String observaciones;               // Observaciones adicionales
    private String cuadreCajaId;                // ID del cuadre de caja asociado (si aplica)
    
    // === CAMPOS DE AUDITORÍA ===
    private LocalDateTime fechaCreacion;
    private LocalDateTime fechaActualizacion;
    
    // Getters y Setters...
}
```

### 2. ItemIngrediente (Embebido en FacturaCompra)

```java
public class ItemIngrediente {
    
    // === DATOS DEL PRODUCTO/INGREDIENTE ===
    private String ingredienteId;               // ⬅️ ID del producto en la BD
    private String ingredienteNombre;           // ⬅️ Nombre del producto
    private Double cantidad;                    // ⬅️ Cantidad comprada
    private String unidad;                      // "UND", "KG", "LT", "CAJA", etc.
    
    // === PRECIOS ===
    private Double precioUnitario;              // ⬅️ Precio por unidad
    private Double precioTotal;                 // = cantidad * precioUnitario
    private Double subtotal;                    // = precioTotal (antes de impuestos)
    
    // === IMPUESTOS POR ITEM ===
    private Double porcentajeImpuesto;          // % de IVA (0, 5, 19)
    private Double valorImpuesto;               // = subtotal * (porcentajeImpuesto/100)
    
    // === DESCUENTOS POR ITEM ===
    private Double porcentajeDescuento;         // % de descuento
    private Double valorDescuento;              // = subtotal * (porcentajeDescuento/100)
    
    // === OTROS ===
    private Boolean descontable;                // Si aplica descuento
    private String observaciones;               // Observaciones del item
    
    // Getters y Setters...
}
```

---

## 📨 DTOs (Data Transfer Objects)

### 1. FacturaCompraRequest (Para crear/actualizar)

```java
public class FacturaCompraRequest {
    
    // === DATOS BÁSICOS ===
    private String numero;
    private String numeroFacturaProveedor;
    private String fecha;                       // ISO 8601: "2026-01-23T15:24:39.624"
    private String fechaVencimiento;
    private String tipoFactura;                 // "compra"
    
    // === PROVEEDOR ===
    private String proveedorNit;
    private String proveedorNombre;
    private String proveedorTelefono;
    private String proveedorDireccion;
    
    // === ⚠️ ITEMS - CRÍTICO ===
    @NotNull
    private List<ItemIngredienteDTO> itemsIngredientes;  // ⬅️ DEBE MAPEARSE
    private List<ItemIngredienteDTO> items;              // ⬅️ Alias/backup
    
    // === TOTALES ===
    private Double subtotal;
    private Double totalDescuentos;
    private Double baseGravable;
    private Double totalImpuestos;
    private Double total;
    
    // === RETENCIONES ===
    private Double totalRetenciones;
    private Double porcentajeRetencion;
    private Double valorRetencion;
    private Double porcentajeReteIva;
    private Double valorReteIva;
    private Double porcentajeReteIca;
    private Double valorReteIca;
    
    // === PAGO ===
    private String medioPago;
    private String formaPago;
    private Boolean pagadoDesdeCaja;
    
    // === OTROS ===
    private String registradoPor;
    private String descripcion;
    private String observaciones;
    
    // Getters y Setters...
}
```

### 2. ItemIngredienteDTO

```java
public class ItemIngredienteDTO {
    
    private String ingredienteId;
    private String ingredienteNombre;
    private Double cantidad;
    private String unidad;
    private Double precioUnitario;
    private Double precioTotal;
    private Double subtotal;
    private Double porcentajeImpuesto;
    private Double valorImpuesto;
    private Double porcentajeDescuento;
    private Double valorDescuento;
    private Boolean descontable;
    private String observaciones;
    
    // Getters y Setters...
}
```

### 3. FacturaCompraResponse

```java
public class FacturaCompraResponse {
    
    private Boolean success;
    private String message;
    private String numeroFactura;
    private FacturaCompra factura;              // ⬅️ Objeto completo con items
    
    // Getters y Setters...
}
```

---

## 🎯 Endpoints del Controller

### FacturaCompraController.java

```java
@RestController
@RequestMapping("/api/facturas-compras")
@CrossOrigin(origins = "*")
public class FacturaCompraController {

    @Autowired
    private FacturaCompraService facturaCompraService;

    // ====================================
    // 📝 CREAR FACTURA DE COMPRA
    // ====================================
    @PostMapping("/crear")
    public ResponseEntity<FacturaCompraResponse> crearFactura(
            @RequestBody FacturaCompraRequest request) {
        
        try {
            FacturaCompra factura = facturaCompraService.crearFactura(request);
            
            FacturaCompraResponse response = new FacturaCompraResponse();
            response.setSuccess(true);
            response.setMessage("Factura de compras creada exitosamente");
            response.setNumeroFactura(factura.getNumero());
            response.setFactura(factura);  // ⬅️ INCLUIR FACTURA COMPLETA CON ITEMS
            
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (Exception e) {
            FacturaCompraResponse response = new FacturaCompraResponse();
            response.setSuccess(false);
            response.setMessage("Error: " + e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }
    }

    // ====================================
    // 📋 OBTENER TODAS LAS FACTURAS
    // ====================================
    @GetMapping
    public ResponseEntity<List<FacturaCompra>> obtenerFacturas() {
        List<FacturaCompra> facturas = facturaCompraService.obtenerTodas();
        return ResponseEntity.ok(facturas);
    }

    // ====================================
    // 🔍 OBTENER FACTURA POR ID
    // ====================================
    @GetMapping("/{id}")
    public ResponseEntity<FacturaCompra> obtenerPorId(@PathVariable String id) {
        return facturaCompraService.obtenerPorId(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // ====================================
    // ✏️ ACTUALIZAR FACTURA
    // ====================================
    @PutMapping("/{id}")
    public ResponseEntity<FacturaCompraResponse> actualizarFactura(
            @PathVariable String id,
            @RequestBody FacturaCompraRequest request) {
        
        try {
            FacturaCompra factura = facturaCompraService.actualizarFactura(id, request);
            
            FacturaCompraResponse response = new FacturaCompraResponse();
            response.setSuccess(true);
            response.setMessage("Factura actualizada exitosamente");
            response.setFactura(factura);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            FacturaCompraResponse response = new FacturaCompraResponse();
            response.setSuccess(false);
            response.setMessage("Error: " + e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }
    }

    // ====================================
    // 🗑️ ELIMINAR FACTURA
    // ====================================
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> eliminarFactura(@PathVariable String id) {
        try {
            facturaCompraService.eliminarFactura(id);
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Factura eliminada exitosamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Error: " + e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }
    }

    // ====================================
    // 📊 FILTROS ADICIONALES
    // ====================================
    
    @GetMapping("/proveedor/{nit}")
    public ResponseEntity<List<FacturaCompra>> obtenerPorProveedor(@PathVariable String nit) {
        return ResponseEntity.ok(facturaCompraService.obtenerPorProveedor(nit));
    }

    @GetMapping("/pagadas-desde-caja")
    public ResponseEntity<Map<String, Object>> obtenerPagadasDesdeCaja() {
        List<FacturaCompra> facturas = facturaCompraService.obtenerPagadasDesdeCaja();
        Map<String, Object> response = new HashMap<>();
        response.put("data", facturas);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/fecha-rango")
    public ResponseEntity<List<FacturaCompra>> obtenerPorRangoFecha(
            @RequestParam String fechaInicio,
            @RequestParam String fechaFin) {
        return ResponseEntity.ok(
            facturaCompraService.obtenerPorRangoFecha(fechaInicio, fechaFin)
        );
    }
}
```

---

## ⚙️ Servicio (FacturaCompraService.java)

```java
@Service
public class FacturaCompraService {

    @Autowired
    private FacturaCompraRepository facturaCompraRepository;

    // ====================================
    // 📝 CREAR FACTURA - ⚠️ MÉTODO CRÍTICO
    // ====================================
    public FacturaCompra crearFactura(FacturaCompraRequest request) {
        
        FacturaCompra factura = new FacturaCompra();
        
        // === Generar número único ===
        String numero = request.getNumero();
        if (numero == null || numero.isEmpty()) {
            numero = "COMP-" + System.currentTimeMillis();
        }
        factura.setNumero(numero);
        
        // === Datos básicos ===
        factura.setFecha(parseFecha(request.getFecha()));
        factura.setFechaVencimiento(parseFecha(request.getFechaVencimiento()));
        factura.setTipoFactura("compra");
        
        // === Proveedor ===
        factura.setProveedorNit(request.getProveedorNit());
        factura.setProveedorNombre(request.getProveedorNombre());
        factura.setProveedorTelefono(request.getProveedorTelefono());
        factura.setProveedorDireccion(request.getProveedorDireccion());
        
        // =============================================
        // ⚠️⚠️⚠️ CRÍTICO: MAPEAR ITEMS ⚠️⚠️⚠️
        // =============================================
        List<ItemIngrediente> items = new ArrayList<>();
        
        // Intentar obtener de itemsIngredientes primero, luego de items
        List<ItemIngredienteDTO> itemsDTO = request.getItemsIngredientes();
        if (itemsDTO == null || itemsDTO.isEmpty()) {
            itemsDTO = request.getItems();
        }
        
        if (itemsDTO != null && !itemsDTO.isEmpty()) {
            for (ItemIngredienteDTO dto : itemsDTO) {
                ItemIngrediente item = new ItemIngrediente();
                
                item.setIngredienteId(dto.getIngredienteId());
                item.setIngredienteNombre(dto.getIngredienteNombre());
                item.setCantidad(dto.getCantidad());
                item.setUnidad(dto.getUnidad());
                item.setPrecioUnitario(dto.getPrecioUnitario());
                item.setPrecioTotal(dto.getPrecioTotal() != null ? dto.getPrecioTotal() : dto.getSubtotal());
                item.setSubtotal(dto.getSubtotal());
                item.setPorcentajeImpuesto(dto.getPorcentajeImpuesto() != null ? dto.getPorcentajeImpuesto() : 0.0);
                item.setValorImpuesto(dto.getValorImpuesto() != null ? dto.getValorImpuesto() : 0.0);
                item.setPorcentajeDescuento(dto.getPorcentajeDescuento() != null ? dto.getPorcentajeDescuento() : 0.0);
                item.setValorDescuento(dto.getValorDescuento() != null ? dto.getValorDescuento() : 0.0);
                item.setDescontable(dto.getDescontable() != null ? dto.getDescontable() : true);
                item.setObservaciones(dto.getObservaciones());
                
                items.add(item);
            }
        }
        
        // ⬅️ GUARDAR EN AMBOS CAMPOS
        factura.setItemsIngredientes(items);
        factura.setItems(items);
        
        // =============================================
        // 💰 CALCULAR TOTALES DESDE LOS ITEMS
        // =============================================
        double subtotal = 0.0;
        double totalImpuestos = 0.0;
        double totalDescuentos = 0.0;
        
        for (ItemIngrediente item : items) {
            subtotal += item.getSubtotal() != null ? item.getSubtotal() : 0.0;
            totalImpuestos += item.getValorImpuesto() != null ? item.getValorImpuesto() : 0.0;
            totalDescuentos += item.getValorDescuento() != null ? item.getValorDescuento() : 0.0;
        }
        
        // Si vienen del request, usar esos valores
        factura.setSubtotal(request.getSubtotal() != null && request.getSubtotal() > 0 
            ? request.getSubtotal() : subtotal);
        factura.setTotalImpuestos(request.getTotalImpuestos() != null && request.getTotalImpuestos() > 0 
            ? request.getTotalImpuestos() : totalImpuestos);
        factura.setTotalDescuentos(request.getTotalDescuentos() != null 
            ? request.getTotalDescuentos() : totalDescuentos);
        factura.setBaseGravable(request.getBaseGravable() != null && request.getBaseGravable() > 0 
            ? request.getBaseGravable() : subtotal);
        
        // === Retenciones ===
        factura.setTotalRetenciones(request.getTotalRetenciones() != null ? request.getTotalRetenciones() : 0.0);
        factura.setPorcentajeRetencion(request.getPorcentajeRetencion() != null ? request.getPorcentajeRetencion() : 0.0);
        factura.setValorRetencion(request.getValorRetencion() != null ? request.getValorRetencion() : 0.0);
        factura.setPorcentajeReteIva(request.getPorcentajeReteIva() != null ? request.getPorcentajeReteIva() : 0.0);
        factura.setValorReteIva(request.getValorReteIva() != null ? request.getValorReteIva() : 0.0);
        factura.setPorcentajeReteIca(request.getPorcentajeReteIca() != null ? request.getPorcentajeReteIca() : 0.0);
        factura.setValorReteIca(request.getValorReteIca() != null ? request.getValorReteIca() : 0.0);
        
        // === TOTAL FINAL ===
        double totalRetenciones = (factura.getValorRetencion() != null ? factura.getValorRetencion() : 0.0)
                                + (factura.getValorReteIva() != null ? factura.getValorReteIva() : 0.0)
                                + (factura.getValorReteIca() != null ? factura.getValorReteIca() : 0.0);
        
        double total = factura.getSubtotal() + factura.getTotalImpuestos() 
                     - factura.getTotalDescuentos() - totalRetenciones;
        
        // Si viene total en el request y es mayor a 0, usarlo
        factura.setTotal(request.getTotal() != null && request.getTotal() > 0 
            ? request.getTotal() : total);
        
        // === Pago ===
        factura.setMedioPago(request.getMedioPago() != null ? request.getMedioPago() : "Efectivo");
        factura.setFormaPago(request.getFormaPago() != null ? request.getFormaPago() : "Contado");
        factura.setPagadoDesdeCaja(request.getPagadoDesdeCaja() != null ? request.getPagadoDesdeCaja() : false);
        
        // === Metadatos ===
        factura.setRegistradoPor(request.getRegistradoPor() != null ? request.getRegistradoPor() : "admin");
        factura.setDescripcion(request.getDescripcion());
        factura.setObservaciones(request.getObservaciones());
        
        // === Auditoría ===
        factura.setFechaCreacion(LocalDateTime.now());
        factura.setFechaActualizacion(LocalDateTime.now());
        
        // === GUARDAR ===
        return facturaCompraRepository.save(factura);
    }
    
    private LocalDateTime parseFecha(String fecha) {
        if (fecha == null || fecha.isEmpty()) {
            return LocalDateTime.now();
        }
        try {
            return LocalDateTime.parse(fecha);
        } catch (Exception e) {
            return LocalDateTime.now();
        }
    }
    
    // ... otros métodos (obtenerTodas, obtenerPorId, etc.)
}
```

---

## 📤 Ejemplo de Request del Frontend

```json
{
  "numero": "COMP-9880042",
  "fecha": "2026-01-23T15:24:39.624",
  "tipoFactura": "compra",
  "proveedorNit": "5",
  "proveedorNombre": "juan",
  "total": 160650,
  "pagadoDesdeCaja": false,
  "itemsIngredientes": [
    {
      "ingredienteId": "696d715af7c3883006751aa6",
      "ingredienteNombre": "SLIDER FIBRA CARBONO MORADO",
      "cantidad": 3,
      "unidad": "UND",
      "precioUnitario": 45000,
      "precioTotal": 135000,
      "subtotal": 135000,
      "descontable": true,
      "observaciones": "",
      "porcentajeImpuesto": 19,
      "valorImpuesto": 25650,
      "porcentajeDescuento": 0,
      "valorDescuento": 0
    }
  ],
  "items": [
    {
      "ingredienteId": "696d715af7c3883006751aa6",
      "ingredienteNombre": "SLIDER FIBRA CARBONO MORADO",
      "cantidad": 3,
      "unidad": "UND",
      "precioUnitario": 45000,
      "precioTotal": 135000,
      "subtotal": 135000,
      "descontable": true,
      "observaciones": "",
      "porcentajeImpuesto": 19,
      "valorImpuesto": 25650,
      "porcentajeDescuento": 0,
      "valorDescuento": 0
    }
  ],
  "medioPago": "Efectivo",
  "formaPago": "Contado",
  "registradoPor": "admin",
  "descripcion": "",
  "observaciones": "",
  "subtotal": 135000,
  "totalDescuentos": 0,
  "baseGravable": 135000,
  "totalImpuestos": 25650,
  "totalRetenciones": 0,
  "porcentajeRetencion": 0,
  "valorRetencion": 0,
  "porcentajeReteIva": 0,
  "valorReteIva": 0,
  "porcentajeReteIca": 0,
  "valorReteIca": 0
}
```

---

## ✅ Response Esperado del Backend

```json
{
  "success": true,
  "message": "Factura de compras creada exitosamente",
  "numeroFactura": "COMP-9880042",
  "factura": {
    "_id": "6973d949f4e2684127dfd26d",
    "numero": "COMP-9880042",
    "fecha": "2026-01-23T15:24:39.624",
    "tipoFactura": "compra",
    "proveedorNit": "5",
    "proveedorNombre": "juan",
    "itemsIngredientes": [
      {
        "ingredienteId": "696d715af7c3883006751aa6",
        "ingredienteNombre": "SLIDER FIBRA CARBONO MORADO",
        "cantidad": 3,
        "unidad": "UND",
        "precioUnitario": 45000,
        "precioTotal": 135000,
        "subtotal": 135000,
        "porcentajeImpuesto": 19,
        "valorImpuesto": 25650,
        "porcentajeDescuento": 0,
        "valorDescuento": 0
      }
    ],
    "items": [],
    "subtotal": 135000,
    "totalDescuentos": 0,
    "baseGravable": 135000,
    "totalImpuestos": 25650,
    "total": 160650,
    "totalRetenciones": 0,
    "medioPago": "Efectivo",
    "formaPago": "Contado",
    "pagadoDesdeCaja": false,
    "registradoPor": "admin"
  }
}
```

---

## ⚠️ Errores Comunes a Evitar

### 1. ❌ NO mapear los items
```java
// MAL - No se copian los items
factura.setItemsIngredientes(null);  // ❌
```

```java
// BIEN - Copiar cada item del DTO
for (ItemIngredienteDTO dto : request.getItemsIngredientes()) {
    ItemIngrediente item = new ItemIngrediente();
    item.setIngredienteId(dto.getIngredienteId());
    // ... copiar todos los campos
    items.add(item);
}
factura.setItemsIngredientes(items);  // ✅
```

### 2. ❌ No calcular el total
```java
// MAL - Total siempre 0
factura.setTotal(0.0);  // ❌
```

```java
// BIEN - Calcular desde items o usar el del request
double total = subtotal + totalImpuestos - totalDescuentos - totalRetenciones;
factura.setTotal(request.getTotal() > 0 ? request.getTotal() : total);  // ✅
```

### 3. ❌ DTO sin getters/setters
```java
// MAL - Jackson no puede deserializar
public class ItemIngredienteDTO {
    private String ingredienteId;
    // Sin getters ni setters ❌
}
```

```java
// BIEN - Con Lombok o getters/setters manuales
@Data  // Lombok
public class ItemIngredienteDTO {
    private String ingredienteId;
    // Lombok genera getters/setters ✅
}
```

---

## 📊 Resumen de Campos Obligatorios

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `numero` | String | ✅ | Número único de factura |
| `fecha` | DateTime | ✅ | Fecha de la factura |
| `proveedorNombre` | String | ✅ | Nombre del proveedor |
| `itemsIngredientes` | List | ✅ | Lista de productos |
| `total` | Double | ✅ | Total de la factura |
| `medioPago` | String | ✅ | Medio de pago |
| `formaPago` | String | ✅ | Forma de pago |

### Campos de cada Item:

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `ingredienteId` | String | ✅ | ID del producto |
| `ingredienteNombre` | String | ✅ | Nombre del producto |
| `cantidad` | Double | ✅ | Cantidad comprada |
| `unidad` | String | ✅ | Unidad de medida |
| `precioUnitario` | Double | ✅ | Precio por unidad |
| `subtotal` | Double | ✅ | cantidad × precioUnitario |

---

## 🔧 Checklist de Implementación

- [ ] Crear modelo `FacturaCompra` con campo `itemsIngredientes`
- [ ] Crear modelo embebido `ItemIngrediente`
- [ ] Crear `FacturaCompraRequest` con `List<ItemIngredienteDTO> itemsIngredientes`
- [ ] Crear `ItemIngredienteDTO` con todos los campos
- [ ] En el servicio, **mapear cada item del DTO al modelo**
- [ ] Calcular totales desde los items si no vienen en el request
- [ ] Devolver la factura completa con items en el response
- [ ] Probar con Postman/Insomnia antes de integrar

---

**Fecha de actualización:** 23 de enero de 2026  
**Versión:** 1.0
