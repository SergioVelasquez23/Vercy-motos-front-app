# Carga Progresiva de Productos - Guía de Uso

## Resumen

Se ha implementado un sistema de carga progresiva de productos que permite cargar productos de 30-40 por vez usando el endpoint `api/productos` directamente con parámetros de paginación.

## ✨ Nuevas Características

### 1. **Clase ProductosPaginationState**
Maneja el estado completo de la paginación:
- Página actual, tamaño de página, total de elementos
- Estado de carga, productos cargados
- Control de "hay más páginas"

### 2. **Métodos Principales**

#### `iniciarCargaProgresiva({int pageSize = 40})`
- Inicia la carga progresiva desde el principio
- Permite configurar el tamaño de página (recomendado: 30-40)
- Resetea el estado anterior

#### `cargarSiguientePaginaProductos()`
- Carga la siguiente página de productos
- Evita cargas duplicadas
- Actualiza automáticamente el estado

#### `cargarTodosLosProductosProgresivamente()`
- Carga automática de todos los productos
- Permite callback de progreso
- Configurable delay entre páginas

### 3. **Propiedades Útiles**

#### `productosActualmenteCargados`
Lista de todos los productos cargados hasta el momento

#### `estadoPaginacion`
Información completa del estado actual:
```dart
{
  'totalCargados': 120,
  'totalElementos': 500,
  'paginaActual': 3,
  'totalPaginas': 13,
  'hasMore': true,
  'isLoading': false,
  'pageSize': 40,
}
```

## 🚀 Casos de Uso

### Caso 1: Carga Manual Paso a Paso
```dart
// Iniciar con páginas de 30 productos
var resultado = await productoService.iniciarCargaProgresiva(pageSize: 30);
print('Primera página: ${resultado['productos'].length} productos');

// Cargar más páginas cuando sea necesario
while (resultado['hasMore']) {
  resultado = await productoService.cargarSiguientePaginaProductos();
  print('Nueva página: ${resultado['productos'].length} productos');
}
```

### Caso 2: Carga Automática con Progreso
```dart
final productos = await productoService.cargarTodosLosProductosProgresivamente(
  pageSize: 40,
  delayBetweenPages: Duration(milliseconds: 500),
  onProgressUpdate: (progreso) {
    print('Progreso: ${progreso['porcentaje']}%');
  },
);
```

### Caso 3: UI Responsiva
```dart
// Cargar primera página inmediatamente
await productoService.iniciarCargaProgresiva(pageSize: 50);
final primerosProductos = productoService.productosActualmenteCargados;

// Mostrar productos inmediatamente en la UI
mostrarEnUI(primerosProductos);

// Continuar cargando en segundo plano
cargarMasEnSegundoPlano();
```

### Caso 4: Integración con Método Existente
```dart
// Opción tradicional (carga todo de una vez)
final productos1 = await productoService.getProductos(useProgressive: false);

// Opción progresiva (carga automática por páginas)
final productos2 = await productoService.getProductos(useProgressive: true);
```

## 🔍 Búsqueda y Filtrado Local

### Buscar en productos ya cargados:
```dart
// Buscar por término
final productosConPizza = productoService.filtrarProductosCargados(
  searchQuery: 'pizza'
);

// Filtrar por categoría y disponibilidad
final productosDisponibles = productoService.filtrarProductosCargados(
  categoriaId: 'cat123',
  disponible: true
);

// Buscar producto específico en cache
final producto = productoService.buscarProductoEnCache('prod123');
```

## ⚡ Ventajas

1. **Mejor Rendimiento**: No carga todos los productos de una vez
2. **UI Más Responsiva**: Productos disponibles inmediatamente
3. **Menor Uso de Memoria**: Carga gradual evita OutOfMemory
4. **Control Granular**: Decidir cuándo y cuántos cargar
5. **Búsqueda Rápida**: Filtrado local en productos cargados
6. **Compatible**: Mantiene compatibilidad con código existente

## 📊 Configuración Recomendada

### Para UI móvil:
- **pageSize**: 30-40 productos
- **delay**: 300-500ms entre páginas
- Cargar primera página inmediatamente, resto en segundo plano

### Para dashboard web:
- **pageSize**: 50-100 productos  
- **delay**: 200ms entre páginas
- Mostrar indicador de progreso

### Para listados simples:
- Usar `cargarTodosLosProductosProgresivamente()` con callback de progreso

## 🛠️ Configuración del Backend

La implementación usa el endpoint:
```
GET /api/productos?page=0&size=40
```

Respuesta esperada:
```json
{
  "success": true,
  "data": {
    "content": [...], // Array de productos
    "page": 0,
    "totalElements": 500,
    "totalPages": 13
  }
}
```

## 🔄 Control de Estado

### Reiniciar carga:
```dart
productoService.reiniciarCargaProgresiva();
```

### Verificar estado:
```dart
final estado = productoService.estadoPaginacion;
if (estado['hasMore']) {
  // Cargar más
}
```

## 📝 Notas Importantes

1. **Thread Safety**: Los métodos evitan cargas duplicadas
2. **Cache Automático**: Los productos se almacenan en cache automáticamente
3. **Error Handling**: Manejo robusto de errores de red
4. **Compatibilidad**: El método `getProductos()` original sigue funcionando
5. **Performance**: Usa `Producto.fromJsonLigero()` para mejor rendimiento

## 🎯 Ejemplo Completo

Ver archivo: `lib/examples/ejemplo_carga_progresiva_productos.dart`