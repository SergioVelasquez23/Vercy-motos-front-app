import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cotizacion.dart';
import '../config/endpoints_config.dart';
import '../utils/api_error.dart';
import 'base_api_service.dart';

class CotizacionService {
  final EndpointsConfig _config = EndpointsConfig();
  final BaseApiService _api = BaseApiService();

  String get baseUrl => '${_config.currentBaseUrl}/api/cotizaciones';
  static const _timeout = Duration(seconds: 30);

  /// Headers con Authorization (Bearer) desde BaseApiService
  Future<Map<String, String>> get _headers => _api.getHeaders();

  /// Obtener todas las cotizaciones
  Future<List<Cotizacion>> obtenerCotizaciones() async {
    try {
        
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: await _headers,
      ).timeout(_timeout);
            
      if (response.statusCode == 200) {
          
        final dynamic responseData = json.decode(response.body);

        // Manejar si viene como lista directa o dentro de un objeto
        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData['data'] != null) {
          data = responseData['data'];
        } else {
            
          throw Exception('Estructura de respuesta inesperada');
        }

          
        return data.map((json) => Cotizacion.fromJson(json)).toList();
      }

        
      throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener cotizaciones');
    } catch (e) {
        
      rethrow;
    }
  }

  /// Obtener cotización por ID
  Future<Cotizacion?> obtenerCotizacionPorId(String id) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/$id'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      if (response.statusCode == 404) {
        return null;
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener cotización');
    } catch (e) {
        
      return null;
    }
  }

  /// Crear cotización
  Future<Cotizacion> crearCotizacion(Cotizacion cotizacion) async {
    try {
      // Calcular totales antes de enviar
      cotizacion.calcularTotales();

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: await _headers,
        body: json.encode(cotizacion.toJson()),
      ).timeout(_timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al crear cotización');
    } catch (e) {
        
      throw Exception('Error al crear cotización: $e');
    }
  }

  /// Actualizar cotización
  Future<Cotizacion> actualizarCotizacion(
    String id,
    Cotizacion cotizacion,
  ) async {
    try {
      // Calcular totales antes de enviar
      cotizacion.calcularTotales();

      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: await _headers,
        body: json.encode(cotizacion.toJson()),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al actualizar cotización');
    } catch (e) {
        
      throw Exception('Error al actualizar cotización: $e');
    }
  }

  /// Eliminar cotización
  Future<bool> eliminarCotizacion(String id) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/$id'), headers: await _headers)
          .timeout(_timeout);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
        
      return false;
    }
  }

  // Cálculos

  /// Calcular totales (preview antes de guardar)
  Future<Map<String, dynamic>> calcularTotales(Cotizacion cotizacion) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/calcular-totales'),
        headers: await _headers,
        body: json.encode(cotizacion.toJson()),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al calcular totales');
    } catch (e) {
        
      // Si falla el backend, calcular localmente
      cotizacion.calcularTotales();
      return {
        'subtotal': cotizacion.subtotal,
        'totalImpuestos': cotizacion.totalImpuestos,
        'totalDescuentos': cotizacion.totalDescuentos,
        'totalRetenciones': cotizacion.totalRetenciones,
        'totalFinal': cotizacion.totalFinal,
      };
    }
  }

  // Estados

  /// Aceptar cotización
  Future<Cotizacion> aceptarCotizacion(String id) async {
    try {
      final response = await http
          .put(Uri.parse('$baseUrl/$id/aceptar'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al aceptar cotización');
    } catch (e) {
        
      throw Exception('Error al aceptar cotización: $e');
    }
  }

  /// Rechazar cotización
  Future<Cotizacion> rechazarCotizacion(String id) async {
    try {
      final response = await http
          .put(Uri.parse('$baseUrl/$id/rechazar'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al rechazar cotización');
    } catch (e) {
        
      throw Exception('Error al rechazar cotización: $e');
    }
  }

  /// Convertir cotización a factura
  Future<Cotizacion> convertirAFactura(String id, String facturaId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$id/convertir-factura'),
        headers: await _headers,
        body: json.encode({'facturaId': facturaId}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al convertir cotización');
    } catch (e) {
        
      throw Exception('Error al convertir cotización: $e');
    }
  }

  // Filtros

  /// Obtener cotizaciones por cliente
  Future<List<Cotizacion>> obtenerPorCliente(String clienteId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/cliente/$clienteId'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cotizacion.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
        
      return [];
    }
  }

  /// Obtener cotizaciones por estado
  Future<List<Cotizacion>> obtenerPorEstado(String estado) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/estado/$estado'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cotizacion.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
        
      return [];
    }
  }

  /// Obtener cotizaciones activas
  Future<List<Cotizacion>> obtenerActivas() async {
    return obtenerPorEstado('activa');
  }

  /// Obtener cotizaciones aceptadas
  Future<List<Cotizacion>> obtenerAceptadas() async {
    return obtenerPorEstado('aceptada');
  }

  /// Obtener cotizaciones rechazadas
  Future<List<Cotizacion>> obtenerRechazadas() async {
    return obtenerPorEstado('rechazada');
  }

  /// Obtener cotizaciones vencidas
  Future<List<Cotizacion>> obtenerVencidas() async {
    return obtenerPorEstado('vencida');
  }

  /// Obtener cotizaciones convertidas a factura
  Future<List<Cotizacion>> obtenerConvertidas() async {
    return obtenerPorEstado('convertida');
  }

  /// Obtener estadísticas de cotizaciones
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/estadisticas'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener estadísticas');
    } catch (e) {
        
      throw Exception('Error al obtener estadísticas: $e');
    }
  }

  // Búsqueda

  /// Buscar cotizaciones
  Future<List<Cotizacion>> buscarCotizaciones(String q) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/buscar?q=${Uri.encodeComponent(q)}'),
        headers: await _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cotizacion.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
        
      return [];
    }
  }

  /// Obtener cotizaciones por rango de fechas
  Future<List<Cotizacion>> obtenerPorRangoFechas(
    DateTime inicio,
    DateTime fin,
  ) async {
    try {
      final inicioStr = inicio.toIso8601String().split('T')[0];
      final finStr = fin.toIso8601String().split('T')[0];

      final response = await http.get(
        Uri.parse('$baseUrl/rango-fechas?inicio=$inicioStr&fin=$finStr'),
        headers: await _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cotizacion.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
        
      return [];
    }
  }

  /// Generar PDF de cotización
  Future<Map<String, dynamic>> generarPDF(String id) async {
    try {
      final headers = await _headers;
      headers['Accept'] = 'application/pdf';
      final response = await http.get(
        Uri.parse('$baseUrl/$id/pdf'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        // El backend debería retornar la URL del PDF o los bytes
        final data = json.decode(response.body);
        return data;
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al generar PDF');
    } catch (e) {
      throw Exception('Error al generar PDF: $e');
    }
  }
}
