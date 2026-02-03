import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alerta_notificacion.dart';
import '../models/api_response.dart';
import 'base_api_service.dart';

/// Servicio para gestión de alertas y notificaciones
class AlertasService {
  static final AlertasService _instance = AlertasService._internal();
  factory AlertasService() => _instance;
  AlertasService._internal();

  final BaseApiService _baseApiService = BaseApiService();

  static const String _notificationsEndpoint = '/notifications';
  static const String _testAlertsEndpoint = '/test-alerts';

  // === ENVÍO DE ALERTAS ===

  /// Envía alerta de stock bajo
  Future<ApiResponse<AlertaNotificacion>> enviarAlertaStock({
    required String whatsapp,
    required String email,
    required String producto,
    required int stockActual,
    required int stockMinimo,
  }) async {
    try {
      final String url = _baseApiService.buildUrl(_notificationsEndpoint);
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'tipo': TipoAlerta.cuentaPorCobrarVencida.toString().split('.').last,
        'destinos': {'whatsapp': whatsapp, 'email': email},
        'datos': {
          'producto': producto,
          'stock_actual': stockActual,
          'stock_minimo': stockMinimo,
        },
        'metodo': MetodoNotificacion.ambos.toString().split('.').last,
        'prioridad': 'alta',
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(alertData))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        final AlertaNotificacion alerta = AlertaNotificacion.fromJson(data);
        return ApiResponse<AlertaNotificacion>(
          success: true,
          data: alerta,
          message: 'Alerta de stock enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<AlertaNotificacion>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<AlertaNotificacion>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Envía alerta de factura próxima a vencer
  Future<ApiResponse<AlertaNotificacion>> enviarAlertaFactura({
    required String whatsapp,
    required String email,
    required String numeroFactura,
    required String cliente,
    required DateTime fechaVencimiento,
    required double monto,
  }) async {
    try {
      final String url = _baseApiService.buildUrl(_notificationsEndpoint);
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'tipo': TipoAlerta.cuentaPorPagarProximaVencer
            .toString()
            .split('.')
            .last,
        'destinos': {'whatsapp': whatsapp, 'email': email},
        'datos': {
          'numero_factura': numeroFactura,
          'cliente': cliente,
          'fecha_vencimiento': fechaVencimiento.toIso8601String(),
          'monto': monto,
        },
        'metodo': MetodoNotificacion.ambos.toString().split('.').last,
        'prioridad': 'media',
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(alertData))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        final AlertaNotificacion alerta = AlertaNotificacion.fromJson(data);
        return ApiResponse<AlertaNotificacion>(
          success: true,
          data: alerta,
          message: 'Alerta de factura enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<AlertaNotificacion>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<AlertaNotificacion>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Envía alerta de deuda vencida
  Future<ApiResponse<AlertaNotificacion>> enviarAlertaDeuda({
    required String whatsapp,
    required String email,
    required String cliente,
    required double montoVencido,
    required int diasVencimiento,
  }) async {
    try {
      final String url = _baseApiService.buildUrl(_notificationsEndpoint);
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'tipo': TipoAlerta.cuentaPorCobrarVencida.toString().split('.').last,
        'destinos': {'whatsapp': whatsapp, 'email': email},
        'datos': {
          'cliente': cliente,
          'monto_vencido': montoVencido,
          'dias_vencimiento': diasVencimiento,
        },
        'metodo': MetodoNotificacion.ambos.toString().split('.').last,
        'prioridad': 'alta',
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(alertData))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        final AlertaNotificacion alerta = AlertaNotificacion.fromJson(data);
        return ApiResponse<AlertaNotificacion>(
          success: true,
          data: alerta,
          message: 'Alerta de deuda enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<AlertaNotificacion>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<AlertaNotificacion>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  // === VERIFICACIÓN DE CONECTIVIDAD ===

  /// Verifica la conectividad con el microservicio de alertas
  Future<ApiResponse<EstadoMicroservicio>> verificarConectividad() async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_notificationsEndpoint/status',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final EstadoMicroservicio estado = EstadoMicroservicio.fromJson(data);
        return ApiResponse<EstadoMicroservicio>(
          success: true,
          data: estado,
          message: 'Conectividad verificada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<EstadoMicroservicio>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<EstadoMicroservicio>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Obtiene la configuración completa del microservicio
  Future<ApiResponse<Map<String, dynamic>>> getConfiguracionCompleta() async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_notificationsEndpoint/config',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: 'Configuración obtenida exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  // === PRUEBAS DE ALERTAS ===

  /// Prueba de alerta de stock
  Future<ApiResponse<String>> probarAlertaStock() async {
    try {
      final String url = _baseApiService.buildUrl('$_testAlertsEndpoint/stock');
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ApiResponse<String>(
          success: true,
          data: data['message'] ?? 'Prueba ejecutada',
          message: 'Prueba de stock ejecutada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Prueba de alerta de factura
  Future<ApiResponse<String>> probarAlertaFactura() async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_testAlertsEndpoint/factura',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ApiResponse<String>(
          success: true,
          data: data['message'] ?? 'Prueba ejecutada',
          message: 'Prueba de factura ejecutada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Prueba de alerta de deuda
  Future<ApiResponse<String>> probarAlertaDeuda() async {
    try {
      final String url = _baseApiService.buildUrl('$_testAlertsEndpoint/deuda');
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ApiResponse<String>(
          success: true,
          data: data['message'] ?? 'Prueba ejecutada',
          message: 'Prueba de deuda ejecutada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Ejecuta todas las pruebas de alertas
  Future<ApiResponse<Map<String, dynamic>>> ejecutarTodasLasPruebas() async {
    try {
      final String url = _baseApiService.buildUrl('$_testAlertsEndpoint/all');
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: 'Todas las pruebas ejecutadas exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }
}
