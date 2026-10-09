import 'base_api_service.dart';
import '../models/dashboard_data.dart';

class ReportesService {
  static final ReportesService _instance = ReportesService._internal();
  factory ReportesService() => _instance;
  ReportesService._internal();

  final BaseApiService _apiService = BaseApiService();

  // Caché en memoria de los ~9 endpoints que arma el Dashboard, con TTL
  // corto: abrirlo dispara esa cantidad de llamadas en paralelo (ver
  // dashboard_screen_v2._cargarDatos), y volver a entrar (navegar a otra
  // pantalla y volver, o el refresh automático por cambio de día/semana) las
  // repetía todas de nuevo sin importar cuánto hubiera pasado. 45s es
  // razonable para un dashboard de reportes (no es un total de caja en vivo
  // durante una venta activa) — "Actualizar"/forceRefresh lo saltea.
  static final Map<String, _ReporteCacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(seconds: 45);

  /// Olvida todo el caché de reportes del dashboard — llamar si hace falta
  /// forzar que la próxima carga sea 100% fresca desde todos lados.
  static void invalidarCacheDashboard() => _cache.clear();

  Future<T> _cacheado<T>(
    String key,
    Future<T> Function() fetch, {
    bool forzar = false,
  }) async {
    if (!forzar) {
      final entry = _cache[key];
      if (entry != null && DateTime.now().difference(entry.cacheadoEn) < _cacheTtl) {
        return entry.data as T;
      }
    }
    final data = await fetch();
    _cache[key] = _ReporteCacheEntry(data, DateTime.now());
    return data;
  }

  // Obtener dashboard
  // soloElectronicos=true → backend excluye pedidos LOCAL (solo POS + FACTURA)
  Future<DashboardData?> getDashboard({bool forceRefresh = false, bool soloElectronicos = false}) {
    return _cacheado(
      'dashboard:$soloElectronicos',
      () => _obtenerDashboardDesdeRed(soloElectronicos),
      forzar: forceRefresh,
    );
  }

  Future<DashboardData?> _obtenerDashboardDesdeRed(bool soloElectronicos) async {
    try {
      final filtro = soloElectronicos ? '&soloElectronicos=true' : '';
      final endpoint = '/api/reportes/dashboard?ignorarCaja=true$filtro';

      final response = await _apiService.get<Map<String, dynamic>>(
        endpoint,
        (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        // Se usan siempre los valores del servidor tal cual. Antes aquí se
        // hacía además un getPedidosHoy() (que en su fallback baja TODOS los
        // pedidos) solo para recalcular totales que luego se descartaban —
        // era una segunda llamada pesada y encadenada en el camino crítico
        // del dashboard, sin efecto en el resultado.
        return DashboardData.fromJson(response.data!);
      } else {
        return null;
      }
    } catch (e) {

      return null;
    }
  }

  // Obtener pedidos por hora. [forzar] se agregó al final (y no como named,
  // ver más abajo) para no romper las llamadas posicionales que ya existían
  // — p. ej. getTopProductos(5) — al mezclar [] con {} Dart no compila.
  Future<List<Map<String, dynamic>>> getPedidosPorHora([
    DateTime? fecha,
    bool forzar = false,
  ]) {
    return _cacheado('pedidosPorHora:${fecha?.toIso8601String()}', () async {
      final fechaParam = fecha != null ? '?fecha=${fecha.toIso8601String()}' : '';
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        '/reportes/pedidos-por-hora$fechaParam',
        (json) => List<Map<String, dynamic>>.from(json),
      );
      return response.isSuccess ? (response.data ?? []) : <Map<String, dynamic>>[];
    }, forzar: forzar);
  }

  // Obtener ventas por día
  Future<List<Map<String, dynamic>>> getVentasPorDia([
    int ultimosDias = 7,
    bool forzar = false,
  ]) {
    return _cacheado('ventasPorDia:$ultimosDias', () async {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        '/ventas-por-dia?ultimosDias=$ultimosDias',
        (json) => List<Map<String, dynamic>>.from(json),
      );
      return response.isSuccess ? (response.data ?? []) : <Map<String, dynamic>>[];
    }, forzar: forzar);
  }

  // Obtener ventas (facturado) por mes — excluye pedidos locales, solo
  // Facturación Electrónica + POS (mismo criterio que ventas por día)
  Future<List<Map<String, dynamic>>> getVentasPorMes([
    int ultimosMeses = 12,
    bool forzar = false,
  ]) {
    return _cacheado('ventasPorMes:$ultimosMeses', () async {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        '/ventas-por-mes?ultimosMeses=$ultimosMeses',
        (json) => List<Map<String, dynamic>>.from(json),
      );
      return response.isSuccess ? (response.data ?? []) : <Map<String, dynamic>>[];
    }, forzar: forzar);
  }

  // Obtener ingresos vs egresos
  Future<List<Map<String, dynamic>>> getIngresosVsEgresos([
    int ultimosMeses = 12,
    bool forzar = false,
  ]) {
    return _cacheado('ingresosVsEgresos:$ultimosMeses', () async {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        '/reportes/ingresos-egresos?ultimosMeses=$ultimosMeses',
        (json) => List<Map<String, dynamic>>.from(json),
      );
      return response.isSuccess ? (response.data ?? []) : <Map<String, dynamic>>[];
    }, forzar: forzar);
  }

  // Obtener top productos
  Future<List<Map<String, dynamic>>> getTopProductos([int limite = 5, bool forzar = false]) {
    return _cacheado('topProductos:$limite', () async {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        '/reportes/top-productos?limite=$limite',
        (json) => List<Map<String, dynamic>>.from(json),
      );
      return response.isSuccess ? (response.data ?? []) : <Map<String, dynamic>>[];
    }, forzar: forzar);
  }

  /// Productos más vendidos en los últimos [dias] días que están en stock bajo
  /// (cantidadActual ≤ cantidadMinima). Útil para reabastecimiento.
  ///
  /// Backend: GET /api/top-vendidos-bajo-stock?dias=7&limite=10
  Future<List<Map<String, dynamic>>> getTopVendidosBajoStock({
    int dias = 7,
    int limite = 10,
    bool forzar = false,
  }) {
    return _cacheado('topVendidosBajoStock:$dias:$limite', () async {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        '/api/top-vendidos-bajo-stock?dias=$dias&limite=$limite',
        (json) => List<Map<String, dynamic>>.from(json),
      );
      return response.isSuccess ? (response.data ?? []) : <Map<String, dynamic>>[];
    }, forzar: forzar);
  }

  // Obtener top clientes (excluyendo Consumidor Final)
  Future<List<Map<String, dynamic>>> getTopClientes([int limite = 5, bool forzar = false]) {
    return _cacheado('topClientes:$limite', () async {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        '/api/reportes/top-clientes?limite=$limite&excluirConsumidorFinal=true',
        (json) => List<Map<String, dynamic>>.from(json),
      );
      return response.isSuccess ? (response.data ?? []) : <Map<String, dynamic>>[];
    }, forzar: forzar);
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
    // 'LOCAL' / 'ENVIOS'; null o 'TODAS' = sin filtrar. Las Facturas no
    // tienen caja, así que un filtro activo las excluye del resultado —
    // ver el mismo criterio en el backend (ReporteService).
    String? tipoCaja,
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
    if (tipoCaja != null && tipoCaja.isNotEmpty && tipoCaja != 'TODAS') {
      endpoint += '&tipoCaja=$tipoCaja';
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
    String? tipoCaja,
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
    if (tipoCaja != null && tipoCaja.isNotEmpty && tipoCaja != 'TODAS') {
      endpoint += '&tipoCaja=$tipoCaja';
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
    bool forzar = false,
  ]) {
    return _cacheado('vendedoresDelMes:$dias', () async {
      try {
        // /vendedores-mes -> /api/vendedores-mes (DashboardController), que sí
        // delega en ReporteService.getVendedoresDelMes — no confundir con el
        // endpoint de mismo nombre bajo /api/reportes en ReportesController,
        // que es una implementación aparte (duplicada inline, no delega en el
        // service) para compatibilidad con clientes viejos.
        final response = await _apiService.get<List<Map<String, dynamic>>>(
          '/vendedores-mes?dias=$dias',
          (json) => List<Map<String, dynamic>>.from(json),
        );
        return response.isSuccess ? (response.data ?? []) : <Map<String, dynamic>>[];
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    }, forzar: forzar);
  }

  /// Ranking de ventas por facturador (Pedido.mesero) en un rango de fechas
  /// libre, opcionalmente filtrado por caja (LOCAL/ENVIOS). A diferencia de
  /// [getVendedoresDelMes] (ventana fija de días, sin filtro de caja), este
  /// soporta el rango + caja que necesita "Análisis de Ventas" para rastrear
  /// quién factura qué en Facturación Envíos.
  Future<List<Map<String, dynamic>>> getVentasPorFacturador({
    required DateTime desde,
    required DateTime hasta,
    String? tipoCaja,
  }) async {
    String endpoint =
        '/api/reportes/ventas-por-facturador?fechaDesde=${desde.toIso8601String()}&fechaHasta=${hasta.toIso8601String()}';
    if (tipoCaja != null && tipoCaja.isNotEmpty && tipoCaja != 'TODAS') {
      endpoint += '&tipoCaja=$tipoCaja';
    }

    try {
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        endpoint,
        (json) => List<Map<String, dynamic>>.from(json),
      );
      return response.isSuccess ? (response.data ?? []) : [];
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

/// Entrada del caché genérico de [ReportesService] — [data] es `dynamic` a
/// propósito porque un solo mapa cachea respuestas de tipos distintos
/// (DashboardData, List<Map>...); `_cacheado<T>` hace el cast al leerla.
class _ReporteCacheEntry {
  final dynamic data;
  final DateTime cacheadoEn;
  _ReporteCacheEntry(this.data, this.cacheadoEn);
}
