package com.prog3.security.Services;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.prog3.security.Models.Ingrediente;
import com.prog3.security.Models.IngredienteProducto;
import com.prog3.security.Models.Inventario;
import com.prog3.security.Models.MovimientoInventario;
import com.prog3.security.Models.Producto;
import com.prog3.security.Repositories.IngredienteRepository;
import com.prog3.security.Repositories.InventarioRepository;
import com.prog3.security.Repositories.MovimientoInventarioRepository;
import com.prog3.security.Repositories.ProductoRepository;

/**
 * ✅ SERVICIO CORREGIDO: Descuento unificado y validado de ingredientes
 * 
 * PROBLEMAS CORREGIDOS:
 * 1. Lógica inconsistente entre productos combo/individual
 * 2. Descuento de ingredientes no seleccionados
 * 3. Validaciones de stock insuficiente
 * 4. Sincronización entre Ingrediente e Inventario
 * 5. Logging y trazabilidad mejorados
 */
@Service
public class InventarioIngredientesService {

    @Autowired
    private IngredienteRepository ingredienteRepository;

    @Autowired
    private ProductoRepository productoRepository;

    @Autowired
    private InventarioRepository inventarioRepository;

    @Autowired
    private MovimientoInventarioRepository movimientoInventarioRepository;

    /**
     * ✅ MÉTODO PRINCIPAL CORREGIDO: Descuenta ingredientes con validaciones estrictas
     * 
     * @param productoId ID del producto
     * @param cantidad Cantidad de productos a preparar
     * @param ingredientesSeleccionados Lista de IDs de ingredientes seleccionados
     * @param motivo Motivo del descuento
     */
    public void descontarIngredientesDelInventario(
            String productoId, 
            int cantidad, 
            List<String> ingredientesSeleccionados, 
            String motivo) {
        
        try {
            System.out.println("🔄 INICIANDO DESCUENTO DE INGREDIENTES");
            System.out.println("   Producto: " + productoId);
            System.out.println("   Cantidad: " + cantidad);
            System.out.println("   Ingredientes seleccionados: " + ingredientesSeleccionados);
            System.out.println("   Motivo: " + motivo);
            
            // Validar entrada
            if (cantidad <= 0) {
                System.err.println("❌ Cantidad inválida: " + cantidad);
                return;
            }
            
            if (ingredientesSeleccionados == null) {
                ingredientesSeleccionados = List.of(); // Lista vacía en lugar de null
            }
            
            // Obtener producto
            Optional<Producto> productoOpt = productoRepository.findById(productoId);
            if (!productoOpt.isPresent()) {
                System.err.println("❌ Producto no encontrado: " + productoId);
                return;
            }
            
            Producto producto = productoOpt.get();
            System.out.println("✅ Producto encontrado: " + producto.getNombre() + 
                              " (Tipo: " + producto.getTipoProducto() + 
                              ", Tiene ingredientes: " + producto.isTieneIngredientes() + ")");
            
            // Verificar si el producto tiene ingredientes
            if (!producto.isTieneIngredientes()) {
                System.out.println("ℹ️ Producto sin ingredientes configurados - No se requiere descuento");
                return;
            }
            
            int ingredientesDescontados = 0;
            
            // 1. PROCESAR INGREDIENTES REQUERIDOS (SIEMPRE se descuentan)
            if (producto.getIngredientesRequeridos() != null && !producto.getIngredientesRequeridos().isEmpty()) {
                System.out.println("📋 Procesando " + producto.getIngredientesRequeridos().size() + " ingredientes requeridos:");
                
                for (IngredienteProducto ingredienteReq : producto.getIngredientesRequeridos()) {
                    double cantidadNecesaria = ingredienteReq.getCantidadNecesaria() * cantidad;
                    System.out.println("   • " + ingredienteReq.getNombre() + ": " + cantidadNecesaria + " " + ingredienteReq.getUnidad());
                    
                    boolean descontado = descontarIngredienteIndividual(
                        ingredienteReq.getIngredienteId(),
                        cantidadNecesaria,
                        motivo + " - Ingrediente requerido: " + ingredienteReq.getNombre(),
                        "Sistema"
                    );
                    
                    if (descontado) ingredientesDescontados++;
                }
            } else {
                System.out.println("ℹ️ No hay ingredientes requeridos configurados");
            }
            
            // 2. PROCESAR INGREDIENTES OPCIONALES (solo los seleccionados)
            if (producto.getIngredientesOpcionales() != null && !producto.getIngredientesOpcionales().isEmpty()) {
                System.out.println("📋 Procesando ingredientes opcionales:");
                System.out.println("   Total opcionales disponibles: " + producto.getIngredientesOpcionales().size());
                System.out.println("   Ingredientes seleccionados: " + ingredientesSeleccionados.size());
                
                for (IngredienteProducto ingredienteOpc : producto.getIngredientesOpcionales()) {
                    // ✅ CORRECCIÓN CRÍTICA: Solo procesar si está en la lista de seleccionados
                    if (ingredientesSeleccionados.contains(ingredienteOpc.getIngredienteId())) {
                        double cantidadNecesaria = ingredienteOpc.getCantidadNecesaria() * cantidad;
                        System.out.println("   ✓ Seleccionado: " + ingredienteOpc.getNombre() + 
                                          ": " + cantidadNecesaria + " " + ingredienteOpc.getUnidad());
                        
                        boolean descontado = descontarIngredienteIndividual(
                            ingredienteOpc.getIngredienteId(),
                            cantidadNecesaria,
                            motivo + " - Ingrediente opcional: " + ingredienteOpc.getNombre(),
                            "Sistema"
                        );
                        
                        if (descontado) ingredientesDescontados++;
                    } else {
                        System.out.println("   ○ No seleccionado: " + ingredienteOpc.getNombre() + " - OMITIDO");
                    }
                }
            } else {
                System.out.println("ℹ️ No hay ingredientes opcionales configurados");
            }
            
            System.out.println("✅ DESCUENTO COMPLETADO");
            System.out.println("   Producto: " + producto.getNombre());
            System.out.println("   Ingredientes procesados: " + ingredientesDescontados);
            System.out.println("========================================");
            
        } catch (Exception e) {
            System.err.println("❌ ERROR CRÍTICO en descuento de ingredientes: " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * ✅ MÉTODO AUXILIAR CORREGIDO: Descuenta un ingrediente individual con validaciones
     * 
     * @param ingredienteId ID del ingrediente
     * @param cantidad Cantidad a descontar
     * @param motivo Motivo del descuento
     * @param responsable Quien realiza la operación
     * @return true si se descontó exitosamente, false si hubo error
     */
    private boolean descontarIngredienteIndividual(
            String ingredienteId, 
            double cantidad, 
            String motivo, 
            String responsable) {
        
        try {
            // Validar parámetros
            if (cantidad <= 0) {
                System.out.println("⚠️ Cantidad inválida para ingrediente " + ingredienteId + ": " + cantidad);
                return false;
            }
            
            // Obtener ingrediente
            Optional<Ingrediente> ingredienteOpt = ingredienteRepository.findById(ingredienteId);
            if (!ingredienteOpt.isPresent()) {
                System.err.println("❌ Ingrediente no encontrado: " + ingredienteId);
                return false;
            }
            
            Ingrediente ingrediente = ingredienteOpt.get();
            
            // ✅ NUEVA VALIDACIÓN: Verificar si es descontable
            if (!ingrediente.isDescontable()) {
                System.out.println("⚠️ Ingrediente no descontable: " + ingrediente.getNombre() + " - OMITIDO");
                return true; // No es error, simplemente no se descuenta
            }
            
            // ✅ VALIDACIÓN CRÍTICA: Verificar stock suficiente
            double stockActual = ingrediente.getStockActual();
            if (stockActual < cantidad) {
                System.err.println("❌ STOCK INSUFICIENTE para " + ingrediente.getNombre());
                System.err.println("   Stock disponible: " + stockActual + " " + ingrediente.getUnidad());
                System.err.println("   Cantidad requerida: " + cantidad + " " + ingrediente.getUnidad());
                
                // Registrar movimiento de error (para auditoría)
                registrarMovimientoError(ingrediente, cantidad, motivo, responsable, stockActual);
                return false; // ERROR CRÍTICO - No se puede completar
            }
            
            // Realizar descuento
            double stockNuevo = stockActual - cantidad;
            ingrediente.setStockActual(stockNuevo);
            ingredienteRepository.save(ingrediente);
            
            // ✅ SINCRONIZACIÓN: Actualizar inventario correspondiente
            sincronizarInventario(ingredienteId, stockNuevo);
            
            // Registrar movimiento exitoso
            registrarMovimientoExitoso(ingrediente, cantidad, motivo, responsable, stockActual, stockNuevo);
            
            // ✅ ALERTA DE STOCK BAJO
            if (stockNuevo <= ingrediente.getStockMinimo()) {
                System.out.println("⚠️ ALERTA STOCK BAJO: " + ingrediente.getNombre() + 
                                 " (Actual: " + stockNuevo + ", Mínimo: " + ingrediente.getStockMinimo() + ")");
            }
            
            System.out.println("   ✅ " + ingrediente.getNombre() + ": " + stockActual + " → " + stockNuevo + 
                              " (-" + cantidad + " " + ingrediente.getUnidad() + ")");
            
            return true;
            
        } catch (Exception e) {
            System.err.println("❌ Error descontando ingrediente " + ingredienteId + ": " + e.getMessage());
            return false;
        }
    }

    /**
     * ✅ NUEVO: Sincroniza el stock en la tabla de inventario
     */
    private void sincronizarInventario(String ingredienteId, double nuevoStock) {
        try {
            Inventario inventario = inventarioRepository.findByProductoId(ingredienteId);
            if (inventario != null) {
                // Verificar si hay discrepancia
                if (Math.abs(inventario.getCantidadActual() - nuevoStock) > 0.0001) {
                    System.out.println("🔄 Sincronizando inventario: " + inventario.getProductoNombre() + 
                                     " (" + inventario.getCantidadActual() + " → " + nuevoStock + ")");
                }
                
                inventario.setCantidadActual(nuevoStock);
                inventario.setFechaUltimaActualizacion(LocalDateTime.now());
                inventarioRepository.save(inventario);
            } else {
                // Crear registro de inventario si no existe
                crearRegistroInventario(ingredienteId, nuevoStock);
            }
        } catch (Exception e) {
            System.err.println("⚠️ Error sincronizando inventario para " + ingredienteId + ": " + e.getMessage());
        }
    }

    /**
     * ✅ NUEVO: Crea registro de inventario para ingrediente
     */
    private void crearRegistroInventario(String ingredienteId, double stock) {
        try {
            Optional<Ingrediente> ingredienteOpt = ingredienteRepository.findById(ingredienteId);
            if (ingredienteOpt.isPresent()) {
                Ingrediente ingrediente = ingredienteOpt.get();
                
                Inventario nuevoInventario = new Inventario();
                nuevoInventario.setProductoId(ingredienteId);
                nuevoInventario.setProductoNombre(ingrediente.getNombre());
                nuevoInventario.setCategoria("Ingrediente");
                nuevoInventario.setCantidadActual(stock);
                nuevoInventario.setCantidadMinima(ingrediente.getStockMinimo());
                nuevoInventario.setUnidadMedida(ingrediente.getUnidad());
                nuevoInventario.setCostoUnitario(0.0);
                nuevoInventario.setFechaUltimaActualizacion(LocalDateTime.now());
                nuevoInventario.setEstado("activo");
                
                inventarioRepository.save(nuevoInventario);
                System.out.println("✅ Registro de inventario creado para: " + ingrediente.getNombre());
            }
        } catch (Exception e) {
            System.err.println("❌ Error creando registro de inventario: " + e.getMessage());
        }
    }

    /**
     * ✅ NUEVO: Registra movimiento exitoso de inventario
     */
    private void registrarMovimientoExitoso(
            Ingrediente ingrediente, 
            double cantidad, 
            String motivo, 
            String responsable,
            double stockAnterior, 
            double stockNuevo) {
        try {
            MovimientoInventario movimiento = new MovimientoInventario();
            movimiento.setProductoId(ingrediente.get_id());
            movimiento.setProductoNombre(ingrediente.getNombre());
            movimiento.setTipoMovimiento("salida");
            movimiento.setMotivo(motivo);
            movimiento.setCantidadAnterior(stockAnterior);
            movimiento.setCantidadMovimiento(-cantidad); // Negativo para salidas
            movimiento.setCantidadNueva(stockNuevo);
            movimiento.setResponsable(responsable);
            movimiento.setObservaciones("Descuento automático de inventario");
            movimiento.setFecha(LocalDateTime.now());
            
            movimientoInventarioRepository.save(movimiento);
        } catch (Exception e) {
            System.err.println("⚠️ Error registrando movimiento: " + e.getMessage());
        }
    }

    /**
     * ✅ NUEVO: Registra movimiento de error para auditoría
     */
    private void registrarMovimientoError(
            Ingrediente ingrediente, 
            double cantidadRequerida, 
            String motivo, 
            String responsable,
            double stockActual) {
        try {
            MovimientoInventario movimientoError = new MovimientoInventario();
            movimientoError.setProductoId(ingrediente.get_id());
            movimientoError.setProductoNombre(ingrediente.getNombre());
            movimientoError.setTipoMovimiento("error");
            movimientoError.setMotivo("ERROR: " + motivo + " - Stock insuficiente");
            movimientoError.setCantidadAnterior(stockActual);
            movimientoError.setCantidadMovimiento(0.0); // No se realizó descuento
            movimientoError.setCantidadNueva(stockActual); // Stock sin cambios
            movimientoError.setResponsable(responsable);
            movimientoError.setObservaciones("Intento fallido - Requerido: " + cantidadRequerida + 
                                           ", Disponible: " + stockActual);
            movimientoError.setFecha(LocalDateTime.now());
            
            movimientoInventarioRepository.save(movimientoError);
        } catch (Exception e) {
            System.err.println("⚠️ Error registrando movimiento de error: " + e.getMessage());
        }
    }

    /**
     * ✅ NUEVO: Valida si hay stock suficiente para un producto antes de procesarlo
     * 
     * @param productoId ID del producto
     * @param cantidad Cantidad de productos
     * @param ingredientesSeleccionados Ingredientes seleccionados
     * @return Map con resultado de validación
     */
    public java.util.Map<String, Object> validarStockDisponible(
            String productoId, 
            int cantidad, 
            List<String> ingredientesSeleccionados) {
        
        java.util.Map<String, Object> resultado = new java.util.HashMap<>();
        java.util.List<java.util.Map<String, Object>> ingredientesFaltantes = new java.util.ArrayList<>();
        java.util.List<java.util.Map<String, Object>> alertasBajo = new java.util.ArrayList<>();
        
        try {
            Optional<Producto> productoOpt = productoRepository.findById(productoId);
            if (!productoOpt.isPresent()) {
                resultado.put("stockSuficiente", false);
                resultado.put("error", "Producto no encontrado");
                return resultado;
            }
            
            Producto producto = productoOpt.get();
            
            if (!producto.isTieneIngredientes()) {
                resultado.put("stockSuficiente", true);
                resultado.put("mensaje", "Producto sin ingredientes - No requiere validación");
                return resultado;
            }
            
            if (ingredientesSeleccionados == null) {
                ingredientesSeleccionados = List.of();
            }
            
            // Validar ingredientes requeridos
            if (producto.getIngredientesRequeridos() != null) {
                for (IngredienteProducto ingredienteReq : producto.getIngredientesRequeridos()) {
                    validarIngredienteIndividual(
                        ingredienteReq, cantidad, "requerido", producto.getNombre(),
                        ingredientesFaltantes, alertasBajo
                    );
                }
            }
            
            // Validar ingredientes opcionales seleccionados
            if (producto.getIngredientesOpcionales() != null) {
                for (IngredienteProducto ingredienteOpc : producto.getIngredientesOpcionales()) {
                    if (ingredientesSeleccionados.contains(ingredienteOpc.getIngredienteId())) {
                        validarIngredienteIndividual(
                            ingredienteOpc, cantidad, "opcional", producto.getNombre(),
                            ingredientesFaltantes, alertasBajo
                        );
                    }
                }
            }
            
            boolean stockSuficiente = ingredientesFaltantes.isEmpty();
            
            resultado.put("stockSuficiente", stockSuficiente);
            resultado.put("ingredientesFaltantes", ingredientesFaltantes);
            resultado.put("alertas", alertasBajo);
            resultado.put("producto", producto.getNombre());
            
        } catch (Exception e) {
            resultado.put("stockSuficiente", false);
            resultado.put("error", "Error validando stock: " + e.getMessage());
        }
        
        return resultado;
    }

    /**
     * ✅ MÉTODO AUXILIAR: Valida un ingrediente individual
     */
    private void validarIngredienteIndividual(
            IngredienteProducto ingredienteProducto, 
            int cantidad, 
            String tipo,
            String nombreProducto,
            java.util.List<java.util.Map<String, Object>> ingredientesFaltantes,
            java.util.List<java.util.Map<String, Object>> alertasBajo) {
        
        try {
            Optional<Ingrediente> ingredienteOpt = ingredienteRepository.findById(ingredienteProducto.getIngredienteId());
            if (!ingredienteOpt.isPresent()) return;
            
            Ingrediente ingrediente = ingredienteOpt.get();
            double cantidadNecesaria = ingredienteProducto.getCantidadNecesaria() * cantidad;
            double stockActual = ingrediente.getStockActual();
            
            if (stockActual < cantidadNecesaria) {
                // Stock insuficiente
                java.util.Map<String, Object> faltante = new java.util.HashMap<>();
                faltante.put("ingredienteId", ingrediente.get_id());
                faltante.put("nombre", ingrediente.getNombre());
                faltante.put("stockActual", stockActual);
                faltante.put("cantidadNecesaria", cantidadNecesaria);
                faltante.put("unidad", ingrediente.getUnidad());
                faltante.put("tipo", tipo);
                faltante.put("producto", nombreProducto);
                faltante.put("faltante", cantidadNecesaria - stockActual);
                ingredientesFaltantes.add(faltante);
            } else if (stockActual - cantidadNecesaria <= ingrediente.getStockMinimo()) {
                // Stock bajo pero suficiente
                java.util.Map<String, Object> alerta = new java.util.HashMap<>();
                alerta.put("ingrediente", ingrediente.getNombre());
                alerta.put("stockActual", stockActual);
                alerta.put("stockMinimo", ingrediente.getStockMinimo());
                alerta.put("stockDespues", stockActual - cantidadNecesaria);
                alerta.put("unidad", ingrediente.getUnidad());
                alertasBajo.add(alerta);
            }
        } catch (Exception e) {
            System.err.println("Error validando ingrediente: " + e.getMessage());
        }
    }
}