# Solución de Concurrencia Multi-usuario

## Problema Original

- **Situación**: 2 usuarios están en el panel de mesas y van a agregar un producto a una mesa que ya tiene un pedido.
- **Error**: En vez de mostrar los productos del pedido actual, hace como que no hay nada.
- **Causa**: Múltiples usuarios acceden simultáneamente sin verificar el estado actual de la mesa.

## Solución Implementada

### 1. Control de Bloqueo Temporal (mesas_screen.dart)

```dart
// Variables para control de concurrencia
final Map<String, DateTime> _mesasEnEdicion = {};
final int _tiempoBloqueoSegundos = 30; // Bloqueo temporal de 30 segundos

// Verificar si mesa está siendo editada
bool _verificarSiMesaEstaEnEdicion(String nombreMesa)

// Bloquear mesa temporalmente
void _bloquearMesaTemporalmente(String nombreMesa)

// Liberar bloqueo manual
void _liberarBloqueoMesa(String nombreMesa)
```

### 2. Mejora en Obtención de Pedido Activo

- **Verificación previa**: Antes de acceder a una mesa, se verifica si está bloqueada por otro usuario.
- **Bloqueo automático**: Al acceder a una mesa, se bloquea temporalmente (30 segundos).
- **Liberación segura**: El bloqueo se libera tanto en éxito como en error.
- **Mensaje al usuario**: Si la mesa está bloqueada, se muestra un mensaje informativo.

### 3. Modificación en MesaCard (mesa_card.dart)

```dart
// Modificación del onTap para usar pedido existente
onTap: () async {
  print('🔄 [MESA_CARD] Mesa ${mesa.nombre} seleccionada');

  if (onObtenerPedidoActivo != null) {
    final pedidoExistente = await onObtenerPedidoActivo!(mesa);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PedidoScreen(
          mesa: mesa,
          pedidoExistente: pedidoExistente, // ✅ Pasar pedido existente
        ),
      ),
    );
  }
}
```

### 4. Logging Detallado para Debugging

- **Seguimiento completo**: Logs detallados en cada paso del proceso.
- **Identificación de problemas**: Alertas cuando hay múltiples pedidos activos.
- **Estado de bloqueos**: Información sobre cuándo se bloquean y liberan las mesas.

## Flujo de Funcionamiento

1. **Usuario hace clic en mesa**:

   - Se verifica si la mesa está bloqueada por otro usuario
   - Si está bloqueada: Se muestra mensaje y se cancela la operación

2. **Mesa disponible**:

   - Se bloquea temporalmente la mesa (30 segundos)
   - Se busca el pedido activo en el servidor
   - Se verifica que el pedido tenga ID válido

3. **Navegación a PedidoScreen**:

   - Se pasa el `pedidoExistente` como parámetro
   - Se libera el bloqueo de la mesa
   - PedidoScreen carga los items existentes del pedido

4. **Manejo de errores**:
   - Si hay error, se libera el bloqueo automáticamente
   - Si la mesa aparece ocupada pero sin pedido, se corrige su estado

## Beneficios de la Solución

1. **Prevención de overwrites**: Ya no se sobreescriben pedidos existentes
2. **Feedback visual**: Los usuarios saben cuándo una mesa está siendo editada
3. **Bloqueo temporal**: Evita accesos simultáneos conflictivos
4. **Auto-recuperación**: Los bloqueos se liberan automáticamente
5. **Corrección automática**: Estados inconsistentes de mesa se corrigen
6. **Debugging mejorado**: Logs detallados para identificar problemas

## Mensajes de Usuario

- **Mesa bloqueada**: "Mesa X está siendo editada por otro usuario. Inténtalo en unos segundos."
- **Tiempo de bloqueo**: 30 segundos con liberación automática
- **Feedback visual**: SnackBar con color naranja para indicar bloqueo temporal

## Testing Recomendado

1. **Caso 1**: 2 usuarios acceden a la misma mesa simultáneamente

   - Resultado esperado: Solo uno puede acceder, el otro ve mensaje de bloqueo

2. **Caso 2**: Usuario accede a mesa con pedido existente

   - Resultado esperado: Se cargan los productos del pedido actual

3. **Caso 3**: Bloqueo automático expira

   - Resultado esperado: Después de 30 segundos, la mesa queda disponible

4. **Caso 4**: Error durante acceso a mesa
   - Resultado esperado: El bloqueo se libera y la mesa queda disponible

Esta solución garantiza que múltiples usuarios puedan trabajar en el sistema sin sobreescribir el trabajo de otros, manteniendo la integridad de los datos y proporcionando una experiencia de usuario clara y consistente.
