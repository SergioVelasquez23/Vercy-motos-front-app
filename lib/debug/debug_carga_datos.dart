// Imports deben ir al inicio
import '../config/endpoints_config.dart';
import '../services/producto_service.dart';

// Script de debug para verificar carga de datos
void main() async {
  print('🔍 Iniciando debug de carga de datos...');

  // 1. Verificar URL base
  print('📡 URL Base: ${EndpointsConfig.baseUrl}');

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
    print('❌ Error cargando productos: $e');
  }
}

Future<void> debugCategorias() async {
  try {
    print('🏷️ Probando carga de categorías...');
    final productoService = ProductoService();
    final categorias = await productoService.getCategorias();
    print('✅ Categorías cargadas: ${categorias.length}');
    if (categorias.isNotEmpty) {
      print('   - Primera categoría: ${categorias.first.nombre}');
    }
  } catch (e) {
    print('❌ Error cargando categorías: $e');
  }
}
