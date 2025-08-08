import 'lib/services/producto_service.dart';

void main() async {
  final ProductoService productoService = ProductoService();

  try {
    // Get all products
    final productos = await productoService.getProductos();

    // Test backend verificatio

    for (final producto in productos) {
      if (producto.tipoProducto == 'combo') {
        try {
          final esCombo = await productoService.verificarSiEsCombo(producto.id);
          final ingredientesOpcionales = await productoService
              .getIngredientesOpcionalesCombo(producto.id);
        } catch (e) {
          print('❌ Error: $e');
        }
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
