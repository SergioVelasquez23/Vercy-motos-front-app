import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async'; // Importar para usar StreamController
import '../models/pedido.dart';
import '../utils/pedido_helper.dart'; // Añadido import
import '../services/producto_service.dart';
import '../models/producto.dart';
import '../models/item_pedido.dart';
import '../config/api_config.dart';

class PedidoService {
  static final PedidoService _instance = PedidoService._internal();
  factory PedidoService() => _instance;

  final _pedidoCompletadoController = StreamController<bool>.broadcast();
  Stream<bool> get onPedidoCompletado => _pedidoCompletadoController.stream;

  final _pedidoPagadoController = StreamController<bool>.broadcast();
  Stream<bool> get onPedidoPagado => _pedidoPagadoController.stream;

  PedidoService._internal() {
    print('🔧 PedidoService: Inicializando servicio y StreamControllers');
  }

  void dispose() {
    print('🔧 PedidoService: Cerrando StreamControllers');
    _pedidoCompletadoController.close();
    _pedidoPagadoController.close();
  }

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();
  final ProductoService _productoService = ProductoService();

  // Función auxiliar para parsear respuestas de lista de pedidos
  List<Pedido> _parseListResponse(dynamic responseData) {
    try {
      List<Pedido> pedidos = [];
      List<dynamic> jsonList;

      if (responseData is Map<String, dynamic>) {
        // Buscar posibles propiedades que contengan la lista de pedidos
        if (responseData.containsKey('pedidos')) {
          jsonList = responseData['pedidos'];
        } else if (responseData.containsKey('data')) {
          jsonList = responseData['data'];
        } else if (responseData.containsKey('results')) {
          jsonList = responseData['results'];
        } else {
          print('⚠️ Estructura de respuesta desconocida: ${responseData.keys}');
          return [];
        }
      } else if (responseData is List) {
        jsonList = responseData;
      } else {
        throw Exception(
          'Formato de respuesta inesperado: ${responseData.runtimeType}',
        );
      }

      // Convertir JSON a objetos Pedido
      pedidos = jsonList.map((json) => Pedido.fromJson(json)).toList();

      // Cargar productos para cada pedido
      for (var pedido in pedidos) {
        cargarProductosParaPedido(pedido);
      }

      return pedidos;
    } catch (e) {
      print('❌ Error parseando lista de pedidos: $e');
      return [];
    }
  }

  // Headers con autenticación
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Obtener todos los pedidos
  Future<List<Pedido>> getAllPedidos() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos'),
        headers: headers,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throw Exception('Error al obtener pedidos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error completo: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Método estático para compatibilidad
  static Future<List<Pedido>> getPedidos() async {
    return await PedidoService().getAllPedidos();
  }

  // Obtener pedidos por tipo
  Future<List<Pedido>> getPedidosByTipo(TipoPedido tipo) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/pedidos?tipo=${tipo.toString().split('.').last}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throw Exception(
          'Error al obtener pedidos por tipo: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener pedidos por estado
  Future<List<Pedido>> getPedidosByEstado(EstadoPedido estado) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/pedidos?estado=${estado.toString().split('.').last}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throw Exception(
          'Error al obtener pedidos por estado: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear nuevo pedido
  Future<Pedido> crearPedido(Pedido pedido) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/pedidos'),
        headers: headers,
        body: json.encode(pedido.toJson()),
      );

      if (response.statusCode == 201) {
        return Pedido.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al crear pedido: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear un nuevo pedido
  Future<Pedido> createPedido(Pedido pedido) async {
    try {
      // Validar que los items del pedido sean válidos
      if (pedido.items.isEmpty) {
        throw Exception('El pedido debe tener al menos un item');
      }

      if (!PedidoHelper.validatePedidoItems(pedido.items)) {
        throw Exception(
          'Los items del pedido no son válidos. Verifica que cada item tenga un ID de producto y cantidad mayor a 0.',
        );
      }

      final headers = await _getHeaders();

      // Debug: Imprimir el JSON que se va a enviar
      final pedidoJson = pedido.toJson();
      print('📦 Creando pedido con datos: ${json.encode(pedidoJson)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/pedidos'),
        headers: headers,
        body: json.encode(pedidoJson),
      );

      print('Create pedido response: ${response.statusCode}');
      print('Create pedido body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return Pedido.fromJson(responseData['data']);
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception('Error al crear pedido: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error creando pedido: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Método estático para compatibilidad
  static Future<Pedido> actualizarEstado(
    String pedidoId,
    EstadoPedido nuevoEstado,
  ) async {
    return await PedidoService().actualizarEstadoPedido(pedidoId, nuevoEstado);
  }

  // Eliminar pedido
  Future<void> eliminarPedido(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/pedidos/$id'),
        headers: headers,
      );

      if (response.statusCode != 204) {
        throw Exception('Error al eliminar pedido: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Filtrar pedidos por múltiples criterios
  Future<List<Pedido>> filtrarPedidos({
    TipoPedido? tipo,
    EstadoPedido? estado,
    String? mesa,
    String? cliente,
    String? mesero,
    String? plataforma,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? busqueda,
  }) async {
    try {
      final headers = await _getHeaders();

      // Construir query parameters
      Map<String, String> queryParams = {};
      if (tipo != null) queryParams['tipo'] = tipo.toString().split('.').last;
      if (estado != null)
        queryParams['estado'] = estado.toString().split('.').last;
      if (mesa != null) queryParams['mesa'] = mesa;
      if (cliente != null) queryParams['cliente'] = cliente;
      if (mesero != null) queryParams['mesero'] = mesero;
      if (plataforma != null) queryParams['plataforma'] = plataforma;
      if (fechaInicio != null)
        queryParams['fechaInicio'] = fechaInicio.toIso8601String();
      if (fechaFin != null)
        queryParams['fechaFin'] = fechaFin.toIso8601String();
      if (busqueda != null && busqueda.isNotEmpty)
        queryParams['busqueda'] = busqueda;

      final uri = Uri.parse(
        '$baseUrl/api/pedidos/filtrar',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throw Exception('Error al filtrar pedidos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener estadísticas
  Future<Map<String, int>> getEstadisticas() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/estadisticas'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return Map<String, int>.from(jsonData);
      } else {
        throw Exception(
          'Error al obtener estadísticas: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener total de ventas por período
  Future<double> getTotalVentas({
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      final headers = await _getHeaders();

      Map<String, String> queryParams = {};
      if (fechaInicio != null)
        queryParams['fechaInicio'] = fechaInicio.toIso8601String();
      if (fechaFin != null)
        queryParams['fechaFin'] = fechaFin.toIso8601String();

      final uri = Uri.parse(
        '$baseUrl/api/pedidos/total-ventas',
      ).replace(queryParameters: queryParams);

      print(
        '🔍 getTotalVentas: Consultando ventas con parámetros: $queryParams',
      );
      print('🔍 getTotalVentas: URL completa: ${uri.toString()}');

      final response = await http.get(uri, headers: headers);

      print('📊 getTotalVentas response status: ${response.statusCode}');
      print('📊 getTotalVentas response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        print('📊 getTotalVentas parsed response: $jsonData');

        if (jsonData['success'] == true) {
          if (jsonData['data'] == null) {
            print('⚠️ getTotalVentas: data es null');
            return 0.0;
          }

          if (!(jsonData['data'] is Map)) {
            print(
              '⚠️ getTotalVentas: data no es un objeto: ${jsonData['data']}',
            );
            return 0.0;
          }

          final total = jsonData['data']['total'];
          print('📊 getTotalVentas total value: $total (${total.runtimeType})');

          if (total == null) {
            print('⚠️ getTotalVentas: El total es null');
            return 0.0;
          }

          if (total is! num) {
            print(
              '⚠️ getTotalVentas: El total no es un número: $total (${total.runtimeType})',
            );
            return 0.0;
          }

          print('✅ getTotalVentas: Total calculado correctamente: $total');
          return total.toDouble();
        } else {
          print('⚠️ getTotalVentas: success es false: ${jsonData['message']}');
          return 0.0;
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Error desconocido';
        print('❌ getTotalVentas: Error del servidor: $errorMessage');
        return 0.0;
      }
    } catch (e, stackTrace) {
      print('❌ getTotalVentas error: $e');
      print('❌ getTotalVentas stack trace: $stackTrace');
      // En caso de error, retornamos 0 en lugar de propagar la excepción
      return 0.0;
    }
  }

  // Obtener pedidos por mesa
  Future<List<Pedido>> getPedidosByMesa(String nombreMesa) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/mesa/$nombreMesa'),
        headers: headers,
      );

      print('getPedidosByMesa response: ${response.statusCode}');
      print('getPedidosByMesa body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Decoded response data: $responseData');

        // Manejar tanto respuesta directa como respuesta con wrapper
        final List<dynamic> jsonList;
        if (responseData is List) {
          jsonList = responseData;
        } else if (responseData['data'] != null) {
          jsonList = responseData['data'];
        } else {
          jsonList = [];
        }

        print('JSON list length: ${jsonList.length}');
        if (jsonList.isNotEmpty) {
          print('First item: ${jsonList.first}');
        }

        final pedidos = jsonList
            .map((json) {
              try {
                return Pedido.fromJson(json);
              } catch (e) {
                print('Error parsing pedido: $e');
                print('JSON causing error: $json');
                return null;
              }
            })
            .where((pedido) => pedido != null)
            .cast<Pedido>()
            .toList();

        print('Parsed pedidos count: ${pedidos.length}');
        return pedidos;
      } else {
        throw Exception(
          'Error al obtener pedidos de mesa: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Exception in getPedidosByMesa: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Actualizar estado de un pedido
  Future<Pedido> actualizarEstadoPedido(
    String pedidoId,
    EstadoPedido nuevoEstado,
  ) async {
    try {
      print(
        '🎯 PedidoService: Actualizando estado del pedido - ID: $pedidoId a estado: $nuevoEstado',
      );

      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse(
              '$baseUrl/api/pedidos/$pedidoId/estado/${nuevoEstado.toString().split('.').last}',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      print(
        '🎯 PedidoService: Update estado response - Status: ${response.statusCode}',
      );
      print(
        '🎯 PedidoService: Update estado response - Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoActualizado = Pedido.fromJson(responseData['data']);

          // Emitir evento cuando se paga el pedido
          if (nuevoEstado == EstadoPedido.pagado) {
            print('🔔 PedidoService: Emitiendo evento de pedido completado');
            _pedidoCompletadoController.add(true);
            print('✅ PedidoService: Evento emitido exitosamente');
          }

          print(
            '🎯 PedidoService: Estado del pedido actualizado exitosamente - ID: ${pedidoActualizado.id}',
          );

          return pedidoActualizado;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ PedidoService: Error actualizando estado del pedido: $e');
      throw Exception('No se pudo actualizar el estado del pedido: $e');
    }
  }

  // Cargar productos para un pedido
  Future<void> cargarProductosParaPedido(Pedido pedido) async {
    try {
      // Crear un mapa de productos por ID
      Map<String, Producto> productosMap = {};
      for (final item in pedido.items) {
        if (!productosMap.containsKey(item.productoId)) {
          try {
            final producto = await _productoService.getProducto(
              item.productoId,
            );
            if (producto != null) {
              productosMap[item.productoId] = producto;
            }
          } catch (e) {
            print('Error al cargar producto ${item.productoId}: $e');
          }
        }
      }

      // Actualizar los items con sus productos
      for (var i = 0; i < pedido.items.length; i++) {
        final item = pedido.items[i];
        final producto = productosMap[item.productoId];
        if (producto != null) {
          pedido.items[i] = ItemPedido(
            productoId: item.productoId,
            producto: producto,
            cantidad: item.cantidad,
            notas: item.notas,
            precio: producto.precio,
          );
        }
      }
    } catch (e) {
      print('Error al cargar productos para el pedido: $e');
    }
  }

  Future<void> cancelarPedido(String pedidoId, String motivo) async {
    final url = '$baseUrl/api/pedidos/cancelar';
    final secureStorage = FlutterSecureStorage();
    final token = await secureStorage.read(key: 'jwt_token');

    if (token == null) {
      throw Exception('No se encontró el token de autenticación');
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'pedidoId': pedidoId, 'motivo': motivo}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al cancelar el pedido: ${response.body}');
    }

    _pedidoCompletadoController.add(true);
  }

  // Pagar un pedido
  Future<Pedido> pagarPedido(
    String pedidoId, {
    String formaPago = 'efectivo',
    double propina = 0.0,
    String pagadoPor = '',
    String notas = '',
  }) async {
    try {
      final headers = await _getHeaders();

      final Map<String, dynamic> pagarData = {
        'formaPago': formaPago,
        'propina': propina,
        'pagadoPor': pagadoPor,
        'notas': notas,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/$pedidoId/pagar'),
        headers: headers,
        body: json.encode(pagarData),
      );

      print('Pagar pedido response: ${response.statusCode}');
      print('Pagar pedido body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoPagado = Pedido.fromJson(responseData['data']);

          // Notificar que se pagó un pedido para actualizar el dashboard
          _pedidoPagadoController.add(true);
          print('🔔 PedidoService: Notificación de pago enviada');

          return pedidoPagado;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception('Error al pagar pedido: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error pagando pedido: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
