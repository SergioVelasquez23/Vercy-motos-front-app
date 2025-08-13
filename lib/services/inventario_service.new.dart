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
  final Duration _timeout = const Duration(seconds: ApiConfig.requestTimeout);

  Stream<bool> get onInventarioActualizado =>
      _inventarioActualizadoController.stream;

  // Construye la URL para las peticiones
  String _buildUrl({String? path}) {
    String url = '${_apiConfig.baseUrl}/$_baseEndpoint';
    if (path != null) {
      url += '/$path';
    }
    return url;
  }

  // Maneja errores de respuesta HTTP
  Exception _handleErrorResponse(http.Response response) {
    try {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['error'] != null) {
        return Exception(data['error']);
      }
    } catch (e) {
      // Si no podemos parsear el JSON, ignoramos
    }
    return Exception('Error en la solicitud: ${response.statusCode}');
  }

  // Obtener todos los movimientos de inventario
  Future<List<MovimientoInventario>> getMovimientosInventario() async {
    if (kDebugMode) {
      print('🔍 GET Request to: ${_buildUrl(path: "movimientos")}');
    }

    try {
      final response = await http
          .get(
            Uri.parse(_buildUrl(path: "movimientos")),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> items = data['data'];
          return items
              .map((item) => MovimientoInventario.fromJson(item))
              .toList();
        }
      } else if (response.statusCode == 404) {
        // Si no hay datos, devolver lista vacía
        return [];
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      return [];
    }
  }

  // Registrar un movimiento de inventario
  Future<MovimientoInventario> registrarMovimiento(
    MovimientoInventario movimiento,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 POST Request to: ${_buildUrl(path: "movimientos")}');
        print('📦 Request body: ${json.encode(movimiento.toJson())}');
      }

      final response = await http
          .post(
            Uri.parse(_buildUrl(path: "movimientos")),
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
      throw Exception('Error al registrar movimiento: $e');
    }
  }

  // Actualizar un movimiento de inventario
  Future<MovimientoInventario> updateMovimiento(
    String id,
    MovimientoInventario movimiento,
  ) async {
    try {
      if (kDebugMode) {
        print('🔄 PUT Request to: ${_buildUrl(path: "movimientos/$id")}');
        print('📦 Request body: ${json.encode(movimiento.toJson())}');
      }

      final response = await http
          .put(
            Uri.parse(_buildUrl(path: "movimientos/$id")),
            headers: _apiConfig.getSecureHeaders(),
            body: json.encode(movimiento.toJson()),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
        print('📦 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
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
      throw Exception('Error al actualizar movimiento: $e');
    }
  }

  // Eliminar un movimiento de inventario
  Future<bool> deleteMovimiento(String id) async {
    try {
      if (kDebugMode) {
        print('🗑️ DELETE Request to: ${_buildUrl(path: "movimientos/$id")}');
      }

      final response = await http
          .delete(
            Uri.parse(_buildUrl(path: "movimientos/$id")),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        _inventarioActualizadoController.add(true);
        return true;
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      throw Exception('Error al eliminar movimiento: $e');
    }
  }

  // Obtener inventario
  Future<List<Inventario>> getInventario() async {
    if (kDebugMode) {
      print('🔍 GET Request to: ${_buildUrl()}');
    }

    try {
      // Primero intentar obtener el inventario normal
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
          final List<Inventario> inventarios = items
              .map((item) => Inventario.fromJson(item))
              .toList();

          // Si hay items, devolverlos
          if (inventarios.isNotEmpty) {
            return inventarios;
          }
        }

        // Si no hay items de inventario, obtener los ingredientes como fallback
        return await _getIngredientesComoInventario();
      }

      // Si hay un error, intentar obtener ingredientes
      return await _getIngredientesComoInventario();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      throw Exception('Error al obtener inventario: $e');
    }
  }

  // Método para obtener ingredientes y convertirlos a formato de inventario
  Future<List<Inventario>> _getIngredientesComoInventario() async {
    if (kDebugMode) {
      print('🔄 Usando ingredientes como alternativa a inventario');
    }

    try {
      final response = await http
          .get(
            Uri.parse('${_apiConfig.baseUrl}/api/ingredientes'),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status (ingredientes): ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> ingredientes = data['data'];

          // Convertir ingredientes a formato de inventario
          return ingredientes.map<Inventario>((ingrediente) {
            return Inventario(
              id: ingrediente['_id'] ?? '',
              categoria: ingrediente['categoria'] ?? 'Ingrediente',
              codigo: ingrediente['_id']?.toString().substring(0, 6) ?? '',
              nombre: ingrediente['nombre'] ?? 'Sin nombre',
              unidad: ingrediente['unidad'] ?? 'Unidad',
              precioCompra: (ingrediente['costo'] ?? 0).toDouble(),
              stockActual: (ingrediente['cantidad'] ?? 0).toDouble(),
              stockMinimo: 5.0, // Valor por defecto
              estado: (ingrediente['cantidad'] ?? 0) > 0
                  ? 'Disponible'
                  : 'Agotado',
            );
          }).toList();
        }
      }

      // Si todo falla, devolver lista vacía
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error obteniendo ingredientes como inventario: $e');
      }
      return [];
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
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      throw Exception('Error al crear ingrediente: $e');
    }
  }

  // Actualizar ingrediente
  Future<Inventario> updateIngrediente(
    String id,
    Inventario ingrediente,
  ) async {
    try {
      if (kDebugMode) {
        print('🔄 PUT Request to: ${_buildUrl(path: id)}');
        print('📦 Request body: ${json.encode(ingrediente.toJson())}');
      }

      final response = await http
          .put(
            Uri.parse(_buildUrl(path: id)),
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
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      throw Exception('Error al actualizar ingrediente: $e');
    }
  }

  // Eliminar ingrediente
  Future<bool> deleteIngrediente(String id) async {
    try {
      if (kDebugMode) {
        print('🗑️ DELETE Request to: ${_buildUrl(path: id)}');
      }

      final response = await http
          .delete(
            Uri.parse(_buildUrl(path: id)),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        _inventarioActualizadoController.add(true);
        return true;
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      throw Exception('Error al eliminar ingrediente: $e');
    }
  }

  // Cerrar el stream controller cuando ya no sea necesario
  void dispose() {
    _inventarioActualizadoController.close();
  }
}
