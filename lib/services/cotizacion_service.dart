import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cotizacion.dart';
import '../config/endpoints_config.dart';

class CotizacionService {
  final EndpointsConfig _config = EndpointsConfig();

  String get baseUrl => '${_config.currentBaseUrl}/api/cotizaciones';

  /// Obtener todas las cotizaciones
  Future<List<Cotizacion>> obtenerCotizaciones() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cotizacion.fromJson(json)).toList();
      }

      throw Exception('Error al obtener cotizaciones: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en obtenerCotizaciones: $e');
      throw Exception('Error al obtener cotizaciones: $e');
    }
  }

  /// Obtener cotización por ID
  Future<Cotizacion?> obtenerCotizacionPorId(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$id'));

      if (response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      if (response.statusCode == 404) {
        return null;
      }

      throw Exception('Error al obtener cotización: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en obtenerCotizacionPorId: $e');
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cotizacion.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      throw Exception('Error al crear cotización: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en crearCotizacion: $e');
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cotizacion.toJson()),
      );

      if (response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      throw Exception('Error al actualizar cotización: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en actualizarCotizacion: $e');
      throw Exception('Error al actualizar cotización: $e');
    }
  }

  /// Eliminar cotización
  Future<bool> eliminarCotizacion(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/$id'));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('❌ Error en eliminarCotizacion: $e');
      return false;
    }
  }

  // Cálculos

  /// Calcular totales (preview antes de guardar)
  Future<Map<String, dynamic>> calcularTotales(Cotizacion cotizacion) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/calcular-totales'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cotizacion.toJson()),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Error al calcular totales: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en calcularTotales: $e');
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
      final response = await http.put(Uri.parse('$baseUrl/$id/aceptar'));

      if (response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      throw Exception('Error al aceptar cotización: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en aceptarCotizacion: $e');
      throw Exception('Error al aceptar cotización: $e');
    }
  }

  /// Rechazar cotización
  Future<Cotizacion> rechazarCotizacion(String id) async {
    try {
      final response = await http.put(Uri.parse('$baseUrl/$id/rechazar'));

      if (response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      throw Exception('Error al rechazar cotización: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en rechazarCotizacion: $e');
      throw Exception('Error al rechazar cotización: $e');
    }
  }

  /// Convertir cotización a factura
  Future<Cotizacion> convertirAFactura(String id, String facturaId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$id/convertir-factura'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'facturaId': facturaId}),
      );

      if (response.statusCode == 200) {
        return Cotizacion.fromJson(json.decode(response.body));
      }

      throw Exception('Error al convertir cotización: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en convertirAFactura: $e');
      throw Exception('Error al convertir cotización: $e');
    }
  }

  // Filtros

  /// Obtener cotizaciones por cliente
  Future<List<Cotizacion>> obtenerPorCliente(String clienteId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cliente/$clienteId'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cotizacion.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('❌ Error en obtenerPorCliente: $e');
      return [];
    }
  }

  /// Obtener cotizaciones por estado
  Future<List<Cotizacion>> obtenerPorEstado(String estado) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/estado/$estado'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cotizacion.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('❌ Error en obtenerPorEstado: $e');
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
      final response = await http.get(Uri.parse('$baseUrl/estadisticas'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Error al obtener estadísticas: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en obtenerEstadisticas: $e');
      throw Exception('Error al obtener estadísticas: $e');
    }
  }

  // Búsqueda

  /// Buscar cotizaciones
  Future<List<Cotizacion>> buscarCotizaciones(String q) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/buscar?q=${Uri.encodeComponent(q)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cotizacion.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('❌ Error en buscarCotizaciones: $e');
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
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cotizacion.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('❌ Error en obtenerPorRangoFechas: $e');
      return [];
    }
  }
}
