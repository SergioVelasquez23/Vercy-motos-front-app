import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../utils/api_error.dart';
import '../models/pedido_asesor.dart';
import '../utils/logger.dart';

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
      
      final pedidoJson = pedido.toJson();

      // Guardar los orígenes originales (workaround backend)
      final origenesOriginales = <String, String>{};
      for (var item in pedidoJson['items']) {
        final productoId = item['productoId'].toString();
        origenesOriginales[productoId] = item['origen'].toString();
      }

      // 🔍 DEBUG: Ver qué se envía al backend
      appLog('📤 Creando pedido asesor:');
      appLog('   Items: ${pedidoJson['items'].length}');
      for (var item in pedidoJson['items']) {
        appLog('   - ${item['productoNombre']}: origen = ${item['origen']}');
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(pedidoJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null 
            ? decoded['data'] 
            : decoded;
        
        // 🔍 DEBUG: Ver qué devuelve el backend
        appLog('📥 Respuesta del backend al crear pedido:');
        if (data is Map && data['items'] != null) {
          appLog('   Items recibidos: ${(data['items'] as List).length}');

          // WORKAROUND: Restaurar orígenes si el backend los perdió
          for (var item in data['items']) {
            final productoId = item['productoId'].toString();
            appLog(
              '   - ${item['productoNombre']}: origen = ${item['origen'] ?? 'NULL'}',
            );

            if (item['origen'] == null &&
                origenesOriginales.containsKey(productoId)) {
              item['origen'] = origenesOriginales[productoId];
              appLog(
                '   ⚠️ Restaurado origen desde frontend: ${item['origen']}',
              );
            }
          }
        }
        
        return PedidoAsesor.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Error al crear pedido');
      }
    } catch (e) {
        
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

        // 🔍 DEBUG: Ver estructura de respuesta
        appLog('🔍 Respuesta del backend (pedidos asesores):');
        if (decoded is Map && decoded['data'] != null) {
          appLog('   Estructura con data wrapper');
        }

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
        
        // 🔍 DEBUG: Ver items en la lista de pedidos
        appLog('📥 Recibidos ${data.length} pedidos del backend');

        final pedidos = data.map((pedidoJson) {
          final pedido = PedidoAsesor.fromJson(pedidoJson);

          // Log de los items del primer pedido para debug
          if (data.indexOf(pedidoJson) == 0 && pedido.items.isNotEmpty) {
            appLog('   Primer pedido - Items:');
            for (var item in pedido.items) {
              appLog('     - ${item.productoNombre}: origen = ${item.origen}');
            }
          }

          return pedido;
        }).toList();

        return pedidos;
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
        
        // 🔍 DEBUG: Ver qué devuelve el backend para pedido individual
        appLog('📥 Pedido obtenido (ID: $id):');
        if (data is Map && data['items'] != null) {
          for (var item in data['items']) {
            appLog(
              '   - ${item['productoNombre']}: origen = ${item['origen'] ?? 'NULL (usará default ALMACÉN)'}',
            );
          }
        }
        
        return PedidoAsesor.fromJson(data);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener pedido');
      }
    } catch (e) {
        
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
        
      rethrow;
    }
  }
}
