import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/factura.dart';
import '../models/api_response.dart';
import '../config/endpoints_config.dart';

/// Servicio para gestionar las operaciones relacionadas con facturas
class FacturaService {
  static final FacturaService _instance = FacturaService._internal();
  factory FacturaService() => _instance;
  FacturaService._internal();

  final EndpointsConfig _endpoints = EndpointsConfig();
  final storage = FlutterSecureStorage();

  /// Obtiene los headers de autenticación para las solicitudes HTTP
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Procesa la respuesta HTTP y extrae los datos de la factura
  Factura? _processFacturaResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      // Manejar respuestas con estructura ApiResponse o directas
      if (responseData['data'] != null) {
        return Factura.fromJson(responseData['data']);
      } else {
        return Factura.fromJson(responseData);
      }
    }
    return null;
  }

  /// Procesa la respuesta HTTP y extrae los datos de las facturas
  List<Factura> _processFacturasResponse(http.Response response) {
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      // Manejar respuestas con estructura ApiResponse o directas
      final List<dynamic> jsonList = responseData['data'] ?? responseData;
      final facturas = jsonList.map((json) => Factura.fromJson(json)).toList();

      // Ordenar facturas por fecha de creación descendente (más recientes primero)
      facturas.sort((a, b) {
        final fechaA =
            a.fechaCreacion ?? DateTime.fromMillisecondsSinceEpoch(0);
        final fechaB =
            b.fechaCreacion ?? DateTime.fromMillisecondsSinceEpoch(0);
        return fechaB.compareTo(fechaA);
      });

      return facturas;
    }
    return [];
  }

  /// Obtiene todas las facturas
  Future<List<Factura>> getFacturas() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturas.lista),
        headers: headers,
      );

      return _processFacturasResponse(response);
    } catch (e) {
      print('❌ Error fetching facturas: $e');
      return [];
    }
  }

  /// Obtiene una factura por su ID
  Future<Factura?> getFacturaPorId(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturas.factura(id)),
        headers: headers,
      );

      return _processFacturaResponse(response);
    } catch (e) {
      print('❌ Error fetching factura: $e');
      return null;
    }
  }

  /// Obtiene una factura por su número
  Future<Factura?> getFacturaPorNumero(String numero) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturas.porNumero(numero)),
        headers: headers,
      );

      return _processFacturaResponse(response);
    } catch (e) {
      print('❌ Error fetching factura por número: $e');
      return null;
    }
  }

  /// Obtiene facturas por NIT
  Future<List<Factura>> getFacturasPorNit(String nit) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturas.porNit(nit)),
        headers: headers,
      );

      return _processFacturasResponse(response);
    } catch (e) {
      print('❌ Error fetching facturas por NIT: $e');
      return [];
    }
  }

  /// Obtiene facturas por teléfono del cliente
  Future<List<Factura>> getFacturasPorTelefono(String telefono) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturas.porTelefono(telefono)),
        headers: headers,
      );

      return _processFacturasResponse(response);
    } catch (e) {
      print('❌ Error fetching facturas por teléfono: $e');
      return [];
    }
  }

  /// Obtiene facturas pendientes de pago
  Future<List<Factura>> getFacturasPendientesPago() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturas.pendientesPago),
        headers: headers,
      );

      return _processFacturasResponse(response);
    } catch (e) {
      print('❌ Error fetching facturas pendientes: $e');
      return [];
    }
  }

  /// Obtiene facturas del día
  Future<List<Factura>> getFacturasDelDia() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturas.ventasDia),
        headers: headers,
      );

      return _processFacturasResponse(response);
    } catch (e) {
      print('❌ Error fetching facturas del día: $e');
      return [];
    }
  }

  /// Obtiene facturas por período
  Future<List<Factura>> getFacturasPorPeriodo(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'fechaInicio': fechaInicio.toIso8601String(),
        'fechaFin': fechaFin.toIso8601String(),
      };

      final uri = Uri.parse(
        _endpoints.facturas.ventasPeriodo,
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      return _processFacturasResponse(response);
    } catch (e) {
      print('❌ Error fetching facturas por período: $e');
      return [];
    }
  }

  /// Crea una nueva factura
  Future<Factura?> crearFactura(Factura factura) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(_endpoints.facturas.lista),
        headers: headers,
        body: json.encode(factura.toJson()),
      );

      return _processFacturaResponse(response);
    } catch (e) {
      print('❌ Error creating factura: $e');
      return null;
    }
  }

  /// Crea una factura a partir de un pedido
  Future<Factura?> crearFacturaDesdePedido(
    String pedidoId,
    Map<String, dynamic> datosFactura,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(_endpoints.facturas.desdePedido(pedidoId)),
        headers: headers,
        body: json.encode(datosFactura),
      );

      return _processFacturaResponse(response);
    } catch (e) {
      print('❌ Error creating factura desde pedido: $e');
      return null;
    }
  }

  /// Actualiza una factura existente
  Future<Factura?> actualizarFactura(String id, Factura factura) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(_endpoints.facturas.factura(id)),
        headers: headers,
        body: json.encode(factura.toJson()),
      );

      return _processFacturaResponse(response);
    } catch (e) {
      print('❌ Error updating factura: $e');
      return null;
    }
  }

  /// Emite una factura
  Future<Factura?> emitirFactura(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(_endpoints.facturas.emitir(id)),
        headers: headers,
      );

      return _processFacturaResponse(response);
    } catch (e) {
      print('❌ Error emitting factura: $e');
      return null;
    }
  }

  /// Registra el pago de una factura
  Future<Factura?> pagarFactura(
    String id,
    Map<String, dynamic> datosPago,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(_endpoints.facturas.pagar(id)),
        headers: headers,
        body: json.encode(datosPago),
      );

      return _processFacturaResponse(response);
    } catch (e) {
      print('❌ Error paying factura: $e');
      return null;
    }
  }

  /// Anula una factura
  Future<Factura?> anularFactura(
    String id,
    Map<String, dynamic> datosAnulacion,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(_endpoints.facturas.anular(id)),
        headers: headers,
        body: json.encode(datosAnulacion),
      );

      return _processFacturaResponse(response);
    } catch (e) {
      print('❌ Error cancelling factura: $e');
      return null;
    }
  }

  /// Elimina una factura
  Future<bool> eliminarFactura(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse(_endpoints.facturas.factura(id)),
        headers: headers,
      );

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('❌ Error deleting factura: $e');
      return false;
    }
  }

  /// Genera un resumen para impresión de un pedido
  Future<Map<String, dynamic>?> generarResumenImpresion(String pedidoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturas.resumenImpresion(pedidoId)),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'] ?? responseData;
      }
      return null;
    } catch (e) {
      print('❌ Error generating print summary: $e');
      return null;
    }
  }

  /// Genera una factura para impresión
  Future<Map<String, dynamic>?> generarFacturaImpresion(
    String facturaId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturas.facturaImpresion(facturaId)),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'] ?? responseData;
      }
      return null;
    } catch (e) {
      print('❌ Error generating invoice print: $e');
      return null;
    }
  }

  /// Obtiene un resumen de ventas
  Future<Map<String, dynamic>?> getResumenVentas() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturas.resumenVentas),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'] ?? responseData;
      }
      return null;
    } catch (e) {
      print('❌ Error fetching sales summary: $e');
      return null;
    }
  }
}
