## 🔧 **Resumen de cambios implementados para mesas especiales:**

### ✅ **Problemas identificados y solucionados:**

1. **📊 Debug mejorado**: Añadí logs detallados en `buildMesaEspecial` para verificar:

   - Número de pedidos activos encontrados
   - Total calculado de los pedidos
   - Estado final (OCUPADA/DISPONIBLE)

2. **🔄 Actualización forzada**: Implementé actualización adicional específica para mesas especiales cuando se regresa de crear un pedido:

   - Detecta automáticamente si es mesa especial
   - Añade un delay de 500ms para que se propague en el backend
   - Fuerza un rebuild adicional del widget

3. **🎯 Método de detección**: Creé `_esMesaEspecial()` para identificar correctamente las mesas especiales:
   - DOMICILIO
   - CAJA
   - MESA AUXILIAR
   - DEUDAS
   - Mesas especiales creadas por el usuario

### 🚀 **Cómo funciona ahora:**

1. **Al crear/actualizar un pedido** en una mesa especial:

   - Se ejecuta `_recargarMesasConCards()` normalmente
   - Se detecta que es mesa especial
   - Se espera 500ms adicionales
   - Se fuerza un rebuild extra con `_widgetRebuildKey++`

2. **En el `FutureBuilder` de `buildMesaEspecial`**:
   - Se obtienen los pedidos de la mesa
   - Se filtran solo los activos (`EstadoPedido.activo`)
   - Se calcula el total correctamente
   - Se muestra el estado y total dinámicamente
   - Se logean detalles para debugging

### 🧪 **Para probar:**

1. **Ir a una mesa especial** (Domicilio, Caja, Mesa Auxiliar, Deudas)
2. **Crear un pedido** con productos
3. **Guardar el pedido**
4. **Verificar** que la mesa especial ahora muestra:
   - Estado: "1 pedido" (en lugar de "Disponible")
   - Color: Rojo (ocupada) en lugar de verde
   - Total: El monto del pedido debajo del estado

### 📋 **Logs de debug a revisar:**

En la consola deberías ver:

```
🔍 Mesa especial "Domicilio" tiene 1 pedidos activos
   - Pedido ABC123: $25000 - Estado: EstadoPedido.activo
📊 Mesa especial "Domicilio": OCUPADA - 1 pedidos - Total: $25000.00
🔄 Pedido creado/actualizado en mesa Domicilio - Iniciando recarga...
🔄 Mesa especial detectada - Forzando actualización adicional...
```

### ⚡ **Si sigue sin funcionar:**

El problema podría estar en:

1. **Cache del backend** - el servidor devuelve datos antiguos
2. **Nombres de mesa** - diferencias en mayúsculas/espacios
3. **Timing del FutureBuilder** - se ejecuta antes de que se guarde

En ese caso necesitaríamos investigar más profundo el servicio `getPedidosByMesa()`.

**¿Quieres que probemos esto primero?** Los logs nos dirán exactamente qué está pasando.
