# Especificación Técnica - ItemPedido Unificado

## 🎯 **OBJETIVOS**

1. **Eliminar ambigüedad** en campos de precio
2. **Sincronizar comportamiento** entre Java y Dart
3. **Simplificar cálculos** y reduce bugs
4. **Mejorar performance** de serialización
5. **Facilitar mantenimiento** futuro

---

## 📋 **ESPECIFICACIÓN FUNCIONAL**

### **Campos del Modelo**

| Campo | Tipo | Requerido | Propósito | Notas |
|-------|------|-----------|-----------|-------|
| `id` | String? | No | Identificador único del item | Generado por BD |
| `productoId` | String | **Sí** | ID del producto referenciado | Clave foránea |
| `productoNombre` | String? | No | Cache del nombre del producto | Para mostrar sin consultas |
| `cantidad` | int | **Sí** | Cantidad del producto pedida | Mínimo: 1 |
| `precioUnitario` | double | **Sí** | Precio por unidad | **ÚNICO campo precio** |
| `notas` | String? | No | Notas especiales del item | Ej: "Sin cebolla" |
| `ingredientesSeleccionados` | List\<String\> | **Sí** | IDs de ingredientes customizados | Lista vacía por defecto |

### **Propiedades Calculadas (No Almacenadas)**

| Propiedad | Fórmula | Propósito |
|-----------|---------|-----------|
| `subtotal` | `cantidad * precioUnitario` | Total del item sin impuestos |

---

## 💻 **ESPECIFICACIÓN TÉCNICA**

### **Backend Java - ItemPedido.java**

```java
package com.prog3.security.Models;

import java.util.List;
import java.util.ArrayList;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;

public class ItemPedido {
    
    // 🏷️ IDENTIFICACIÓN
    private String id;                              // Opcional, generado por MongoDB
    
    // 🔗 REFERENCIA A PRODUCTO  
    private String productoId;                      // ID del producto (requerido)
    private String productoNombre;                  // Cache del nombre (opcional)
    
    // 📊 CANTIDADES Y PRECIOS
    private int cantidad;                           // Cantidad pedida (requerido)
    private double precioUnitario;                  // ÚNICO precio (requerido)
    
    // 📝 INFORMACIÓN ADICIONAL
    private String notas;                           // Notas especiales (opcional)
    private List<String> ingredientesSeleccionados; // Ingredientes customizados
    
    // 🏗️ CONSTRUCTORES
    public ItemPedido() {
        this.ingredientesSeleccionados = new ArrayList<>();
        this.cantidad = 1;
        this.precioUnitario = 0.0;
    }
    
    public ItemPedido(String productoId, int cantidad, double precioUnitario) {
        this();
        this.productoId = productoId;
        this.cantidad = cantidad;
        this.precioUnitario = precioUnitario;
    }
    
    public ItemPedido(String productoId, String productoNombre, int cantidad, double precioUnitario) {
        this(productoId, cantidad, precioUnitario);
        this.productoNombre = productoNombre;
    }
    
    // 🧮 CÁLCULOS AUTOMÁTICOS
    @JsonProperty("subtotal")
    public double getSubtotal() {
        return this.cantidad * this.precioUnitario;
    }
    
    // ⚠️ NO SETTER para subtotal - es calculado
    @JsonIgnore
    public void setSubtotal(double subtotal) {
        // Ignorar intentos de establecer subtotal - es calculado automáticamente
    }
    
    // 🔧 VALIDACIONES
    public void setCantidad(int cantidad) {
        if (cantidad <= 0) {
            throw new IllegalArgumentException("La cantidad debe ser mayor a 0");
        }
        this.cantidad = cantidad;
    }
    
    public void setPrecioUnitario(double precioUnitario) {
        if (precioUnitario < 0) {
            throw new IllegalArgumentException("El precio unitario no puede ser negativo");
        }
        this.precioUnitario = precioUnitario;
    }
    
    // 🔗 GETTERS Y SETTERS ESTÁNDAR
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    
    public String getProductoId() { return productoId; }
    public void setProductoId(String productoId) { this.productoId = productoId; }
    
    public String getProductoNombre() { return productoNombre; }
    public void setProductoNombre(String productoNombre) { this.productoNombre = productoNombre; }
    
    public int getCantidad() { return cantidad; }
    public double getPrecioUnitario() { return precioUnitario; }
    
    public String getNotas() { return notas; }
    public void setNotas(String notas) { this.notas = notas; }
    
    public List<String> getIngredientesSeleccionados() { return ingredientesSeleccionados; }
    public void setIngredientesSeleccionados(List<String> ingredientesSeleccionados) { 
        this.ingredientesSeleccionados = ingredientesSeleccionados != null ? ingredientesSeleccionados : new ArrayList<>(); 
    }
    
    // 🔍 MÉTODOS UTILITARIOS
    @Override
    public String toString() {
        return String.format("ItemPedido{id='%s', productoId='%s', cantidad=%d, precioUnitario=%.2f, subtotal=%.2f}", 
                           id, productoId, cantidad, precioUnitario, getSubtotal());
    }
    
    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (obj == null || getClass() != obj.getClass()) return false;
        ItemPedido that = (ItemPedido) obj;
        return Objects.equals(id, that.id) && Objects.equals(productoId, that.productoId);
    }
    
    @Override
    public int hashCode() {
        return Objects.hash(id, productoId);
    }
}
```

### **Frontend Flutter - item_pedido_new.dart**

```dart
/// Modelo ItemPedido unificado con backend
/// 
/// Esta versión elimina la ambigüedad en precios y mantiene
/// consistencia total con el modelo Java.
class ItemPedido {
  
  // 🏷️ IDENTIFICACIÓN
  final String? id;                           // Opcional, generado por BD
  
  // 🔗 REFERENCIA A PRODUCTO
  final String productoId;                    // ID del producto (requerido)
  final String? productoNombre;               // Cache del nombre (opcional)
  final Producto? producto;                   // Referencia completa (opcional, para UI)
  
  // 📊 CANTIDADES Y PRECIOS  
  final int cantidad;                         // Cantidad pedida (requerido)
  final double precioUnitario;                // ÚNICO precio (requerido)
  
  // 📝 INFORMACIÓN ADICIONAL
  final String? notas;                        // Notas especiales (opcional)
  final List<String> ingredientesSeleccionados; // Ingredientes customizados

  // 🏗️ CONSTRUCTOR
  const ItemPedido({
    this.id,
    required this.productoId,
    this.productoNombre,
    this.producto,
    required this.cantidad,
    required this.precioUnitario,
    this.notas,
    this.ingredientesSeleccionados = const [],
  }) : assert(cantidad > 0, 'La cantidad debe ser mayor a 0'),
       assert(precioUnitario >= 0, 'El precio unitario no puede ser negativo');

  // 🧮 CÁLCULOS AUTOMÁTICOS
  double get subtotal => cantidad * precioUnitario;

  // 📄 SERIALIZACIÓN JSON
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'productoId': productoId,
    if (productoNombre != null) 'productoNombre': productoNombre,
    'cantidad': cantidad,
    'precioUnitario': precioUnitario,
    'subtotal': subtotal,  // Incluido para compatibilidad, pero calculado
    if (notas != null && notas!.isNotEmpty) 'notas': notas,
    'ingredientesSeleccionados': ingredientesSeleccionados,
  };

  // 📥 DESERIALIZACIÓN JSON
  factory ItemPedido.fromJson(Map<String, dynamic> json, {Producto? producto}) {
    // Manejar diferentes formatos de precio por compatibilidad
    double precio = 0.0;
    
    // Prioridad: precioUnitario > precio > subtotal/cantidad
    if (json.containsKey('precioUnitario')) {
      precio = (json['precioUnitario'] as num).toDouble();
    } else if (json.containsKey('precio')) {
      precio = (json['precio'] as num).toDouble();
    } else if (json.containsKey('subtotal') && json.containsKey('cantidad')) {
      final subtotal = (json['subtotal'] as num).toDouble();
      final cantidad = (json['cantidad'] as num).toInt();
      precio = cantidad > 0 ? subtotal / cantidad : 0.0;
    }

    return ItemPedido(
      id: json['id'],
      productoId: json['productoId'] ?? '',
      productoNombre: json['productoNombre'],
      producto: producto,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
      precioUnitario: precio,
      notas: json['notas'],
      ingredientesSeleccionados: json['ingredientesSeleccionados'] != null
          ? List<String>.from(json['ingredientesSeleccionados'])
          : [],
    );
  }

  // 🔄 MÉTODOS DE COPIA
  ItemPedido copyWith({
    String? id,
    String? productoId,
    String? productoNombre,
    Producto? producto,
    int? cantidad,
    double? precioUnitario,
    String? notas,
    List<String>? ingredientesSeleccionados,
  }) {
    return ItemPedido(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      productoNombre: productoNombre ?? this.productoNombre,
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      notas: notas ?? this.notas,
      ingredientesSeleccionados: ingredientesSeleccionados ?? this.ingredientesSeleccionados,
    );
  }

  // 🔍 MÉTODOS UTILITARIOS
  @override
  String toString() => 
      'ItemPedido(id: $id, productoId: $productoId, cantidad: $cantidad, precioUnitario: $precioUnitario, subtotal: ${subtotal.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemPedido &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productoId == other.productoId;

  @override
  int get hashCode => id.hashCode ^ productoId.hashCode;

  // 🧪 MÉTODOS DE VALIDACIÓN
  bool get isValid => 
      productoId.isNotEmpty && 
      cantidad > 0 && 
      precioUnitario >= 0;

  List<String> get validationErrors {
    final errors = <String>[];
    if (productoId.isEmpty) errors.add('ProductoId es requerido');
    if (cantidad <= 0) errors.add('Cantidad debe ser mayor a 0');
    if (precioUnitario < 0) errors.add('Precio unitario no puede ser negativo');
    return errors;
  }
}
```

---

## 🔄 **FORMATO JSON ESTÁNDAR**

### **Estructura JSON Unificada:**

```json
{
  "id": "item_123",
  "productoId": "prod_456",
  "productoNombre": "Hamburguesita Especial",
  "cantidad": 2,
  "precioUnitario": 15.50,
  "subtotal": 31.00,
  "notas": "Sin cebolla, extra queso",
  "ingredientesSeleccionados": ["ing_001", "ing_002", "ing_003"]
}
```

### **Campos Opcionales en JSON:**
- `id` - Puede estar ausente en creación
- `productoNombre` - Puede ser null si no está cached
- `notas` - Puede ser null o string vacío
- `subtotal` - Incluido para compatibilidad, pero siempre calculado

---

## 🧪 **CASOS DE PRUEBA**

### **Test 1: Creación Básica**
```java
// Java
ItemPedido item = new ItemPedido("prod123", 3, 12.50);
assertEquals(37.50, item.getSubtotal(), 0.01);
```

```dart
// Dart
final item = ItemPedido(productoId: 'prod123', cantidad: 3, precioUnitario: 12.50);
expect(item.subtotal, equals(37.50));
```

### **Test 2: Serialización Round-trip**
```
Java Object → JSON → Dart Object → JSON → Java Object
Debe mantener todos los datos intactos
```

### **Test 3: Validaciones**
```java
// Debe fallar
assertThrows(IllegalArgumentException.class, () -> {
    new ItemPedido("prod123", 0, 12.50);  // cantidad = 0
});
```

```dart
// Debe fallar
expect(() => ItemPedido(productoId: 'prod123', cantidad: 0, precioUnitario: 12.50), 
       throwsA(isA<AssertionError>()));
```

---

## ⚡ **BENEFICIOS GARANTIZADOS**

### **✅ Eliminación de Ambigüedad**
- Un solo campo precio: `precioUnitario`
- Cálculo consistente de subtotal
- Menos confusión para desarrolladores

### **✅ Sincronización Total**
- Misma lógica en Java y Dart
- JSON compatible en ambas direcciones
- Comportamiento idéntico

### **✅ Mejor Performance**
- JSON más pequeño (menos campos)
- Cálculos optimizados
- Validaciones en el constructor

### **✅ Mantenibilidad Mejorada**
- Un solo lugar para lógica de cálculo
- Tests más simples y confiables
- Cambios futuros más fáciles

---

**SIGUIENTE**: Implementar los modelos actualizados
