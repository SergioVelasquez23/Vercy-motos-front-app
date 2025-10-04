import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/inventario.dart';
import '../models/movimiento_inventario.dart';
import '../models/api_response.dart';
import '../config/api_config.dart';
import 'base_api_service.dart';

class InventarioService {
  final BaseApiService _apiService = BaseApiService();
  final ApiConfig _apiConfig = ApiConfig();
  final String _baseEndpoint = 'inventario';
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
      print('🔍 Obteniendo movimientos de inventario...');
    }

    try {
      final response = await _apiService.getList<MovimientoInventario>(
        '$_baseEndpoint/movimientos',
        (json) => MovimientoInventario.fromJson(json),
      );

      if (response.success && response.data != null) {
        if (kDebugMode) {
          print('✅ Movimientos obtenidos: ${response.data!.length}');
        }
        return response.data!;
      } else {
        if (kDebugMode) {
          print('⚠️ Error en respuesta: ${response.message}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error obteniendo movimientos: $e');
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

  // Alias para registrarMovimiento (compatibilidad)
  Future<MovimientoInventario> crearMovimientoInventario(
    MovimientoInventario movimiento,
  ) async {
    return registrarMovimiento(movimiento);
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
            final stock =
                (ingrediente['stockActual'] ?? ingrediente['cantidad'] ?? 0)
                    .toDouble();
            return Inventario(
              id: ingrediente['_id'] ?? '',
              categoria: ingrediente['categoria'] ?? 'Ingrediente',
              codigo: ingrediente['_id']?.toString().substring(0, 6) ?? '',
              nombre: ingrediente['nombre'] ?? 'Sin nombre',
              unidad: ingrediente['unidad'] ?? 'Unidad',
              precioCompra: (ingrediente['costo'] ?? 0).toDouble(),
              stockActual: stock,
              stockMinimo: 5.0, // Valor por defecto
              estado: stock > 0 ? 'Disponible' : 'Agotado',
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

  // ✅ CORREGIDO: Validar stock ANTES de procesar el pedido
  Future<Map<String, dynamic>> validarStockAntesDePedido(
    Map<String, List<String>> ingredientesPorItem,
    Map<String, int> cantidadPorProducto,
  ) async {
    try {
      if (kDebugMode) {
        print('🔍 Validando stock antes de crear pedido...');
      }

      final Map<String, dynamic> requestBody = {
        'ingredientesPorItem': ingredientesPorItem,
        'cantidadPorProducto': cantidadPorProducto,
        'validarSolo': true, // Solo validar, no descontar
      };

      final response = await http
          .post(
            Uri.parse(_buildUrl(path: "validar-stock-pedido")),
            headers: _apiConfig.getSecureHeaders(),
            body: json.encode(requestBody),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'stockSuficiente': true,
            'ingredientesValidados':
                data['data']['ingredientesValidados'] ?? [],
            'alertas': data['data']['alertas'] ?? [],
          };
        } else {
          return {
            'stockSuficiente': false,
            'mensaje': data['message'] ?? 'Stock insuficiente',
            'ingredientesFaltantes':
                data['data']['ingredientesFaltantes'] ?? [],
          };
        }
      }

      return {
        'stockSuficiente': false,
        'mensaje': 'Error al validar stock: ${response.statusCode}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error validando stock: $e');
      }
      return {
        'stockSuficiente': false,
        'mensaje': 'Error de conexión al validar stock: $e',
      };
    }
  }

  // ✅ MEJORADO: Procesa un pedido para actualizar el inventario con validaciones
  Future<bool> procesarPedidoParaInventario(
    String pedidoId,
    Map<String, List<String>> ingredientesPorItem,
  ) async {
    try {
      if (kDebugMode) {
        print('🔄 Procesando pedido para actualizar inventario: $pedidoId');
        print(
          '📦 Body ingredientesPorItem: ${json.encode(ingredientesPorItem)}',
        );
      }

      final response = await http
          .post(
            Uri.parse(_buildUrl(path: "procesar-pedido/$pedidoId")),
            headers: _apiConfig.getSecureHeaders(),
            body: json.encode(ingredientesPorItem),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
        print('📦 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _inventarioActualizadoController.add(true);

          // ✅ NUEVO: Verificar si hay alertas de stock bajo
          if (responseData['data'] != null &&
              responseData['data']['alertas'] != null) {
            final alertas = responseData['data']['alertas'] as List;
            if (alertas.isNotEmpty && kDebugMode) {
              print('⚠️ ALERTAS DE STOCK BAJO:');
              for (var alerta in alertas) {
                print(
                  '   - ${alerta['ingrediente']}: Stock actual ${alerta['stockActual']}, mínimo ${alerta['stockMinimo']}',
                );
              }
            }
          }

          return true;
        } else {
          throw Exception(
            responseData['message'] ?? 'Error procesando inventario',
          );
        }
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error procesando pedido para inventario: $e');
      }
      // ✅ MEJORADO: Propagar error crítico de stock insuficiente
      if (e.toString().contains('stock insuficiente') ||
          e.toString().contains('insufficient stock')) {
        rethrow; // Propagar errores críticos de stock
      }
      return false;
    }
  }

  // Devuelve ingredientes al inventario (usado en cancelación de pedidos)
  Future<bool> devolverIngredientesAlInventario(
    String pedidoId,
    String productoId,
    List<Map<String, dynamic>> ingredientes,
    String motivo,
    String responsable,
  ) async {
    try {
      if (kDebugMode) {
        print(
          '🔄 Devolviendo ingredientes al inventario para pedido: $pedidoId, producto: $productoId',
        );
      }

      final Map<String, dynamic> requestBody = {
        'pedidoId': pedidoId,
        'productoId': productoId,
        'ingredientes': ingredientes,
        'motivo': motivo,
        'responsable': responsable,
      };

      final response = await http
          .post(
            Uri.parse(_buildUrl(path: "devolver-ingredientes")),
            headers: _apiConfig.getSecureHeaders(),
            body: json.encode(requestBody),
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
        print('❌ Error devolviendo ingredientes al inventario: $e');
      }
      // No lanzamos una excepción porque no queremos interrumpir el flujo principal
      return false;
    }
  }

  // Obtener ingredientes descontados para un producto de un pedido
  Future<List<Map<String, dynamic>>> getIngredientesDescontadosParaProducto(
    String pedidoId,
    String productoId,
  ) async {
    try {
      final uri = Uri.parse(
        '${_apiConfig.baseUrl}/api/inventario/ingredientes-descontados?pedidoId=$pedidoId&productoId=$productoId',
      );
      final response = await http
          .get(uri, headers: _apiConfig.getSecureHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> ingredientes = data['data'];
          return ingredientes.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error obteniendo ingredientes descontados: $e');
      }
      return [];
    }
  }

  // ✅ NUEVO: Limpiar movimientos erróneos
  Future<Map<String, dynamic>> limpiarMovimientosErroneos() async {
    try {
      if (kDebugMode) {
        print('🧹 Limpiando movimientos erróneos...');
      }

      final response = await http
          .delete(
            Uri.parse(_buildUrl(path: 'movimientos/limpiar-errores')),
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
          _inventarioActualizadoController.add(true);
          return data['data'];
        }
        throw Exception('Formato de respuesta inválido');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error limpiando movimientos: $e');
      }
      throw Exception('Error al limpiar movimientos erróneos: $e');
    }
  }

  // ✅ NUEVO: Sincronizar inventario con ingredientes
  Future<Map<String, dynamic>> sincronizarInventarioConIngredientes() async {
    try {
      if (kDebugMode) {
        print('🔄 Sincronizando inventario con ingredientes...');
      }

      final response = await http
          .post(
            Uri.parse(_buildUrl(path: 'sincronizar-con-ingredientes')),
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
          _inventarioActualizadoController.add(true);
          return data['data'];
        }
        throw Exception('Formato de respuesta inválido');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sincronizando inventario: $e');
      }
      throw Exception('Error al sincronizar inventario: $e');
    }
  }
}
