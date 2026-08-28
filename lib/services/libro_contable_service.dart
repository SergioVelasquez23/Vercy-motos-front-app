import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'base_api_service.dart';

class LibroContableService {
  final String _baseUrl = ApiConfig.instance.baseUrl;
  final BaseApiService _baseService = BaseApiService();

  /// Tiempo máximo de espera para todos los reportes de este servicio. Los
  /// cálculos por rango (resumen contable, costeo, rentabilidad) recorren
  /// muchos pedidos/items y pueden tardar varios minutos en rangos amplios.
  static const Duration _timeout = Duration(minutes: 10);

  /// Obtiene el libro contable de un mes: ventas de Facturación Electrónica + POS
  /// separadas de ventas Locales (desglosadas por medio de pago detallado), más
  /// totales de Compras y Gastos del mes.
  Future<Map<String, dynamic>> getLibroContableMensual(int anio, int mes) async {
    try {
      final token = await _baseService.getToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final url = Uri.parse(
        '$_baseUrl/api/reportes/libro-contable?anio=$anio&mes=$mes',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            _timeout,
            onTimeout: () {
              throw Exception(
                'El servidor tardó demasiado en responder. Intenta con un mes con menos datos.',
              );
            },
          );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          return jsonData['data'] as Map<String, dynamic>;
        } else {
          throw Exception(jsonData['message'] ?? 'Error desconocido');
        }
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Verifica tus credenciales.');
      } else if (response.statusCode == 403) {
        throw Exception(
          'No tienes permisos para ver el libro contable.',
        );
      } else if (response.statusCode == 404) {
        throw Exception(
          'Endpoint no encontrado. Verifica la configuración del servidor.',
        );
      } else {
        final errorBody = response.body.isNotEmpty
            ? response.body
            : 'Sin detalles del error';
        throw Exception(
          'Error del servidor (${response.statusCode}): $errorBody',
        );
      }
    } on SocketException {
      throw Exception('Sin conexión a internet. Verifica tu conectividad.');
    } on http.ClientException {
      throw Exception('Error de conexión con el servidor.');
    } on FormatException {
      throw Exception('Error en el formato de respuesta del servidor.');
    } catch (e) {
      rethrow;
    }
  }

  /// Igual que [getLibroContableMensual] pero para un rango de fechas
  /// arbitrario en vez de un mes calendario completo — incluye "utilidadBruta"
  /// (ventas − compras − gastos del mismo rango), equivalente al balance de
  /// cierre de caja pero calculado sobre el período elegido.
  Future<Map<String, dynamic>> getLibroContablePorRango(
    DateTime desde,
    DateTime hasta,
  ) async {
    try {
      final token = await _baseService.getToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final url = Uri.parse(
        '$_baseUrl/api/reportes/libro-contable/rango'
        '?fechaDesde=${desde.toIso8601String()}&fechaHasta=${hasta.toIso8601String()}',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            _timeout,
            onTimeout: () {
              throw Exception(
                'El servidor tardó demasiado en responder. Intenta con un rango más corto.',
              );
            },
          );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          return jsonData['data'] as Map<String, dynamic>;
        } else {
          throw Exception(jsonData['message'] ?? 'Error desconocido');
        }
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Verifica tus credenciales.');
      } else if (response.statusCode == 403) {
        throw Exception(
          'No tienes permisos para ver el libro contable.',
        );
      } else {
        final errorBody = response.body.isNotEmpty
            ? response.body
            : 'Sin detalles del error';
        throw Exception(
          'Error del servidor (${response.statusCode}): $errorBody',
        );
      }
    } on SocketException {
      throw Exception('Sin conexión a internet. Verifica tu conectividad.');
    } on http.ClientException {
      throw Exception('Error de conexión con el servidor.');
    } on FormatException {
      throw Exception('Error en el formato de respuesta del servidor.');
    } catch (e) {
      rethrow;
    }
  }

  /// Costeo de inventario y utilidad real (basada en costo de mercancía
  /// vendida, no solo caja). Combina el método "por venta" (costo capturado
  /// en cada item, o estimado con el costo actual del producto si la venta
  /// es anterior a esa captura) y el método "por inventario" (fórmula
  /// contable clásica Inventario inicial + Compras sin IVA − Inventario
  /// final), este último solo se calcula si se informa [inventarioInicial].
  Future<Map<String, dynamic>> getCosteoInventario(
    DateTime desde,
    DateTime hasta, {
    double? inventarioInicial,
  }) async {
    try {
      final token = await _baseService.getToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      var url =
          '$_baseUrl/api/reportes/costeo-utilidad'
          '?fechaDesde=${desde.toIso8601String()}&fechaHasta=${hasta.toIso8601String()}';
      if (inventarioInicial != null) {
        url += '&inventarioInicial=$inventarioInicial';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            _timeout,
            onTimeout: () {
              throw Exception(
                'El servidor tardó demasiado en responder. Intenta con un rango más corto.',
              );
            },
          );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          return jsonData['data'] as Map<String, dynamic>;
        } else {
          throw Exception(jsonData['message'] ?? 'Error desconocido');
        }
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Verifica tus credenciales.');
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permisos para ver este reporte.');
      } else {
        final errorBody = response.body.isNotEmpty
            ? response.body
            : 'Sin detalles del error';
        throw Exception(
          'Error del servidor (${response.statusCode}): $errorBody',
        );
      }
    } on SocketException {
      throw Exception('Sin conexión a internet. Verifica tu conectividad.');
    } on http.ClientException {
      throw Exception('Error de conexión con el servidor.');
    } on FormatException {
      throw Exception('Error en el formato de respuesta del servidor.');
    } catch (e) {
      rethrow;
    }
  }

  /// GET genérico con el mismo manejo de token/timeout/errores que los demás
  /// métodos de este servicio — usado por los reportes de rentabilidad y
  /// comparación de períodos para no triplicar ese bloque otra vez.
  Future<Map<String, dynamic>> _getJson(String url) async {
    try {
      final token = await _baseService.getToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            _timeout,
            onTimeout: () {
              throw Exception(
                'El servidor tardó demasiado en responder. Intenta con un rango más corto.',
              );
            },
          );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          return jsonData['data'] as Map<String, dynamic>;
        } else {
          throw Exception(jsonData['message'] ?? 'Error desconocido');
        }
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Verifica tus credenciales.');
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permisos para ver este reporte.');
      } else {
        final errorBody = response.body.isNotEmpty
            ? response.body
            : 'Sin detalles del error';
        throw Exception(
          'Error del servidor (${response.statusCode}): $errorBody',
        );
      }
    } on SocketException {
      throw Exception('Sin conexión a internet. Verifica tu conectividad.');
    } on http.ClientException {
      throw Exception('Error de conexión con el servidor.');
    } on FormatException {
      throw Exception('Error en el formato de respuesta del servidor.');
    } catch (e) {
      rethrow;
    }
  }

  /// Rentabilidad por producto en el rango: cuáles son más rentables (por
  /// utilidad real) y cuáles tienen mucha venta pero poco margen (lista por
  /// cantidad vendida, con su margen % visible).
  Future<Map<String, dynamic>> getRentabilidadProductos(
    DateTime desde,
    DateTime hasta, {
    int limite = 10,
    String? filtroTipoItem,
  }) {
    var url =
        '$_baseUrl/api/reportes/rentabilidad-productos'
        '?fechaDesde=${desde.toIso8601String()}&fechaHasta=${hasta.toIso8601String()}'
        '&limite=$limite';
    if (filtroTipoItem != null) {
      url += '&filtroTipoItem=$filtroTipoItem';
    }
    return _getJson(url);
  }

  /// Rentabilidad por cliente en el rango: quiénes generan mayor utilidad
  /// real, no solo mayor venta. Agrupa por el nombre de cliente en texto
  /// libre del pedido (el sistema no tiene un clienteId real todavía).
  Future<Map<String, dynamic>> getRentabilidadClientes(
    DateTime desde,
    DateTime hasta, {
    int limite = 10,
    bool excluirConsumidorFinal = true,
  }) {
    final url =
        '$_baseUrl/api/reportes/rentabilidad-clientes'
        '?fechaDesde=${desde.toIso8601String()}&fechaHasta=${hasta.toIso8601String()}'
        '&limite=$limite&excluirConsumidorFinal=$excluirConsumidorFinal';
    return _getJson(url);
  }

  /// Compara la utilidad real de dos períodos (sirve tanto para "mes actual
  /// vs. mes anterior" como para "este rango vs. mismo rango año anterior" —
  /// quien llama decide qué representa cada rango).
  Future<Map<String, dynamic>> getComparativoPeriodos(
    DateTime desdeActual,
    DateTime hastaActual,
    DateTime desdeAnterior,
    DateTime hastaAnterior,
  ) {
    final url =
        '$_baseUrl/api/reportes/comparar-periodos'
        '?fechaDesdeActual=${desdeActual.toIso8601String()}&fechaHastaActual=${hastaActual.toIso8601String()}'
        '&fechaDesdeAnterior=${desdeAnterior.toIso8601String()}&fechaHastaAnterior=${hastaAnterior.toIso8601String()}';
    return _getJson(url);
  }

  /// Detección de anomalías contables: gastos que subieron anormalmente por
  /// categoría, caída de ventas, clientes que compran menos, facturas
  /// inusualmente altas, proveedores con aumento de precio, y meses con
  /// pérdida — cada una con un mensaje ya redactado por el backend.
  Future<Map<String, dynamic>> getAnomalias(
    DateTime desde,
    DateTime hasta, {
    int cantidadPeriodosHistoricos = 6,
    int cantidadMesesPerdida = 6,
  }) {
    final url =
        '$_baseUrl/api/reportes/anomalias'
        '?fechaDesde=${desde.toIso8601String()}&fechaHasta=${hasta.toIso8601String()}'
        '&cantidadPeriodosHistoricos=$cantidadPeriodosHistoricos&cantidadMesesPerdida=$cantidadMesesPerdida';
    return _getJson(url);
  }

  /// Recomendaciones en texto sobre la salud financiera del período: reglas
  /// fijas (margen bajo, gastos fijos altos, compras altas, desbalance
  /// repuestos/mano de obra, cartera vencida) más la comparación contra el
  /// período anterior — cada una con un "mensaje" ya redactado por el backend,
  /// igual criterio que [getAnomalias]. Devuelve la lista directamente (el
  /// backend responde con una lista, no un mapa, a diferencia de los demás
  /// métodos de este servicio).
  Future<List<dynamic>> getRecomendaciones(DateTime desde, DateTime hasta) async {
    final token = await _baseService.getToken();
    if (token == null) {
      throw Exception('No hay token de autenticación');
    }

    final url = Uri.parse(
      '$_baseUrl/api/reportes/libro-contable/recomendaciones'
      '?fechaDesde=${desde.toIso8601String()}&fechaHasta=${hasta.toIso8601String()}',
    );

    try {
      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            _timeout,
            onTimeout: () {
              throw Exception(
                'El servidor tardó demasiado en responder. Intenta con un rango más corto.',
              );
            },
          );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          return jsonData['data'] as List<dynamic>;
        } else {
          throw Exception(jsonData['message'] ?? 'Error desconocido');
        }
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Verifica tus credenciales.');
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permisos para ver este reporte.');
      } else {
        final errorBody = response.body.isNotEmpty
            ? response.body
            : 'Sin detalles del error';
        throw Exception(
          'Error del servidor (${response.statusCode}): $errorBody',
        );
      }
    } on SocketException {
      throw Exception('Sin conexión a internet. Verifica tu conectividad.');
    } on http.ClientException {
      throw Exception('Error de conexión con el servidor.');
    } on FormatException {
      throw Exception('Error en el formato de respuesta del servidor.');
    } catch (e) {
      rethrow;
    }
  }
}
