import '../models/producto.dart';
import '../models/item_pedido.dart';

class PedidoHelper {
  static ItemPedido createPedidoItem({
    required Producto producto,
    required int cantidad,
    String? notas,
  }) {
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad debe ser mayor a 0');
    }

    return ItemPedido(
      productoId: producto.id,
      cantidad: cantidad,
      notas: notas,
      precioUnitario: producto.precio,
      productoNombre: producto.nombre,
    );
  }

  static List<ItemPedido> createPedidoItems(List<Producto> productos) {
    return productos
        .map(
          (producto) => createPedidoItem(
            producto: producto,
            cantidad: 1, // Cantidad por defecto
          ),
        )
        .toList();
  }

  static bool validatePedidoItems(List<ItemPedido> items) {
    return items.every(
      (item) => item.productoId.isNotEmpty && item.cantidad > 0,
    );
  }
}
