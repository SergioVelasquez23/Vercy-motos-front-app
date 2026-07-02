import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../utils/api_error.dart';
import '../utils/logger.dart';
import '../models/traslado.dart';

class TrasladoService {
  final ApiConfig _apiConfig = ApiConfig();
  final storage = FlutterSecureStorage();

  static const _timeout = Duration(seconds: 30);

  String get baseUrl => '${_apiConfig.baseUrl}/api/traslados';

  // Obtener headers con token
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

  // Listar traslados
  Future<List<Traslado>> listarTraslados({
    String? estado,
    String? bodegaId,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = baseUrl;

      List<String> params = [];
      if (estado != null && estado != 'TODOS') {
        params.add('estado=$estado');
      }
      if (bodegaId != null && bodegaId.isNotEmpty) {
        params.add('bodegaId=$bodegaId');
      }

      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // Manejar diferentes estructuras de respuesta
        List<dynamic> data;
        if (decoded is List) {
          // Respuesta directa como lista
          data = decoded;
        } else if (decoded is Map) {
          // Respuesta envuelta en objeto con 'data' o 'content'
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
        
        return data.map((json) => Traslado.fromJson(json)).toList();
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al cargar traslados');
      }
    } catch (e) {
        
      return []; // Retornar lista vacía en caso de error para no romper la UI
    }
  }

  // Obtener un traslado por ID
  Future<Traslado> obtenerTraslado(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Manejar respuesta envuelta
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return Traslado.fromJson(data);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener traslado');
      }
    } catch (e) {
        
      rethrow;
    }
  }

  // Crear traslado — body real del backend:
  // { asesor, tipo: "BODEGA_A_ALMACEN"|"ALMACEN_A_BODEGA", observaciones?, items: [{productoId, cantidad}] }
  Future<Traslado> crearTraslado({
    required List<Map<String, dynamic>> items, // [{ productoId, cantidad }]
    required String origen,   // "BODEGA" o "ALMACEN"
    required String destino,  // "BODEGA" o "ALMACEN"
    required String asesor,
    String? observaciones,
  }) async {
    try {
      final headers = await _getHeaders();
      final tipo = '${origen}_A_$destino'; // e.g. "BODEGA_A_ALMACEN"
      final body = json.encode({
        'asesor': asesor,
        'tipo': tipo,
        'items': items,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones,
      });

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: body,
      ).timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return Traslado.fromJson(data);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al crear traslado');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Procesar traslado (aceptar o rechazar)
  Future<Traslado> procesarTraslado({
    required String trasladoId,
    required String accion, // ACEPTAR o RECHAZAR
    required String aprobador,
    String? observaciones,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'trasladoId': trasladoId,
        'accion': accion,
        'aprobador': aprobador,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones,
      });

      final response = await http.put(
        Uri.parse('$baseUrl/procesar'),
        headers: headers,
        body: body,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Manejar respuesta envuelta
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return Traslado.fromJson(data);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al procesar traslado');
      }
    } catch (e) {

      rethrow;
    }
  }

  // 🆕 Obtener stock de un producto específico
  Future<Map<String, dynamic>> obtenerStockProducto(String productoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/producto/$productoId/stock'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return decoded is Map<String, dynamic> ? decoded : {};
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener stock');
      }
    } catch (e) {
        
      return {'cantidadBodega': 0, 'cantidadAlmacen': 0, 'cantidadTotal': 0};
    }
  }

  // 🆕 Traslado rápido (sin aprobación)
  Future<Map<String, dynamic>> trasladoRapido({
    required String productoId,
    required String origen, // "BODEGA" o "ALMACEN"
    required String destino, // "BODEGA" o "ALMACEN"
    required double cantidad,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'productoId': productoId,
        'origen': origen,
        'destino': destino,
        'cantidad': cantidad,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/traslado-rapido'),
        headers: headers,
        body: body,
      ).timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        return decoded is Map<String, dynamic> ? decoded : {};
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error en traslado rápido');
      }
    } catch (e) {

      rethrow;
    }
  }

  // 🆕 Completar traslado (marca como completado sin validar stock)
  Future<void> completarTraslado({
    required String trasladoId,
    required String aprobador,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'aprobador': aprobador});

      final response = await http.post(
        Uri.parse('$baseUrl/$trasladoId/completar'),
        headers: headers,
        body: body,
      ).timeout(_timeout);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al completar traslado');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ─── Nuevos endpoints por producto (/api/productos/{id}/traslado) ──────────

  /// POST /api/productos/{productoId}/traslado
  /// Body: { cantidad, origen, destino, usuario, observaciones }
  /// Respuesta: { productoNombre, cantidad, origen, destino, stockResultante: { bodega, almacen } }
  Future<Map<String, dynamic>> trasladarProducto({
    required String productoId,
    required double cantidad,
    required String origen, // "bodega" o "almacen"
    required String destino, // "bodega" o "almacen"
    required String usuario,
    String? observaciones,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'cantidad': cantidad,
        'origen': origen,
        'destino': destino,
        'usuario': usuario,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones,
      });

      final response = await http.post(
        Uri.parse('${_apiConfig.baseUrl}/api/productos/$productoId/traslado'),
        headers: headers,
        body: body,
      ).timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return data is Map<String, dynamic> ? data : {};
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al trasladar producto');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Después de una venta exitosa, elimina de los traslados activos los items
  /// cuyos productos ya fueron facturados. Si todos los items de un traslado
  /// fueron vendidos → elimina el traslado. Si quedan items → actualiza el traslado.
  /// [mongoProductoIds] son los IDs reales de MongoDB de los productos vendidos.
  Future<void> notificarProductosFacturados(List<String> mongoProductoIds) async {
    if (mongoProductoIds.isEmpty) return;
    try {
      final traslados = await listarTraslados();
      for (final traslado in traslados) {
        if (traslado.id == null || traslado.items.isEmpty) continue;

        final itemsRestantes = traslado.items
            .where((item) => !mongoProductoIds.contains(item.productoId))
            .toList();

        if (itemsRestantes.length == traslado.items.length) continue; // nada facturado aquí

        if (itemsRestantes.isEmpty) {
          await eliminarTraslado(traslado.id!);
        } else {
          await _actualizarItemsTraslado(traslado.id!, traslado, itemsRestantes);
        }
      }
    } catch (e) {
      appLog('⚠️ [TrasladoService] Error al limpiar traslados post-facturación: $e');
    }
  }

  Future<void> _actualizarItemsTraslado(
    String id,
    Traslado traslado,
    List<ItemTraslado> itemsRestantes,
  ) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        ...traslado.toJson(),
        'items': itemsRestantes
            .map((i) => {
                  'productoId': i.productoId,
                  'nombreProducto': i.nombreProducto,
                  'cantidad': i.cantidad,
                })
            .toList(),
      });
      await http.put(Uri.parse('$baseUrl/$id'), headers: headers, body: body).timeout(_timeout);
    } catch (e) {
      appLog('⚠️ [TrasladoService] No se pudo actualizar items del traslado $id: $e');
    }
  }

  /// DELETE /api/traslados/{id}
  Future<void> eliminarTraslado(String id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: headers,
    ).timeout(_timeout);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throwBackendError(response.body, response.statusCode, prefix: 'Error al eliminar traslado');
    }
  }

  /// GET /api/productos/traslados?usuario=&productoId=&limit=
  Future<List<Map<String, dynamic>>> listarTrasladosProducto({
    String? usuario,
    String? productoId,
    int limit = 50,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{'limit': '$limit'};
      if (usuario != null && usuario.isNotEmpty) params['usuario'] = usuario;
      if (productoId != null && productoId.isNotEmpty) params['productoId'] = productoId;

      final uri = Uri.parse('${_apiConfig.baseUrl}/api/productos/traslados')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
