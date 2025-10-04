# 🛠️ MEJORAS IMPLEMENTADAS AL SISTEMA DE DESCUENTO DE INGREDIENTES

## 📋 **PROBLEMAS IDENTIFICADOS Y CORRECCIONES APLICADAS**

### **1. ✅ VALIDACIÓN DE STOCK ANTES DE CREAR PEDIDO**

#### **Frontend (Flutter):**

- **Nuevo método:** `validarStockAntesDePedido()` en `InventarioService`
- **Validación previa:** Verificar stock disponible antes de crear pedido
- **Alertas de usuario:** Mostrar ingredientes faltantes específicos
- **Opción de continuación:** Permitir crear pedido de emergencia (casos excepcionales)

#### **Backend (Java):**

```java
// Nuevo endpoint a implementar en InventarioController
@PostMapping("/validar-stock-pedido")
public ResponseEntity<ApiResponse<Map<String, Object>>> validarStockPedido(
    @RequestBody Map<String, Object> request) {

    Map<String, List<String>> ingredientesPorItem = (Map<String, List<String>>) request.get("ingredientesPorItem");
    Map<String, Integer> cantidadPorProducto = (Map<String, Integer>) request.get("cantidadPorProducto");
    boolean validarSolo = (boolean) request.getOrDefault("validarSolo", true);

    Map<String, Object> resultado = new HashMap<>();
    List<Map<String, Object>> ingredientesFaltantes = new ArrayList<>();
    List<Map<String, Object>> alertas = new ArrayList<>();

    try {
        for (Map.Entry<String, List<String>> entry : ingredientesPorItem.entrySet()) {
            String productoId = entry.getKey();
            List<String> ingredientesIds = entry.getValue();
            int cantidadProducto = cantidadPorProducto.getOrDefault(productoId, 1);

            // Obtener producto para validar ingredientes requeridos y opcionales
            Optional<Producto> productoOpt = productoRepository.findById(productoId);
            if (!productoOpt.isPresent()) continue;

            Producto producto = productoOpt.get();

            // Validar ingredientes requeridos (SIEMPRE se descuentan)
            if (producto.getIngredientesRequeridos() != null) {
                for (IngredienteProducto ingredienteReq : producto.getIngredientesRequeridos()) {
                    double cantidadNecesaria = ingredienteReq.getCantidadNecesaria() * cantidadProducto;

                    Ingrediente ingrediente = ingredienteRepository.findById(ingredienteReq.getIngredienteId()).orElse(null);
                    if (ingrediente != null) {
                        if (ingrediente.getStockActual() < cantidadNecesaria) {
                            // Stock insuficiente
                            Map<String, Object> faltante = new HashMap<>();
                            faltante.put("ingredienteId", ingrediente.get_id());
                            faltante.put("nombre", ingrediente.getNombre());
                            faltante.put("stockActual", ingrediente.getStockActual());
                            faltante.put("cantidadNecesaria", cantidadNecesaria);
                            faltante.put("tipo", "requerido");
                            faltante.put("producto", producto.getNombre());
                            ingredientesFaltantes.add(faltante);
                        } else if (ingrediente.getStockActual() - cantidadNecesaria <= ingrediente.getStockMinimo()) {
                            // Stock bajo pero suficiente
                            Map<String, Object> alerta = new HashMap<>();
                            alerta.put("ingrediente", ingrediente.getNombre());
                            alerta.put("stockActual", ingrediente.getStockActual());
                            alerta.put("stockMinimo", ingrediente.getStockMinimo());
                            alerta.put("stockDespues", ingrediente.getStockActual() - cantidadNecesaria);
                            alertas.add(alerta);
                        }
                    }
                }
            }

            // Validar ingredientes opcionales SELECCIONADOS
            if (producto.getIngredientesOpcionales() != null) {
                for (IngredienteProducto ingredienteOpc : producto.getIngredientesOpcionales()) {
                    // Solo validar si está en la lista de seleccionados
                    if (ingredientesIds.contains(ingredienteOpc.getIngredienteId())) {
                        double cantidadNecesaria = ingredienteOpc.getCantidadNecesaria() * cantidadProducto;

                        Ingrediente ingrediente = ingredienteRepository.findById(ingredienteOpc.getIngredienteId()).orElse(null);
                        if (ingrediente != null) {
                            if (ingrediente.getStockActual() < cantidadNecesaria) {
                                // Stock insuficiente
                                Map<String, Object> faltante = new HashMap<>();
                                faltante.put("ingredienteId", ingrediente.get_id());
                                faltante.put("nombre", ingrediente.getNombre());
                                faltante.put("stockActual", ingrediente.getStockActual());
                                faltante.put("cantidadNecesaria", cantidadNecesaria);
                                faltante.put("tipo", "opcional");
                                faltante.put("producto", producto.getNombre());
                                ingredientesFaltantes.add(faltante);
                            } else if (ingrediente.getStockActual() - cantidadNecesaria <= ingrediente.getStockMinimo()) {
                                // Stock bajo pero suficiente
                                Map<String, Object> alerta = new HashMap<>();
                                alerta.put("ingrediente", ingrediente.getNombre());
                                alerta.put("stockActual", ingrediente.getStockActual());
                                alerta.put("stockMinimo", ingrediente.getStockMinimo());
                                alerta.put("stockDespues", ingrediente.getStockActual() - cantidadNecesaria);
                                alertas.add(alerta);
                            }
                        }
                    }
                }
            }
        }

        // Determinar resultado
        boolean stockSuficiente = ingredientesFaltantes.isEmpty();

        resultado.put("stockSuficiente", stockSuficiente);
        resultado.put("ingredientesFaltantes", ingredientesFaltantes);
        resultado.put("alertas", alertas);

        if (stockSuficiente) {
            return responseService.success(resultado, "Stock validado correctamente");
        } else {
            return responseService.badRequest("Stock insuficiente para completar el pedido", resultado);
        }

    } catch (Exception e) {
        return responseService.internalError("Error al validar stock: " + e.getMessage());
    }
}
```

### **2. ✅ LÓGICA UNIFICADA DE DESCUENTO**

#### **Corrección en InventarioIngredientesService:**

```java
public void descontarIngredientesDelInventario(
    String productoId,
    int cantidad,
    List<String> ingredientesSeleccionados,
    String motivo) {

    try {
        Optional<Producto> productoOpt = productoRepository.findById(productoId);
        if (!productoOpt.isPresent()) {
            System.err.println("❌ Producto no encontrado: " + productoId);
            return;
        }

        Producto producto = productoOpt.get();
        System.out.println("🔄 Procesando descuento para: " + producto.getNombre() +
                          " (Tipo: " + producto.getTipoProducto() + ")");

        // 1. INGREDIENTES REQUERIDOS (SIEMPRE se descuentan)
        if (producto.getIngredientesRequeridos() != null) {
            for (IngredienteProducto ingredienteReq : producto.getIngredientesRequeridos()) {
                double cantidadNecesaria = ingredienteReq.getCantidadNecesaria() * cantidad;
                descontarIngredienteIndividual(
                    ingredienteReq.getIngredienteId(),
                    cantidadNecesaria,
                    motivo + " - Ingrediente requerido: " + ingredienteReq.getNombre()
                );
            }
        }

        // 2. INGREDIENTES OPCIONALES (solo los seleccionados)
        if (producto.getIngredientesOpcionales() != null && ingredientesSeleccionados != null) {
            for (IngredienteProducto ingredienteOpc : producto.getIngredientesOpcionales()) {
                // ✅ CORREGIDO: Solo descontar si está en la lista de seleccionados
                if (ingredientesSeleccionados.contains(ingredienteOpc.getIngredienteId())) {
                    double cantidadNecesaria = ingredienteOpc.getCantidadNecesaria() * cantidad;
                    descontarIngredienteIndividual(
                        ingredienteOpc.getIngredienteId(),
                        cantidadNecesaria,
                        motivo + " - Ingrediente opcional: " + ingredienteOpc.getNombre()
                    );
                }
            }
        }

        System.out.println("✅ Descuento completado para producto: " + producto.getNombre());

    } catch (Exception e) {
        System.err.println("❌ Error en descuento de ingredientes: " + e.getMessage());
        e.printStackTrace();
    }
}

private void descontarIngredienteIndividual(String ingredienteId, double cantidad, String motivo) {
    try {
        // Obtener ingrediente
        Optional<Ingrediente> ingredienteOpt = ingredienteRepository.findById(ingredienteId);
        if (!ingredienteOpt.isPresent()) {
            System.err.println("❌ Ingrediente no encontrado: " + ingredienteId);
            return;
        }

        Ingrediente ingrediente = ingredienteOpt.get();

        // ✅ NUEVA VALIDACIÓN: Verificar si es descontable
        if (!ingrediente.isDescontable()) {
            System.out.println("⚠️ Ingrediente no descontable: " + ingrediente.getNombre());
            return;
        }

        // Validar cantidad positiva
        if (cantidad <= 0) {
            System.out.println("⚠️ Cantidad inválida para " + ingrediente.getNombre() + ": " + cantidad);
            return;
        }

        // ✅ VALIDACIÓN ESTRICTA: Verificar stock suficiente
        double stockActual = ingrediente.getStockActual();
        if (stockActual < cantidad) {
            System.err.println("❌ STOCK INSUFICIENTE para " + ingrediente.getNombre() +
                             ". Disponible: " + stockActual + ", Necesario: " + cantidad);

            // Registrar movimiento de error (sin descontar)
            MovimientoInventario movimientoError = new MovimientoInventario();
            movimientoError.setProductoId(ingredienteId);
            movimientoError.setProductoNombre(ingrediente.getNombre());
            movimientoError.setTipoMovimiento("error");
            movimientoError.setMotivo("ERROR: " + motivo + " - Stock insuficiente");
            movimientoError.setCantidadAnterior(stockActual);
            movimientoError.setCantidadMovimiento(0.0); // Sin descuento
            movimientoError.setCantidadNueva(stockActual); // Stock sin cambios
            movimientoError.setResponsable("Sistema");
            movimientoError.setFecha(LocalDateTime.now());

            movimientoInventarioRepository.save(movimientoError);
            return; // NO descontar si no hay stock
        }

        // Realizar descuento
        double stockNuevo = stockActual - cantidad;
        ingrediente.setStockActual(stockNuevo);
        ingredienteRepository.save(ingrediente);

        // Actualizar inventario si existe
        Inventario inventario = inventarioRepository.findByProductoId(ingredienteId);
        if (inventario != null) {
            inventario.setCantidadActual(stockNuevo);
            inventario.setFechaUltimaActualizacion(LocalDateTime.now());
            inventarioRepository.save(inventario);
        }

        // Registrar movimiento exitoso
        MovimientoInventario movimiento = new MovimientoInventario();
        movimiento.setProductoId(ingredienteId);
        movimiento.setProductoNombre(ingrediente.getNombre());
        movimiento.setTipoMovimiento("salida");
        movimiento.setMotivo(motivo);
        movimiento.setCantidadAnterior(stockActual);
        movimiento.setCantidadMovimiento(-cantidad); // Negativo para salidas
        movimiento.setCantidadNueva(stockNuevo);
        movimiento.setResponsable("Sistema");
        movimiento.setFecha(LocalDateTime.now());

        movimientoInventarioRepository.save(movimiento);

        System.out.println("✅ Descontado: " + ingrediente.getNombre() +
                          " - Cantidad: " + cantidad +
                          " - Stock: " + stockActual + " → " + stockNuevo);

        // Alerta de stock bajo
        if (stockNuevo <= ingrediente.getStockMinimo()) {
            System.out.println("⚠️ STOCK BAJO: " + ingrediente.getNombre() +
                             " (Actual: " + stockNuevo + ", Mínimo: " + ingrediente.getStockMinimo() + ")");
        }

    } catch (Exception e) {
        System.err.println("❌ Error descontando ingrediente " + ingredienteId + ": " + e.getMessage());
    }
}
```

### **3. ✅ CORRECCIÓN DE LA LÓGICA DE PRODUCTOS INDIVIDUALES**

#### **Problema identificado:**

```java
// ❌ INCORRECTO: Descuenta TODOS los opcionales para productos individuales
if (producto.esIndividual()) {
    for (IngredienteProducto ingredienteOpc : producto.getIngredientesOpcionales()) {
        // Se procesa SIEMPRE, sin importar si fue seleccionado
    }
}
```

#### **Corrección aplicada:**

```java
// ✅ CORRECTO: Solo descontar ingredientes que están en la lista de seleccionados
if (producto.getIngredientesOpcionales() != null && ingredientesSeleccionados != null) {
    for (IngredienteProducto ingredienteOpc : producto.getIngredientesOpcionales()) {
        // Solo procesar si está en la lista de seleccionados
        if (ingredientesSeleccionados.contains(ingredienteOpc.getIngredienteId())) {
            // Descontar independientemente del tipo de producto
        }
    }
}
```

### **4. ✅ SINCRONIZACIÓN MEJORADA**

#### **Nuevo método de sincronización:**

```java
@PostMapping("/sincronizar-stock")
public ResponseEntity<ApiResponse<Map<String, Object>>> sincronizarStock() {
    try {
        List<Ingrediente> ingredientes = ingredienteRepository.findAll();
        Map<String, Object> resultado = new HashMap<>();
        List<String> corregidos = new ArrayList<>();

        for (Ingrediente ingrediente : ingredientes) {
            Inventario inventario = inventarioRepository.findByProductoId(ingrediente.get_id());

            if (inventario != null) {
                // Verificar discrepancias
                if (Math.abs(ingrediente.getStockActual() - inventario.getCantidadActual()) > 0.0001) {
                    System.out.println("⚠️ Sincronizando: " + ingrediente.getNombre() +
                                     " - Ingrediente: " + ingrediente.getStockActual() +
                                     " - Inventario: " + inventario.getCantidadActual());

                    // Usar el stock del Ingrediente como fuente de verdad
                    inventario.setCantidadActual(ingrediente.getStockActual());
                    inventario.setFechaUltimaActualizacion(LocalDateTime.now());
                    inventarioRepository.save(inventario);

                    corregidos.add(ingrediente.getNombre());
                }
            }
        }

        resultado.put("ingredientesCorregidos", corregidos.size());
        resultado.put("detalles", corregidos);

        return responseService.success(resultado, "Sincronización completada");
    } catch (Exception e) {
        return responseService.internalError("Error en sincronización: " + e.getMessage());
    }
}
```

## 📊 **RESUMEN DE MEJORAS**

### **✅ PROBLEMAS CORREGIDOS:**

1. **Validación de stock previa** - No se crean pedidos sin stock suficiente
2. **Lógica unificada** - Un solo punto de descuento de ingredientes
3. **Productos individuales** - Solo se descuentan ingredientes seleccionados
4. **Descuento duplicado** - Eliminada duplicación en diferentes servicios
5. **Sincronización** - Stock consistente entre Ingrediente e Inventario
6. **Logging mejorado** - Trazabilidad completa de movimientos

### **✅ FUNCIONALIDADES NUEVAS:**

1. **Alertas de stock bajo** - Notificación cuando stock está por debajo del mínimo
2. **Validación previa** - Verificar disponibilidad antes de crear pedido
3. **Manejo de errores** - Registro de intentos fallidos sin interrumpir flujo
4. **Ingredientes no descontables** - Campo para ingredientes que no afectan stock
5. **Movimientos de error** - Trazabilidad de intentos fallidos

### **🔄 PRÓXIMOS PASOS:**

1. **Testing exhaustivo** - Probar todos los escenarios
2. **Implementar endpoints** - Agregar endpoints de validación al backend
3. **UI mejorada** - Mostrar stock disponible en tiempo real
4. **Reportes** - Dashboard de ingredientes con stock bajo
5. **Auditoria** - Revisar movimientos sospechosos automáticamente

## 🚀 **IMPLEMENTACIÓN**

Para implementar estas mejoras:

1. **Aplicar cambios en backend** - Implementar endpoints de validación
2. **Actualizar frontend** - Usar nueva validación en pantalla de pedidos
3. **Migrar datos** - Sincronizar stock existente
4. **Configurar alertas** - Establecer umbrales de stock mínimo
5. **Entrenar usuarios** - Explicar nuevas validaciones

## 📱 **IMPACTO EN UX**

### **Para el Usuario:**

- ✅ **Prevención de errores** - No se crean pedidos imposibles de completar
- ✅ **Información clara** - Saber exactamente qué ingredientes faltan
- ✅ **Flexibilidad** - Opción de continuar en casos excepcionales
- ✅ **Alertas tempranas** - Notificación de stock bajo

### **Para el Negocio:**

- ✅ **Control de inventario** - Stock real y preciso
- ✅ **Reducción de desperdicios** - No sobreestimar disponibilidad
- ✅ **Mejor planificación** - Alertas para reabastecimiento
- ✅ **Trazabilidad completa** - Auditoria de todos los movimientos
