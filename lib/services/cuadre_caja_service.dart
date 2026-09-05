import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cuadre_caja.dart';
import '../config/api_config.dart';
import '../utils/api_error.dart';
import '../utils/logger.dart';
import 'base_api_service.dart';

/// Interfaz minima usada por las pantallas que necesitan inyectar un fake en
/// tests (ver abrir_caja_screen.dart / cerrar_caja_screen.dart) - necesaria
/// porque CuadreCajaService es un singleton (factory constructor) y por lo
/// tanto no se puede `extends` desde una clase fake en otro archivo.
abstract class ICuadreCajaService {
  Future<List<CuadreCaja>> getAllCuadres();
  Future<CuadreCaja> createCuadre({
    required String nombre,
    required String responsable,
    required double fondoInicial,
    required double efectivoDeclarado,
    required double efectivoEsperado,
    required double tolerancia,
    String? observaciones,
    String? tipoCaja,
  });
  Future<CuadreCaja> updateCuadre(
    String id, {
    String? nombre,
    String? responsable,
    double? fondoInicial,
    double? efectivoDeclarado,
    double? efectivoEsperado,
    double? tolerancia,
    String? observaciones,
    bool? cerrarCaja,
    String? estado,
  });
  Future<Map<String, dynamic>> getCuadreCompleto({String? tipoCaja});
  Future<Map<String, dynamic>> getDetallesVentas({String? tipoCaja});
  Future<Map<String, dynamic>> getVentasPorTipoPago();
  Future<Map<String, dynamic>> getResumenVentasHoy();
}

class CuadreCajaService implements ICuadreCajaService {
  static final CuadreCajaService _instance = CuadreCajaService._internal();
  factory CuadreCajaService() => _instance;
  CuadreCajaService._internal();

  String get baseUrl => ApiConfig.instance.baseUrl;

  // Headers con autenticación. BaseApiService resuelve el token según la
  // plataforma (localStorage en web, secure storage en móvil) — leer aquí
  // FlutterSecureStorage directo dejaba el token en null en web.
  Future<Map<String, String>> _getHeaders() async {
    final headers = await BaseApiService().getHeaders();
    headers['Accept'] = 'application/json';
    return headers;
  }

  // Obtener todos los cuadres de caja
  Future<List<CuadreCaja>> getAllCuadres() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final rawData = responseData['data'];
        List<dynamic> jsonList;
        if (rawData is List) {
          jsonList = rawData;
        } else if (rawData is Map) {
          jsonList = (rawData['content'] as List?) ?? [];
        } else {
          jsonList = [];
        }
        final cuadres = jsonList
            .map((j) => CuadreCaja.fromJson(j))
            .toList();

        // Ordenar cuadres por fecha de apertura descendente (más recientes primero)
        cuadres.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));

        return cuadres;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener cuadres');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener cuadres');
    }
  }

  // Obtener cuadre por ID
  Future<CuadreCaja?> getCuadreById(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener cuadre');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener cuadre');
    }
  }

  // Obtener cuadres por responsable
  Future<List<CuadreCaja>> getCuadresByResponsable(String responsable) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/responsable/$responsable'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final cuadres = jsonList
            .map((json) => CuadreCaja.fromJson(json))
            .toList();

        // Ordenar cuadres por fecha de apertura descendente (más recientes primero)
        cuadres.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));

        return cuadres;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener cuadres por responsable');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener cuadres por responsable');
    }
  }

  // Obtener cuadres por estado
  Future<List<CuadreCaja>> getCuadresByEstado(String estado) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/estado/$estado'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final cuadres = jsonList
            .map((json) => CuadreCaja.fromJson(json))
            .toList();

        // Ordenar cuadres por fecha de apertura descendente (más recientes primero)
        cuadres.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));

        return cuadres;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener cuadres por estado');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener cuadres por estado');
    }
  }

  // Obtener cuadres de hoy
  Future<List<CuadreCaja>> getCuadresHoy() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/hoy'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final cuadres = jsonList
            .map((json) => CuadreCaja.fromJson(json))
            .toList();

        // Ordenar cuadres por fecha de apertura descendente (más recientes primero)
        cuadres.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));

        return cuadres;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener cuadres de hoy');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener cuadres de hoy');
    }
  }

  // Obtener cajas abiertas
  Future<List<CuadreCaja>> getCajasAbiertas() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/abiertas'),
        headers: headers,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // El data puede ser List o Map (paginado); manejar ambos
        final rawData = responseData['data'];
        List<dynamic> jsonList;
        if (rawData is List) {
          jsonList = rawData;
        } else if (rawData is Map) {
          // Spring Page: {"content": [...], ...}
          jsonList = (rawData['content'] as List?) ?? [];
        } else {
          jsonList = [];
        }
        appLog('[CajaService] /abiertas → ${jsonList.length} cajas raw');
        final cuadres = jsonList
            .map((j) => CuadreCaja.fromJson(j))
            .toList();
        appLog('[CajaService] IDs obtenidos: ${cuadres.map((c) => c.id).toList()}');

        // Ordenar cuadres por fecha de apertura descendente (más recientes primero)
        cuadres.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));

        return cuadres;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener cajas abiertas');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener cajas abiertas');
    }
  }

  // Obtener la caja activa actual (primera caja abierta)
  // Devuelve null solo cuando se CONFIRMÓ que no hay caja abierta (alguno de
  // los dos endpoints respondió con una lista vacía). Si ambos fallan por un
  // problema real (red, timeout, backend caído), esto se propaga como
  // excepción en vez de devolver null — antes un simple error de conexión se
  // veía exactamente igual a "no hay caja abierta" y disparaba el mensaje
  // "Debe abrir caja" aunque la caja siguiera abierta.
  Future<CuadreCaja?> getCajaActiva() async {
    // Try the dedicated /abiertas endpoint first
    try {
      final cajasAbiertas = await getCajasAbiertas();
      return cajasAbiertas.isNotEmpty ? cajasAbiertas.first : null;
    } catch (_) {
      // Este endpoint falló — probar el de respaldo antes de rendirse.
    }

    // Fallback: get all cuadres and filter client-side. Si esto también
    // falla, se deja subir la excepción (no se convierte en null).
    final todos = await getAllCuadres();
    final abiertas = todos.where((c) => !c.cerrada).toList();
    abiertas.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));
    return abiertas.isNotEmpty ? abiertas.first : null;
  }

  // Obtener la caja abierta de un tipo especifico ('LOCAL' o 'ENVIOS').
  // Espejo de CuadreCajaService.obtenerCajaAbiertaPorTipo en el backend:
  // con dos cajas abiertas a la vez, getCajaActiva() (que toma "la primera")
  // ya no alcanza para saber a cual pertenece una operacion.
  Future<CuadreCaja?> getCajaActivaPorTipo(String tipoCaja) async {
    final tipoNormalizado = tipoCaja.trim().toUpperCase();
    try {
      final cajasAbiertas = await getCajasAbiertas();
      return cajasAbiertas
          .where((c) => c.tipoCaja == tipoNormalizado)
          .firstOrNull;
    } catch (_) {
      // Este endpoint falló — probar el de respaldo antes de rendirse.
    }

    final todos = await getAllCuadres();
    final abiertas = todos
        .where((c) => !c.cerrada && c.tipoCaja == tipoNormalizado)
        .toList();
    abiertas.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));
    return abiertas.isNotEmpty ? abiertas.first : null;
  }

  // Validar si hay una caja abierta (método de conveniencia)
  Future<bool> hayCajaAbierta() async {
    try {
      final cajaActiva = await getCajaActiva();
      return cajaActiva != null;
    } catch (e) {
        
      return false;
    }
  }

  // Obtener efectivo esperado con logging detallado
  Future<Map<String, dynamic>> getEfectivoEsperado({String? tipoCaja}) async {
    try {

      final headers = await _getHeaders();

      final uri = Uri.parse('$baseUrl/api/cuadres-caja/reportes/efectivo-esperado')
          .replace(queryParameters: tipoCaja != null ? {'tipoCaja': tipoCaja} : null);
      final response = await http.get(uri, headers: headers);

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
          

        final efectivoEsperado = (responseData['data']['efectivoEsperado'] ?? 0)
            .toDouble();
        final transferenciasEsperadas =
            (responseData['data']['transferenciasEsperadas'] ??
                    responseData['data']['transferenciaEsperada'] ??
                    0)
                .toDouble();

                      
        return responseData['data'];
      } else {
          
          

        // Fallback: intentar calcular manualmente desde pedidos
        return await _calcularEfectivoManual();
      }
    } catch (e) {
        
      // Fallback: intentar calcular manualmente desde pedidos
      return await _calcularEfectivoManual();
    }
  }

  // Método fallback para calcular efectivo manualmente
  Future<Map<String, dynamic>> _calcularEfectivoManual() async {
    try {
        

      // Usar el nuevo método que obtiene datos por cuadre activo
      Map<String, dynamic>? ventasData;

      try {
        ventasData = await getVentasPorCuadreActivo();
          
      } catch (e) {
          

        // Fallback a los métodos antiguos
        try {
          ventasData = await getVentasPorCuadreActivo();
            
        } catch (e2) {
            

          try {
            ventasData = await getDetallesVentas();
              
          } catch (e3) {
              
          }
        }
      }

      if (ventasData == null) {
        try {
          ventasData = await getTodosPedidosHoy();
            
        } catch (e) {
            
        }
      }

      double efectivoEsperado = 0.0;
      double transferenciasEsperadas = 0.0;

      if (ventasData != null) {
          
          

        // Procesar los datos según la estructura que venga del backend
        if (ventasData.containsKey('efectivo')) {
          efectivoEsperado = (ventasData['efectivo'] ?? 0).toDouble();
        }

        if (ventasData.containsKey('transferencias')) {
          transferenciasEsperadas = (ventasData['transferencias'] ?? 0)
              .toDouble();
        } else if (ventasData.containsKey('transferencia')) {
          transferenciasEsperadas = (ventasData['transferencia'] ?? 0)
              .toDouble();
        }

        // Si vienen datos por tipo de pago, procesarlos
        if (ventasData.containsKey('ventasPorTipo')) {
          final ventasPorTipo =
              ventasData['ventasPorTipo'] as Map<String, dynamic>? ?? {};
            

          ventasPorTipo.forEach((tipoPago, monto) {
            double valor = (monto ?? 0).toDouble();
            String tipo = tipoPago.toLowerCase();

            if (tipo.contains('efectivo') || tipo == 'cash') {
              efectivoEsperado += valor;
                
            } else if (tipo.contains('transfer') ||
                tipo.contains('debito') ||
                tipo.contains('tarjeta')) {
              transferenciasEsperadas += valor;
            }
          });
        }

        // Si no vienen datos específicos, sumar pedidos manualmente
        if ((efectivoEsperado == 0 && transferenciasEsperadas == 0) &&
            ventasData.containsKey('pedidos')) {
            
          List<dynamic> pedidos = ventasData['pedidos'] ?? [];
            

          for (var pedido in pedidos) {
            if (pedido['estado'] == 'pagado') {
              double total = (pedido['total'] ?? 0).toDouble();
              String tipoPago =
                  (pedido['tipoPago'] ?? pedido['tipo_pago'] ?? 'efectivo')
                      .toString()
                      .toLowerCase();

                 
              if (tipoPago.contains('efectivo') || tipoPago == 'cash') {
                efectivoEsperado += total;
                  
              } else if (tipoPago.contains('transfer') ||
                  tipoPago.contains('debito') ||
                  tipoPago.contains('tarjeta')) {
                transferenciasEsperadas += total;
              } else {
                // Por defecto, considerar como efectivo si no se especifica
                efectivoEsperado += total;
              }
            }
          }
        }
      }

        
        
                  
      return {
        'efectivoEsperado': efectivoEsperado,
        'transferenciasEsperadas': transferenciasEsperadas,
        'transferenciaEsperada': transferenciasEsperadas, // Compatibilidad
        'totalVentas': efectivoEsperado + transferenciasEsperadas,
        'calculoManual': true,
        'timestamp': DateTime.now().toIso8601String(),
        'detalleCalculo': {
          'efectivo': efectivoEsperado,
          'transferencias': transferenciasEsperadas,
        },
      };
    } catch (e) {
        
      // Devolver valores por defecto en caso de error total
      return {
        'efectivoEsperado': 0.0,
        'transferenciasEsperadas': 0.0,
        'transferenciaEsperada': 0.0,
        'totalVentas': 0.0,
        'error': 'No se pudo calcular el efectivo esperado',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Crear cuadre de caja
  Future<CuadreCaja> createCuadre({
    required String nombre,
    required String responsable,
    required double fondoInicial,
    required double efectivoDeclarado,
    required double efectivoEsperado,
    required double tolerancia,
    String? observaciones,
    String? tipoCaja,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'nombre': nombre,
        'responsable': responsable,
        'fondoInicial': fondoInicial,
        'efectivoDeclarado': efectivoDeclarado,
        'efectivoEsperado': efectivoEsperado,
        'tolerancia': tolerancia,
        'observaciones': observaciones ?? '',
        'tipoCaja': tipoCaja ?? 'LOCAL',
      };

      // 🔍 LOGGING: Debug para fondo inicial
        
        
        
        
        

      final response = await http.post(
        Uri.parse('$baseUrl/api/cuadres-caja'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final cuadreCreado = CuadreCaja.fromJson(responseData['data']);

        // 🔍 LOGGING: Debug para respuesta del backend
          
          
                     

        if (cuadreCreado.fondoInicial != fondoInicial) {
            
            
                     }

        return cuadreCreado;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al crear cuadre');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al crear cuadre');
    }
  }

  /// Actualizar cuadre de caja con limpieza automática de cache
  ///
  /// El parámetro [cerrarCaja] es crítico:
  /// - Si es `true`, el backend:
  ///   1. Limpia automáticamente el cache de pedidos y mesas
  ///   2. Calcula e incluye ingresos adicionales en el resumen
  ///   3. Registra el cierre en el historial
  ///   4. Actualiza el estado del cuadre a "cerrado"
  /// - Todo esto ocurre en una sola transacción para mantener integridad de datos
  Future<CuadreCaja> updateCuadre(
    String id, {
    String? nombre,
    String? responsable,
    double? fondoInicial,
    double? efectivoDeclarado,
    double? efectivoEsperado,
    double? tolerancia,
    String? observaciones,
    bool? cerrarCaja, // Parámetro crítico para cerrar caja y limpiar cache
    String? estado,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        if (nombre != null) 'nombre': nombre,
        if (responsable != null) 'responsable': responsable,
        if (fondoInicial != null) 'fondoInicial': fondoInicial,
        if (efectivoDeclarado != null) 'efectivoDeclarado': efectivoDeclarado,
        if (efectivoEsperado != null) 'efectivoEsperado': efectivoEsperado,
        if (tolerancia != null) 'tolerancia': tolerancia,
        if (observaciones != null) 'observaciones': observaciones,
        if (cerrarCaja != null)
          'cerrarCaja': cerrarCaja, // Campo correcto para el backend
        if (estado != null) 'estado': estado,
      };

        

      final response = await http.put(
        Uri.parse('$baseUrl/api/cuadres-caja/$id'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Si se está cerrando la caja, el backend automáticamente:
        // - Limpia cache de pedidos y mesas
        // - Incluye ingresos adicionales en el resumen
        // - Registra el cierre en historial
        if (cerrarCaja == true) {
            

          // Extraer información adicional del cierre si está disponible
          Map<String, dynamic> detallesCierre = {};
          if (responseData.containsKey('detallesCierre')) {
            detallesCierre = responseData['detallesCierre'];
          }

          // Registrar detalles del proceso de limpieza
            
                                      
        }

        return CuadreCaja.fromJson(responseData['data']);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al actualizar cuadre');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al actualizar cuadre');
    }
  }

  // Aprobar cuadre
  Future<CuadreCaja> aprobarCuadre(String id, String aprobador) async {
    try {
      final headers = await _getHeaders();
      final body = {'aprobador': aprobador};

      final response = await http.put(
        Uri.parse('$baseUrl/api/cuadres-caja/operaciones/$id/aprobar'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al aprobar cuadre');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al aprobar cuadre');
    }
  }

  // Rechazar cuadre
  Future<CuadreCaja> rechazarCuadre(
    String id,
    String aprobador, {
    String? observacion,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'aprobador': aprobador,
        if (observacion != null) 'observacion': observacion,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/cuadres-caja/operaciones/$id/rechazar'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al rechazar cuadre');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al rechazar cuadre');
    }
  }

  // Eliminar cuadre
  Future<bool> deleteCuadre(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/cuadres-caja/$id'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      wrapOrThrow(e, context: 'Error al eliminar cuadre');
    }
  }

  // Debug de pedidos - para verificar qué pedidos están registrados
  Future<Map<String, dynamic>> debugPedidos({String? tipoCaja}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/api/cuadres-caja/reportes/debug-pedidos')
          .replace(queryParameters: tipoCaja != null ? {'tipoCaja': tipoCaja} : null);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener debug de pedidos');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener debug de pedidos');
    }
  }

  Future<Map<String, dynamic>> getDetallesVentas({String? tipoCaja}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/api/cuadres-caja/reportes/detalles-ventas')
          .replace(queryParameters: tipoCaja != null ? {'tipoCaja': tipoCaja} : null);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener detalles de ventas');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener detalles de ventas');
    }
  }

  Future<Map<String, dynamic>> getTodosPedidosHoy({String? tipoCaja}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/api/cuadres-caja/reportes/todos-pedidos-hoy')
          .replace(queryParameters: tipoCaja != null ? {'tipoCaja': tipoCaja} : null);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener todos los pedidos');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener todos los pedidos');
    }
  }

  // Obtener ventas por cuadre de caja activo en lugar de por fecha
  Future<Map<String, dynamic>> getVentasPorCuadreActivo() async {
    try {
        
      final headers = await _getHeaders();

      // Obtener la caja activa
      final cajaActiva = await getCajaActiva();
      if (cajaActiva == null) {
          
        return {
          'total': 0.0,
          'efectivo': 0.0,
          'transferencias': 0.0,
          'tarjeta': 0.0,
          'otros': 0.0,
        };
      }

        
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/consultas/cuadre/${cajaActiva.id}/pagados'),
        headers: headers,
      );

        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
          

        // Procesar pedidos para calcular totales por tipo de pago
        final List<dynamic> pedidos = responseData['data'] ?? [];
        double totalEfectivo = 0.0;
        double totalTransferencias = 0.0;
        double totalTarjeta = 0.0;
        double totalOtros = 0.0;

        for (var pedidoJson in pedidos) {
          final double totalPedido =
              (pedidoJson['totalPagado'] ?? pedidoJson['total'] ?? 0)
                  .toDouble();
          final String formaPago = (pedidoJson['formaPago'] ?? 'otros')
              .toString()
              .toLowerCase();

          // Revisar si tiene pagos parciales para procesarlos individualmente
          if (pedidoJson['pagosParciales'] != null &&
              pedidoJson['pagosParciales'] is List &&
              (pedidoJson['pagosParciales'] as List).isNotEmpty) {
               
            // Si tiene pagos parciales, ignorar la forma de pago principal y procesar cada pago
            final pagosParciales = pedidoJson['pagosParciales'] as List;

            for (var pagoParcial in pagosParciales) {
              final double montoParcial = (pagoParcial['monto'] ?? 0.0)
                  .toDouble();
              final String formaPagoParcial = (pagoParcial['formaPago'] ?? '')
                  .toString()
                  .toLowerCase();

                

              switch (formaPagoParcial) {
                case 'efectivo':
                  totalEfectivo += montoParcial;
                  break;
                case 'transferencia':
                  totalTransferencias += montoParcial;
                  break;
                case 'tarjeta':
                  totalTarjeta += montoParcial;
                  break;
                default:
                  totalOtros += montoParcial;
              }
            }
          } else {
            // Procesar normalmente si no tiene pagos parciales
            switch (formaPago) {
              case 'efectivo':
                totalEfectivo += totalPedido;
                break;
              case 'transferencia':
                totalTransferencias += totalPedido;
                break;
              case 'tarjeta':
                totalTarjeta += totalPedido;
                break;
              default:
                totalOtros += totalPedido;
            }
          }
        }

        final double total =
            totalEfectivo + totalTransferencias + totalTarjeta + totalOtros;

          
          
                     
          
          

        return {
          'total': total,
          'efectivo': totalEfectivo,
          'transferencias': totalTransferencias,
          'tarjeta': totalTarjeta,
          'otros': totalOtros,
        };
      } else {
          
          

        return {
          'total': 0.0,
          'efectivo': 0.0,
          'transferencias': 0.0,
          'tarjeta': 0.0,
          'otros': 0.0,
        };
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener ventas por cuadre activo');
    }
  }

  // Obtener resumen completo de ventas del día
  Future<Map<String, dynamic>> getResumenVentasHoy() async {
    try {
        
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/reportes/detalles-ventas'),
        headers: headers,
      );

        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
          
        return responseData['data'];
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener resumen de ventas');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener resumen de ventas');
    }
  }

  // Método para compatibilidad con código legacy - alias de getVentasPorCuadreActivo
  Future<Map<String, dynamic>> getVentasPorTipoPago() async {
    return await getVentasPorCuadreActivo();
  }

  // Obtener información completa del cuadre actual incluyendo contadores
  Future<Map<String, dynamic>> getCuadreCompleto({String? tipoCaja}) async {
    try {

      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/api/cuadres-caja/reportes/cuadre-completo')
          .replace(queryParameters: tipoCaja != null ? {'tipoCaja': tipoCaja} : null);
      final response = await http.get(uri, headers: headers);

        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
          
        return responseData['data'];
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener cuadre completo');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener cuadre completo');
    }
  }

  // 📊 Obtener resumen de cierre completo con totales por método de pago
  Future<Map<String, dynamic>> getResumenCierreCompleto(String cuadreId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/reportes/$cuadreId/resumen-cierre'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener resumen de cierre');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener resumen de cierre');
    }
  }

  // 📊 Obtener informe temporal de cuadre de caja (sin guardar)
  Future<Map<String, dynamic>> getInformeCuadreTemp() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/reportes/cuadre-caja'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener informe de cuadre');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener informe de cuadre');
    }
  }
}
