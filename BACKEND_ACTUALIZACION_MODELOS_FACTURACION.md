# 📄 Actualización de Modelos para Facturación Electrónica

## 📋 Resumen
Este documento especifica los campos nuevos que deben agregarse a los modelos del backend (Java/Spring Boot) para soportar el módulo de **Facturación Electrónica** compatible con la DIAN.

---

## 🏗️ Modelo: `ItemPedido` (Item de Factura)

### Campos Nuevos a Agregar:

```java
@Document(collection = "items_pedido")
public class ItemPedido {
    
    // ===== CAMPOS EXISTENTES =====
    private String id;
    private String productoId;
    private String productoNombre;
    private Integer cantidad;
    private Double precioUnitario;
    private String notas;
    private List<String> ingredientesSeleccionados;
    
    // ===== NUEVOS CAMPOS PARA FACTURACIÓN =====
    
    /**
     * Código interno del producto
     * Ejemplo: "PROD-001", "SKU-123"
     */
    private String codigoProducto;
    
    /**
     * Código de barras del producto
     * Ejemplo: "7501234567890"
     */
    private String codigoBarras;
    
    /**
     * Tipo de impuesto aplicado
     * Valores: "IVA", "INC", "Exento", "IVA+INC"
     */
    private String tipoImpuesto;
    
    /**
     * Porcentaje del impuesto
     * Ejemplo: 19.0 (para IVA 19%), 8.0 (para INC 8%)
     */
    @NotNull
    private Double porcentajeImpuesto = 0.0;
    
    /**
     * Valor calculado del impuesto
     * Calculado como: (subtotal * porcentajeImpuesto) / 100
     */
    @NotNull
    private Double valorImpuesto = 0.0;
    
    /**
     * Porcentaje de descuento aplicado a este item
     * Ejemplo: 10.0 (para 10% de descuento)
     */
    @NotNull
    private Double porcentajeDescuento = 0.0;
    
    /**
     * Valor del descuento aplicado
     * Puede ser calculado o un valor fijo
     */
    @NotNull
    private Double valorDescuento = 0.0;
    
    // ===== GETTERS CALCULADOS =====
    
    /**
     * Subtotal del item (sin impuestos ni descuentos)
     * @return cantidad * precioUnitario
     */
    public Double getSubtotal() {
        return cantidad * precioUnitario;
    }
    
    /**
     * Valor total del item (incluye impuesto y descuento)
     * @return subtotal + valorImpuesto - valorDescuento
     */
    public Double getValorTotal() {
        return getSubtotal() + valorImpuesto - valorDescuento;
    }
}
```

---

## 🧾 Modelo: `Pedido` (Factura/Documento)

### Campos Nuevos a Agregar:

```java
@Document(collection = "pedidos")
public class Pedido {
    
    // ===== CAMPOS EXISTENTES =====
    private String id;
    private Date fecha;
    private String tipo;
    private String mesa;
    private String cliente;
    private String mesero;
    private List<ItemPedido> items;
    private Double total;
    private String estado;
    private String notas;
    private String formaPago;
    private Boolean incluyePropina;
    private Double descuento;
    private String cuadreId;
    private Double totalPagado;
    private List<PagoParcial> pagosParciales;
    private Date fechaPago;
    private String pagadoPor;
    private Double propina;
    
    // ===== NUEVOS CAMPOS PARA FACTURACIÓN ELECTRÓNICA =====
    
    // --- INFORMACIÓN GENERAL DE FACTURA ---
    
    /**
     * Descripción general de la factura
     * Puede incluir notas, términos y condiciones, etc.
     */
    private String descripcionFactura;
    
    /**
     * URLs de archivos adjuntos (PDFs, imágenes, etc.)
     * Ejemplo: ["https://storage.com/file1.pdf", "https://storage.com/file2.jpg"]
     */
    private List<String> archivosAdjuntos;
    
    /**
     * Tipo de factura según la DIAN
     * Valores: "POS", "Electrónica", "Computarizada", "Manual"
     * Default: "POS"
     */
    @NotNull
    private String tipoFactura = "POS";
    
    /**
     * Fecha de vencimiento de la factura
     * Aplicable para facturas de crédito
     */
    private Date fechaVencimiento;
    
    /**
     * Número único de la factura
     * Formato: "FAC-0001", "FE-2024-001", etc.
     * Debe ser secuencial y único por cada tipo de factura
     */
    private String numeroFactura;
    
    /**
     * Código de barras de la factura (CUFE para facturas electrónicas)
     * Generado según especificaciones de la DIAN
     */
    private String codigoBarrasFactura;
    
    // --- RETENCIONES Y TRIBUTOS ---
    
    /**
     * Porcentaje de retención en la fuente
     * Ejemplo: 2.5 (para 2.5%)
     */
    @NotNull
    private Double retencion = 0.0;
    
    /**
     * Valor calculado de la retención
     */
    @NotNull
    private Double valorRetencion = 0.0;
    
    /**
     * Porcentaje de ReteIVA (Retención de IVA)
     * Ejemplo: 15.0 (para 15%)
     */
    @NotNull
    private Double reteIVA = 0.0;
    
    /**
     * Valor calculado de ReteIVA
     */
    @NotNull
    private Double valorReteIVA = 0.0;
    
    /**
     * Porcentaje de ReteICA (Retención de Industria y Comercio)
     * Varía según el municipio
     */
    @NotNull
    private Double reteICA = 0.0;
    
    /**
     * Valor calculado de ReteICA
     */
    @NotNull
    private Double valorReteICA = 0.0;
    
    /**
     * AIU (Administración, Imprevistos, Utilidad)
     * Estructura: {
     *   "administracion": 10.0,  // %
     *   "imprevistos": 5.0,      // %
     *   "utilidad": 10.0         // %
     * }
     * Aplica principalmente para contratos de obra
     */
    private Map<String, Object> aiu;
    
    // --- DESCUENTOS DETALLADOS ---
    
    /**
     * Tipo de descuento general aplicado
     * Valores: "Valor", "Porcentaje"
     */
    @NotNull
    private String tipoDescuentoGeneral = "Valor";
    
    /**
     * Valor del descuento general
     * Si tipoDescuentoGeneral = "Valor": monto fijo (ej: 10000)
     * Si tipoDescuentoGeneral = "Porcentaje": porcentaje (ej: 10.0 para 10%)
     */
    @NotNull
    private Double descuentoGeneral = 0.0;
    
    /**
     * Suma de todos los descuentos aplicados a items individuales
     * Calculado automáticamente sumando valorDescuento de cada item
     */
    @NotNull
    private Double descuentoProductos = 0.0;
    
    // --- TOTALES CALCULADOS ---
    
    /**
     * Subtotal (suma de items sin impuestos ni descuentos)
     * Calculado como: Σ(item.subtotal)
     */
    @NotNull
    private Double subtotal = 0.0;
    
    /**
     * Total de impuestos de toda la factura
     * Calculado como: Σ(item.valorImpuesto)
     */
    @NotNull
    private Double totalImpuestos = 0.0;
    
    /**
     * Total de descuentos (general + productos)
     * Calculado como: descuentoGeneral + descuentoProductos
     */
    @NotNull
    private Double totalDescuentos = 0.0;
    
    /**
     * Total de retenciones aplicadas
     * Calculado como: valorRetencion + valorReteIVA + valorReteICA
     */
    @NotNull
    private Double totalRetenciones = 0.0;
    
    /**
     * Total final a pagar
     * Calculado como: subtotal + totalImpuestos - totalDescuentos - totalRetenciones
     */
    @NotNull
    private Double totalFinal = 0.0;
    
    // ===== MÉTODOS DE CÁLCULO RECOMENDADOS =====
    
    /**
     * Calcula todos los totales de la factura
     * Debe llamarse antes de guardar o actualizar
     */
    public void calcularTotales() {
        // 1. Calcular subtotal
        this.subtotal = items.stream()
            .mapToDouble(ItemPedido::getSubtotal)
            .sum();
        
        // 2. Calcular total de impuestos
        this.totalImpuestos = items.stream()
            .mapToDouble(item -> item.getValorImpuesto())
            .sum();
        
        // 3. Calcular descuento de productos
        this.descuentoProductos = items.stream()
            .mapToDouble(item -> item.getValorDescuento())
            .sum();
        
        // 4. Calcular descuento general (si es porcentaje)
        if ("Porcentaje".equals(this.tipoDescuentoGeneral)) {
            this.descuentoGeneral = (this.subtotal * this.descuentoGeneral) / 100;
        }
        
        // 5. Calcular total de descuentos
        this.totalDescuentos = this.descuentoGeneral + this.descuentoProductos;
        
        // 6. Calcular retenciones
        this.valorRetencion = (this.subtotal * this.retencion) / 100;
        this.valorReteIVA = (this.totalImpuestos * this.reteIVA) / 100;
        this.valorReteICA = (this.subtotal * this.reteICA) / 100;
        this.totalRetenciones = this.valorRetencion + this.valorReteIVA + this.valorReteICA;
        
        // 7. Calcular total final
        this.totalFinal = this.subtotal + this.totalImpuestos - this.totalDescuentos - this.totalRetenciones;
    }
}
```

---

## 🔧 Validaciones Recomendadas

### Para ItemPedido:
```java
@NotNull(message = "La cantidad es requerida")
@Min(value = 1, message = "La cantidad debe ser mayor a 0")
private Integer cantidad;

@NotNull(message = "El precio unitario es requerido")
@Min(value = 0, message = "El precio unitario no puede ser negativo")
private Double precioUnitario;

@Min(value = 0, message = "El porcentaje de impuesto no puede ser negativo")
@Max(value = 100, message = "El porcentaje de impuesto no puede ser mayor a 100")
private Double porcentajeImpuesto;

@Min(value = 0, message = "El porcentaje de descuento no puede ser negativo")
@Max(value = 100, message = "El porcentaje de descuento no puede ser mayor a 100")
private Double porcentajeDescuento;
```

### Para Pedido:
```java
@NotNull(message = "El tipo de factura es requerido")
@Pattern(regexp = "POS|Electrónica|Computarizada|Manual")
private String tipoFactura;

@NotNull(message = "El tipo de descuento general es requerido")
@Pattern(regexp = "Valor|Porcentaje")
private String tipoDescuentoGeneral;

// Validación personalizada para fecha de vencimiento
@AssertTrue(message = "La fecha de vencimiento debe ser posterior a la fecha de emisión")
private boolean isFechaVencimientoValida() {
    return fechaVencimiento == null || fechaVencimiento.after(fecha);
}
```

---

## 📊 Endpoints Sugeridos

### Crear Factura/Pedido:
```http
POST /api/facturas
Content-Type: application/json

{
  "tipoFactura": "POS",
  "cliente": "cliente_id",
  "items": [
    {
      "productoId": "prod_123",
      "cantidad": 2,
      "precioUnitario": 50000,
      "tipoImpuesto": "IVA",
      "porcentajeImpuesto": 19.0,
      "porcentajeDescuento": 10.0
    }
  ],
  "descuentoGeneral": 5000,
  "tipoDescuentoGeneral": "Valor",
  "retencion": 2.5,
  "reteIVA": 15.0
}
```

### Calcular Totales (Pre-guardado):
```http
POST /api/facturas/calcular-totales
Content-Type: application/json

{
  "items": [...],
  "descuentoGeneral": 5000,
  "tipoDescuentoGeneral": "Valor",
  "retencion": 2.5
}

Response:
{
  "subtotal": 100000,
  "totalImpuestos": 19000,
  "totalDescuentos": 15000,
  "totalRetenciones": 2500,
  "totalFinal": 101500
}
```

---

## 🎯 Prioridades de Implementación

### Fase 1 (Esencial):
- ✅ Campos básicos de ItemPedido (códigos, impuestos básicos)
- ✅ Campos básicos de Pedido (tipo factura, número, fechas)
- ✅ Cálculos de subtotales y totales

### Fase 2 (Importante):
- ✅ Descuentos por item y generales
- ✅ Retenciones básicas (Retención en la fuente)
- ✅ Validaciones de negocio

### Fase 3 (Avanzado):
- ✅ ReteIVA y ReteICA
- ✅ AIU para contratos
- ✅ Archivos adjuntos
- ✅ Integración con DIAN

---

## 📝 Notas Importantes

1. **Todos los cálculos deben realizarse en el backend** para garantizar consistencia
2. **Los valores monetarios deben usar Double o BigDecimal** para precisión
3. **Los porcentajes se almacenan como números** (19.0 para 19%, no 0.19)
4. **Las fechas deben seguir ISO 8601** para compatibilidad
5. **El numeroFactura debe ser único** y seguir una secuencia
6. **Implementar índices en MongoDB** para numeroFactura, fechaVencimiento, cliente

---

## 🔍 Índices Recomendados (MongoDB)

```javascript
// Para ItemPedido
db.items_pedido.createIndex({ "productoId": 1 });
db.items_pedido.createIndex({ "codigoBarras": 1 });
db.items_pedido.createIndex({ "codigoProducto": 1 });

// Para Pedido
db.pedidos.createIndex({ "numeroFactura": 1 }, { unique: true });
db.pedidos.createIndex({ "tipoFactura": 1, "fecha": -1 });
db.pedidos.createIndex({ "cliente": 1, "fecha": -1 });
db.pedidos.createIndex({ "fechaVencimiento": 1 });
db.pedidos.createIndex({ "estado": 1, "fecha": -1 });
```

---

## ✅ Checklist de Implementación

- [ ] Agregar campos a modelo ItemPedido
- [ ] Agregar campos a modelo Pedido
- [ ] Implementar método calcularTotales()
- [ ] Agregar validaciones
- [ ] Crear/actualizar endpoints
- [ ] Agregar índices en base de datos
- [ ] Actualizar DTOs
- [ ] Actualizar tests unitarios
- [ ] Documentar API (Swagger)
- [ ] Probar integración con frontend

---

**Fecha de creación:** 17 de enero de 2026  
**Autor:** Equipo Frontend  
**Para:** Equipo Backend Java
