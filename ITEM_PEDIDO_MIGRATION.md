# Guía de Migración - Servicios Dependientes de ItemPedido

## 🎯 **OBJETIVO**

Actualizar todos los servicios, screens, y componentes que usan el modelo ItemPedido para trabajar con la nueva versión unificada, sin romper la funcionalidad existente.

---

## 🔍 **ANÁLISIS DE DEPENDENCIAS**

### **📱 Frontend Flutter - Archivos Afectados:**

#### **Servicios que usan ItemPedido:**
- `lib/services/pedido_service.dart` - CRÍTICO
- `lib/services/inventario_service.dart` - Maneja ingredientes
- `lib/utils/pedido_helper.dart` - Validaciones

#### **Screens que manejan ItemPedido:**
- `lib/screens/pedido_screen.dart` - Creación/edición
- `lib/screens/pedidos_screen_fusion.dart` - Lista de pedidos
- `lib/screens/productos_screen.dart` - Agregar a pedido
- `lib/widgets/cancelar_producto_dialog.dart` - Cancelaciones

#### **Widgets/Components:**
- `lib/widgets/base_pedidos_screen.dart` - Base común
- Cualquier widget que muestre listas de items

### **🔧 Backend Java - Archivos Afectados:**

#### **Controladores:**
- `PedidosController.java` - CRÍTICO 
- `InventarioController.java` - Si maneja items
- Cualquier otro controlador que procese items

#### **Servicios:**
- Servicios que manipulen lists de ItemPedido
- DTOs que contengan ItemPedido

---

## 🔄 **PASOS DE MIGRACIÓN**

### **PASO 1: Preparación (30 min)**

1. **Backup de archivos críticos:**
```bash
# Backend
cp ItemPedido.java ItemPedido_backup.java

# Frontend  
cp lib/models/item_pedido.dart lib/models/item_pedido_backup.dart
cp lib/services/pedido_service.dart lib/services/pedido_service_backup.dart
```

2. **Identificar todos los usos:**
```bash
# Buscar referencias en Flutter
grep -r "ItemPedido" lib/ --include="*.dart"
grep -r "\.precio" lib/ --include="*.dart" 
grep -r "\.subtotal" lib/ --include="*.dart"
```

### **PASO 2: Reemplazar modelos (15 min)**

```bash
# Backend
mv ItemPedido_new.java ItemPedido.java

# Frontend
mv lib/models/item_pedido_new.dart lib/models/item_pedido.dart
```

### **PASO 3: Actualizar Servicios (60 min)**

#### **A. PedidoService (Flutter)**

**CAMBIOS NECESARIOS:**

```dart
// ANTES
ItemPedido(
  productoId: producto.id,
  producto: producto,
  cantidad: cantidad,
  precio: producto.precio,  // ❌ Campo 'precio'
  notas: notas,
);

// DESPUÉS  
ItemPedido(
  productoId: producto.id,
  producto: producto,
  productoNombre: producto.nombre,  // ✅ Agregar cache
  cantidad: cantidad,
  precioUnitario: producto.precio,  // ✅ Campo 'precioUnitario'
  notas: notas,
);
```

#### **B. Validaciones en PedidoHelper**

```dart
// ANTES
bool validatePedidoItems(List<ItemPedido> items) {
  return items.every((item) => 
    item.productoId.isNotEmpty && 
    item.cantidad > 0 && 
    item.precio > 0  // ❌ Campo 'precio'
  );
}

// DESPUÉS
bool validatePedidoItems(List<ItemPedido> items) {
  return items.every((item) => item.isValid);  // ✅ Usar validación built-in
}
```

### **PASO 4: Actualizar Screens (90 min)**

#### **A. Pantallas de Creación de Pedidos**

**CAMBIOS EN WIDGETS:**

```dart
// ANTES - Mostrar precio
Text('\$${item.precio.toStringAsFixed(2)}')

// DESPUÉS - Usar precioUnitario
Text('\$${item.precioUnitario.toStringAsFixed(2)}')

// ALTERNATIVA - Usar getter compatibilidad
Text('\$${item.precio.toStringAsFixed(2)}')  // ✅ Sigue funcionando (deprecated)
```

#### **B. Cálculos en UI**

```dart
// ANTES - Cálculo manual inconsistente  
double total = items.fold(0, (sum, item) => sum + (item.precio * item.cantidad));

// DESPUÉS - Usar subtotal calculado
double total = items.fold(0, (sum, item) => sum + item.subtotal);
```

### **PASO 5: Actualizar Backend Java (45 min)**

#### **A. Constructores en DTOs**

```java
// Si tienes DTOs que crean ItemPedido
public class CrearPedidoRequest {
    // ANTES
    public ItemPedido toItemPedido() {
        ItemPedido item = new ItemPedido();
        item.setProductoId(this.productoId);
        item.setCantidad(this.cantidad);
        item.setPrecio(this.precio);  // ❌ Campo eliminado
        return item;
    }
    
    // DESPUÉS
    public ItemPedido toItemPedido() {
        return new ItemPedido(
            this.productoId,
            this.cantidad, 
            this.precio  // ✅ Mapea a precioUnitario automáticamente
        );
    }
}
```

#### **B. Validaciones en Controladores**

```java
// ANTES - Validación manual
private boolean validarItem(ItemPedido item) {
    return item.getProductoId() != null 
        && item.getCantidad() > 0 
        && item.getPrecio() > 0;  // ❌ Campo eliminado
}

// DESPUÉS - Usar validación built-in
private boolean validarItem(ItemPedido item) {
    return item.isValid();  // ✅ Validación integrada
}
```

---

## 🚨 **PUNTOS CRÍTICOS DE ATENCIÓN**

### **1. Campos de Precio Eliminados (CRÍTICO)**

**❌ Campos que YA NO EXISTEN en Java:**
- `precio` (duplicado de precioUnitario)
- `total` (usar getSubtotal())
- `pagado` (mover a nivel Pedido)

**⚠️ ACCIÓN REQUERIDA:**
- Buscar todos los `.getPrecio()` y reemplazar por `.getPrecioUnitario()`
- Buscar todos los `.getTotal()` y reemplazar por `.getSubtotal()`
- Eliminar referencias a `.isPagado()`

### **2. Cálculos Automáticos (IMPORTANTE)**

**✅ ANTES**: Subtotal se almacenaba y podía desactualizarse
**✅ DESPUÉS**: Subtotal siempre calculado automáticamente

**⚠️ ACCIÓN REQUERIDA:**
- Eliminar cualquier código que haga `item.setSubtotal()`
- Confiar en que `item.getSubtotal()` siempre es correcto

### **3. Serialización JSON (CRÍTICO)**

**Frontend → Backend:**
```json
{
  "productoId": "prod123",
  "cantidad": 2,
  "precioUnitario": 15.50,    // ✅ Nuevo campo estándar
  "subtotal": 31.00,          // ✅ Calculado, incluído para compatibilidad
  "notas": "Sin cebolla"
}
```

**⚠️ ACCIÓN REQUERIDA:**
- Verificar que el backend puede deserializar el nuevo formato
- Probar round-trip: Flutter → Backend → Flutter

---

## 🧪 **PLAN DE PRUEBAS**

### **Fase 1: Pruebas Unitarias (30 min)**
```bash
# Ejecutar tests de ItemPedido
dart run lib/models/item_pedido_test.dart
```

### **Fase 2: Pruebas de Integración (60 min)**
1. **Crear pedido** desde la app móvil
2. **Verificar en backend** que se recibe correctamente
3. **Obtener pedidos** desde backend
4. **Verificar en frontend** que se muestra correctamente

### **Fase 3: Pruebas de Regresión (90 min)**
1. **Funcionalidad existente** debe seguir funcionando
2. **Cálculos de totales** deben ser idénticos
3. **Reportes y estadísticas** deben mostrar números correctos

---

## 📋 **CHECKLIST DE MIGRACIÓN**

### **Backend Java:**
- [ ] ✅ Reemplazar `ItemPedido.java` con versión nueva
- [ ] 🔍 Buscar y reemplazar `.getPrecio()` → `.getPrecioUnitario()`
- [ ] 🔍 Buscar y reemplazar `.getTotal()` → `.getSubtotal()`
- [ ] ❌ Eliminar referencias a `.isPagado()`
- [ ] ✅ Compilar sin errores
- [ ] 🧪 Ejecutar tests unitarios

### **Frontend Flutter:**
- [ ] ✅ Reemplazar `item_pedido.dart` con versión nueva
- [ ] 🔍 Buscar referencias a `.precio` en código
- [ ] 🔧 Actualizar creación de ItemPedido en servicios
- [ ] 🔧 Actualizar widgets que muestran precios
- [ ] 🔧 Actualizar validaciones en helpers
- [ ] 🧪 Ejecutar `testItemPedidoUnificado()`
- [ ] 📱 Probar creación de pedidos desde UI

### **Integración:**
- [ ] 🔄 Crear pedido desde Flutter → Backend
- [ ] 🔄 Obtener pedidos desde Backend → Flutter  
- [ ] 📊 Verificar cálculos de totales
- [ ] 📋 Verificar reportes y estadísticas

---

## 🆘 **RESOLUCIÓN DE PROBLEMAS**

### **Error: "precio field not found"**
```dart
// SOLUCIÓN: Usar precioUnitario o getter compatibilidad
item.precioUnitario  // ✅ Recomendado
// o
item.precio  // ✅ Funciona pero deprecated
```

### **Error: "total field not found"** 
```java
// SOLUCIÓN: Usar getSubtotal()
item.getSubtotal()  // ✅ Siempre correcto
```

### **Error: "Subtotal calculation mismatch"**
```dart
// CAUSA: Mezclar precio y precioUnitario
// SOLUCIÓN: Usar solo precioUnitario consistentemente
final total = items.fold(0.0, (sum, item) => sum + item.subtotal);
```

### **Error: "JSON deserialization failed"**
```java
// CAUSA: Backend esperando campo "precio" que ya no existe
// SOLUCIÓN: El nuevo modelo maneja compatibilidad automáticamente
// Verificar que se está usando ItemPedido_new.java
```

---

## ⚡ **ROLLBACK PLAN**

Si algo falla crítico:

1. **Revertir modelos:**
```bash
# Backend
mv ItemPedido.java ItemPedido_new.java
mv ItemPedido_backup.java ItemPedido.java

# Frontend
mv lib/models/item_pedido.dart lib/models/item_pedido_new.dart
mv lib/models/item_pedido_backup.dart lib/models/item_pedido.dart
```

2. **Revertir servicios:**
```bash
mv lib/services/pedido_service_backup.dart lib/services/pedido_service.dart
```

3. **Reiniciar aplicaciones** y verificar funcionamiento

---

## 🎯 **BENEFICIOS POST-MIGRACIÓN**

### **✅ Consistencia Total**
- Un solo campo precio en ambos lados
- Cálculos idénticos garantizados
- Menos bugs por inconsistencias

### **✅ Mejor Mantenibilidad**
- Cambios futuros en un solo lugar
- Validaciones centralizadas
- Código más limpio y claro

### **✅ Performance Mejorado**
- JSON más pequeño y eficiente
- Menos campos para serializar
- Cálculos optimizados

---

**¿LISTO PARA LA MIGRACIÓN?** ✅

**Tiempo estimado total: 4-5 horas**
**Riesgo: MEDIO** (con rollback plan preparado)
**Beneficio: ALTO** (elimina inconsistencias críticas)
