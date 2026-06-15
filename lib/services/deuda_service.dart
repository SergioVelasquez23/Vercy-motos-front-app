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

  // ─── Listar deudas ──────────────────────────────────────────────────────────

  Future<List<Deuda>> listarDeudas({
    bool? soloActivas,
    String? clienteInfo,
    String? pedidoId,
  }) async {
    try {
      final params = <String, String>{};
      if (soloActivas == true) params['soloActivas'] = 'true';
      if (clienteInfo != null && clienteInfo.isNotEmpty) params['clienteInfo'] = clienteInfo;
      if (pedidoId != null && pedidoId.isNotEmpty) params['pedidoId'] = pedidoId;

      final uri = Uri.parse(_baseService.buildUrl('/deudas'))
          .replace(queryParameters: params.isNotEmpty ? params : null);

      final response = await http.get(uri, headers: await _baseService.getHeaders());

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        if (data is List) {
          return data.map((j) => Deuda.fromJson(j as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Deuda>> listarDeudasActivas() async {
    try {
      final uri = Uri.parse(_baseService.buildUrl('/deudas/activas'));
      final response = await http.get(uri, headers: await _baseService.getHeaders());
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        if (data is List) {
          return data.map((j) => Deuda.fromJson(j as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Deuda>> listarDeudasVencidas() async {
    try {
      final uri = Uri.parse(_baseService.buildUrl('/deudas/vencidas'));
      final response = await http.get(uri, headers: await _baseService.getHeaders());
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        if (data is List) {
          return data.map((j) => Deuda.fromJson(j as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Deuda?> obtenerDetalle(String id) async {
    try {
      final uri = Uri.parse(_baseService.buildUrl('/deudas/$id'));
      final response = await http.get(uri, headers: await _baseService.getHeaders());
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        if (data is Map<String, dynamic>) return Deuda.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Registrar pago (nueva API: POST /api/deudas/{id}/pagar) ──────────────

  Future<Map<String, dynamic>> registrarPago({
    required String deudaId,
    required double monto,
    required String medioPago,
    required String recibidoPor,
    String? notas,
  }) async {
    try {
      final uri = Uri.parse(_baseService.buildUrl('/deudas/$deudaId/pagar'));
      final body = {
        'monto': monto,
        'medioPago': medioPago,
        'recibidoPor': recibidoPor,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      };
      final response = await http.post(
        uri,
        headers: await _baseService.getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? data,
          'message': data['message'] ?? 'Pago registrado exitosamente',
        };
      }
      final err = jsonDecode(response.body);
      return {
        'success': false,
        'message': err['message'] ?? 'Error ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // ─── Historial de pagos (GET /api/deudas/{id}/pagos) ─────────────────────

  Future<List<PagoDeuda>> obtenerHistorialPagos(String deudaId) async {
    try {
      final uri = Uri.parse(_baseService.buildUrl('/deudas/$deudaId/pagos'));
      final response = await http.get(uri, headers: await _baseService.getHeaders());
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        if (data is List) {
          return data.map((j) => PagoDeuda.fromJson(j as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ─── Estadísticas (GET /api/deudas/estadisticas) ─────────────────────────

  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final uri = Uri.parse(_baseService.buildUrl('/deudas/estadisticas'));
      final response = await http.get(uri, headers: await _baseService.getHeaders());
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        return {
          'success': true,
          'totalDeudas': _toDouble(data['totalDeudas']),
          'deudasActivas': (data['deudasActivas'] as num?)?.toInt() ?? 0,
          'deudasVencidas': (data['deudasVencidas'] as num?)?.toInt() ?? 0,
        };
      }
      return {'success': false, 'totalDeudas': 0.0, 'deudasActivas': 0, 'deudasVencidas': 0};
    } catch (e) {
      return {'success': false, 'totalDeudas': 0.0, 'deudasActivas': 0, 'deudasVencidas': 0};
    }
  }

  // ─── Toggle estado (PUT /api/deudas/{id}/estado?activa=false) ─────────────

  Future<bool> toggleEstado(String deudaId, {required bool activa, String modificadoPor = 'admin'}) async {
    try {
      final uri = Uri.parse(_baseService.buildUrl('/deudas/$deudaId/estado'))
          .replace(queryParameters: {'activa': activa.toString(), 'modificadoPor': modificadoPor});
      final response = await http.put(uri, headers: await _baseService.getHeaders());
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── Crear deuda desde pedido (mantener compatibilidad) ───────────────────

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
      final body = {
        'pedidoId': pedido.id,
        'clienteInfo': cliente,
        'montoTotal': pedido.total,
        if (fechaVencimiento != null) 'fechaVencimiento': fechaVencimiento.toIso8601String(),
        if (notas != null) 'notas': notas,
        'creadoPor': creadoPor,
      };
      final response = await http.post(
        Uri.parse(url),
        headers: await _baseService.getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? data, 'message': 'Deuda creada'};
      }
      return {'success': false, 'message': 'Error ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
