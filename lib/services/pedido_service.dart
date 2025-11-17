import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async'; // Importar para usar StreamController
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
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

  // Mantener un caché local de pedidos para actualizaciones rápidas
  final Map<String, Pedido> _pedidosCache = {};

  // ✅ NUEVO: Cache para evitar correcciones de estado en bucle
  final Map<String, DateTime> _estadoCorregidoCache = {};

  final InventarioService _inventarioService = InventarioService();
  final CuadreCajaService _cuadreCajaService = CuadreCajaService();

  PedidoService._internal() {
    // PedidoService: Inicializando servicio y StreamControllers
  }

  void dispose() {
    // PedidoService: Cerrando StreamControllers
    _pedidoCompletadoController.close();
    _pedidoPagadoController.close();
  }

  /// Actualiza el estado de un pedido en la caché local
  /// Útil para asegurar que el estado se refleje correctamente en la UI
  /// independientemente de la respuesta del servidor
  Future<void> updateEstadoPedidoLocal(
    String pedidoId,
    EstadoPedido nuevoEstado,
  ) async {
    try {
      print(
        '🔄 Actualizando estado de pedido localmente: $pedidoId -> ${nuevoEstado.name}',
      );

      // Buscar el pedido en caché si existe
      Pedido? pedido = _pedidosCache[pedidoId];

      // Si no está en caché, intentar obtenerlo del servidor
      if (pedido == null) {
        final pedidoActualizado = await getPedidoById(pedidoId);
        if (pedidoActualizado != null) {
          // Actualizar el estado y guardar en caché
          pedidoActualizado.estado = nuevoEstado;
          _pedidosCache[pedidoId] = pedidoActualizado;
          print('✅ Estado del pedido actualizado localmente desde servidor');
        }
      } else {
        // Actualizar el pedido existente en caché
        pedido.estado = nuevoEstado;
        _pedidosCache[pedidoId] = pedido;
        print('✅ Estado del pedido actualizado localmente desde caché');
      }

      // Notificar el cambio para actualizar la UI
      _pedidoPagadoController.add(true);
    } catch (e) {
      print('❌ Error al actualizar estado local del pedido: $e');
    }
  }

  /// Helper para formatear fechas de manera consistente con el backend
  /// ULTRA-ROBUSTO: Nunca falla el formateo de fecha
  String _formatearFechaParaBackend(DateTime fecha) {
    try {
      // Asegurar que sea hora local y válida
      final fechaLocal = fecha.toLocal();

      // Validar que la fecha esté en un rango razonable
      if (fechaLocal.year < 1900 || fechaLocal.year > 2100) {
        print(
          '⚠️ Fecha fuera de rango (${fechaLocal.year}), usando fecha actual',
        );
        final fechaActual = DateTime.now().toLocal();
        return _formatoManualFecha(fechaActual);
      }

      // Formateo manual SIEMPRE para evitar problemas de locale
      return _formatoManualFecha(fechaLocal);
    } catch (e) {
      print('❌ Error crítico formateando fecha: $e');
      print('❌ Fecha original: ${fecha.toString()}');
      // Fallback absoluto: usar fecha actual con formateo manual
      try {
        final fechaActual = DateTime.now().toLocal();
        return _formatoManualFecha(fechaActual);
      } catch (e2) {
        print('❌ Fallback crítico en formateo de fecha: $e2');
        // Último recurso: formato ISO básico hardcodeado
        final now = DateTime.now();
        return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      }
    }
  }

  /// Formateo manual de fecha ULTRA-SEGURO
  String _formatoManualFecha(DateTime fecha) {
    try {
      // Formato: yyyy-MM-ddTHH:mm:ss
      final year = fecha.year.toString().padLeft(4, '0');
      final month = fecha.month.toString().padLeft(2, '0');
      final day = fecha.day.toString().padLeft(2, '0');
      final hour = fecha.hour.toString().padLeft(2, '0');
      final minute = fecha.minute.toString().padLeft(2, '0');
      final second = fecha.second.toString().padLeft(2, '0');

      final resultado = '$year-$month-${day}T$hour:$minute:$second';

      // Validar que el resultado tenga el formato correcto
      if (!RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$',
      ).hasMatch(resultado)) {
        print('⚠️ Formato de fecha inválido generado: $resultado');
        // Fallback con valores predeterminados si algo salió mal
        return '${DateTime.now().year}-01-01T00:00:00';
      }

      return resultado;
    } catch (e) {
      print('❌ Error en formateo manual: $e');
      return '${DateTime.now().year}-01-01T00:00:00';
    }
  }

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();
  final ProductoService _productoService = ProductoService();

  // Obtener token del storage
  Future<String?> _getToken() async {
    try {
      if (kIsWeb) {
        return html.window.localStorage['jwt_token'];
      } else {
        return await storage.read(key: 'jwt_token');
      }
    } catch (e) {
      print('Error obteniendo token: $e');
      return null;
    }
  }

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

      // Log detallado para depuración de reportes
      print(
        '🔍 REPORTE DETALLADO: Recibidos ${jsonList.length} pedidos del servidor',
      );
      int pedidosFiltrados = 0;

      // Convertir JSON a objetos Pedido
      pedidos = jsonList.map((json) {
        final pedido = Pedido.fromJson(json);
        final estadoOriginal = pedido.estado;
        final bool teoriaPagado = pedido.estaPagado;

        // Corregir estados inconsistentes
        if (pedido.estado == EstadoPedido.activo &&
            pedido.pagadoPor != null &&
            pedido.pagadoPor!.isNotEmpty) {
          print(
            '⚠️ Estado inconsistente en _parseListResponse: ID=${pedido.id}, estado=${pedido.estado}, pagadoPor=${pedido.pagadoPor}',
          );
          print('✅ Corrigiendo estado a PAGADO automáticamente');
          pedido.estado = EstadoPedido.pagado;
          pedidosFiltrados++;
        }

        // Verificar si el tipo es cortesía pero el estado no lo refleja
        if (pedido.tipo == TipoPedido.cortesia &&
            pedido.estado != EstadoPedido.cortesia) {
          print(
            '⚠️ Estado inconsistente en _parseListResponse: pedido tipo CORTESÍA pero estado=${pedido.estado}',
          );
          print('✅ Corrigiendo estado a CORTESÍA automáticamente');
          pedido.estado = EstadoPedido.cortesia;
        }

        // Si estado es "pendiente", convertirlo a activo o pagado según otros campos
        if (pedido.estado.toString().toLowerCase() == "pendiente") {
          if (pedido.pagadoPor != null && pedido.pagadoPor!.isNotEmpty) {
            print(
              '⚠️ Estado "pendiente" detectado con pagadoPor: ${pedido.pagadoPor}',
            );
            print('✅ Corrigiendo estado a PAGADO automáticamente');
            pedido.estado = EstadoPedido.pagado;
            pedidosFiltrados++;
          } else {
            print('⚠️ Estado "pendiente" detectado sin pagadoPor');
            print('✅ Corrigiendo estado a ACTIVO automáticamente');
            pedido.estado = EstadoPedido.activo;
            pedidosFiltrados++;
          }
        }

        // Verificar inconsistencias adicionales para diagnóstico
        if (estadoOriginal != pedido.estado) {
          print('📊 DIAGNÓSTICO VENTAS - Pedido ID: ${pedido.id}');
          print('  - Estado original: $estadoOriginal');
          print('  - Estado corregido: ${pedido.estado}');
          print('  - estaPagado: $teoriaPagado');
          print('  - pagadoPor: ${pedido.pagadoPor ?? "NULL"}');
          print('  - formaPago: ${pedido.formaPago ?? "NULL"}');
          print(
            '  - fechaPago: ${pedido.fechaPago != null ? "PRESENTE" : "NULL"}',
          );
        }

        // Guardar en caché para acceso rápido
        if (pedido.id.isNotEmpty) {
          _pedidosCache[pedido.id] = pedido;
        }

        return pedido;
      }).toList();

      // Ordenar pedidos por fecha descendente (más recientes primero)
      pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));

      // Análisis de pedidos pagados para diagnóstico de ventas
      int pedidosPagados = 0;
      int pedidosActivos = 0;
      int pedidosCortesia = 0;
      int pedidosCancelados = 0;
      int pedidosConEstadoPagado = 0;
      int pedidosConPagadoPorSinEstadoPagado = 0;

      for (var pedido in pedidos) {
        final bool realmentePagado = pedido.estaPagado;

        if (realmentePagado) {
          pedidosPagados++;
        }

        if (pedido.estado == EstadoPedido.activo) {
          pedidosActivos++;
          // Verificar si tiene pagadoPor pero no está marcado como pagado
          if (pedido.pagadoPor != null && pedido.pagadoPor!.isNotEmpty) {
            pedidosConPagadoPorSinEstadoPagado++;
          }
        } else if (pedido.estado == EstadoPedido.pagado) {
          pedidosConEstadoPagado++;
        } else if (pedido.estado == EstadoPedido.cortesia) {
          pedidosCortesia++;
        } else if (pedido.estado == EstadoPedido.cancelado) {
          pedidosCancelados++;
        }
      }

      // Imprimir resumen para diagnóstico
      print('📊 ANÁLISIS DE VENTAS - Total pedidos: ${pedidos.length}');
      print('  - Pedidos realmente pagados (estaPagado): $pedidosPagados');
      print('  - Pedidos con estado=PAGADO: $pedidosConEstadoPagado');
      print(
        '  - Pedidos con pagadoPor pero sin estado PAGADO: $pedidosConPagadoPorSinEstadoPagado',
      );
      print('  - Pedidos CORTESÍA: $pedidosCortesia');
      print('  - Pedidos ACTIVOS: $pedidosActivos');
      print('  - Pedidos CANCELADOS: $pedidosCancelados');
      print('  - Pedidos con estados corregidos: $pedidosFiltrados');

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
    final token = await _getToken();
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

  // Obtener pedidos de hoy para analizar ventas
  Future<List<Pedido>> getPedidosHoy() async {
    try {
      final headers = await _getHeaders();
      final hoy = DateTime.now();
      final String fechaHoy =
          "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";

      print('🔍 Obteniendo pedidos de hoy: $fechaHoy');

      // Intentar primero con el endpoint específico
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/por-fecha?fecha=$fechaHoy'),
        headers: headers,
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        print('⚠️ Error al obtener pedidos de hoy: ${response.statusCode}');

        // FALLBACK: Obtener todos los pedidos y filtrar por fecha
        print(
          '🔄 Usando fallback: obteniendo todos los pedidos y filtrando...',
        );

        final todosPedidos = await getAllPedidos();
        final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
        final finHoy = inicioHoy.add(Duration(days: 1));

        final pedidosDeHoy = todosPedidos.where((pedido) {
          return pedido.fecha.isAfter(inicioHoy) &&
              pedido.fecha.isBefore(finHoy);
        }).toList();

        print('✅ Pedidos filtrados de hoy: ${pedidosDeHoy.length}');
        return pedidosDeHoy;
      }
    } catch (e) {
      print('❌ Error obteniendo pedidos de hoy: $e');

      // FALLBACK DE EMERGENCIA: Filtrar todos los pedidos
      try {
        print('🆘 Fallback de emergencia...');
        final hoy = DateTime.now();
        final todosPedidos = await getAllPedidos();
        final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
        final finHoy = inicioHoy.add(Duration(days: 1));

        final pedidosDeHoy = todosPedidos.where((pedido) {
          return pedido.fecha.isAfter(inicioHoy) &&
              pedido.fecha.isBefore(finHoy);
        }).toList();

        print('✅ Fallback - Pedidos de hoy: ${pedidosDeHoy.length}');
        return pedidosDeHoy;
      } catch (fallbackError) {
        print('❌ Error en fallback: $fallbackError');
        return [];
      }
    }
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
      // VALIDACIÓN: Verificar que hay una caja pendiente antes de crear el pedido
      print('🔍 Validando que hay una caja pendiente...');
      final cajas = await _cuadreCajaService.getAllCuadres();
      final cajaActiva = cajas
          .where((c) => c.estado == 'pendiente')
          .firstOrNull;

      if (cajaActiva == null) {
        print('❌ Caja cerrada - No se puede crear pedido');
        throw Exception(
          'Debe abrir caja para continuar. Para registrar pedidos primero debe abrir la caja del día.',
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
      // VALIDACIÓN: Verificar que hay una caja pendiente antes de crear el pedido
      print('🔍 Validando que hay una caja pendiente...');
      final cajas = await _cuadreCajaService.getAllCuadres();
      final cajaActiva = cajas
          .where((c) => c.estado == 'pendiente')
          .firstOrNull;

      if (cajaActiva == null) {
        print('❌ Caja cerrada - No se puede crear pedido');
        throw Exception(
          'Debe abrir caja para continuar. Para registrar pedidos primero debe abrir la caja del día.',
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

          // ✅ CORREGIDO: Validar stock antes de procesar
          final Map<String, int> cantidadPorProducto = {
            for (var item in pedidoCreado.items) item.productoId: item.cantidad,
          };

          // Validar stock disponible antes de descontar
          final validacion = await _inventarioService.validarStockAntesDePedido(
            ingredientesPorItem,
            cantidadPorProducto,
          );

          if (!validacion['stockSuficiente']) {
            print('⚠️ Stock insuficiente detectado: ${validacion['mensaje']}');
            // Continuar pero registrar la alerta
          }

          // Procesar descuento de ingredientes automáticamente
          try {
            final procesado = await _inventarioService
                .procesarPedidoParaInventario(
                  pedidoCreado.id,
                  ingredientesPorItem,
                );
            if (procesado) {
              print(
                '✅ Ingredientes descontados correctamente para pedido: ${pedidoCreado.id}',
              );
            } else {
              print(
                '⚠️ Advertencia: Pedido creado pero inventario no actualizado completamente',
              );
            }
          } catch (e) {
            print('⚠️ Error al descontar ingredientes del inventario: $e');
            // ✅ MEJORADO: Si es error crítico de stock, propagar
            if (e.toString().contains('stock insuficiente') ||
                e.toString().contains('insufficient stock')) {
              throw Exception(
                'Pedido creado pero error crítico de inventario: $e',
              );
            }
          }

          // Notificar a la aplicación que se creó un pedido (listeners pueden recargar UI)
          try {
            _pedidoCompletadoController.add(true);
            print('🔔 Evento: pedido creado -> notificados listeners');
          } catch (e) {
            print('⚠️ Error notificando pedido creado: $e');
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

      // Asegurar que el campo notas nunca sea nulo para evitar error en el backend
      if (pedidoJson['notas'] == null) {
        pedidoJson['notas'] = "";
      }

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

          // Notificar a la aplicación que se actualizó un pedido
          try {
            _pedidoCompletadoController.add(true);
            print('🔔 Evento: pedido actualizado -> notificados listeners');
          } catch (e) {
            print('⚠️ Error notificando pedido actualizado: $e');
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

  // Eliminar pedido (con reversión automática de dinero en caja)
  Future<void> eliminarPedido(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/pedidos/$id'),
        headers: headers,
      );

      print('🔧 Eliminando pedido $id - Status: ${response.statusCode}');
      print('🔧 Response body: ${response.body}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        // El backend maneja automáticamente:
        // - Reversión de dinero en caja si el pedido estaba pagado
        // - Limpieza de cache
        // - Registro en historial de ediciones
        print('✅ Pedido eliminado con reversión automática de dinero');
        return;
      } else {
        // Intentar obtener mensaje de error del backend
        String errorMsg = 'Error al eliminar pedido: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMsg = errorData['message'];
          }
        } catch (_) {
          // Usar mensaje genérico si no se puede parsear
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ Error eliminando pedido: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Eliminar pedido forzadamente (para administradores)
  // Esta función específicamente maneja pedidos pagados o con estado especial
  Future<void> eliminarPedidoForzado(String id) async {
    try {
      print('🔧 ADMIN: Intentando eliminar pedido forzadamente: $id');

      final headers = await _getHeaders();

      // Intentar eliminación forzada con parámetro admin
      final response = await http.delete(
        Uri.parse('$baseUrl/api/pedidos/$id?force=true&admin=true'),
        headers: headers,
      );

      print('🔧 ADMIN: Respuesta del servidor: ${response.statusCode}');
      print('🔧 ADMIN: Cuerpo de respuesta: ${response.body}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        print('✅ ADMIN: Pedido eliminado exitosamente');
        return;
      }

      // Si el endpoint normal falla, intentar con endpoint específico de admin
      if (response.statusCode != 204) {
        print('⚠️ ADMIN: Endpoint normal falló, intentando endpoint admin...');

        final adminResponse = await http.delete(
          Uri.parse('$baseUrl/api/admin/pedidos/$id'),
          headers: headers,
        );

        print(
          '🔧 ADMIN: Respuesta endpoint admin: ${adminResponse.statusCode}',
        );
        print('🔧 ADMIN: Cuerpo respuesta admin: ${adminResponse.body}');

        if (adminResponse.statusCode == 204 ||
            adminResponse.statusCode == 200) {
          print('✅ ADMIN: Pedido eliminado via endpoint admin');
          return;
        }

        // Si ambos fallan, mostrar información detallada
        String errorMsg = 'Error al eliminar pedido: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMsg = errorData['message'];
          }
        } catch (e) {
          // Si no se puede parsear el JSON, usar mensaje por defecto
        }

        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ ADMIN: Error eliminando pedido: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  /// Eliminar pedido pagado - Revierte automáticamente el dinero de las ventas
  /// Este método utiliza el endpoint especial que maneja la reversión de pagos
  Future<void> eliminarPedidoPagado(String id) async {
    try {
      print('INFO: Eliminando pedido pagado: $id (con reversión de dinero)');

      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/pedidos/$id/pagado'),
        headers: headers,
      );

      print('INFO: Respuesta del servidor: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('INFO: Cuerpo de respuesta: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Pedido pagado eliminado exitosamente con reversión de dinero');
        return;
      }

      // Manejar errores específicos
      String errorMsg =
          'Error al eliminar pedido pagado: ${response.statusCode}';

      if (response.body.isNotEmpty) {
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('message')) {
            errorMsg = errorData['message'];
          }
        } catch (e) {
          // Si no se puede parsear el JSON, usar mensaje por defecto
        }
      }

      throw Exception(errorMsg);
    } catch (e) {
      print('❌ Error eliminando pedido pagado: $e');
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
        Pedido? pedido;

        // Manejar respuesta con wrapper de éxito
        if (responseData is Map<String, dynamic>) {
          if (responseData['success'] == true && responseData['data'] != null) {
            pedido = Pedido.fromJson(responseData['data']);
          } else if (responseData.containsKey('_id') ||
              responseData.containsKey('id')) {
            // Respuesta directa sin wrapper
            pedido = Pedido.fromJson(responseData);
          }

          // Corregir estados inconsistentes
          if (pedido != null) {
            // Si el pedido está inconsistente (estado=pendiente pero pagadoPor existe)
            if (pedido.estado == EstadoPedido.activo &&
                pedido.pagadoPor != null &&
                pedido.pagadoPor!.isNotEmpty) {
              print(
                '⚠️ Estado inconsistente detectado: ID=${pedido.id}, estado=${pedido.estado}, pagadoPor=${pedido.pagadoPor}',
              );
              print('✅ Corrigiendo estado a PAGADO automáticamente');
              pedido.estado = EstadoPedido.pagado;
            }

            // ✅ MEJORADO: Verificar inconsistencias sin crear bucles
            if (pedido.tipo == TipoPedido.cortesia &&
                pedido.estado != EstadoPedido.cortesia) {
              // Solo corregir si no se ha corregido recientemente
              final cacheKey = '${pedido.id}_estado_corregido';
              final lastCorrection = _estadoCorregidoCache[cacheKey];
              final now = DateTime.now();

              if (lastCorrection == null ||
                  now.difference(lastCorrection).inSeconds > 30) {
                print(
                  '⚠️ Estado inconsistente detectado: pedido tipo CORTESÍA pero estado=${pedido.estado}',
                );
                print('✅ Corrigiendo estado a CORTESÍA automáticamente');
                pedido.estado = EstadoPedido.cortesia;
                _estadoCorregidoCache[cacheKey] = now;
              }
            }

            // Guardar en caché para acceso rápido
            _pedidosCache[pedidoId] = pedido;
          }

          return pedido;
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
      
      // 🔧 VALIDACIÓN: Verificar que el nombre no esté vacío
      if (nombreLimpio.isEmpty) {
        print('❌ Error: Nombre de mesa vacío en getPedidosByMesa()');
        throw Exception('El nombre de la mesa no puede estar vacío');
      }
      
      // Usar Uri.encodeComponent para manejar correctamente los espacios y caracteres especiales
      final encodedNombreMesa = Uri.encodeComponent(nombreLimpio);
      print('🔍 Obteniendo pedidos para mesa: "$nombreLimpio" (encoded: "$encodedNombreMesa")');
      
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

                // Corregir estados inconsistentes
                if (pedido.estado == EstadoPedido.activo &&
                    pedido.pagadoPor != null &&
                    pedido.pagadoPor!.isNotEmpty) {
                  print(
                    '⚠️ Estado inconsistente detectado (mesa ${nombreMesa}): ID=${pedido.id}, estado=${pedido.estado}, pagadoPor=${pedido.pagadoPor}',
                  );
                  print('✅ Corrigiendo estado a PAGADO automáticamente');
                  pedido.estado = EstadoPedido.pagado;
                }

                // ✅ MEJORADO: Verificar inconsistencias sin crear bucles (mesa específica)
                if (pedido.tipo == TipoPedido.cortesia &&
                    pedido.estado != EstadoPedido.cortesia) {
                  // Solo corregir si no se ha corregido recientemente
                  final cacheKey = '${pedido.id}_mesa_estado_corregido';
                  final lastCorrection = _estadoCorregidoCache[cacheKey];
                  final now = DateTime.now();

                  if (lastCorrection == null ||
                      now.difference(lastCorrection).inSeconds > 30) {
                    print(
                      '⚠️ Estado inconsistente detectado: pedido tipo CORTESÍA pero estado=${pedido.estado}',
                    );
                    print('✅ Corrigiendo estado a CORTESÍA automáticamente');
                    pedido.estado = EstadoPedido.cortesia;
                    _estadoCorregidoCache[cacheKey] = now;
                  }
                }

                // Si estado es "pendiente", convertirlo a activo o pagado según otros campos
                if (pedido.estado.toString().toLowerCase() == "pendiente") {
                  if (pedido.pagadoPor != null &&
                      pedido.pagadoPor!.isNotEmpty) {
                    print(
                      '⚠️ Estado "pendiente" detectado con pagadoPor: ${pedido.pagadoPor}',
                    );
                    print('✅ Corrigiendo estado a PAGADO automáticamente');
                    pedido.estado = EstadoPedido.pagado;
                  } else {
                    print('⚠️ Estado "pendiente" detectado sin pagadoPor');
                    print('✅ Corrigiendo estado a ACTIVO automáticamente');
                    pedido.estado = EstadoPedido.activo;
                  }
                }

                // Guardar en caché para acceso rápido
                if (pedido.id.isNotEmpty) {
                  _pedidosCache[pedido.id] = pedido;
                }

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
      // Error de conexión manejado silenciosamente
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('connection')) {
        throw Exception(
          'Error de conexión a internet. Verifica tu conectividad WiFi.',
        );
      }
      throw Exception('Error al cargar pedidos. Intenta nuevamente.');
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
            agregadoPor: item.agregadoPor, // ✅ CORREGIDO: Preservar agregadoPor
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
            agregadoPor: item.agregadoPor, // ✅ CORREGIDO: Preservar agregadoPor
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
    final token = await _getToken();

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
    double totalPagado = 0.0,
    String procesadoPor = '',
    String notas = '',
    TipoPedido? tipoPedido,
    bool esCortesia = false,
    bool esConsumoInterno = false,
    String? motivoCortesia,
    String? tipoConsumoInterno,
    double descuento = 0.0, // ✅ NUEVO: Parámetro para descuento
    List<Map<String, dynamic>>?
    pagosParciales, // ✅ NUEVO: Soporte para pagos mixtos
    // Campos adicionales para el pago múltiple
    bool pagoMultiple = false,
    double montoEfectivo = 0.0,
    double montoTarjeta = 0.0,
    double montoTransferencia = 0.0,
  }) async {
    // Declarar tipoPago aquí para que sea accesible tanto en el try como en el catch
    String tipoPago = 'pagado';

    try {
      final headers = await _getHeaders();
      // Determinar el tipoPago según las opciones
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
        'descuento':
            descuento, // ✅ INCLUIR DESCUENTO PARA TODOS LOS TIPOS DE PAGO
      };

      // Solo incluir campos específicos para pagos normales
      if (tipoPago == 'pagado') {
        // Validar forma de pago principal - Nueva lógica para pagos múltiples
        if (pagoMultiple || formaPago == 'mixto' || formaPago == 'multiple') {
          // Para pagos mixtos o múltiples, mantener 'mixto' que es el esperado por el backend
          pagarData['formaPago'] = 'mixto';
          print('💳 Configurando pago como MIXTO (pago múltiple)');

          // Nueva implementación para el nuevo tipo de pago múltiple
          if (pagoMultiple) {
            List<Map<String, dynamic>> pagosMixtos = [];

            // Agregar cada método de pago solo si tiene un monto mayor a cero
            if (montoEfectivo > 0) {
              pagosMixtos.add({
                'formaPago': 'efectivo',
                'monto': montoEfectivo,
              });
            }

            if (montoTarjeta > 0) {
              pagosMixtos.add({'formaPago': 'tarjeta', 'monto': montoTarjeta});
            }

            if (montoTransferencia > 0) {
              pagosMixtos.add({
                'formaPago': 'transferencia',
                'monto': montoTransferencia,
              });
            }

            if (pagosMixtos.isNotEmpty) {
              pagarData['pagosMixtos'] = pagosMixtos;
              print('💳 Pagos múltiples configurados: ${pagosMixtos.length}');
              print('   • Efectivo: $montoEfectivo');
              print('   • Tarjeta: $montoTarjeta');
              print('   • Transferencia: $montoTransferencia');
            }
          }
          // Compatibilidad con el método anterior (pagos parciales)
          else if (pagosParciales != null && pagosParciales.isNotEmpty) {
            List<Map<String, dynamic>> pagosMixtos = [];

            for (var pago in pagosParciales) {
              // Convertir el formato interno al formato esperado por la API
              Map<String, dynamic> pagoMixto = {
                'formaPago': pago['formaPago'],
                'monto': pago['monto'],
              };
              pagosMixtos.add(pagoMixto);
            }

            pagarData['pagosMixtos'] = pagosMixtos;
            print(
              '💳 Pagos mixtos configurados (modo anterior): ${pagosMixtos.length}',
            );
          }
        } else if (formaPago != 'efectivo' &&
            formaPago != 'transferencia' &&
            formaPago != 'tarjeta' &&
            formaPago != 'otro') {
          print(
            '⚠️ Forma de pago en pagarPedido no reconocida: "$formaPago". Usando efectivo por defecto.',
          );
          formaPago = 'efectivo';
          pagarData['formaPago'] = formaPago;
        } else {
          pagarData['formaPago'] = formaPago;
        }

        pagarData['propina'] = propina;
        // ✅ DESCUENTO YA INCLUIDO ARRIBA: pagarData['descuento'] = descuento;
        pagarData['pagado'] = true;
        pagarData['estado'] = 'Pagado'; // Asegurar que el estado sea explícito
        pagarData['fechaPago'] = _formatearFechaParaBackend(DateTime.now());
        pagarData['totalPagado'] = totalPagado > 0
            ? totalPagado
            : null; // Enviar solo si es diferente de 0

        // Log adicional para forma de pago
        print('💵 Forma de pago configurada: $formaPago');
      }

      // Campos específicos para cortesías - Estructura simplificada
      if (tipoPago == 'cortesia') {
        // Solo los campos esenciales para cortesías
        pagarData['motivoCortesia'] =
            motivoCortesia ?? 'Pedido procesado como cortesía';
        pagarData['estado'] = 'Cortesia';
        // No incluir campos de pago para cortesías, EXCEPTO descuento
        pagarData.remove('formaPago');
        pagarData.remove('propina');
        // ✅ MANTENER DESCUENTO: pagarData.remove('descuento');
        pagarData.remove('totalPagado');
        pagarData.remove('pagado');
      }

      // Campos específicos para consumo interno - Estructura simplificada
      if (tipoPago == 'consumo_interno') {
        // Solo los campos esenciales para consumo interno
        pagarData['tipoConsumoInterno'] = tipoConsumoInterno ?? 'empleado';
        pagarData['estado'] = 'Pagado';
        // No incluir campos de pago para consumo interno, EXCEPTO descuento
        pagarData.remove('formaPago');
        pagarData.remove('propina');
        // ✅ MANTENER DESCUENTO: pagarData.remove('descuento');
        pagarData.remove('totalPagado');
        pagarData.remove('pagado');
      }

      // Validaciones adicionales para cortesías
      if (tipoPago == 'cortesia') {
        // Asegurar que todos los campos requeridos estén presentes
        if (!pagarData.containsKey('motivoCortesia')) {
          pagarData['motivoCortesia'] = 'Pedido procesado como cortesía';
        }
        if (!pagarData.containsKey('estado')) {
          pagarData['estado'] = 'Cortesia';
        }
      }

      // Validaciones adicionales para consumo interno
      if (tipoPago == 'consumo_interno') {
        // Asegurar que todos los campos requeridos estén presentes
        if (!pagarData.containsKey('tipoConsumoInterno')) {
          pagarData['tipoConsumoInterno'] = 'empleado';
        }
        if (!pagarData.containsKey('estado')) {
          pagarData['estado'] = 'Pagado';
        }
      }

      print('INFO: Datos enviados al pagar pedido:');
      print('  - Pedido ID: $pedidoId');
      print('  - Tipo de pago: $tipoPago');
      print('  - Forma de pago: $formaPago');
      print('  - Propina: \$${propina.toStringAsFixed(0)}');
      print(
        '  - Descuento: \$${descuento.toStringAsFixed(0)}',
      ); // ✅ NUEVO: Log de descuento
      print('  - Es cortesía: $esCortesia');
      print('  - Es consumo interno: $esConsumoInterno');

      // Asegurar que el estado está correctamente configurado en la solicitud
      if (tipoPago == 'pagado' && !pagarData.containsKey('estado')) {
        pagarData['estado'] = 'Pagado';
        print('⚠️ Forzando estado=Pagado en la solicitud');
      } else if (tipoPago == 'cortesia' && !pagarData.containsKey('estado')) {
        pagarData['estado'] = 'Cortesia';
        print('⚠️ Forzando estado=Cortesia en la solicitud');
      } else if (tipoPago == 'consumo_interno' &&
          !pagarData.containsKey('estado')) {
        pagarData['estado'] = 'Pagado'; // También se marca como pagado
        print('⚠️ Forzando estado=Pagado para consumo interno en la solicitud');
      }

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

          // Asegurarse de que el pedido tenga el estado correcto
          if (tipoPago == 'pagado' &&
              pedidoPagado.estado != EstadoPedido.pagado) {
            pedidoPagado.estado = EstadoPedido.pagado;
            print('⚠️ Estado del pedido corregido a PAGADO');
          } else if (tipoPago == 'cortesia' &&
              pedidoPagado.estado != EstadoPedido.cortesia) {
            pedidoPagado.estado = EstadoPedido.cortesia;
            print('⚠️ Estado del pedido corregido a CORTESÍA');
          }

          // Actualizar la caché con el pedido pagado
          _pedidosCache[pedidoId] = pedidoPagado;

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

      // Intento de reconciliación: tal vez el backend procesó el pago pero devolvió 500
      try {
        print('🔎 Intentando reconciliar estado del pedido desde servidor...');
        final pedidoVerificado = await getPedidoById(pedidoId);
        if (pedidoVerificado != null) {
          print('🔎 Estado del pedido verificado: ${pedidoVerificado.estado}');

          // Considerar éxito si el estado coincide con lo esperado
          final bool esExitoPorEstado =
              (tipoPago == 'cortesia' &&
                  pedidoVerificado.estado == EstadoPedido.cortesia) ||
              (tipoPago == 'consumo_interno' &&
                  pedidoVerificado.estado == EstadoPedido.pagado) ||
              (pedidoVerificado.estado == EstadoPedido.pagado);

          if (esExitoPorEstado) {
            print(
              '⚠️ Pago posiblemente procesado a pesar del error HTTP. Usando estado del servidor como éxito.',
            );

            // Actualizar caché y notificar listeners
            _pedidosCache[pedidoId] = pedidoVerificado;
            try {
              _pedidoPagadoController.add(true);
            } catch (_) {}

            return pedidoVerificado;
          }
        }
      } catch (verifyErr) {
        print('⚠️ Error durante reconciliación de pedido: $verifyErr');
      }

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
    // Nuevos parámetros para pago múltiple
    bool pagoMultiple = false,
    double montoEfectivo = 0.0,
    double montoTarjeta = 0.0,
    double montoTransferencia = 0.0,
  }) async {
    try {
      final headers = await _getHeaders();

      // ✅ CORRECCIÓN: Calcular desde item.subtotal que incluye descuentos
      double totalSeleccionado = itemsSeleccionados.fold<double>(
        0.0,
        (sum, item) => sum + item.subtotal,
      );

      // ✅ CORRECCIÓN: Usar item.id en lugar de productoId para identificar items específicos
      List<String> itemIds = itemsSeleccionados
          .map((item) => item.id ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      print('🔍 Debug itemIds:');
      for (int i = 0; i < itemsSeleccionados.length; i++) {
        final item = itemsSeleccionados[i];
        print(
          '  Item $i: id=${item.id}, productoId=${item.productoId}, nombre=${item.productoNombre}',
        );
      }
      print('  ItemIds finales: $itemIds');

      final Map<String, dynamic> pagoData = {
        'itemIds': itemIds,
        'formaPago': formaPago,
        'procesadoPor': procesadoPor,
        'notas': notas,
        'totalCalculado': totalSeleccionado + propina,
        // Campos adicionales para pagos múltiples
        'pagoMultiple': pagoMultiple,
        'montoEfectivo': montoEfectivo,
        'montoTarjeta': montoTarjeta,
        'montoTransferencia': montoTransferencia,
      };

      print('INFO: Datos para pago parcial:');
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

      final token = await _getToken();
      if (token == null) {
        throw Exception('Token de autenticación no encontrado');
      }

      // Preparar datos de los productos a mover según formato del backend
      final productosData = itemsParaMover.map((item) {
        // Asegurar que cantidad siempre sea un entero
        int cantidad;
        if (item.cantidad is String) {
          cantidad = int.tryParse(item.cantidad.toString()) ?? 1;
        } else if (item.cantidad is double) {
          cantidad = item.cantidad.toInt();
        } else {
          cantidad = item.cantidad;
        }

        return {'productoId': item.productoId, 'cantidad': cantidad};
      }).toList();

      final requestData = {
        'pedidoId': pedidoOrigenId, // Backend espera 'pedidoId'
        'mesaDestino':
            mesaDestinoNombre, // Enviar nombre completo de mesa (A1, B6, C1)
        'productos': productosData, // Backend espera 'productos'
      };

      print('🌐 LLAMADA API - MOVER PRODUCTOS ESPECÍFICOS:');
      print('   • Endpoint: POST /api/pedidos/mover-productos-especificos');
      print('   • Pedido ID: $pedidoOrigenId');
      print('   • Mesa destino: $mesaDestinoNombre');
      print('   • Productos a mover: ${productosData.length}');
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
          print('  - Nueva orden creada: ${data['nuevoPedidoId'] != null}');
          print('  - Nuevo pedido ID: ${data['nuevoPedidoId'] ?? 'N/A'}');
          print(
            '  - Items movidos: ${data['productosMovidos'] ?? itemsParaMover.length}',
          );

          // Retornar la respuesta completa del backend con información adicional
          return {
            'success': true,
            'data': data, // Datos completos del backend
            'message':
                responseData['message'] ??
                'Productos movidos exitosamente a $mesaDestinoNombre',
            // Mantener compatibilidad con código existente
            'nuevaOrdenCreada': data['nuevoPedidoId'] != null,
            'itemsMovidos': data['productosMovidos'] ?? itemsParaMover.length,
            'pedidoDestinoId': data['nuevoPedidoId'],
            'mesaDestino': data['mesaDestino'],
            'pedidoOriginalEliminado': data['pedidoOriginalEliminado'] ?? false,
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

  /// Elimina todos los pedidos activos (solo para administradores)
  ///
  /// Hace una solicitud DELETE al endpoint de administrador para eliminar todos los pedidos activos.
  /// Devuelve un mapa con 'success' (bool) y 'message' (String) indicando el resultado.
  Future<Map<String, dynamic>> eliminarTodosPedidosActivos() async {
    try {
      print('🔧 ADMIN: Intentando eliminar todos los pedidos activos');

      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/eliminar-todos-pedidos-activos'),
        headers: headers,
      );

      print('🔧 ADMIN: Respuesta del servidor: ${response.statusCode}');
      print('🔧 ADMIN: Cuerpo de respuesta: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ ADMIN: Todos los pedidos activos eliminados correctamente');

        // Notificar que se han actualizado los pedidos
        _pedidoCompletadoController.add(true);

        return {
          'success': true,
          'message':
              'Todos los pedidos activos han sido eliminados correctamente',
        };
      }

      // Manejo de errores
      String errorMessage = 'Error al eliminar pedidos activos';
      try {
        if (response.body.isNotEmpty) {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        }
      } catch (_) {
        // Si no se puede decodificar la respuesta, usar el mensaje por defecto
      }

      print('❌ ADMIN: Error al eliminar pedidos activos: $errorMessage');
      return {
        'success': false,
        'message': errorMessage,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      print('❌ ADMIN: Excepción al eliminar pedidos activos: $e');
      return {
        'success': false,
        'message': 'Error al conectar con el servidor: $e',
      };
    }
  }
}
