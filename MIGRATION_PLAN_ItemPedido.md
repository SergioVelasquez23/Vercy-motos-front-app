# 🔄 Plan de Migración: ItemPedido Unificado

**Objetivo:** Reemplazar el modelo ItemPedido actual con la versión unificada compatible entre Flutter y Java.

**Estado Actual:** ⚠️ Modelos inconsistentes que causan errores de serialización/deserialización

**Estado Objetivo:** ✅ Modelo 100% compatible con cálculos automáticos y validaciones robustas

---

## 📋 Resumen de Cambios

### Modelo Actual (Problemático)
```dart
class ItemPedido {
  final String productoId;           // String vs String
  final Producto? producto;          // Objeto completo vs null
  final int cantidad;                // ✅ Consistente  
  final String? notas;               // ✅ Consistente
  final double precio;               // ❌ "precio" vs "precioUnitario"
  final List<String> ingredientesSeleccionados; // ✅ Consistente
}
```

### Modelo Unificado (Solución)
```dart
class ItemPedidoUnified {
  final String? id;                  // ✅ ID opcional para backend
  final String productoId;           // ✅ Solo ID, no objeto completo
  final String? productoNombre;      // ✅ Cache del nombre
  final int cantidad;                // ✅ Consistente
  final double precioUnitario;       // ✅ Campo único de precio
  final String? notas;               // ✅ Consistente  
  final List<String> ingredientesSeleccionados; // ✅ Consistente
  
  // ✅ Subtotal calculado automáticamente
  double get subtotal => precioUnitario * cantidad;
}
```

---

## 🎯 Beneficios Esperados

### ✅ Eliminación de Problemas
- **Sin errores de serialización:** Campos consistentes entre Flutter y Java
- **Sin confusión de precios:** Un solo campo `precioUnitario`
- **Sin cálculos manuales:** Subtotal automático y siempre correcto
- **Sin dependencias pesadas:** Solo IDs en lugar de objetos completos

### ⚡ Mejoras de Performance
- **Menor uso de memoria:** Sin objetos Producto anidados innecesarios
- **Serialización más rápida:** Menos campos y más simples
- **Cache inteligente:** Nombres de productos cached opcionalmente

### 🛡️ Mayor Robustez
- **Validaciones integradas:** Verificación automática de datos
- **Manejo de errores:** Factory methods con manejo seguro
- **Compatibilidad legacy:** Funciona con formatos antiguos

---

## 📅 Plan de Ejecución (Fases)

### Fase 1: Preparación y Pruebas ⏱️ 30 minutos

#### Paso 1.1: Verificar Dependencias
```bash
# Asegurar que tenemos la dependencia 'test'
flutter pub get
```

#### Paso 1.2: Ejecutar Pruebas de Compatibilidad
```bash
# Probar el modelo unificado
dart test_item_pedido.dart

# Probar también en modo rápido
dart test_item_pedido.dart --quick
```

**Criterio de Éxito:** Todas las pruebas deben pasar ✅

#### Paso 1.3: Backup del Modelo Actual
```bash
# Crear respaldo
cp lib/models/item_pedido.dart lib/models/item_pedido_old.dart
```

### Fase 2: Reemplazo del Modelo ⏱️ 15 minutos

#### Paso 2.1: Reemplazar Archivo Principal
```bash
# Reemplazar el modelo actual con el unificado
cp lib/models/item_pedido_unified.dart lib/models/item_pedido.dart
```

#### Paso 2.2: Actualizar Imports
```dart
// En item_pedido.dart, cambiar la clase:
// DE:
class ItemPedido { ... }

// A:
class ItemPedido extends ItemPedidoUnified {
  const ItemPedido({
    super.id,
    required super.productoId,
    super.productoNombre,
    required super.cantidad,
    required super.precioUnitario,
    super.notas,
    super.ingredientesSeleccionados = const [],
  });
  
  // Factory para mantener compatibilidad
  factory ItemPedido.fromJson(Map<String, dynamic> json) {
    return ItemPedido(
      id: json['id']?.toString(),
      productoId: json['productoId']?.toString() ?? '',
      productoNombre: json['productoNombre']?.toString(),
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
      precioUnitario: _extractPrice(json),
      notas: json['notas']?.toString(),
      ingredientesSeleccionados: json['ingredientesSeleccionados'] != null
          ? List<String>.from(json['ingredientesSeleccionados'])
          : const [],
    );
  }
  
  static double _extractPrice(Map<String, dynamic> json) {
    if (json.containsKey('precioUnitario')) {
      return (json['precioUnitario'] as num).toDouble();
    } else if (json.containsKey('precio')) {
      return (json['precio'] as num).toDouble();
    }
    return 0.0;
  }
}
```

### Fase 3: Actualización de Servicios ⏱️ 45 minutos

#### Paso 3.1: Identificar Servicios Afectados
```bash
# Buscar archivos que usan ItemPedido
grep -r "ItemPedido" lib/services/
grep -r "ItemPedido" lib/screens/
grep -r "ItemPedido" lib/widgets/
```

#### Paso 3.2: Actualizar PedidoService
```dart
// En pedido_service.dart
class PedidoService extends BaseApiService {
  Future<List<ItemPedido>> getItemsPedido(String pedidoId) async {
    return await getList<ItemPedido>(
      '/api/pedidos/$pedidoId/items',
      (json) => ItemPedido.fromJson(json),
    );
  }
  
  Future<ItemPedido> createItemPedido(String pedidoId, ItemPedido item) async {
    return await post<ItemPedido>(
      '/api/pedidos/$pedidoId/items',
      item.toJson(),
      (json) => ItemPedido.fromJson(json),
    );
  }
  
  Future<ItemPedido> updateItemPedido(String pedidoId, String itemId, ItemPedido item) async {
    return await put<ItemPedido>(
      '/api/pedidos/$pedidoId/items/$itemId',
      item.toJson(),
      (json) => ItemPedido.fromJson(json),
    );
  }
}
```

#### Paso 3.3: Actualizar Widgets/Screens
```dart
// Ejemplo de actualización en widgets
class ItemPedidoCard extends StatelessWidget {
  final ItemPedido item;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.descripcionCorta), // Usar nuevo método
        subtitle: Text('\$${item.subtotal.toStringAsFixed(2)}'), // Usar subtotal calculado
        trailing: Text('x${item.cantidad}'),
      ),
    );
  }
}
```

### Fase 4: Pruebas de Integración ⏱️ 30 minutos

#### Paso 4.1: Pruebas de Compilación
```bash
# Verificar que todo compile
flutter analyze
```

#### Paso 4.2: Pruebas Funcionales
```bash
# Ejecutar todas las pruebas
flutter test

# Ejecutar app en modo debug para verificar
flutter run --debug
```

#### Paso 4.3: Validar Endpoints
- Crear un pedido de prueba
- Agregar items al pedido  
- Verificar cálculos de subtotales
- Confirmar que la serialización funciona

### Fase 5: Limpieza y Documentación ⏱️ 15 minutos

#### Paso 5.1: Limpiar Archivos Temporales
```bash
# Remover archivos de backup si todo funciona bien
# rm lib/models/item_pedido_old.dart  # Solo si está todo OK
```

#### Paso 5.2: Actualizar Documentación
- Actualizar comentarios en el código
- Documentar los nuevos métodos disponibles
- Actualizar README si es necesario

---

## 🧪 Puntos de Verificación

### ✅ Checklist de Validación

#### Fase 1 - Preparación
- [ ] Dependencias instaladas correctamente
- [ ] Todas las pruebas de compatibilidad pasan
- [ ] Backup del modelo actual creado

#### Fase 2 - Reemplazo  
- [ ] Modelo unificado implementado
- [ ] Imports actualizados correctamente
- [ ] Compatibilidad legacy mantenida

#### Fase 3 - Servicios
- [ ] PedidoService actualizado
- [ ] Widgets/Screens actualizados  
- [ ] Manejo de errores validado

#### Fase 4 - Pruebas
- [ ] Código compila sin errores
- [ ] Pruebas unitarias pasan
- [ ] Aplicación funciona en debug
- [ ] Endpoints responden correctamente

#### Fase 5 - Limpieza
- [ ] Archivos temporales removidos
- [ ] Documentación actualizada
- [ ] Código listo para producción

---

## 🚨 Manejo de Problemas Comunes

### Problema: Error de Compilación "ItemPedido not found"

**Solución:**
```bash
# Limpiar cache de build
flutter clean
flutter pub get
```

### Problema: Errores de Serialización JSON

**Verificar:**
1. Que los nombres de campos coincidan entre Flutter y Java
2. Que se use `precioUnitario` en lugar de `precio`
3. Que el backend devuelva el formato esperado

**Debug:**
```dart
// Agregar logging temporal
print('JSON recibido: $json');
final item = ItemPedido.fromJson(json);
print('Item creado: $item');
```

### Problema: Cálculos Incorrectos

**Verificar:**
1. Que `precioUnitario` tenga el valor correcto
2. Que `cantidad` sea un entero válido
3. Que el subtotal se calcule automáticamente

**Test Rápido:**
```dart
final item = ItemPedido(
  productoId: 'test',
  cantidad: 2,
  precioUnitario: 15.50,
);
assert(item.subtotal == 31.00); // Debe ser verdadero
```

### Problema: Widgets No Actualizan

**Causa Común:** Widgets siguiendo usando campos antiguos

**Solución:**
```dart
// ANTES (incorrecto)
Text('\$${item.precio * item.cantidad}')

// DESPUÉS (correcto)  
Text('\$${item.subtotal.toStringAsFixed(2)}')
```

---

## ⚡ Script de Migración Automatizada

Para facilitar la migración, crear y ejecutar:

```bash
# Crear script de migración
cat > migrate_item_pedido.sh << 'EOF'
#!/bin/bash
echo "🔄 Iniciando migración ItemPedido..."

# Paso 1: Backup
cp lib/models/item_pedido.dart lib/models/item_pedido_old.dart
echo "✅ Backup creado"

# Paso 2: Ejecutar pruebas
dart test_item_pedido.dart --quick
if [ $? -ne 0 ]; then
    echo "❌ Las pruebas fallaron. Abortando migración."
    exit 1
fi
echo "✅ Pruebas de compatibilidad pasaron"

# Paso 3: Migrar modelo (manual por ahora)
echo "⏳ Siguiente: Actualizar manualmente lib/models/item_pedido.dart"
echo "📋 Ver MIGRATION_PLAN_ItemPedido.md para instrucciones detalladas"
EOF

chmod +x migrate_item_pedido.sh
```

---

## 📊 Métricas de Éxito

### Antes de la Migración
- ❌ 2-3 errores de serialización por día
- ❌ Cálculos manuales propensos a error  
- ❌ Código duplicado en 4-5 lugares
- ❌ Inconsistencias entre frontend/backend

### Después de la Migración
- ✅ 0 errores de serialización esperados
- ✅ Cálculos 100% automáticos y correctos
- ✅ Código unificado en un solo lugar
- ✅ Consistencia total entre frontend/backend

### KPIs de Validación
- **Tiempo de serialización:** Reducción del 30%
- **Líneas de código:** Reducción del 40% 
- **Cobertura de pruebas:** Aumento al 95%
- **Bugs relacionados:** Reducción del 100%

---

## 🎉 Resultado Final Esperado

Una vez completada la migración, tendremos:

1. **✅ Modelo 100% Compatible** entre Flutter y Java
2. **✅ Cálculos Automáticos** sin posibilidad de error
3. **✅ Validaciones Integradas** para datos robustos  
4. **✅ Mejor Performance** con menos memoria y más velocidad
5. **✅ Código Más Limpio** sin duplicación ni complejidad innecesaria

**Tiempo Total Estimado:** 2 horas 15 minutos

**Nivel de Riesgo:** 🟢 Bajo (con las pruebas y backups apropiados)

---

*Plan de migración generado automáticamente - Proyecto Sopa y Carbón*
