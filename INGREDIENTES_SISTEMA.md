# Sistema de Gestión de Ingredientes en Pedidos

Este sistema permite el descuento automático de ingredientes del inventario cuando se agregan productos a un pedido, y la devolución selectiva de ingredientes cuando se cancela un producto.

## Funcionalidades Implementadas

### 1. Descuento Automático de Ingredientes

Cuando se crea o actualiza un pedido, los ingredientes requeridos por cada producto se descontan automáticamente del inventario.

**Cómo funciona:**

- Al llamar `PedidoService.createPedido()` o `PedidoService.updatePedido()`
- Se procesa automáticamente el descuento de ingredientes
- Los ingredientes se descontan según las cantidades requeridas por cada producto

### 2. Cancelación Selectiva de Productos

Cuando se necesita cancelar un producto del pedido, se puede decidir qué ingredientes devolver al inventario.

**Casos de uso:**

- ✅ **Ingredientes frescos**: Se pueden devolver (lechuga, tomate, cebolla)
- ❌ **Ingredientes procesados**: No se pueden devolver (carne asada, papas fritas)

## Uso en el Frontend

### Para mostrar el diálogo de cancelación:

```dart
import '../widgets/cancelar_producto_dialog.dart';

// En tu pantalla de pedidos
void _cancelarProducto(Producto producto) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => CancelarProductoDialog(
      pedidoId: widget.pedido.id,
      producto: producto,
      onProductoCancelado: () {
        // Actualizar la UI después de la cancelación
        _recargarPedido();
      },
    ),
  );

  if (result == true) {
    // El producto fue cancelado exitosamente
    print('Producto cancelado con ingredientes procesados');
  }
}
```

### Para usar directamente los servicios:

```dart
import '../services/pedido_service.dart';
import '../models/cancelar_producto_request.dart';

final pedidoService = PedidoService();

// Obtener ingredientes disponibles para devolución
List<IngredienteDevolucion> ingredientes = await pedidoService
    .obtenerIngredientesParaDevolucion(pedidoId, productoId);

// Marcar qué ingredientes devolver
for (var ingrediente in ingredientes) {
  if (ingrediente.nombre.contains('carne')) {
    // La carne ya fue asada, no se puede devolver
    ingrediente = ingrediente.copyWith(
      devolver: false,
      motivoNoDevolucion: 'Ya fue preparado'
    );
  } else {
    // Los vegetales sí se pueden devolver
    ingrediente = ingrediente.copyWith(devolver: true);
  }
}

// Crear request de cancelación
final request = CancelarProductoRequest(
  pedidoId: pedidoId,
  productoId: productoId,
  ingredientes: ingredientes,
  motivo: 'Cambio de cliente',
  responsable: 'Juan Pérez',
);

// Procesar la cancelación
await pedidoService.cancelarProductoConIngredientes(request);
```

## Modelos de Datos

### IngredienteDevolucion

```dart
class IngredienteDevolucion {
  final String ingredienteId;
  final String nombre;
  final double cantidadDescontada;    // Cantidad que se descontó
  final double cantidadADevolver;    // Cantidad que se va a devolver
  final String unidad;
  final bool devolver;               // Si se devuelve o no
  final String? motivoNoDevolucion;  // Por qué no se devuelve
}
```

### CancelarProductoRequest

```dart
class CancelarProductoRequest {
  final String pedidoId;
  final String productoId;
  final List<IngredienteDevolucion> ingredientes;
  final String motivo;
  final String responsable;
}
```

## Endpoints del Backend (Documentación)

### GET `/api/pedidos/{pedidoId}/producto/{productoId}/ingredientes-devolucion`

Obtiene la lista de ingredientes que fueron descontados del inventario para un producto específico.

**Respuesta:**

```json
{
  "success": true,
  "data": [
    {
      "ingredienteId": "64a1b2c3d4e5f6g7h8i9j0k1",
      "nombre": "Carne de res",
      "cantidadDescontada": 0.25,
      "cantidadADevolver": 0.25,
      "unidad": "kg",
      "devolver": true,
      "motivoNoDevolucion": null
    }
  ]
}
```

### POST `/api/pedidos/cancelar-producto`

Cancela un producto del pedido y devuelve los ingredientes seleccionados al inventario.

**Request Body:**

```json
{
  "pedidoId": "64a1b2c3d4e5f6g7h8i9j0k1",
  "productoId": "64a1b2c3d4e5f6g7h8i9j0k2",
  "ingredientes": [
    {
      "ingredienteId": "64a1b2c3d4e5f6g7h8i9j0k3",
      "nombre": "Lechuga",
      "cantidadDescontada": 0.1,
      "cantidadADevolver": 0.1,
      "unidad": "kg",
      "devolver": true,
      "motivoNoDevolucion": null
    },
    {
      "ingredienteId": "64a1b2c3d4e5f6g7h8i9j0k4",
      "nombre": "Carne asada",
      "cantidadDescontada": 0.25,
      "cantidadADevolver": 0,
      "unidad": "kg",
      "devolver": false,
      "motivoNoDevolucion": "Ya fue preparado"
    }
  ],
  "motivo": "Cambio de cliente",
  "responsable": "Juan Pérez"
}
```

### POST `/api/pedidos/{pedidoId}/procesar-inventario`

Procesa el descuento de ingredientes automáticamente para todo el pedido.

## Configuración Requerida

### 1. Productos con Ingredientes

Asegúrate de que los productos en tu sistema tengan configurados sus `ingredientesRequeridos`:

```json
{
  "nombre": "Hamburguesa Clásica",
  "ingredientesRequeridos": [
    {
      "ingredienteId": "64a1b2c3d4e5f6g7h8i9j0k3",
      "cantidad": 0.1,
      "unidad": "kg"
    },
    {
      "ingredienteId": "64a1b2c3d4e5f6g7h8i9j0k4",
      "cantidad": 0.25,
      "unidad": "kg"
    }
  ]
}
```

### 2. Inventario Actualizado

Mantén el inventario actualizado con las cantidades correctas de cada ingrediente.

## Casos de Uso Ejemplo

### Escenario 1: Cancelación Completa con Devolución

- Cliente cancela hamburguesa antes de cocinar
- Se devuelven: carne cruda, lechuga, tomate, cebolla
- Motivo: "Cambio de cliente"

### Escenario 2: Cancelación Parcial sin Devolución

- Cliente cancela hamburguesa después de cocinar
- No se devuelve: carne asada (ya procesada)
- Se devuelven: lechuga, tomate (aún frescos)
- Motivo: "Error en el pedido"

### Escenario 3: Cancelación por Política

- Producto con ingredientes perecederos
- No se devuelven ingredientes por política de higiene
- Motivo: "Política de la casa"

## Notas Técnicas

1. **Manejo de Errores**: Si falla el procesamiento de inventario, no falla la creación/actualización del pedido
2. **Logging**: Todas las operaciones se registran con logs detallados
3. **Validaciones**: Se valida que existan ingredientes y cantidades suficientes
4. **Trazabilidad**: Cada movimiento de inventario queda registrado con motivo y responsable
