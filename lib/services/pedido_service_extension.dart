import '../services/sincronizador_service.dart';

/// Esta clase extiende las funcionalidades de PedidoService para integrar
/// la sincronización automática entre pedidos y mesas.
class PedidoServiceExtension {
  static Future<void> sincronizarTras(Function original) async {
    try {
      // Llamada a función original
      await original();

      // Sincronizar después de la operación
      await SincronizadorService().sincronizarEstadoMesasPedidos();
    } catch (e) {
      print('❌ Error en sincronización tras operación de pedido: $e');
      // Re-lanzar la excepción original
      rethrow;
    }
  }
}
