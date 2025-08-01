import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/inventario.dart';
import '../models/movimiento_inventario.dart';
import '../config/api_config.dart';

class InventarioService {
  final ApiConfig _apiConfig = ApiConfig();
  final String _baseEndpoint = '/api/ingredientes';
  final _inventarioActualizadoController = StreamController<bool>.broadcast();
  final Duration _timeout = Duration(seconds: ApiConfig.requestTimeout);

  InventarioService() {
    if (kDebugMode) {
      print('🔧 InventarioService initialized with endpoint: $_baseEndpoint');
    }
  }

  Stream<bool> get onInventarioActualizado =>
      _inventarioActualizadoController.stream;

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
