import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/pedido_asesor.dart';

class PedidoAsesorService {
  final ApiConfig _apiConfig = ApiConfig();
  final storage = FlutterSecureStorage();

  String get baseUrl => '${_apiConfig.baseUrl}/api/pedidos-asesor';

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Crear pedido de asesor
  Future<PedidoAsesor> crearPedido(PedidoAsesor pedido) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(pedido.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null 
            ? decoded['data'] 
            : decoded;
        return PedidoAsesor.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Error al crear pedido');
      }
    } catch (e) {
      print('Error en crearPedido: $e');
      rethrow;
    }
  }

  // Listar pedidos (con filtros opcionales)
  Future<List<PedidoAsesor>> listarPedidos({
    String? estado,
    String? asesorId,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = baseUrl;

      List<String> params = [];
      if (estado != null && estado != 'TODOS') {
        params.add('estado=$estado');
      }
      if (asesorId != null && asesorId.isNotEmpty) {
        params.add('asesorId=$asesorId');
      }

      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // Manejar diferentes estructuras de respuesta
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] != null) {
            final dataField = decoded['data'];
            if (dataField is List) {
              data = dataField;
            } else if (dataField is Map && dataField['content'] != null) {
              data = dataField['content'] as List;
            } else {
              data = [];
            }
          } else if (decoded['content'] != null) {
            data = decoded['content'] as List;
          } else {
            data = [];
          }
        } else {
          data = [];
        }
        
        return data.map((json) => PedidoAsesor.fromJson(json)).toList();
      } else {
        // Intentar obtener el mensaje de error del backend
        String errorMsg = 'Error al cargar pedidos: ${response.statusCode}';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody['message'] != null) {
            errorMsg = errorBody['message'];
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Error en listarPedidos: $e');
      return []; // Retornar lista vacía para no romper la UI
    }
  }

  // Obtener un pedido específico
  Future<PedidoAsesor> obtenerPedido(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return PedidoAsesor.fromJson(data);
      } else {
        throw Exception('Error al obtener pedido: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerPedido: $e');
      rethrow;
    }
  }

  // Actualizar pedido
  Future<PedidoAsesor> actualizarPedido(String id, PedidoAsesor pedido) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
        body: json.encode(pedido.toJson()),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return PedidoAsesor.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Error al actualizar pedido');
      }
    } catch (e) {
      print('Error en actualizarPedido: $e');
      rethrow;
    }
  }

  // Marcar como facturado
  Future<PedidoAsesor> marcarComoFacturado(
    String id,
    String facturadoPor,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/$id/facturar'),
        headers: headers,
        body: json.encode({'facturadoPor': facturadoPor}),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return PedidoAsesor.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Error al facturar pedido');
      }
    } catch (e) {
      print('Error en marcarComoFacturado: $e');
      rethrow;
    }
  }

  // Cancelar pedido
  Future<PedidoAsesor> cancelarPedido(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/$id/cancelar'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return PedidoAsesor.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Error al cancelar pedido');
      }
    } catch (e) {
      print('Error en cancelarPedido: $e');
      rethrow;
    }
  }

  // Eliminar pedido
  Future<void> eliminarPedido(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Error al eliminar pedido');
      }
    } catch (e) {
      print('Error en eliminarPedido: $e');
      rethrow;
    }
  }
}
