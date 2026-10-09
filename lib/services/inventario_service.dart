import 'dart:async';
import '../models/movimiento_inventario.dart';
import 'base_api_service.dart';

/// Historial de movimientos de inventario de productos.
///
/// El stock solo lo mueve el backend (ventas, compras, devoluciones, traslados y
/// ajustes pasan por su InventarioService); el front únicamente consulta el historial.
class InventarioService {
  final BaseApiService _apiService = BaseApiService();
  static const String _baseEndpoint = 'api/inventario';

  /// Movimientos de inventario, más recientes primero.
  Future<List<MovimientoInventario>> getMovimientosInventario() async {
    try {
      final response = await _apiService.getList<MovimientoInventario>(
        '$_baseEndpoint/movimientos',
        (json) => MovimientoInventario.fromJson(json),
      );

      if (response.success && response.data != null) {
        return response.data!;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
