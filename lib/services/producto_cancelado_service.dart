/// Servicio para gestionar productos cancelados en pedidos
///
/// Este servicio maneja el registro, consulta y gestión de productos
/// que han sido cancelados de pedidos con sus respectivos motivos.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/producto_cancelado.dart';
import '../models/item_pedido.dart';
import 'base_api_service.dart';

class ProductoCanceladoService {
  static final ProductoCanceladoService _instance = ProductoCanceladoService._internal();
  factory ProductoCanceladoService() => _instance;
  ProductoCanceladoService._internal();

  final BaseApiService _baseService = BaseApiService();

  /// Registrar un producto como cancelado
  Future<Map<String, dynamic>> registrarCancelacion({
    required String pedidoId,
    required String mesaNombre,
    required ItemPedido itemOriginal,
    required String canceladoPor,
    required MotivoCancelacion motivo,
    String? descripcionMotivo,
    String? observaciones,
    double? montoReembolsado,
    String? metodoPago,
    String? autorizadoPor,
  }) async {
    try {
      final url = _baseService.buildUrl('/productos-cancelados');
      
      final productoCancelado = ProductoCancelado(
        pedidoId: pedidoId,
        mesaNombre: mesaNombre,
        itemOriginal: itemOriginal,
        fechaCancelacion: DateTime.now(),
        canceladoPor: canceladoPor,
        motivo: motivo,
        descripcionMotivo: descripcionMotivo,
        observaciones: observaciones,
        montoReembolsado: montoReembolsado,
        metodoPago: metodoPago,
        autorizadoPor: autorizadoPor,
        fechaReembolso: montoReembolsado != null ? DateTime.now() : null,
      );

      final response = await http.post(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
        body: jsonEncode(productoCancelado.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'productoCancelado': ProductoCancelado.fromJson(data),
          'message': 'Producto cancelado registrado exitosamente',
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error registrando cancelación: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Obtener todos los productos cancelados con filtros
  Future<Map<String, dynamic>> obtenerProductosCancelados({
    String? pedidoId,
    String? mesaNombre,
    String? canceladoPor,
    MotivoCancelacion? motivo,
    EstadoCancelacion? estado,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    try {
      var url = _baseService.buildUrl('/productos-cancelados');
      
      // Construir parámetros de consulta
      Map<String, String> queryParams = {};
      if (pedidoId != null) queryParams['pedidoId'] = pedidoId;
      if (mesaNombre != null) queryParams['mesaNombre'] = mesaNombre;
      if (canceladoPor != null) queryParams['canceladoPor'] = canceladoPor;
      if (motivo != null) queryParams['motivo'] = motivo.name;
      if (estado != null) queryParams['estado'] = estado.name;
      if (fechaDesde != null) queryParams['fechaDesde'] = fechaDesde.toIso8601String();
      if (fechaHasta != null) queryParams['fechaHasta'] = fechaHasta.toIso8601String();

      if (queryParams.isNotEmpty) {
        url += '?' + queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        List<ProductoCancelado> productos = [];
        if (data is List) {
          productos = data.map((item) => ProductoCancelado.fromJson(item)).toList();
        } else if (data['productos'] != null) {
          productos = (data['productos'] as List)
              .map((item) => ProductoCancelado.fromJson(item))
              .toList();
        }

        return {
          'success': true,
          'productos': productos,
          'total': productos.length,
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
          'productos': <ProductoCancelado>[],
        };
      }
    } catch (e) {
      print('Error obteniendo productos cancelados: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'productos': <ProductoCancelado>[],
      };
    }
  }

  /// Obtener productos cancelados por mesa
  Future<Map<String, dynamic>> obtenerPorMesa(String mesaNombre) async {
    return obtenerProductosCancelados(mesaNombre: mesaNombre);
  }

  /// Obtener productos cancelados por pedido
  Future<Map<String, dynamic>> obtenerPorPedido(String pedidoId) async {
    return obtenerProductosCancelados(pedidoId: pedidoId);
  }

  /// Obtener productos cancelados por usuario
  Future<Map<String, dynamic>> obtenerPorUsuario(String usuario) async {
    return obtenerProductosCancelados(canceladoPor: usuario);
  }

  /// Confirmar una cancelación
  Future<Map<String, dynamic>> confirmarCancelacion({
    required String cancelacionId,
    required String confiradoPor,
    String? observaciones,
  }) async {
    try {
      final url = _baseService.buildUrl('/productos-cancelados/$cancelacionId/confirmar');
      
      final response = await http.put(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
        body: jsonEncode({
          'confirmadoPor': confiradoPor,
          'fechaConfirmacion': DateTime.now().toIso8601String(),
          if (observaciones != null) 'observaciones': observaciones,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'productoCancelado': ProductoCancelado.fromJson(data),
          'message': 'Cancelación confirmada exitosamente',
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error confirmando cancelación: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Revertir una cancelación (restaurar el producto)
  Future<Map<String, dynamic>> revertirCancelacion({
    required String cancelacionId,
    required String revertidoPor,
    String? motivo,
  }) async {
    try {
      final url = _baseService.buildUrl('/productos-cancelados/$cancelacionId/revertir');
      
      final response = await http.put(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
        body: jsonEncode({
          'revertidoPor': revertidoPor,
          'fechaReversion': DateTime.now().toIso8601String(),
          if (motivo != null) 'motivoReversion': motivo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'productoCancelado': ProductoCancelado.fromJson(data),
          'message': 'Cancelación revertida exitosamente',
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error revirtiendo cancelación: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Obtener estadísticas de cancelaciones
  Future<Map<String, dynamic>> obtenerEstadisticas({
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    try {
      var url = _baseService.buildUrl('/productos-cancelados/estadisticas');
      
      Map<String, String> queryParams = {};
      if (fechaDesde != null) queryParams['fechaDesde'] = fechaDesde.toIso8601String();
      if (fechaHasta != null) queryParams['fechaHasta'] = fechaHasta.toIso8601String();

      if (queryParams.isNotEmpty) {
        url += '?' + queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'totalCancelaciones': data['totalCancelaciones'] ?? 0,
          'montoTotalCancelado': (data['montoTotalCancelado'] ?? 0).toDouble(),
          'montoTotalReembolsado': (data['montoTotalReembolsado'] ?? 0).toDouble(),
          'cancelacionesPorMotivo': data['cancelacionesPorMotivo'] ?? {},
          'cancelacionesPorUsuario': data['cancelacionesPorUsuario'] ?? {},
          'cancelacionesPorMesa': data['cancelacionesPorMesa'] ?? {},
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Buscar cancelaciones por rango de fechas
  Future<Map<String, dynamic>> buscarPorFecha({
    required DateTime fechaDesde,
    required DateTime fechaHasta,
  }) async {
    return obtenerProductosCancelados(
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );
  }

  /// Obtener cancelaciones del día actual
  Future<Map<String, dynamic>> obtenerCancelacionesHoy() async {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(Duration(days: 1));

    return obtenerProductosCancelados(
      fechaDesde: inicioHoy,
      fechaHasta: finHoy,
    );
  }
}