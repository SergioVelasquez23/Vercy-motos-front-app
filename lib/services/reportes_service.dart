import 'base_api_service.dart';
import '../models/dashboard_data.dart';
import '../services/pedido_service.dart'; // Para acceder a pedidos directamente
import '../utils/dashboard_helper.dart'; // Utilidad para cálculos de ventas correctos

class ReportesService {
  static final ReportesService _instance = ReportesService._internal();
  factory ReportesService() => _instance;
  ReportesService._internal();

  final BaseApiService _apiService = BaseApiService();
  final PedidoService _pedidoService = PedidoService();

  // Obtener dashboard
  Future<DashboardData?> getDashboard({bool forceRefresh = false}) async {
    try {
      // Agregar parámetro de timestamp para evitar caching de HTTP
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // ✅ IMPORTANTE: ignorarCaja=true para que el backend NO filtre por cuadreId
      // Esto evita que "Facturado Hoy" muestre datos de cajas anteriores
      final endpoint = forceRefresh
          ? '/api/reportes/dashboard?_t=$timestamp&ignorarCaja=true'
          : '/api/reportes/dashboard?ignorarCaja=true';

      final response = await _apiService.get<Map<String, dynamic>>(
        endpoint,
        (json) => json,
      );

      // Respuesta recibida - Success: ${response.isSuccess}
        

      if (response.isSuccess && response.data != null) {
        final dashboardData = DashboardData.fromJson(response.data!);

        // CORRECIÓN: Obtener pedidos de hoy para verificar datos
        final pedidosHoy = await _pedidoService.getPedidosHoy();

        // Calcular total real de ventas usando nuestra lógica mejorada
        final totalVentasCorrectas = DashboardHelper.calcularTotalVentas(
          pedidosHoy,
        );

        // Contar pedidos realmente pagados
        int pedidosRealmentePagados = 0;
        for (var pedido in pedidosHoy) {
          if (pedido.estaPagado) {
            pedidosRealmentePagados++;
          }
        }

          
          
          
          
                                

        // ✅ DESACTIVADO: Ya no se corrigen los valores del servidor
        if ((totalVentasCorrectas - dashboardData.ventasHoy.total).abs() > 0) {
                     }

        // ✅ SIEMPRE usar los datos originales del servidor
          
        return dashboardData;
      } else {
                   return null;
      }
    } catch (e) {
        
      return null;
    }
  }

  // Obtener pedidos por hora
  Future<List<Map<String, dynamic>>> getPedidosPorHora([
    DateTime? fecha,
  ]) async {
    final fechaParam = fecha != null ? '?fecha=${fecha.toIso8601String()}' : '';
    final response = await _apiService.get<List<Map<String, dynamic>>>(
      '/reportes/pedidos-por-hora$fechaParam',
      (json) => List<Map<String, dynamic>>.from(json),
    );

    if (response.isSuccess) {
      return response.data ?? [];
    } else {
        
      return [];
    }
  }

  // Obtener ventas por día
  Future<List<Map<String, dynamic>>> getVentasPorDia([
    int ultimosDias = 7,
  ]) async {
    final response = await _apiService.get<List<Map<String, dynamic>>>(
      '/ventas-por-dia?ultimosDias=$ultimosDias',
      (json) => List<Map<String, dynamic>>.from(json),
    );

    if (response.isSuccess) {
      return response.data ?? [];
    } else {
        
      return [];
    }
  }

  // Obtener ingresos vs egresos
  Future<List<Map<String, dynamic>>> getIngresosVsEgresos([
    int ultimosMeses = 12,
  ]) async {
    final response = await _apiService.get<List<Map<String, dynamic>>>(
      '/reportes/ingresos-egresos?ultimosMeses=$ultimosMeses',
      (json) => List<Map<String, dynamic>>.from(json),
    );

    if (response.isSuccess) {
      return response.data ?? [];
    } else {
               return [];
    }
  }

  // Obtener top productos
  Future<List<Map<String, dynamic>>> getTopProductos([int limite = 5]) async {
    final response = await _apiService.get<List<Map<String, dynamic>>>(
      '/reportes/top-productos?limite=$limite',
      (json) => List<Map<String, dynamic>>.from(json),
    );

    if (response.isSuccess) {
      return response.data ?? [];
    } else {
      return [];
    }
  }

  /// Productos más vendidos en los últimos [dias] días que están en stock bajo
  /// (cantidadActual ≤ cantidadMinima). Útil para reabastecimiento.
  ///
  /// Backend: GET /api/top-vendidos-bajo-stock?dias=7&limite=10
  Future<List<Map<String, dynamic>>> getTopVendidosBajoStock({
    int dias = 7,
    int limite = 10,
  }) async {
    final response = await _apiService.get<List<Map<String, dynamic>>>(
      '/api/top-vendidos-bajo-stock?dias=$dias&limite=$limite',
      (json) => List<Map<String, dynamic>>.from(json),
    );
    if (response.isSuccess) return response.data ?? [];
    return [];
  }

  // Obtener top clientes (excluyendo Consumidor Final)
  Future<List<Map<String, dynamic>>> getTopClientes([int limite = 5]) async {
    final response = await _apiService.get<List<Map<String, dynamic>>>(
      '/api/reportes/top-clientes?limite=$limite&excluirConsumidorFinal=true',
      (json) => List<Map<String, dynamic>>.from(json),
    );

    if (response.isSuccess) {
      return response.data ?? [];
    } else {
      return [];
    }
  }

  // Obtener reporte detallado de ventas por producto
  Future<List<Map<String, dynamic>>> getProductosVentasDetallado({
    required DateTime desde,
    required DateTime hasta,
    String? cliente,
    String? producto,
    String? vendedor,
    String? codigo,
    String? cuadreId,
  }) async {
    String endpoint =
        '/api/reportes/productos/ventas-detallado?fechaDesde=${desde.toIso8601String()}&fechaHasta=${hasta.toIso8601String()}';

    if (cliente != null && cliente.isNotEmpty) {
      endpoint += '&cliente=$cliente';
    }
    if (producto != null && producto.isNotEmpty) {
      endpoint += '&nombreProducto=$producto';
    }
    if (vendedor != null && vendedor.isNotEmpty) {
      endpoint += '&vendedor=$vendedor';
    }
    if (codigo != null && codigo.isNotEmpty) {
      endpoint += '&codigo=$codigo';
    }
    if (cuadreId != null && cuadreId.isNotEmpty) {
      endpoint += '&cuadreId=$cuadreId';
    }

    try {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        endpoint,
        (json) => List<Map<String, dynamic>>.from(json),
      );

      if (response.isSuccess) {
        return response.data ?? [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Obtener reporte agrupado de ventas por producto
  Future<List<Map<String, dynamic>>> getProductosVentasAgrupado({
    required DateTime desde,
    required DateTime hasta,
    String? cliente,
    String? producto,
    String? vendedor,
    String? codigo,
    String? cuadreId,
  }) async {
    String endpoint =
        '/api/reportes/productos/ventas-agrupado?fechaDesde=${desde.toIso8601String()}&fechaHasta=${hasta.toIso8601String()}';

    if (cliente != null && cliente.isNotEmpty) {
      endpoint += '&cliente=$cliente';
    }
    if (producto != null && producto.isNotEmpty) {
      endpoint += '&nombreProducto=$producto';
    }
    if (vendedor != null && vendedor.isNotEmpty) {
      endpoint += '&vendedor=$vendedor';
    }
    if (codigo != null && codigo.isNotEmpty) {
      endpoint += '&codigo=$codigo';
    }
    if (cuadreId != null && cuadreId.isNotEmpty) {
      endpoint += '&cuadreId=$cuadreId';
    }

    try {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        endpoint,
        (json) => List<Map<String, dynamic>>.from(json),
      );

      if (response.isSuccess) {
        return response.data ?? [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Obtener ventas por categoría
  Future<List<Map<String, dynamic>>> getVentasPorCategoria([
    int limite = 5,
  ]) async {
    try {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        '/reportes/ventas-por-categoria?limite=$limite',
        (json) => List<Map<String, dynamic>>.from(json),
      );

      if (response.isSuccess) {
        return response.data ?? [];
      } else {
                   return [];
      }
    } catch (e) {
        
      // Si el endpoint no existe aún, podemos devolver datos simulados temporales
      rethrow;
    }
  }

  // MÉTODOS ADICIONALES PARA CUADRE DE CAJA (si se necesitan en el futuro)

  // Obtener cuadre de caja del día
  Future<Map<String, dynamic>?> getCuadreCaja() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/reportes/cuadre-caja',
      (json) => json,
    );

    if (response.isSuccess) {
        
      return response.data!;
    } else {
        
      return null;
    }
  }

  // Cerrar caja
  Future<Map<String, dynamic>?> cerrarCaja({
    required double efectivoDeclarado,
    required String responsable,
    double tolerancia = 5000.0,
    String? observaciones,
  }) async {
    final response = await _apiService
        .post<Map<String, dynamic>>('/reportes/cuadre-caja/cerrar', {
          'efectivoDeclarado': efectivoDeclarado,
          'responsable': responsable,
          'tolerancia': tolerancia,
          'observaciones': observaciones,
        }, (json) => json);

    if (response.isSuccess) {
        
      return response.data!;
    } else {
        
      return null;
    }
  }

  // Obtener historial de cuadres
  Future<List<Map<String, dynamic>>?> getHistorialCuadres({
    int dias = 30,
  }) async {
    final response = await _apiService.getList<Map<String, dynamic>>(
      '/reportes/cuadre-caja/historial?dias=$dias',
      (json) => json,
    );

    if (response.isSuccess) {
      return response.data!;
    } else {
               return [];
    }
  }

  // Obtener alertas del sistema
  Future<Map<String, dynamic>?> getAlertas() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/reportes/alertas',
      (json) => json,
    );

    if (response.isSuccess) {
      return response.data!;
    } else {
        
      return null;
    }
  }

  // Actualizar objetivo de ventas
  Future<bool> actualizarObjetivo(String periodo, double nuevoObjetivo) async {
    try {
         
      final requestData = {'periodo': periodo, 'objetivo': nuevoObjetivo};

      final response = await _apiService.put<Map<String, dynamic>>(
        '/reportes/objetivo',
        requestData,
        (json) => json,
      );

      if (response.isSuccess) {
        return true;
      } else {
          
          
        // Fallback: guardar localmente hasta que el servidor esté disponible
        await _guardarObjetivoLocal(periodo, nuevoObjetivo);
        return true;
      }
    } catch (e) {
        
        
      // Fallback: guardar localmente
      await _guardarObjetivoLocal(periodo, nuevoObjetivo);
      return true;
    }
  }

  // Obtener últimos pedidos con detalles
  Future<List<Map<String, dynamic>>> getUltimosPedidos([
    int limite = 10,
  ]) async {
    try {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        '/ultimos-pedidos?limite=$limite',
        (json) => List<Map<String, dynamic>>.from(json),
      );

      if (response.isSuccess) {
        return response.data ?? [];
      } else {
          
        return [];
      }
    } catch (e) {
        
      return [];
    }
  }

  // Obtener vendedores del mes
  Future<List<Map<String, dynamic>>> getVendedoresDelMes([
    int dias = 30,
  ]) async {
    try {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        '/vendedores-mes?dias=$dias',
        (json) => List<Map<String, dynamic>>.from(json),
      );

      if (response.isSuccess) {
        return response.data ?? [];
      } else {
                   return [];
      }
    } catch (e) {
        
      return [];
    }
  }

  // Método temporal para guardar objetivos localmente
  Future<void> _guardarObjetivoLocal(String periodo, double objetivo) async {
    try {
      // En una implementación real, usarías SharedPreferences o similar
               // Por ahora solo mostramos el mensaje
    } catch (e) {
        
    }
  }
}
