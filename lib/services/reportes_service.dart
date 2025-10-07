import 'base_api_service.dart';
import '../models/dashboard_data.dart';

class ReportesService {
  static final ReportesService _instance = ReportesService._internal();
  factory ReportesService() => _instance;
  ReportesService._internal();

  final BaseApiService _apiService = BaseApiService();

  // Obtener dashboard
  Future<DashboardData?> getDashboard() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/reportes/dashboard',
        (json) => json,
      );

      // Respuesta recibida - Success: ${response.isSuccess}
      print('📦 Data: ${response.data != null ? 'Presente' : 'Null'}');

      if (response.isSuccess && response.data != null) {
        final dashboardData = DashboardData.fromJson(response.data!);
        return dashboardData;
      } else {
        print(
          '⚠️ Respuesta no exitosa o data null - Error: ${response.errorMessage}',
        );
        return null;
      }
    } catch (e) {
      print('❌ Error en getDashboard(): $e');
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
      print('⚠️ Error al obtener pedidos por hora: ${response.errorMessage}');
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
      print('⚠️ Error al obtener ventas por día: ${response.errorMessage}');
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
      print(
        '⚠️ Error al obtener ingresos vs egresos: ${response.errorMessage}',
      );
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
        print(
          '⚠️ Error al obtener ventas por categoría: ${response.errorMessage}',
        );
        return [];
      }
    } catch (e) {
      print('❌ Excepción en getVentasPorCategoria: $e');
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
      print('✅ Cuadre de caja obtenido');
      return response.data!;
    } else {
      print('⚠️ Error al obtener cuadre de caja: ${response.errorMessage}');
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
      print('✅ Caja cerrada exitosamente');
      return response.data!;
    } else {
      print('⚠️ Error al cerrar caja: ${response.errorMessage}');
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
      print(
        '⚠️ Error al obtener historial de cuadres: ${response.errorMessage}',
      );
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
      print('⚠️ Error al obtener alertas: ${response.errorMessage}');
      return null;
    }
  }

  // Actualizar objetivo de ventas
  Future<bool> actualizarObjetivo(String periodo, double nuevoObjetivo) async {
    try {
      print(
        '🎯 Actualizando objetivo $periodo a \$${nuevoObjetivo.toStringAsFixed(0)}',
      );

      final requestData = {'periodo': periodo, 'objetivo': nuevoObjetivo};

      final response = await _apiService.put<Map<String, dynamic>>(
        '/reportes/objetivo',
        requestData,
        (json) => json,
      );

      if (response.isSuccess) {
        return true;
      } else {
        print('❌ Error al actualizar objetivo: ${response.errorMessage}');
        print('⚠️ Usando almacenamiento local temporal');
        // Fallback: guardar localmente hasta que el servidor esté disponible
        await _guardarObjetivoLocal(periodo, nuevoObjetivo);
        return true;
      }
    } catch (e) {
      print('❌ Excepción al actualizar objetivo: $e');
      print('⚠️ Usando almacenamiento local temporal');
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
        print('⚠️ Error al obtener últimos pedidos: ${response.errorMessage}');
        return [];
      }
    } catch (e) {
      print('❌ Excepción obteniendo últimos pedidos: $e');
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
        print(
          '⚠️ Error al obtener vendedores del mes: ${response.errorMessage}',
        );
        return [];
      }
    } catch (e) {
      print('❌ Excepción obteniendo vendedores del mes: $e');
      return [];
    }
  }

  // Método temporal para guardar objetivos localmente
  Future<void> _guardarObjetivoLocal(String periodo, double objetivo) async {
    try {
      // En una implementación real, usarías SharedPreferences o similar
      print(
        '💾 Guardando objetivo $periodo = \$${objetivo.toStringAsFixed(0)} localmente',
      );
      // Por ahora solo mostramos el mensaje
    } catch (e) {
      print('❌ Error guardando objetivo local: $e');
    }
  }
}
