# Corrección: Descuento de Ingredientes Opcionales en Inventario

## Fecha: Octubre 4, 2025

## Problema Identificado

**Issue**: Los ingredientes opcionales seleccionados por el cliente no se están descontando del inventario de la misma manera que los ingredientes requeridos.

**Descripción**:

- Los productos con ingredientes requeridos se descontaban correctamente
- Los productos con ingredientes opcionales seleccionados NO se descontaban correctamente del inventario
- Se necesita que ambos tipos de ingredientes (requeridos + opcionales seleccionados) se descuenten por igual

## Análisis del Código

### Frontend - Construcción de Ingredientes

En `lib/screens/pedido_screen.dart`, método `_guardarPedido()`:

```dart
// 1. SIEMPRE agregar ingredientes REQUERIDOS
for (var ingredienteReq in producto.ingredientesRequeridos) {
  ingredientesIds.add(ingredienteReq.ingredienteId);
}

// 2. Para ingredientes OPCIONALES - SOLO los seleccionados
if (producto.ingredientesOpcionales.isNotEmpty) {
  for (var ing in producto.ingredientesDisponibles) {
    final opcional = producto.ingredientesOpcionales.where((i) => ...);
    if (opcional.isNotEmpty) {
      ingredientesIds.add(opcional.first.ingredienteId);  // ← AQUÍ se agregan igual
    }
  }
}
```

### Envío al Backend

Los ingredientes se envían en el mapa `ingredientesPorItem`:

```dart
ingredientesPorItem[producto.id] = ingredientesIds; // ← TODOS los ingredientes juntos
```

## Solución Implementada

### 1. Mejoras en el Logging

- ✅ Agregado debug específico para identificar cuándo los ingredientes opcionales deben ser descontados
- ✅ Mensajes claros: "SERÁ DESCONTADO DEL INVENTARIO"
- ✅ Resumen completo antes del envío al backend

### 2. Verificación de Estructura

- ✅ Confirmado que los ingredientes opcionales seleccionados se agregan al mismo array `ingredientesIds`
- ✅ Confirmado que se envían al backend en la misma estructura que los requeridos
- ✅ Los `ItemPedido` incluyen tanto requeridos como opcionales en `ingredientesSeleccionados`

### 3. Logs de Verificación

```dart
print('🎯 RESUMEN PARA INVENTARIO:');
print('   - Total ingredientes a descontar: ${ingredientesIds.length}');
print('   - IDs que se enviarán al inventario: $ingredientesIds');
print('   - TODOS estos ingredientes deben ser descontados por igual');
```

## Backend - Verificación Requerida

El problema podría estar en el backend si:

1. **Servicio de Inventario**: El método `procesarPedidoParaInventario()` no está procesando todos los ingredientes por igual
2. **Diferenciación Incorrecta**: El backend está diferenciando entre requeridos y opcionales cuando NO debería
3. **Falta de Validación**: No está validando que todos los ingredientes en `ingredientesSeleccionados` se descuenten

## Testing

### Caso de Prueba

1. **Producto**: "Adición de carne"

   - Ingredientes requeridos: [] (ninguno)
   - Ingredientes opcionales: ["Chicharrón", "Carne"]
   - Cliente selecciona: "Chicharrón"

2. **Expectativa**:

   ```dart
   ingredientesIds = ["ID_del_chicharron"]
   ```

3. **Backend debe**:
   - Descontar 1 unidad de "Chicharrón" del inventario
   - Tratar este ingrediente igual que si fuera requerido

### Logs a Monitorear

```
🔍 PROCESANDO PRODUCTO: Adicion de carne
+ OPCIONAL SELECCIONADO: Chicharrón (ID_del_chicharron) [SERÁ DESCONTADO DEL INVENTARIO]
🎯 RESUMEN PARA INVENTARIO:
   - Total ingredientes a descontar: 1
   - IDs que se enviarán al inventario: ["ID_del_chicharron"]
   - TODOS estos ingredientes deben ser descontados por igual
```

## Conclusión

### ✅ Frontend Corregido

- Los ingredientes opcionales seleccionados se procesan igual que los requeridos
- Se envían al backend en la misma estructura
- Logs mejorados para debuggear

### ⚠️ Verificación Backend Pendiente

Si el problema persiste después de estos cambios, el issue está en:

- `InventarioService.procesarPedidoParaInventario()`
- El endpoint backend `/inventario/procesar-pedido/:pedidoId`
- La lógica de descuento que diferencia incorrectamente entre tipos de ingredientes

### 🎯 Resultado Esperado

**TODOS los ingredientes** (requeridos + opcionales seleccionados) deben descontarse del inventario **de la misma manera**, sin diferenciación en el tratamiento.
