import '../models/pedido.dart';
import '../models/item_pedido.dart';

/// Utilidad para calcular totales considerando descuentos y propinas
/// aplicados correctamente cuando el backend no los procesa bien
class PaymentCalculator {
  /// Calcula el total real de un pedido considerando descuentos y propinas
  /// CORREGIDO: Calcula total correcto para detalles de cierre de caja
  static double calcularTotalReal(Pedido pedido) {
    final subtotal = calcularSubtotal(pedido);
    final totalConDescuento = subtotal - pedido.descuento;
    final totalFinal = totalConDescuento + pedido.propina;

    print('💰 Calculando total real para pedido ${pedido.id}:');
    print('  - Subtotal: \$${subtotal.toStringAsFixed(0)}');
    print('  - Descuento: -\$${pedido.descuento.toStringAsFixed(0)}');
    print('  - Total con descuento: \$${totalConDescuento.toStringAsFixed(0)}');
    print('  - Propina: +\$${pedido.propina.toStringAsFixed(0)}');
    print('  - TOTAL FINAL: \$${totalFinal.toStringAsFixed(0)}');

    return totalFinal;
  }

  /// Calcula el total real para un DetallePedido de resumen de cierre
  static double calcularTotalRealDetalle(
    double totalBase,
    double descuento,
    double propina,
  ) {
    final totalConDescuento = totalBase - descuento;
    final totalFinal = totalConDescuento + propina;

    print('💰 Calculando total real para detalle:');
    print('  - Total base: \$${totalBase.toStringAsFixed(0)}');
    print('  - Descuento: -\$${descuento.toStringAsFixed(0)}');
    print('  - Total con descuento: \$${totalConDescuento.toStringAsFixed(0)}');
    print('  - Propina: +\$${propina.toStringAsFixed(0)}');
    print('  - TOTAL FINAL: \$${totalFinal.toStringAsFixed(0)}');

    return totalFinal;
  }

  /// Calcula el subtotal base de un pedido
  static double calcularSubtotal(Pedido pedido) {
    return pedido.items.fold(
      0.0,
      (sum, item) => sum + (item.precioUnitario * item.cantidad),
    );
  }

  /// Calcula el total con descuentos aplicados
  static double aplicarDescuento(
    double total,
    double descuentoPorcentaje,
    double descuentoValor,
  ) {
    double totalConDescuento = total;

    // Aplicar descuento por porcentaje primero
    if (descuentoPorcentaje > 0) {
      totalConDescuento = totalConDescuento * (1 - (descuentoPorcentaje / 100));
    }

    // Luego restar descuento por valor fijo
    if (descuentoValor > 0) {
      totalConDescuento = totalConDescuento - descuentoValor;
    }

    // No puede ser negativo
    return totalConDescuento < 0 ? 0.0 : totalConDescuento;
  }

  /// Calcula el total final incluyendo propina
  static double calcularTotalConPropina(
    double totalConDescuento,
    double propina,
  ) {
    return totalConDescuento + propina;
  }

  /// Verifica si un pedido debería mostrar valores calculados en lugar de backend
  static bool deberiaUsarCalculoLocal(Pedido pedido) {
    // Si el backend devuelve descuento = 0 y propina = 0,
    // pero hay indicios de que deberían existir, usar cálculo local
    // Por ahora, siempre confiar en los valores del pedido
    return false;
  }

  /// Calcula el total de una lista de items
  static double calcularTotalItems(List<ItemPedido> items) {
    return items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Formatea un valor monetario para mostrar
  static String formatearMoneda(double valor) {
    return '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  /// Calcula estadísticas de ventas considerando descuentos/propinas
  static Map<String, dynamic> calcularEstadisticasVentas(List<Pedido> pedidos) {
    double totalVentas = 0.0;
    double totalDescuentos = 0.0;
    double totalPropinas = 0.0;
    int pedidosPagados = 0;

    for (var pedido in pedidos) {
      if (pedido.estaPagado) {
        pedidosPagados++;

        // Usar totalPagado si está disponible, sino calcular
        if (pedido.totalPagado > 0) {
          totalVentas += pedido.totalPagado;
        } else {
          totalVentas += calcularTotalReal(pedido);
        }

        totalDescuentos += pedido.descuento;
        totalPropinas += pedido.propina;
      }
    }

    return {
      'totalVentas': totalVentas,
      'totalDescuentos': totalDescuentos,
      'totalPropinas': totalPropinas,
      'pedidosPagados': pedidosPagados,
      'promedioVenta': pedidosPagados > 0 ? totalVentas / pedidosPagados : 0.0,
    };
  }

  /// Debug: Imprime información detallada de un pedido para debugging
  static void debugPedido(Pedido pedido, String contexto) {
    print('🔍 DEBUG PEDIDO [$contexto]:');
    print('  - ID: ${pedido.id}');
    print('  - Total base: ${formatearMoneda(pedido.total)}');
    print('  - Descuento: ${formatearMoneda(pedido.descuento)}');
    print('  - Propina: ${formatearMoneda(pedido.propina)}');
    print('  - Total pagado: ${formatearMoneda(pedido.totalPagado)}');
    print('  - Estado: ${pedido.estado}');
    print('  - Está pagado: ${pedido.estaPagado}');
    print('  - Total calculado: ${formatearMoneda(calcularTotalReal(pedido))}');
  }
}
