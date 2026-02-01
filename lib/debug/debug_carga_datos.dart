// Imports deben ir al inicio
import '../config/endpoints_config.dart';
import '../services/producto_service.dart';

// Script de debug para verificar carga de datos
void main() async {
    

  // 1. Verificar URL base
    

  // 2. Probar carga de productos
  await debugProductos();

  // 3. Probar carga de categorías
  await debugCategorias();
}

Future<void> debugProductos() async {
  try {
    final productoService = ProductoService();
    final productos = await productoService.getProductos(useProgressive: true);
    if (productos.isNotEmpty) {
    }
  } catch (e) {
      
  }
}

Future<void> debugCategorias() async {
  try {
      
    final productoService = ProductoService();
    final categorias = await productoService.getCategorias();
      
    if (categorias.isNotEmpty) {
        
    }
  } catch (e) {
      
  }
}
