import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async'; // Importar para usar StreamController
import '../models/pedido.dart';
import '../utils/pedido_helper.dart'; // Añadido import
import '../services/producto_service.dart';
import '../services/inventario_service.dart'; // Para manejar descuento de ingredientes
import '../models/producto.dart';
import '../models/item_pedido.dart';
import '../models/cancelar_producto_request.dart'; // Para cancelaciones selectivas
import '../config/api_config.dart';
import '../services/cuadre_caja_service.dart'; // Para validar caja abierta

class PedidoService {
  static final PedidoService _instance = PedidoService._internal();
  factory PedidoService() => _instance;

  final _pedidoCompletadoController = StreamController<bool>.broadcast();
  Stream<bool> get onPedidoCompletado => _pedidoCompletadoController.stream;

  final _pedidoPagadoController = StreamController<bool>.broadcast();
  Stream<bool> get onPedidoPagado => _pedidoPagadoController.stream;

  final InventarioService _inventarioService = InventarioService();
  final CuadreCajaService _cuadreCajaService = CuadreCajaService();

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

      // Ordenar pedidos por fecha descendente (más recientes primero)
      pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));

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

  // Crear nuevo pedido (método legacy - ahora usa validación de caja)
  Future<Pedido> crearPedido(Pedido pedido) async {
    try {
      // VALIDACIÓN: Verificar que hay una caja abierta antes de crear el pedido
      print('🔍 Validando que hay una caja abierta...');
      final cajaActiva = await _cuadreCajaService.getCajaActiva();

      if (cajaActiva == null) {
        print('❌ No hay caja abierta para crear pedido');
        throw Exception(
          'No se puede crear un pedido sin una caja abierta. Debe abrir una caja antes de registrar pedidos.',
        );
      }

      // Asignar cuadreId al pedido automáticamente
      pedido.cuadreId = cajaActiva.id;
      print(
        '✅ Pedido vinculado a cuadre: ${cajaActiva.id} - ${cajaActiva.nombre}',
      );

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
      // VALIDACIÓN: Verificar que hay una caja abierta antes de crear el pedido
      print('🔍 Validando que hay una caja abierta...');
      final cajaActiva = await _cuadreCajaService.getCajaActiva();

      if (cajaActiva == null) {
        print('❌ No hay caja abierta para crear pedido');
        throw Exception(
          'No se puede crear un pedido sin una caja abierta. Debe abrir una caja antes de registrar pedidos.',
        );
      }

      // Asignar cuadreId al pedido automáticamente
      pedido.cuadreId = cajaActiva.id;
      print(
        '✅ Pedido vinculado a cuadre: ${cajaActiva.id} - ${cajaActiva.nombre}',
      );

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
          final pedidoCreado = Pedido.fromJson(responseData['data']);

          // Construir el Map<String, List<String>> de ingredientes seleccionados por producto
          final Map<String, List<String>> ingredientesPorItem = {
            for (var item in pedidoCreado.items)
              item.productoId: item.ingredientesSeleccionados,
          };

          // Procesar descuento de ingredientes automáticamente
          try {
            await _inventarioService.procesarPedidoParaInventario(
              pedidoCreado.id,
              ingredientesPorItem,
            );
            print(
              '✅ Ingredientes descontados correctamente para pedido: ${pedidoCreado.id}',
            );
          } catch (e) {
            print('⚠️ Error al descontar ingredientes del inventario: $e');
            // No fallar la creación del pedido, solo loggear el error
          }

          return pedidoCreado;
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

  // Actualizar pedido existente
  Future<Pedido> updatePedido(Pedido pedido) async {
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
      print(
        '🔄 Actualizando pedido ${pedido.id} con datos: ${json.encode(pedidoJson)}',
      );

      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/${pedido.id}'),
        headers: headers,
        body: json.encode(pedidoJson),
      );

      print('Update pedido response: ${response.statusCode}');
      print('Update pedido body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoActualizado = Pedido.fromJson(responseData['data']);

          // Construir el Map<String, List<String>> de ingredientes seleccionados por producto
          final Map<String, List<String>> ingredientesPorItem = {
            for (var item in pedidoActualizado.items)
              item.productoId: item.ingredientesSeleccionados,
          };

          // Procesar cambios en ingredientes automáticamente
          try {
            await _inventarioService.procesarPedidoParaInventario(
              pedidoActualizado.id,
              ingredientesPorItem,
            );
            print(
              '✅ Inventario actualizado correctamente para pedido: ${pedidoActualizado.id}',
            );
          } catch (e) {
            print('⚠️ Error al actualizar inventario: $e');
            // No fallar la actualización del pedido, solo loggear el error
          }

          return pedidoActualizado;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception('Error al actualizar pedido: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error actualizando pedido: $e');
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
      if (estado != null) {
        queryParams['estado'] = estado.toString().split('.').last;
      }
      if (mesa != null) queryParams['mesa'] = mesa;
      if (cliente != null) queryParams['cliente'] = cliente;
      if (mesero != null) queryParams['mesero'] = mesero;
      if (plataforma != null) queryParams['plataforma'] = plataforma;
      if (fechaInicio != null) {
        queryParams['fechaInicio'] = fechaInicio.toIso8601String();
      }
      if (fechaFin != null) {
        queryParams['fechaFin'] = fechaFin.toIso8601String();
      }
      if (busqueda != null && busqueda.isNotEmpty) {
        queryParams['busqueda'] = busqueda;
      }

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

  // Obtener pedidos por mesero (para el módulo de meseros)
  Future<List<Pedido>> obtenerPedidosPorMesero(String nombreMesero) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/mesero/$nombreMesero'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throw Exception(
          'Error al obtener pedidos del mesero: ${response.statusCode}',
        );
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
      if (fechaInicio != null) {
        queryParams['fechaInicio'] = fechaInicio.toIso8601String();
      }
      if (fechaFin != null) {
        queryParams['fechaFin'] = fechaFin.toIso8601String();
      }

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

          if (jsonData['data'] is! Map) {
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

  // Obtener un pedido por su ID
  Future<Pedido?> getPedidoById(String pedidoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/$pedidoId'),
        headers: headers,
      );

      print('getPedidoById response: ${response.statusCode}');
      print('getPedidoById body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Manejar respuesta con wrapper de éxito
        if (responseData is Map<String, dynamic>) {
          if (responseData['success'] == true && responseData['data'] != null) {
            return Pedido.fromJson(responseData['data']);
          } else if (responseData.containsKey('_id') ||
              responseData.containsKey('id')) {
            // Respuesta directa sin wrapper
            return Pedido.fromJson(responseData);
          }
        }

        print('⚠️ Formato de respuesta inesperado: $responseData');
        return null;
      } else {
        print('❌ Error al obtener pedido por ID: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception in getPedidoById: $e');
      return null;
    }
  }

  // Obtener pedidos por mesa
  Future<List<Pedido>> getPedidosByMesa(String nombreMesa) async {
    try {
      final headers = await _getHeaders();
      // Limpiar el nombre de la mesa de cualquier carácter de salto de línea o espacios extra
      final nombreLimpio = nombreMesa
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      // Usar Uri.encodeComponent para manejar correctamente los espacios y caracteres especiales
      final encodedNombreMesa = Uri.encodeComponent(nombreLimpio);
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/mesa/$encodedNombreMesa'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Manejar tanto respuesta directa como respuesta con wrapper
        final List<dynamic> jsonList;
        if (responseData is List) {
          jsonList = responseData;
        } else if (responseData['data'] != null) {
          jsonList = responseData['data'];
        } else {
          jsonList = [];
        }

        final pedidos = jsonList
            .map((json) {
              try {
                final pedido = Pedido.fromJson(json);
                return pedido;
              } catch (e) {
                print('❌ Error parsing pedido: $e');
                print('JSON causing error: $json');
                return null;
              }
            })
            .where((pedido) => pedido != null)
            .cast<Pedido>()
            .toList();

        return pedidos;
      } else {
        throw Exception(
          'Error al obtener pedidos de mesa: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Exception in getPedidosByMesa: $e');
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

      // Primero intentamos cargar todos los productos
      for (final item in pedido.items) {
        if (!productosMap.containsKey(item.productoId)) {
          // Validar que el ID del producto no sea vacío
          if (item.productoId.isEmpty) {
            continue;
          }

          try {
            final producto = await _productoService.getProducto(
              item.productoId,
            );
            if (producto != null) {
              productosMap[item.productoId] = producto;
            } else {
              // Crear un producto ficticio para evitar errores en la UI
              productosMap[item.productoId] = Producto(
                id: item.productoId,
                nombre: "Producto no disponible",
                precio: item.precio,
                costo: 0,
                utilidad: 0,
                descripcion: "Este producto ya no está disponible",
              );
            }
          } catch (e) {
            print('❌ Error al cargar producto ${item.productoId}: $e');
          }
        }
      }

      // Actualizar los items con sus productos
      for (var i = 0; i < pedido.items.length; i++) {
        final item = pedido.items[i];
        final producto = productosMap[item.productoId];

        if (producto != null) {
          // Si tenemos el producto completo, lo usamos
          pedido.items[i] = ItemPedido(
            productoId: item.productoId,
            productoNombre: producto.nombre,
            cantidad: item.cantidad,
            notas: item.notas,
            precioUnitario: producto.precio,
          );
        } else if (item.producto == null) {
          // Si no tenemos el producto, pero tenemos nombre en el JSON, creamos un producto básico
          String nombreProducto = "Producto desconocido";

          // Intentar obtener nombre del producto desde el servicio de productos
          try {
            final nombreInfo = await _productoService.getProductoNombre(
              item.productoId,
            );
            if (nombreInfo != null && nombreInfo.isNotEmpty) {
              nombreProducto = nombreInfo;
            }
          } catch (e) {
            print('❌ Error obteniendo nombre del producto: $e');
          }

          // Crear un producto básico con la información disponible
          final productoBasico = Producto(
            id: item.productoId,
            nombre: nombreProducto,
            precio: item.precio,
            costo: 0.0,
            utilidad: 0.0,
            cantidad: 0,
          );

          pedido.items[i] = ItemPedido(
            productoId: item.productoId,
            productoNombre: productoBasico.nombre,
            cantidad: item.cantidad,
            notas: item.notas,
            precioUnitario: item.precioUnitario,
          );
        }
      }
    } catch (e) {
      print('Error al cargar productos para el pedido: $e');
    }
  }

  // Método legacy para cancelar pedidos (mantener por compatibilidad)
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

  // Nuevo método para cancelar pedidos usando el DTO PagarPedidoRequest
  Future<Pedido> cancelarPedidoConDTO(
    String pedidoId, {
    String procesadoPor = '',
    String notas = '',
  }) async {
    try {
      final headers = await _getHeaders();

      final Map<String, dynamic> cancelarData = {
        'tipoPago': 'cancelado', // Usar el nuevo DTO
        'procesadoPor': procesadoPor,
        'notas': notas,
      };

      print('🚫 Datos enviados al cancelar pedido:');
      print('  - Pedido ID: $pedidoId');
      print('  - Datos completos: ${json.encode(cancelarData)}');

      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/$pedidoId/pagar'),
        headers: headers,
        body: json.encode(cancelarData),
      );

      print('Cancelar pedido response: ${response.statusCode}');
      print('Cancelar pedido body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoCancelado = Pedido.fromJson(responseData['data']);

          // Notificar que se canceló un pedido
          _pedidoCompletadoController.add(true);
          print('🔔 PedidoService: Notificación de cancelación enviada');

          return pedidoCancelado;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception('Error al cancelar pedido: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error cancelando pedido: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Actualizar tipo de un pedido (cortesía, consumo interno, etc.)
  Future<Pedido> actualizarTipoPedido(
    String pedidoId,
    TipoPedido nuevoTipo,
  ) async {
    try {
      final headers = await _getHeaders();

      print('🔄 Actualizando tipo de pedido:');
      print('  - Pedido ID: $pedidoId');
      print('  - Nuevo tipo: $nuevoTipo');

      // PASO 1: Obtener el pedido actual completo
      final getPedidoResponse = await http.get(
        Uri.parse('$baseUrl/api/pedidos/$pedidoId'),
        headers: headers,
      );

      if (getPedidoResponse.statusCode != 200) {
        throw Exception(
          'No se pudo obtener el pedido: ${getPedidoResponse.statusCode}',
        );
      }

      final getPedidoData = json.decode(getPedidoResponse.body);
      if (getPedidoData['success'] != true || getPedidoData['data'] == null) {
        throw Exception('Formato de respuesta inválido al obtener pedido');
      }

      // PASO 2: Modificar solo el tipo en el pedido completo
      final pedidoCompleto = getPedidoData['data'] as Map<String, dynamic>;
      // El backend espera el tipo en mayúsculas (NORMAL, CORTESIA, INTERNO, etc.)
      pedidoCompleto['tipo'] = nuevoTipo.toJson().toUpperCase();

      print('  - Datos completos a enviar: ${json.encode(pedidoCompleto)}');

      // PASO 3: Actualizar el pedido completo con el nuevo tipo
      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/$pedidoId'),
        headers: headers,
        body: json.encode(pedidoCompleto),
      );

      print('Actualizar tipo pedido response: ${response.statusCode}');
      print('Actualizar tipo pedido body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return Pedido.fromJson(responseData['data']);
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception(
          'Error al actualizar tipo de pedido: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error actualizando tipo de pedido: $e');
      throw Exception('No se pudo actualizar el tipo del pedido: $e');
    }
  }

  // Pagar un pedido - Actualizado para coincidir con PagarPedidoRequest del backend
  Future<Pedido> pagarPedido(
    String pedidoId, {
    String formaPago = 'efectivo',
    double propina = 0.0,
    String procesadoPor = '',
    String notas = '',
    TipoPedido? tipoPedido,
    bool esCortesia = false,
    bool esConsumoInterno = false,
    String? motivoCortesia,
    String? tipoConsumoInterno,
  }) async {
    try {
      final headers = await _getHeaders();

      // Determinar el tipoPago según las opciones
      String tipoPago;
      if (esCortesia) {
        tipoPago = 'cortesia';
      } else if (esConsumoInterno) {
        tipoPago = 'consumo_interno';
      } else {
        tipoPago = 'pagado'; // Por defecto es pagado normal
      }

      // Construir el objeto según el DTO PagarPedidoRequest
      final Map<String, dynamic> pagarData = {
        'tipoPago': tipoPago, // Campo requerido
        'procesadoPor': procesadoPor, // Cambio de 'pagadoPor' a 'procesadoPor'
        'notas': notas,
      };

      // Solo incluir campos específicos para pagos normales
      if (tipoPago == 'pagado') {
        // Validar forma de pago
        if (formaPago != 'efectivo' && formaPago != 'transferencia') {
          print(
            '⚠️ Forma de pago en pagarPedido no reconocida: "$formaPago". Usando efectivo por defecto.',
          );
          formaPago = 'efectivo';
        }

        pagarData['formaPago'] = formaPago;
        pagarData['propina'] = propina;
        pagarData['pagado'] = true;
        pagarData['estado'] = 'Pagado'; // Asegurar que el estado sea explícito
        pagarData['fechaPago'] = DateTime.now().toIso8601String();

        // Log adicional para forma de pago
        print('💵 Forma de pago configurada: $formaPago');
      }

      // Solo incluir motivoCortesia para cortesías
      if (tipoPago == 'cortesia' &&
          motivoCortesia != null &&
          motivoCortesia.isNotEmpty) {
        pagarData['motivoCortesia'] = motivoCortesia;
      }

      // Solo incluir tipoConsumoInterno para consumo interno
      if (tipoPago == 'consumo_interno' &&
          tipoConsumoInterno != null &&
          tipoConsumoInterno.isNotEmpty) {
        pagarData['tipoConsumoInterno'] = tipoConsumoInterno;
      }

      print('🚀 Datos enviados al pagar pedido:');
      print('  - Pedido ID: $pedidoId');
      print('  - Tipo de pago: $tipoPago');
      print('  - Es cortesía: $esCortesia');
      print('  - Es consumo interno: $esConsumoInterno');
      print('  - Datos completos: ${json.encode(pagarData)}');

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
          print('✅ PedidoService: Pago completado exitosamente');

          return pedidoPagado;
        } else {
          print(
            '❌ PedidoService: Formato de respuesta inválido: ${response.body}',
          );
          throw Exception(
            'Formato de respuesta inválido: ${responseData['message'] ?? 'Sin mensaje'}',
          );
        }
      } else {
        print(
          '❌ PedidoService: Error HTTP ${response.statusCode}: ${response.body}',
        );
        final errorData = json.decode(response.body);
        String errorMessage = errorData['message'] ?? 'Error desconocido';
        throw Exception(
          'Error al pagar pedido (${response.statusCode}): $errorMessage',
        );
      }
    } catch (e) {
      print('❌ Error pagando pedido: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Pagar productos específicos de un pedido (pago parcial)
  Future<Map<String, dynamic>> pagarProductosParciales(
    String pedidoId, {
    required List<ItemPedido> itemsSeleccionados,
    String formaPago = 'efectivo',
    double propina = 0.0,
    String procesadoPor = '',
    String notas = '',
  }) async {
    try {
      final headers = await _getHeaders();

      // Calcular el total de los items seleccionados
      double totalSeleccionado = itemsSeleccionados.fold<double>(
        0.0,
        (sum, item) => sum + (item.precio * item.cantidad),
      );

      // Crear lista de IDs de items para el backend
      List<String> itemIds = itemsSeleccionados
          .map((item) => item.id ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      final Map<String, dynamic> pagoData = {
        'itemIds': itemIds,
        'formaPago': formaPago,
        'propina': propina,
        'procesadoPor': procesadoPor,
        'notas': notas,
        'totalCalculado': totalSeleccionado + propina,
        'fechaPago': DateTime.now().toIso8601String(),
      };

      print('🚀 Datos para pago parcial:');
      print('  - Pedido ID: $pedidoId');
      print('  - Items seleccionados: ${itemIds.length}');
      print('  - Total calculado: ${totalSeleccionado + propina}');
      print('  - Datos completos: ${json.encode(pagoData)}');

      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/$pedidoId/pagar-parcial'),
        headers: headers,
        body: json.encode(pagoData),
      );

      print('Pago parcial response: ${response.statusCode}');
      print('Pago parcial body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Notificar que se procesó un pago
          _pedidoPagadoController.add(true);
          print('🔔 PedidoService: Notificación de pago parcial enviada');
          print('✅ PedidoService: Pago parcial completado exitosamente');

          return {
            'success': true,
            'pedidoActualizado': responseData['data']['pedidoActualizado'],
            'documentoCreado': responseData['data']['documentoCreado'],
            'itemsPagados': itemsSeleccionados.length,
            'totalPagado': totalSeleccionado + propina,
            'cambio': responseData['data']['cambio'] ?? 0.0,
          };
        } else {
          throw Exception(
            'Formato de respuesta inválido: ${responseData['message'] ?? 'Sin mensaje'}',
          );
        }
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = errorData['message'] ?? 'Error desconocido';
        throw Exception(
          'Error al procesar pago parcial (${response.statusCode}): $errorMessage',
        );
      }
    } catch (e) {
      print('❌ Error en pago parcial: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener ingredientes que pueden devolverse para un producto cancelado
  Future<List<IngredienteDevolucion>> obtenerIngredientesParaDevolucion(
    String pedidoId,
    String productoId,
  ) async {
    try {
      final ingredientes = await _inventarioService
          .getIngredientesDescontadosParaProducto(pedidoId, productoId);

      return ingredientes
          .map((ingrediente) => IngredienteDevolucion.fromJson(ingrediente))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo ingredientes para devolución: $e');
      throw Exception('Error al obtener ingredientes para devolución: $e');
    }
  }

  // Cancelar producto con selección de ingredientes
  Future<void> cancelarProductoConIngredientes(
    CancelarProductoRequest request,
  ) async {
    try {
      final ingredientesADevolver = request.ingredientes
          .where((ingrediente) => ingrediente.devolver)
          .map((ingrediente) => ingrediente.toJson())
          .toList();

      await _inventarioService.devolverIngredientesAlInventario(
        request.pedidoId,
        request.productoId,
        ingredientesADevolver,
        request.motivo,
        request.responsable,
      );

      print('✅ Producto cancelado con ingredientes devueltos correctamente');
    } catch (e) {
      print('❌ Error cancelando producto con ingredientes: $e');
      throw Exception('Error al cancelar producto con ingredientes: $e');
    }
  }

  // Mover un pedido de una mesa a otra
  Future<Pedido> moverPedidoAMesa(
    String pedidoId,
    String nuevaMesa, {
    String? nombrePedido,
  }) async {
    try {
      final headers = await _getHeaders();

      final Map<String, dynamic> requestData = {'nuevaMesa': nuevaMesa};

      if (nombrePedido != null && nombrePedido.isNotEmpty) {
        requestData['nombrePedido'] = nombrePedido;
      }

      print('🚚 Moviendo pedido $pedidoId a mesa: $nuevaMesa');
      if (nombrePedido != null) {
        print('  - Nombre del pedido: $nombrePedido');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/$pedidoId/mover-mesa'),
        headers: headers,
        body: json.encode(requestData),
      );

      print('Mover pedido response: ${response.statusCode}');
      print('Mover pedido body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoMovido = Pedido.fromJson(responseData['data']);
          print('✅ Pedido movido exitosamente a $nuevaMesa');
          return pedidoMovido;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = errorData['message'] ?? 'Error desconocido';
        throw Exception(
          'Error al mover pedido (${response.statusCode}): $errorMessage',
        );
      }
    } catch (e) {
      print('❌ Error moviendo pedido: $e');
      throw Exception('Error moviendo pedido: $e');
    }
  }

  /// Mueve productos específicos de un pedido a otra mesa
  /// Crea automáticamente una nueva orden en la mesa destino si está libre
  Future<Map<String, dynamic>> moverProductosEspecificos({
    required String pedidoOrigenId,
    required String mesaDestinoNombre,
    required List<ItemPedido> itemsParaMover,
    required String usuarioId,
    required String usuarioNombre,
  }) async {
    try {
      print('🔄 Moviendo productos específicos...');
      print('  - Pedido origen: $pedidoOrigenId');
      print('  - Mesa destino: $mesaDestinoNombre');
      print('  - Items a mover: ${itemsParaMover.length}');

      final token = await storage.read(key: 'jwt_token');
      if (token == null) {
        throw Exception('Token de autenticación no encontrado');
      }

      // Preparar datos de los items a mover
      final itemsData = itemsParaMover
          .map(
            (item) => {
              'itemId': item.id,
              'cantidad': item.cantidad,
              'precio': item.precio,
              'productoId': item.productoId,
              'productoNombre': item.productoNombre,
              'notas': item.notas,
            },
          )
          .toList();

      final requestData = {
        'pedidoOrigenId': pedidoOrigenId,
        'mesaDestinoNombre': mesaDestinoNombre,
        'itemsParaMover': itemsData,
        'usuarioId': usuarioId,
        'usuarioNombre': usuarioNombre,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('📤 Enviando request: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/pedidos/mover-productos-especificos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestData),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final data = responseData['data'] ?? {};

          print('✅ Productos movidos exitosamente');
          print('  - Mesa destino: $mesaDestinoNombre');
          print('  - Nueva orden creada: ${data['nuevaOrdenCreada'] ?? false}');
          print(
            '  - Items movidos: ${data['itemsMovidos'] ?? itemsParaMover.length}',
          );

          return {
            'success': true,
            'nuevaOrdenCreada': data['nuevaOrdenCreada'] ?? false,
            'itemsMovidos': data['itemsMovidos'] ?? itemsParaMover.length,
            'pedidoDestinoId': data['pedidoDestinoId'],
            'message': 'Productos movidos exitosamente a $mesaDestinoNombre',
          };
        } else {
          throw Exception(
            responseData['message'] ?? 'Error procesando el movimiento',
          );
        }
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = errorData['message'] ?? 'Error desconocido';
        throw Exception(
          'Error al mover productos (${response.statusCode}): $errorMessage',
        );
      }
    } catch (e) {
      print('❌ Error moviendo productos específicos: $e');
      return {'success': false, 'message': 'Error al mover productos: $e'};
    }
  }
}
