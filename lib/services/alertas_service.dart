import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alerta_notificacion.dart';
import '../models/api_response.dart';
import 'base_api_service.dart';
import '../utils/logger.dart';
import '../utils/api_error.dart';

/// Servicio para gestión de alertas y notificaciones
class AlertasService {

    // === INTEGRACIÓN TELEGRAM ===
    static const String _telegramApiUrl = 'https://api.telegram.org/bot';
    static const String _telegramToken = '8539029528:AAFjyVd941iMgpIbqEbwN6VLWEZi_m4p53U'; // Reemplaza por tu token real
  static const String _telegramChatId =
      '6535645414'; // ID del chat de Telegram para alertas

    /// Envía un mensaje de texto a Telegram
    Future<http.Response> sendTelegramMessage(String message) async {
      final url = Uri.parse('$_telegramApiUrl$_telegramToken/sendMessage');
      final response = await http.post(
        url,
        body: {
          'chat_id': _telegramChatId,
          'text': message,
        },
      );
      return response;
    }

    /// Envía una foto a Telegram
    Future<http.Response> sendTelegramPhoto(String photoUrl, {String? caption}) async {
      final url = Uri.parse('$_telegramApiUrl$_telegramToken/sendPhoto');
      final response = await http.post(
        url,
        body: {
          'chat_id': _telegramChatId,
          'photo': photoUrl,
          if (caption != null) 'caption': caption,
        },
      );
      return response;
    }

    /// Envía un documento a Telegram
    Future<http.Response> sendTelegramDocument(String documentUrl, {String? caption}) async {
      final url = Uri.parse('$_telegramApiUrl$_telegramToken/sendDocument');
      final response = await http.post(
        url,
        body: {
          'chat_id': _telegramChatId,
          'document': documentUrl,
          if (caption != null) 'caption': caption,
        },
      );
      return response;
    }
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
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<AlertaNotificacion>(
        success: false,
        data: null,
        message: errorMessage(e),
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
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<AlertaNotificacion>(
        success: false,
        data: null,
        message: errorMessage(e),
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
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<AlertaNotificacion>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Envía alerta de gasto realizado
  Future<ApiResponse<Map<String, dynamic>>> enviarAlertaGasto({
    required String tipoGasto,
    required String concepto,
    required double monto,
    required String responsable,
    String? formaPago,
    String? numeroRecibo,
    String? numeroFactura,
    String? proveedor,
  }) async {
    try {
      final String url = _baseApiService.buildUrl(
        '/api/telegram-gastos/alerta',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'tipoGasto': tipoGasto,
        'concepto': concepto,
        'monto': monto,
        'responsable': responsable,
        if (formaPago != null) 'formaPago': formaPago,
        if (numeroRecibo != null) 'numeroRecibo': numeroRecibo,
        if (numeroFactura != null) 'numeroFactura': numeroFactura,
        if (proveedor != null) 'proveedor': proveedor,
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(alertData))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: 'Alerta de gasto enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: errorMessage(e),
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
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<EstadoMicroservicio>(
        success: false,
        data: null,
        message: errorMessage(e),
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
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: errorMessage(e),
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
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: errorMessage(e),
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
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: errorMessage(e),
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
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Prueba de alerta de gastos
  Future<ApiResponse<String>> probarAlertaGasto() async {
    try {
      final String url = _baseApiService.buildUrl('/api/telegram-gastos/test');
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ApiResponse<String>(
          success: true,
          data: data['message'] ?? 'Prueba ejecutada',
          message: 'Prueba de gastos ejecutada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<String>(
        success: false,
        data: null,
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  // === BOT CUENTAS POR PAGAR ===

  /// Envía alerta de nueva cuenta por pagar
  Future<ApiResponse<Map<String, dynamic>>> enviarAlertaNuevaCxP({
    required String proveedor,
    required String numeroFactura,
    required double monto,
    required DateTime fechaVencimiento,
    String? descripcion,
  }) async {
    try {
      final String url = _baseApiService.buildUrl(
        '/api/cuentas-por-pagar-bot/nueva-cuenta',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'proveedorNombre': proveedor,
        'numeroFactura': numeroFactura,
        'montoTotal': monto,
        'diasVencimiento': fechaVencimiento.difference(DateTime.now()).inDays,
        if (descripcion != null) 'descripcion': descripcion,
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(alertData))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: 'Alerta de nueva CxP enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Envía alerta de cuenta próxima a vencer
  Future<ApiResponse<Map<String, dynamic>>> enviarAlertaCxPProximaVencer({
    required String numeroFactura,
    required double monto,
    required int diasRestantes,
    String? cuentaId,
  }) async {
    try {
      appLog('\n📡 [ALERTAS API] enviarAlertaCxPProximaVencer()');

      String baseUrl = _baseApiService.buildUrl(
        '/api/cuentas-por-pagar-bot/proxima-a-vencer',
      );

      if (cuentaId != null && cuentaId.isNotEmpty) {
        baseUrl += '?cuentaId=$cuentaId';
      }

      appLog('🌐 URL: $baseUrl');

      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'numeroFactura': numeroFactura,
        'montoTotal': monto,
        'diasVencimiento': diasRestantes,
      };

      appLog('📦 Body JSON que se envía al backend:');
      appLog('   ${json.encode(alertData)}');

      final http.Response response = await _baseApiService.httpClient
          .post(
            Uri.parse(baseUrl),
            headers: headers,
            body: json.encode(alertData),
          )
          .timeout(const Duration(seconds: 30));

      appLog('📥 [ALERTAS API] Response status: ${response.statusCode}');
      appLog('📥 [ALERTAS API] Response body: ${response.body}\n');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        appLog('✅ [ALERTAS API] Alerta PRÓXIMA A VENCER enviada exitosamente\n');
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: 'Alerta de CxP próxima a vencer enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      appLog('❌ [ALERTAS API] Error al enviar alerta\n');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      appLog('💥 [ALERTAS API] Excepción: $e\n');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Envía alerta de cuenta vencida
  Future<ApiResponse<Map<String, dynamic>>> enviarAlertaCxPVencida({
    required String numeroFactura,
    required double montoVencido,
    required int diasVencida,
    String? cuentaId,
  }) async {
    try {
      appLog('\n📡 [ALERTAS API] enviarAlertaCxPVencida()');

      String baseUrl = _baseApiService.buildUrl(
        '/api/cuentas-por-pagar-bot/cuenta-vencida',
      );

      if (cuentaId != null && cuentaId.isNotEmpty) {
        baseUrl += '?cuentaId=$cuentaId';
      }

      appLog('🌐 URL: $baseUrl');

      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'numeroFactura': numeroFactura,
        'montoTotal': montoVencido,
        'diasVencimiento': diasVencida,
      };

      appLog('📦 Body JSON que se envía al backend:');
      appLog('   ${json.encode(alertData)}');

      final http.Response response = await _baseApiService.httpClient
          .post(
            Uri.parse(baseUrl),
            headers: headers,
            body: json.encode(alertData),
          )
          .timeout(const Duration(seconds: 30));

      appLog('📥 [ALERTAS API] Response status: ${response.statusCode}');
      appLog('📥 [ALERTAS API] Response body: ${response.body}\n');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: 'Alerta de CxP vencida enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      appLog('❌ [ALERTAS API] Error al enviar alerta\n');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      appLog('💥 [ALERTAS API] Excepción: $e\n');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Envía alerta de descuento próximo a vencer
  Future<ApiResponse<Map<String, dynamic>>> enviarAlertaDescuentoProximoVencer({
    required String numeroFactura,
    required double montoSinDescuento,
    required double montoConDescuento,
    required double ahorro,
    required int? diasRestantes,
    String? cuentaId,
  }) async {
    try {
      appLog('\n📡 [ALERTAS API] enviarAlertaDescuentoProximoVencer()');

      String baseUrl = _baseApiService.buildUrl(
        '/api/cuentas-por-pagar-bot/descuento-proximo-vencer',
      );

      // Agregar cuentaId como parámetro de query si está disponible
      if (cuentaId != null && cuentaId.isNotEmpty) {
        baseUrl += '?cuentaId=$cuentaId';
      }

      appLog('🌐 URL Final: $baseUrl');

      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'numeroFactura': numeroFactura,
        'montoTotal': montoSinDescuento,
        'porcentajeDescuento': (ahorro / montoSinDescuento * 100)
            .toStringAsFixed(2),
        if (diasRestantes != null) 'diasDescuento': diasRestantes,
      };

      appLog('📦 Body JSON que se envía al backend:');
      appLog('   ${json.encode(alertData)}');
      appLog('   montoSinDescuento: $montoSinDescuento');
      appLog('   montoConDescuento: $montoConDescuento');
      appLog('   ahorro: $ahorro');

      final http.Response response = await _baseApiService.httpClient
          .post(
            Uri.parse(baseUrl),
            headers: headers,
            body: json.encode(alertData),
          )
          .timeout(const Duration(seconds: 30));

      appLog('📨 Respuesta del backend:');
      appLog('   Status: ${response.statusCode}');
      appLog('   Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        appLog(
          '✅ [ALERTAS API] Alerta DESCUENTO EN RIESGO enviada exitosamente\n',
        );
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: 'Alerta de descuento próximo a vencer enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      appLog('❌ [ALERTAS API] Error al enviar alerta\n');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      appLog('💥 [ALERTAS API] Excepción: $e\n');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Envía alerta de descuento perdido
  Future<ApiResponse<Map<String, dynamic>>> enviarAlertaDescuentoPerdido({
    required String proveedor,
    required String numeroFactura,
    required double montoSinDescuento,
    required double ahorroQueSePerdio,
  }) async {
    try {
      final String url = _baseApiService.buildUrl(
        '/api/cuentas-por-pagar-bot/descuento-perdido',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'proveedorNombre': proveedor,
        'numeroFactura': numeroFactura,
        'montoTotal': montoSinDescuento,
        'ahorroQueSePerdio': ahorroQueSePerdio,
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(alertData))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: 'Alerta de descuento perdido enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Envía alerta de abono realizado
  Future<ApiResponse<Map<String, dynamic>>> enviarAlertaAbonoRealizado({
    required String proveedor,
    required String numeroFactura,
    required double montoAbono,
    required double saldoPendiente,
  }) async {
    try {
      final String url = _baseApiService.buildUrl(
        '/api/cuentas-por-pagar-bot/abono-realizado',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'proveedorNombre': proveedor,
        'numeroFactura': numeroFactura,
        'montoAbono': montoAbono,
        'saldoPendiente': saldoPendiente,
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(alertData))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: 'Alerta de abono realizado enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Envía alerta de cuenta pagada completamente
  Future<ApiResponse<Map<String, dynamic>>> enviarAlertaCuentaPagada({
    required String proveedor,
    required String numeroFactura,
    required double montoTotal,
    String? cuentaId,
  }) async {
    try {
      appLog('\n📡 [ALERTAS API] enviarAlertaCuentaPagada()');

      final String url = _baseApiService.buildUrl(
        '/api/cuentas-por-pagar-bot/cuenta-pagada',
      );

      appLog('🌐 URL: $url');

      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> alertData = {
        'proveedorNombre': proveedor,
        'numeroFactura': numeroFactura,
        'montoTotal': montoTotal,
        if (cuentaId != null && cuentaId.isNotEmpty) 'cuentaId': cuentaId,
      };

      appLog('📦 Body JSON que se envía al backend:');
      appLog('   ${json.encode(alertData)}');

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(alertData))
          .timeout(const Duration(seconds: 30));

      appLog('📨 Respuesta del backend:');
      appLog('   Status: ${response.statusCode}');
      appLog('   Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        appLog('✅ [ALERTAS API] Alerta CUENTA PAGADA enviada exitosamente\n');
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: 'Alerta de cuenta pagada enviada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      appLog('❌ [ALERTAS API] Error al enviar alerta\n');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      appLog('💥 [ALERTAS API] Excepción: $e\n');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Prueba de alerta del bot de cuentas por pagar
  Future<ApiResponse<String>> probarAlertaCxP() async {
    try {
      final String url = _baseApiService.buildUrl(
        '/api/cuentas-por-pagar-bot/test',
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
          message: 'Prueba de CxP ejecutada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<String>(
        success: false,
        data: null,
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: errorMessage(e),
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
        message: parseBackendException(response.body, response.statusCode).displayMessage,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }
}
