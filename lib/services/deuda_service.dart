/// Servicio para gestionar deudas persistentes entre cuadres de caja
///
/// Este servicio maneja la creación, consulta, pago y administración
/// de deudas que deben persistir entre diferentes cuadres.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/deuda.dart';
import '../models/pedido.dart';
import 'base_api_service.dart';

class DeudaService {
  static final DeudaService _instance = DeudaService._internal();
  factory DeudaService() => _instance;
  DeudaService._internal();

  final BaseApiService _baseService = BaseApiService();

  /// Crear una nueva deuda desde un pedido
  Future<Map<String, dynamic>> crearDeudaDesdePedido({
    required Pedido pedido,
    required String cliente,
    String? telefono,
    DateTime? fechaVencimiento,
    String? notas,
    required String creadoPor,
  }) async {
    try {
      final url = _baseService.buildUrl('/deudas');

      final deuda = Deuda(
        descripcion: 'Pedido ${pedido.mesa} - ${pedido.items.length} items',
        montoOriginal: pedido.total,
        montoPendiente: pedido.total,
        fechaCreacion: DateTime.now(),
        fechaVencimiento: fechaVencimiento,
        creadoPor: creadoPor,
        cliente: cliente,
        telefono: telefono,
        pedidoId: pedido.id,
        mesaNombre: pedido.mesa,
        items: pedido.items,
        notas: notas,
      );

      final response = await http.post(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
        body: jsonEncode(deuda.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'deuda': Deuda.fromJson(data),
          'message': 'Deuda creada exitosamente',
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error creando deuda: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Crear deuda manual (no desde pedido)
  Future<Map<String, dynamic>> crearDeudaManual({
    required String descripcion,
    required double monto,
    required String cliente,
    String? telefono,
    DateTime? fechaVencimiento,
    TipoDeuda tipo = TipoDeuda.otro,
    String? notas,
    required String creadoPor,
  }) async {
    try {
      final url = _baseService.buildUrl('/deudas');

      final deuda = Deuda(
        descripcion: descripcion,
        montoOriginal: monto,
        montoPendiente: monto,
        fechaCreacion: DateTime.now(),
        fechaVencimiento: fechaVencimiento,
        creadoPor: creadoPor,
        cliente: cliente,
        telefono: telefono,
        tipo: tipo,
        notas: notas,
      );

      final response = await http.post(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
        body: jsonEncode(deuda.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'deuda': Deuda.fromJson(data),
          'message': 'Deuda creada exitosamente',
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error creando deuda manual: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Obtener todas las deudas con filtros opcionales
  Future<Map<String, dynamic>> obtenerDeudas({
    EstadoDeuda? estado,
    String? cliente,
    bool? soloVencidas,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    try {
      var url = _baseService.buildUrl('/deudas');

      // Construir parámetros de consulta
      Map<String, String> queryParams = {};
      if (estado != null) queryParams['estado'] = estado.name;
      if (cliente != null && cliente.isNotEmpty)
        queryParams['cliente'] = cliente;
      if (soloVencidas == true) queryParams['vencidas'] = 'true';
      if (fechaDesde != null)
        queryParams['fechaDesde'] = fechaDesde.toIso8601String();
      if (fechaHasta != null)
        queryParams['fechaHasta'] = fechaHasta.toIso8601String();

      if (queryParams.isNotEmpty) {
        url +=
            '?' +
            queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<Deuda> deudas = [];
        if (data is List) {
          deudas = data.map((item) => Deuda.fromJson(item)).toList();
        } else if (data['deudas'] != null) {
          deudas = (data['deudas'] as List)
              .map((item) => Deuda.fromJson(item))
              .toList();
        }

        return {'success': true, 'deudas': deudas, 'total': deudas.length};
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
          'deudas': <Deuda>[],
        };
      }
    } catch (e) {
      print('Error obteniendo deudas: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'deudas': <Deuda>[],
      };
    }
  }

  /// Registrar un pago hacia una deuda
  Future<Map<String, dynamic>> registrarPago({
    required String deudaId,
    required double monto,
    required String formaPago,
    String? referencia,
    String? notas,
    required String procesadoPor,
  }) async {
    try {
      final url = _baseService.buildUrl('/deudas/$deudaId/pagos');

      final pago = PagoDeuda(
        deudaId: deudaId,
        monto: monto,
        fecha: DateTime.now(),
        procesadoPor: procesadoPor,
        formaPago: formaPago,
        referencia: referencia,
        notas: notas,
      );

      final response = await http.post(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
        body: jsonEncode(pago.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'deuda': Deuda.fromJson(data['deuda']),
          'pago': PagoDeuda.fromJson(data['pago']),
          'message': 'Pago registrado exitosamente',
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error registrando pago: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Obtener historial de pagos de una deuda
  Future<Map<String, dynamic>> obtenerHistorialPagos(String deudaId) async {
    try {
      final url = _baseService.buildUrl('/deudas/$deudaId/pagos');

      final response = await http.get(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<PagoDeuda> pagos = [];
        if (data is List) {
          pagos = data.map((item) => PagoDeuda.fromJson(item)).toList();
        } else if (data['pagos'] != null) {
          pagos = (data['pagos'] as List)
              .map((item) => PagoDeuda.fromJson(item))
              .toList();
        }

        return {'success': true, 'pagos': pagos};
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
          'pagos': <PagoDeuda>[],
        };
      }
    } catch (e) {
      print('Error obteniendo historial de pagos: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'pagos': <PagoDeuda>[],
      };
    }
  }

  /// Cancelar una deuda (marcarla como cancelada)
  Future<Map<String, dynamic>> cancelarDeuda({
    required String deudaId,
    required String motivo,
    required String canceladoPor,
  }) async {
    try {
      final url = _baseService.buildUrl('/deudas/$deudaId/cancelar');

      final response = await http.put(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
        body: jsonEncode({
          'motivo': motivo,
          'canceladoPor': canceladoPor,
          'fechaCancelacion': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'deuda': Deuda.fromJson(data),
          'message': 'Deuda cancelada exitosamente',
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error cancelando deuda: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Obtener estadísticas de deudas
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final url = _baseService.buildUrl('/deudas/estadisticas');

      final response = await http.get(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'totalDeudas': data['totalDeudas'] ?? 0,
          'montoPendienteTotal': (data['montoPendienteTotal'] ?? 0).toDouble(),
          'deudasVencidas': data['deudasVencidas'] ?? 0,
          'montoVencido': (data['montoVencido'] ?? 0).toDouble(),
          'deudasPorCliente': data['deudasPorCliente'] ?? {},
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Buscar deudas por cliente
  Future<Map<String, dynamic>> buscarPorCliente(String cliente) async {
    return obtenerDeudas(cliente: cliente);
  }

  /// Obtener deudas vencidas
  Future<Map<String, dynamic>> obtenerDeudasVencidas() async {
    return obtenerDeudas(soloVencidas: true);
  }

  /// Obtener deudas pendientes
  Future<Map<String, dynamic>> obtenerDeudasPendientes() async {
    return obtenerDeudas(estado: EstadoDeuda.pendiente);
  }
}
