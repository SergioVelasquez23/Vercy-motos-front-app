import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/factura.dart';
import '../models/pedido.dart';
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

  /// Procesa la respuesta HTTP y extrae los datos de los pedidos
  List<Pedido> _processPedidosResponse(http.Response response) {
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      // Manejar respuestas con estructura ApiResponse o directas
      final List<dynamic> jsonList = responseData['data'] ?? responseData;
      final pedidos = jsonList.map((json) => Pedido.fromJson(json)).toList();

      // Ordenar pedidos por fecha descendente (más recientes primero)
      pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));

      return pedidos;
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
        
      return [];
    }
  }

  /// Obtiene pedidos en estado PAGO con paginación
  /// Carga 10 pedidos por página por defecto
  Future<List<Pedido>> getPedidosPagados({int page = 0, int size = 10}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {'page': page.toString(), 'size': size.toString()};

      final uri = Uri.parse(
        _endpoints.pedidos.pagados,
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Manejar respuesta con estructura ApiResponse
        final Map<String, dynamic> datos = responseData['data'] ?? responseData;
        final List<dynamic> contenido = datos['contenido'] ?? [];

        final pedidos = contenido
            .map((json) => Pedido.fromJson(json as Map<String, dynamic>))
            .toList();

        // Ordenar pedidos por fecha descendente
        pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));

        return pedidos;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Obtiene todos los pedidos pagados (sin paginación)
  /// Útil para cuando necesitas todos los registros de una vez
  Future<List<Pedido>> getAllPedidosPagados() async {
    try {
      final List<Pedido> todosPedidos = [];
      int page = 0;
      bool hayMas = true;

      while (hayMas) {
        final pedidos = await getPedidosPagados(page: page, size: 50);

        if (pedidos.isEmpty) {
          hayMas = false;
        } else {
          todosPedidos.addAll(pedidos);
          page++;
        }
      }

      return todosPedidos;
    } catch (e) {
      return [];
    }
  }

  /// Obtiene información paginada completa de pedidos pagados
  /// Incluye totales, número de páginas, etc.
  Future<Map<String, dynamic>?> getPedidosPagadosInfo({
    int page = 0,
    int size = 10,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {'page': page.toString(), 'size': size.toString()};

      final uri = Uri.parse(
        _endpoints.pedidos.pagados,
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Manejar respuesta con estructura ApiResponse
        final Map<String, dynamic> datos = responseData['data'] ?? responseData;
        return datos;
      }
      return null;
    } catch (e) {
      return null;
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
        
      return null;
    }
  }
}
