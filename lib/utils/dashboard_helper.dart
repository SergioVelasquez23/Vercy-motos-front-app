import '../models/pedido.dart';

/// Utilidad para corregir inconsistencias en el cálculo de ventas y reportes
class DashboardHelper {
  /// Verifica si un pedido debe ser contado como una venta según criterios mejorados
  static bool esPedidoPagado(Pedido pedido) {
    return pedido.estaPagado;
  }

  /// Calcula el total de ventas para una lista de pedidos,
  /// considerando el método estaPagado para identificación correcta
  static double calcularTotalVentas(List<Pedido> pedidos) {
    double total = 0.0;
    int contadorPagados = 0;
    int pedidosActivos = 0;
    List<Map<String, dynamic>> detallesPagados = [];

    for (var pedido in pedidos) {
      print(
        '📋 Analizando pedido ${pedido.id}: estaPagado=${pedido.estaPagado}, estado=${pedido.estado}, total=${pedido.total}, totalPagado=${pedido.totalPagado}',
      );

      if (pedido.estaPagado) {
        // Usar totalPagado si está disponible, de lo contrario usar total regular
        final montoVenta = pedido.totalPagado > 0
            ? pedido.totalPagado
            : pedido.total;
        total += montoVenta;
        contadorPagados++;

        detallesPagados.add({
          'id': pedido.id,
          'monto': montoVenta,
          'totalOriginal': pedido.total,
          'totalPagado': pedido.totalPagado,
        });
      } else if (pedido.estado == EstadoPedido.activo) {
        pedidosActivos++;
      }
    }

      
      
      
      
      
      

    return total;
  }
}
