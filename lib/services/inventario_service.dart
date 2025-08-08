import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/inventario.dart';
import '../models/movimiento_inventario.dart';
import '../config/api_config.dart';

class InventarioService {
  final ApiConfig _apiConfig = ApiConfig();
  final String _baseEndpoint = 'api/inventario';
  final _inventarioActualizadoController = StreamController<bool>.broadcast();
  final Duration _timeout = Duration(seconds: ApiConfig.requestTimeout);

  InventarioService() {
    if (kDebugMode) {
      print('🔧 InventarioService initialized with endpoint: $_baseEndpoint');
    }
  }

  Stream<bool> get onInventarioActualizado =>
      _inventarioActualizadoController.stream;

  /// Procesar pedido para descontar ingredientes del inventario
  /// Maneja el error 404 si el endpoint no está disponible en el backend
  Future<void> procesarPedidoParaInventario(String pedidoId) async {
    if (kDebugMode) {
      print('🔄 Procesando pedido para descuento de inventario: $pedidoId');
    }

    try {
      final response = await http
          .post(
            Uri.parse(
              '${_apiConfig.baseUrl}/api/pedidos/$pedidoId/procesar-inventario',
            ),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
        print('📦 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          _inventarioActualizadoController.add(true);
          if (kDebugMode) {
            print(
              '✅ Inventario actualizado correctamente para pedido: $pedidoId',
            );
          }
          return;
        }
      } else if (response.statusCode == 404) {
        // Endpoint no disponible - el backend debe procesarlo automáticamente
        if (kDebugMode) {
          print(
            'ℹ️ Endpoint de inventario no disponible (404) - se asume procesamiento automático en backend',
          );
        }
        _inventarioActualizadoController.add(true);
        return;
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error procesando inventario para pedido: $e');
      }
      // No lanzar excepción para no fallar la creación del pedido
      if (kDebugMode) {
        print(
          '⚠️ Continuando sin fallar el pedido - el backend debería procesar automáticamente',
        );
      }
      _inventarioActualizadoController.add(true);
    }
  }

  String _buildUrl([String? path]) {
    // Eliminar barras finales de la URL base
    final base = _apiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    // Eliminar barras iniciales y finales del endpoint base
    final endpoint = _baseEndpoint
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');

    if (path == null) {
      return '$base/$endpoint';
    }

    // Eliminar barras iniciales y finales del path
    final cleanPath = path
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
    return '$base/$endpoint/$cleanPath';
  }

  String _buildMovimientosUrl([String? path]) {
    // Eliminar barras finales de la URL base
    final base = _apiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    // Eliminar barras iniciales y finales del endpoint base
    final endpoint = _baseEndpoint
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');

    if (path == null) {
      return '$base/$endpoint/movimientos';
    }

    // Eliminar barras iniciales y finales del path
    final cleanPath = path
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
    return '$base/$endpoint/movimientos/$cleanPath';
  }

  // Obtener todos los movimientos de inventario
  Future<List<MovimientoInventario>> getMovimientosInventario() async {
    if (kDebugMode) {
      print('🔍 GET Request to: ${_buildMovimientosUrl()}');
    }

    try {
      final response = await http
          .get(
            Uri.parse(_buildMovimientosUrl()),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
        print('📦 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> items = data['data'];
          return items
              .map((item) => MovimientoInventario.fromJson(item))
              .toList();
        }
        throw Exception('Formato de respuesta inválido');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      throw Exception('Error al obtener movimientos de inventario: $e');
    }
  }

  // Obtener todos los ingredientes
  Future<List<Inventario>> getInventario() async {
    if (kDebugMode) {
      print('🔍 GET Request to: ${_buildUrl()}');
    }

    try {
      final response = await http
          .get(Uri.parse(_buildUrl()), headers: _apiConfig.getSecureHeaders())
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
        print('📦 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> items = data['data'];
          return items.map((item) => Inventario.fromJson(item)).toList();
        }
        throw Exception('Formato de respuesta inválido');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      throw Exception('Error al obtener inventario: $e');
    }
  }

  // Crear ingrediente
  Future<Inventario> createIngrediente(Inventario ingrediente) async {
    try {
      if (kDebugMode) {
        print('📤 POST Request to: ${_buildUrl()}');
        print('📦 Request body: ${json.encode(ingrediente.toJson())}');
      }

      final response = await http
          .post(
            Uri.parse(_buildUrl()),
            headers: _apiConfig.getSecureHeaders(),
            body: json.encode(ingrediente.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _inventarioActualizadoController.add(true);
          return Inventario.fromJson(data['data']);
        }
        throw Exception('Formato de respuesta inválido');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      throw Exception('Error al crear ingrediente: $e');
    }
  }

  // Actualizar ingrediente
  Future<Inventario> updateIngrediente(
    String id,
    Inventario ingrediente,
  ) async {
    try {
      // Validar que el ID no esté vacío
      if (id.isEmpty) {
        throw Exception('El ID del ingrediente es requerido');
      }

      final url = _buildUrl(id);
      if (kDebugMode) {
        print('📝 PUT Request to: $url');
        print('📦 Request body: ${json.encode(ingrediente.toJson())}');
      }

      final response = await http
          .put(
            Uri.parse(url),
            headers: _apiConfig.getSecureHeaders(),
            body: json.encode(ingrediente.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _inventarioActualizadoController.add(true);
          return Inventario.fromJson(data['data']);
        }
        throw Exception('Formato de respuesta inválido');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      throw Exception('Error al actualizar ingrediente: $e');
    }
  }

  // Eliminar ingrediente
  Future<bool> deleteIngrediente(String id) async {
    try {
      if (kDebugMode) {
        print('🗑️ DELETE Request to: ${_buildUrl(id)}');
      }

      final response = await http
          .delete(
            Uri.parse(_buildUrl(id)),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        _inventarioActualizadoController.add(true);
        return true;
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      throw Exception('Error al eliminar ingrediente: $e');
    }
  }

  // Crear un nuevo movimiento de inventario
  Future<MovimientoInventario> crearMovimientoInventario(
    MovimientoInventario movimiento,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 POST Request to: ${_buildMovimientosUrl()}');
        print('📦 Request body: ${json.encode(movimiento.toJson())}');
      }

      final response = await http
          .post(
            Uri.parse(_buildMovimientosUrl()),
            headers: _apiConfig.getSecureHeaders(),
            body: json.encode(movimiento.toJson()),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
        print('📦 Response body: ${response.body}');
      }

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _inventarioActualizadoController.add(true);
          return MovimientoInventario.fromJson(data['data']);
        }
        throw Exception('Formato de respuesta inválido');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      throw Exception('Error al crear movimiento de inventario: $e');
    }
  }

  // Actualizar stock
  Future<Inventario> updateStock(String id, double cantidad) async {
    try {
      if (kDebugMode) {
        print(
          '📊 PUT Request to: ${_buildUrl("$id/stock?cantidad=$cantidad")}',
        );
      }

      final response = await http
          .put(
            Uri.parse(_buildUrl("$id/stock?cantidad=$cantidad")),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _inventarioActualizadoController.add(true);
          return Inventario.fromJson(data['data']);
        }
        throw Exception('Formato de respuesta inválido');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      throw Exception('Error al actualizar stock: $e');
    }
  }

  // FUNCIÓN DESHABILITADA - El procesamiento se hace automáticamente en el backend
  // cuando se crean/actualizan pedidos
  /*
  Future<void> procesarPedidoParaInventario(String pedidoId) async {
    if (kDebugMode) {
      print('🔄 Procesando pedido para descuento de inventario: $pedidoId');
    }

    try {
      final response = await http
          .post(
            Uri.parse(
              '${_apiConfig.baseUrl}/api/pedidos/$pedidoId/procesar-inventario',
            ),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
        print('📦 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          _inventarioActualizadoController.add(true);
          if (kDebugMode) {
            print(
              '✅ Inventario actualizado correctamente para pedido: $pedidoId',
            );
          }
          return;
        }
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error procesando inventario para pedido: $e');
      }
      throw Exception('Error al procesar inventario para pedido: $e');
    }
  }
  */

  /// Función informativa - El procesamiento se hace automáticamente en el backend
  void notificarProcesamientoInventario(String pedidoId) {
    if (kDebugMode) {
      print(
        'ℹ️ El pedido $pedidoId será procesado automáticamente en el backend para actualizar inventario',
      );
    }
    // Notificar que el inventario podría haberse actualizado
    _inventarioActualizadoController.add(true);
  }

  // Obtener ingredientes que fueron descontados para un producto específico del pedido
  Future<List<Map<String, dynamic>>> getIngredientesDescontadosParaProducto(
    String pedidoId,
    String productoId,
  ) async {
    if (kDebugMode) {
      print(
        '🔍 Obteniendo ingredientes descontados para producto: $productoId en pedido: $pedidoId',
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              '${_apiConfig.baseUrl}/api/pedidos/$pedidoId/producto/$productoId/ingredientes-devolucion',
            ),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
        print('📦 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        return [];
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      throw Exception('Error al obtener ingredientes descontados: $e');
    }
  }

  // Devolver ingredientes seleccionados al inventario
  Future<void> devolverIngredientesAlInventario(
    String pedidoId,
    String productoId,
    List<Map<String, dynamic>> ingredientesADevolver,
    String motivo,
    String responsable,
  ) async {
    if (kDebugMode) {
      print('↩️ Devolviendo ingredientes al inventario');
      print('   Pedido: $pedidoId');
      print('   Producto: $productoId');
      print('   Ingredientes: ${ingredientesADevolver.length}');
      print('   Motivo: $motivo');
      print('   Responsable: $responsable');
    }

    try {
      final requestBody = {
        'pedidoId': pedidoId,
        'productoId': productoId,
        'ingredientes': ingredientesADevolver,
        'motivo': motivo,
        'responsable': responsable,
      };

      final response = await http
          .post(
            Uri.parse('${_apiConfig.baseUrl}/api/pedidos/cancelar-producto'),
            headers: _apiConfig.getSecureHeaders(),
            body: json.encode(requestBody),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
        print('📦 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          _inventarioActualizadoController.add(true);
          if (kDebugMode) {
            print('✅ Ingredientes devueltos correctamente al inventario');
          }
          return;
        }
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error devolviendo ingredientes: $e');
      }
      throw Exception('Error al devolver ingredientes al inventario: $e');
    }
  }

  Exception _handleErrorResponse(http.Response response) {
    try {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final String errorMessage = errorData['message'] ?? 'Error desconocido';
      return Exception('Error ${response.statusCode}: $errorMessage');
    } catch (e) {
      return Exception('Error ${response.statusCode}: ${response.body}');
    }
  }

  void dispose() {
    _inventarioActualizadoController.close();
  }
}
