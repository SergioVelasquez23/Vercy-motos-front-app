import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/inventario.dart';
import '../models/movimiento_inventario.dart';
import '../models/api_response.dart';
import '../config/api_config.dart';
import '../utils/api_error.dart';
import 'base_api_service.dart';

class InventarioService {
  final BaseApiService _apiService = BaseApiService();
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

  // Obtener todos los movimientos de inventario
  Future<List<MovimientoInventario>> getMovimientosInventario() async {
    try {
      final response = await _apiService.getList<MovimientoInventario>(
        '$_baseEndpoint/movimientos',
        (json) => MovimientoInventario.fromJson(json),
      );

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Registrar un movimiento de inventario
  Future<MovimientoInventario> registrarMovimiento(
    MovimientoInventario movimiento,
  ) async {
    try {
      // Siempre mostrar logs para debug

      final response = await http
          .post(
            Uri.parse(_buildUrl(path: "movimientos")),
            headers: _apiConfig.getSecureHeaders(),
            body: json.encode(movimiento.toJson()),
          )
          .timeout(_timeout);

      // Aceptar 200 o 201 como éxito
      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _inventarioActualizadoController.add(true);
          return MovimientoInventario.fromJson(data['data']);
        }
        // Si no tiene el formato esperado pero fue exitoso, crear uno básico
        return movimiento;
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al registrar movimiento');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al registrar movimiento');
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
      if (kDebugMode) {}

      final response = await http
          .put(
            Uri.parse(_buildUrl(path: "movimientos/$id")),
            headers: _apiConfig.getSecureHeaders(),
            body: json.encode(movimiento.toJson()),
          )
          .timeout(_timeout);

      if (kDebugMode) {}

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _inventarioActualizadoController.add(true);
          return MovimientoInventario.fromJson(data['data']);
        }
        throw Exception('Formato de respuesta inválido');
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al actualizar movimiento');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al actualizar movimiento');
    }
  }

  // Eliminar un movimiento de inventario
  Future<bool> deleteMovimiento(String id) async {
    try {
      if (kDebugMode) {}

      final response = await http
          .delete(
            Uri.parse(_buildUrl(path: "movimientos/$id")),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (kDebugMode) {}

      if (response.statusCode == 200) {
        _inventarioActualizadoController.add(true);
        return true;
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al eliminar movimiento');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al eliminar movimiento');
    }
  }

  // Obtener inventario
  Future<List<Inventario>> getInventario() async {
    if (kDebugMode) {}

    try {
      // Primero intentar obtener el inventario normal
      final response = await http
          .get(Uri.parse(_buildUrl()), headers: _apiConfig.getSecureHeaders())
          .timeout(_timeout);

      if (kDebugMode) {}

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
      wrapOrThrow(e, context: 'Error al obtener inventario');
    }
  }

  // Método para obtener ingredientes y convertirlos a formato de inventario
  Future<List<Inventario>> _getIngredientesComoInventario() async {
    if (kDebugMode) {}

    try {
      final response = await http
          .get(
            Uri.parse('${_apiConfig.baseUrl}/api/ingredientes'),
            headers: _apiConfig.getSecureHeaders(),
          )
          .timeout(_timeout);

      if (kDebugMode) {}

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
      if (kDebugMode) {}
      return [];
    }
  }

  // Crear ingrediente
  Future<Inventario> createIngrediente(Inventario ingrediente) async {
    try {
      if (kDebugMode) {}

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

      throwBackendError(response.body, response.statusCode, prefix: 'Error al crear ingrediente');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al crear ingrediente');
    }
  }

  // Actualizar ingrediente
  Future<Inventario> updateIngrediente(
    String id,
    Inventario ingrediente,
  ) async {
    try {
      if (kDebugMode) {}

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

      throwBackendError(response.body, response.statusCode, prefix: 'Error al actualizar ingrediente');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al actualizar ingrediente');
    }
  }

  // Eliminar ingrediente
  Future<bool> deleteIngrediente(String id) async {
    try {
      if (kDebugMode) {}

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

      throwBackendError(response.body, response.statusCode, prefix: 'Error al eliminar ingrediente');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al eliminar ingrediente');
    }
  }

  // Cerrar el stream controller cuando ya no sea necesario
  void dispose() {
    _inventarioActualizadoController.close();
  }

  // ✅ COMENTADO: Este método ya no se usa
  // Las validaciones de stock ahora se hacen en la UI verificando
  // directamente los atributos almacen y bodega del producto
  //
  // Future<Map<String, dynamic>> validarStockAntesDePedido(
  //   Map<String, List<String>> ingredientesPorItem,
  //   Map<String, int> cantidadPorProducto,
  // ) async {
  //   try {
  //     if (kDebugMode) {
  //
  //     }
  //
  //     final Map<String, dynamic> requestBody = {
  //       'ingredientesPorItem': ingredientesPorItem,
  //       'cantidadPorProducto': cantidadPorProducto,
  //       'validarSolo': true, // Solo validar, no descontar
  //     };
  //
  //     final response = await http
  //         .post(
  //           Uri.parse(_buildUrl(path: "validar-stock-pedido")),
  //           headers: _apiConfig.getSecureHeaders(),
  //           body: json.encode(requestBody),
  //         )
  //         .timeout(_timeout);
  //
  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       if (data['success'] == true) {
  //         return {
  //           'stockSuficiente': true,
  //           'ingredientesValidados':
  //               data['data']['ingredientesValidados'] ?? [],
  //           'alertas': data['data']['alertas'] ?? [],
  //         };
  //       } else {
  //         return {
  //           'stockSuficiente': false,
  //           'mensaje': data['message'] ?? 'Stock insuficiente',
  //           'ingredientesFaltantes':
  //               data['data']['ingredientesFaltantes'] ?? [],
  //         };
  //       }
  //     }
  //
  //     // ✅ SILENCIOSO: Error de servidor, continuar sin mostrar diálogo molesto
  //     return {
  //       'stockSuficiente': true, // ✅ Cambiar a true para evitar diálogo
  //       'mensaje': 'Validación omitida por error de servidor',
  //     };
  //   } catch (e) {
  //     if (kDebugMode) {
  //
  //     }
  //     return {
  //       'stockSuficiente': false,
  //       'mensaje': 'Error de conexión al validar stock: $e',
  //     };
  //   }
  // }

  // ✅ COMENTADO: Este método ya no se usa
  // Las validaciones de stock y movimientos ahora se hacen en la UI
  // y registramos movimientos directamente con registrarMovimiento()
  //
  // Future<bool> procesarPedidoParaInventario(
  //   String pedidoId,
  //   Map<String, List<String>> ingredientesPorItem,
  // ) async {
  //   try {
  //     if (kDebugMode) {
  //
  //                  }
  //     final response = await http
  //         .post(
  //           Uri.parse(_buildUrl(path: "procesar-pedido/$pedidoId")),
  //           headers: _apiConfig.getSecureHeaders(),
  //           body: json.encode(ingredientesPorItem),
  //         )
  //         .timeout(_timeout);
  //     if (kDebugMode) {
  //     }
  //     if (response.statusCode == 200) {
  //       final responseData = json.decode(response.body);
  //       if (responseData['success'] == true) {
  //         _inventarioActualizadoController.add(true);
  //         if (responseData['data'] != null &&
  //             responseData['data']['alertas'] != null) {
  //           final alertas = responseData['data']['alertas'] as List;
  //           if (alertas.isNotEmpty && kDebugMode) {
  //             for (var alerta in alertas) {
  //             }
  //           }
  //         }
  //         return true;
  //       } else {
  //         throw Exception(
  //           responseData['message'] ?? 'Error procesando inventario',
  //         );
  //       }
  //     }
  //     throw _handleErrorResponse(response);
  //   } catch (e) {
  //     if (kDebugMode) {
  //     }
  //     if (e.toString().contains('stock insuficiente') ||
  //         e.toString().contains('insufficient stock')) {
  //       rethrow;
  //     }
  //     return false;
  //   }
  // }

  // ✅ COMENTADO: Este método no se necesita porque usa endpoints obsoletos
  // Los endpoints /devolver-ingredientes y /ingredientes-descontados no existen en el backend
  // Future<bool> devolverIngredientesAlInventario(
  //   String pedidoId,
  //   String productoId,
  //   List<Map<String, dynamic>> ingredientes,
  //   String motivo,
  //   String responsable,
  // ) async {
  //   try {
  //     if (kDebugMode) {
  //                  }
  //     final Map<String, dynamic> requestBody = {
  //       'pedidoId': pedidoId,
  //       'productoId': productoId,
  //       'ingredientes': ingredientes,
  //       'motivo': motivo,
  //       'responsable': responsable,
  //     };
  //     final response = await http
  //         .post(
  //           Uri.parse(_buildUrl(path: "devolver-ingredientes")),
  //           headers: _apiConfig.getSecureHeaders(),
  //           body: json.encode(requestBody),
  //         )
  //         .timeout(_timeout);
  //     if (kDebugMode) {
  //
  //     }
  //     if (response.statusCode == 200) {
  //       _inventarioActualizadoController.add(true);
  //       return true;
  //     }
  //     throw _handleErrorResponse(response);
  //   } catch (e) {
  //     if (kDebugMode) {
  //
  //     }
  //     return false;
  //   }
  // }

  // ✅ COMENTADO: Este método no se necesita porque usa un endpoint obsoleto
  // El endpoint /ingredientes-descontados no existe en el backend
  // Future<List<Map<String, dynamic>>> getIngredientesDescontadosParaProducto(
  //   String pedidoId,
  //   String productoId,
  // ) async {
  //   try {
  //     final uri = Uri.parse(
  //       '${_apiConfig.baseUrl}/api/inventario/ingredientes-descontados?pedidoId=$pedidoId&productoId=$productoId',
  //     );
  //     final response = await http
  //         .get(uri, headers: _apiConfig.getSecureHeaders())
  //         .timeout(_timeout);
  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       if (data['success'] == true && data['data'] != null) {
  //         final List<dynamic> ingredientes = data['data'];
  //         return ingredientes.cast<Map<String, dynamic>>();
  //       }
  //     }
  //     return [];
  //   } catch (e) {
  //     if (kDebugMode) {
  //
  //     }
  //     return [];
  //   }
  // }

  // ✅ COMENTADO: Este método de limpieza de movimientos erróneos no se necesita
  // El endpoint /movimientos/limpiar-errores no existe en el backend

  // ✅ COMENTADO: Este método de sincronización de inventario no se necesita
  // El endpoint /sincronizar-con-ingredientes no existe en el backend
}
