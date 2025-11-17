import 'dart:async';
import '../models/pedido.dart';
import '../utils/pedido_helper.dart';
import 'base/http_api_service.dart';
import 'base/base_api_service.dart';
import 'inventario_service.dart'; // Mantener dependencia existente

/// PedidoService refactorizado usando BaseApiService
///
/// Este servicio demuestra cómo migrar lógica de negocio compleja
/// manteniendo la funcionalidad existente pero eliminando duplicación.
///
/// BENEFICIOS DEMOSTRADOS:
/// - Separación clara entre lógica HTTP y lógica de negocio
/// - Manejo consistente de errores
/// - Logging automático en desarrollo
/// - Menor acoplamiento con detalles de implementación HTTP
class PedidoService {
  static final PedidoService _instance = PedidoService._internal();
  factory PedidoService() => _instance;
  PedidoService._internal();

  final BaseApiService _apiService = HttpApiService();
  final InventarioService _inventarioService = InventarioService();

  // StreamControllers para notificaciones (mantener funcionalidad existente)
  final _pedidoCompletadoController = StreamController<bool>.broadcast();
  Stream<bool> get onPedidoCompletado => _pedidoCompletadoController.stream;

  final _pedidoPagadoController = StreamController<bool>.broadcast();
  Stream<bool> get onPedidoPagado => _pedidoPagadoController.stream;

  /// Obtiene todos los pedidos del sistema
  Future<List<Pedido>> getAllPedidos() async {
    try {
      final data = await _apiService.get<dynamic>('/api/pedidos');
      return _parseListResponse(data);
    } on ApiException {
      rethrow;
    }
  }

  /// Obtiene pedidos filtrados por tipo
  Future<List<Pedido>> getPedidosByTipo(TipoPedido tipo) async {
    try {
      final data = await _apiService.get<dynamic>(
        '/api/pedidos',
        queryParams: {'tipo': tipo.toString().split('.').last},
      );
      return _parseListResponse(data);
    } on ApiException {
      rethrow;
    }
  }

  /// Obtiene pedidos filtrados por estado
  Future<List<Pedido>> getPedidosByEstado(EstadoPedido estado) async {
    try {
      final data = await _apiService.get<dynamic>(
        '/api/pedidos',
        queryParams: {'estado': estado.toString().split('.').last},
      );
      return _parseListResponse(data);
    } on ApiException {
      rethrow;
    }
  }

  /// Obtiene pedidos de una mesa específica
  Future<List<Pedido>> getPedidosByMesa(String nombreMesa) async {
    try {
      // Limpiar el nombre de la mesa
      final nombreLimpio = nombreMesa
          .replaceAll('\\n', ' ')
          .replaceAll(RegExp(r'\\s+'), ' ')
          .trim();

      // 🔧 VALIDACIÓN: Verificar que el nombre no esté vacío
      if (nombreLimpio.isEmpty) {
        print('❌ Error: Nombre de mesa vacío en getPedidosByMesa()');
        throw Exception('El nombre de la mesa no puede estar vacío');
      }
      
      print('🔍 Obteniendo pedidos para mesa: "$nombreLimpio"');

      final data = await _apiService.get<dynamic>(
        '/api/pedidos/mesa/$nombreLimpio',
      );
      return _parseListResponse(data);
    } on ApiException {
      rethrow;
    }
  }

  /// Crea un nuevo pedido con validación de inventario
  Future<Pedido> createPedido(Pedido pedido) async {
    try {
      // Validaciones de negocio (mantener lógica existente)
      if (pedido.items.isEmpty) {
        throw ApiException('El pedido debe tener al menos un item');
      }

      if (!PedidoHelper.validatePedidoItems(pedido.items)) {
        throw ApiException(
          'Los items del pedido no son válidos. Verifica que cada item tenga un ID de producto y cantidad mayor a 0.',
        );
      }

      // Crear el pedido
      final data = await _apiService.post<Map<String, dynamic>>(
        '/api/pedidos',
        body: pedido.toJson(),
      );

      final pedidoCreado = Pedido.fromJson(data);

      // Procesar inventario (mantener lógica existente)
      await _procesarInventarioPedido(pedidoCreado);

      return pedidoCreado;
    } on ApiException {
      rethrow;
    }
  }

  /// Actualiza un pedido existente
  Future<Pedido> updatePedido(Pedido pedido) async {
    try {
      // Validaciones de negocio
      if (pedido.items.isEmpty) {
        throw ApiException('El pedido debe tener al menos un item');
      }

      if (!PedidoHelper.validatePedidoItems(pedido.items)) {
        throw ApiException(
          'Los items del pedido no son válidos. Verifica que cada item tenga un ID de producto y cantidad mayor a 0.',
        );
      }

      // Actualizar el pedido
      final data = await _apiService.put<Map<String, dynamic>>(
        '/api/pedidos/${pedido.id}',
        body: pedido.toJson(),
      );

      final pedidoActualizado = Pedido.fromJson(data);

      // Procesar cambios en inventario
      await _procesarInventarioPedido(pedidoActualizado);

      return pedidoActualizado;
    } on ApiException {
      rethrow;
    }
  }

  /// Actualiza el estado de un pedido
  Future<Pedido> actualizarEstadoPedido(
    String pedidoId,
    EstadoPedido nuevoEstado,
  ) async {
    try {
      final data = await _apiService.put<Map<String, dynamic>>(
        '/api/pedidos/$pedidoId/estado/${nuevoEstado.toString().split('.').last}',
      );

      final pedidoActualizado = Pedido.fromJson(data);

      // Emitir evento cuando se paga el pedido
      if (nuevoEstado == EstadoPedido.pagado) {
        _pedidoCompletadoController.add(true);
      }

      return pedidoActualizado;
    } on ApiException {
      rethrow;
    }
  }

  /// Paga un pedido con todas las opciones disponibles
  Future<Pedido> pagarPedido(
    String pedidoId, {
    String formaPago = 'efectivo',
    double propina = 0.0,
    String procesadoPor = '',
    String notas = '',
    bool esCortesia = false,
    bool esConsumoInterno = false,
    String? motivoCortesia,
    String? tipoConsumoInterno,
  }) async {
    try {
      // Determinar el tipo de pago
      String tipoPago;
      if (esCortesia) {
        tipoPago = 'cortesia';
      } else if (esConsumoInterno) {
        tipoPago = 'consumo_interno';
      } else {
        tipoPago = 'pagado';
      }

      // Construir el cuerpo de la petición
      final Map<String, dynamic> pagarData = {
        'tipoPago': tipoPago,
        'procesadoPor': procesadoPor,
        'notas': notas,
      };

      // Campos específicos para pagos normales
      if (tipoPago == 'pagado') {
        // Validar forma de pago
        if (formaPago != 'efectivo' && formaPago != 'transferencia') {
          formaPago = 'efectivo'; // Valor por defecto
        }

        pagarData.addAll({
          'formaPago': formaPago,
          'propina': propina,
          'pagado': true,
          'estado': 'Pagado',
          'fechaPago': DateTime.now().toIso8601String(),
        });
      }

      // Campos específicos para cortesías
      if (tipoPago == 'cortesia' &&
          motivoCortesia != null &&
          motivoCortesia.isNotEmpty) {
        pagarData['motivoCortesia'] = motivoCortesia;
      }

      // Campos específicos para consumo interno
      if (tipoPago == 'consumo_interno' &&
          tipoConsumoInterno != null &&
          tipoConsumoInterno.isNotEmpty) {
        pagarData['tipoConsumoInterno'] = tipoConsumoInterno;
      }

      // Realizar la petición
      final data = await _apiService.put<Map<String, dynamic>>(
        '/api/pedidos/$pedidoId/pagar',
        body: pagarData,
      );

      final pedidoPagado = Pedido.fromJson(data);

      // Notificar que se pagó un pedido
      _pedidoPagadoController.add(true);

      return pedidoPagado;
    } on ApiException {
      rethrow;
    }
  }

  /// Obtiene el total de ventas para un rango de fechas
  Future<double> getTotalVentas({
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (fechaInicio != null) {
        queryParams['fechaInicio'] = fechaInicio.toIso8601String();
      }
      if (fechaFin != null) {
        queryParams['fechaFin'] = fechaFin.toIso8601String();
      }

      final data = await _apiService.get<Map<String, dynamic>>(
        '/api/pedidos/total-ventas',
        queryParams: queryParams,
        parser: (responseData) {
          // Manejar la estructura específica de esta respuesta
          if (responseData is Map<String, dynamic>) {
            if (responseData['success'] == true &&
                responseData['data'] != null) {
              final dataMap = responseData['data'] as Map<String, dynamic>;
              final total = dataMap['total'];
              return {'total': total is num ? total.toDouble() : 0.0};
            }
          }
          return {'total': 0.0};
        },
      );

      return data['total'] as double;
    } on ApiException {
      // En caso de error, retornar 0 en lugar de propagar la excepción
      return 0.0;
    }
  }

  /// Método privado para procesar inventario (mantener lógica existente)
  Future<void> _procesarInventarioPedido(Pedido pedido) async {
    try {
      final Map<String, List<String>> ingredientesPorItem = {
        for (var item in pedido.items)
          item.productoId: item.ingredientesSeleccionados,
      };

      await _inventarioService.procesarPedidoParaInventario(
        pedido.id,
        ingredientesPorItem,
      );
    } catch (e) {
      // No fallar la operación principal si hay error en inventario
      print('⚠️ Error al procesar inventario: $e');
    }
  }

  /// Método privado para parsear listas de pedidos (mantener lógica existente)
  List<Pedido> _parseListResponse(dynamic responseData) {
    try {
      List<Pedido> pedidos = [];
      List<dynamic> jsonList;

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('pedidos')) {
          jsonList = responseData['pedidos'];
        } else if (responseData.containsKey('data')) {
          jsonList = responseData['data'];
        } else if (responseData.containsKey('results')) {
          jsonList = responseData['results'];
        } else {
          return [];
        }
      } else if (responseData is List) {
        jsonList = responseData;
      } else {
        throw ApiException(
          'Formato de respuesta inesperado: ${responseData.runtimeType}',
        );
      }

      // Convertir JSON a objetos Pedido
      pedidos = jsonList.map((json) => Pedido.fromJson(json)).toList();

      // Ordenar pedidos por fecha descendente
      pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));

      return pedidos;
    } catch (e) {
      print('❌ Error parseando lista de pedidos: $e');
      return [];
    }
  }

  /// Limpia los recursos del servicio
  void dispose() {
    _pedidoCompletadoController.close();
    _pedidoPagadoController.close();
  }

  // Métodos estáticos para compatibilidad con código existente
  static Future<List<Pedido>> getPedidos() async {
    return await PedidoService().getAllPedidos();
  }

  static Future<Pedido> actualizarEstado(
    String pedidoId,
    EstadoPedido nuevoEstado,
  ) async {
    return await PedidoService().actualizarEstadoPedido(pedidoId, nuevoEstado);
  }
}
