import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/endpoints_config.dart';

/// Servicio para mantener el backend activo con pings automáticos
/// Previene que Render duerma el servicio por inactividad
class KeepAliveService {
  static final KeepAliveService _instance = KeepAliveService._internal();
  factory KeepAliveService() => _instance;
  KeepAliveService._internal();

  Timer? _pingTimer;
  bool _isActive = false;
  final EndpointsConfig _endpointsConfig = EndpointsConfig();

  /// Duración entre pings (10 minutos para estar seguro)
  static const Duration _pingInterval = Duration(minutes: 10);

  /// Inicia el servicio de keep-alive
  void startKeepAlive() {
    if (_isActive) {
      print('🔄 Keep-alive ya está activo');
      return;
    }

    _isActive = true;
    print(
      '🚀 Iniciando keep-alive service - ping cada ${_pingInterval.inMinutes} minutos',
    );

    // Hacer el primer ping inmediatamente
    _sendPing();

    // Configurar timer para pings regulares
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      _sendPing();
    });
  }

  /// Detiene el servicio de keep-alive
  void stopKeepAlive() {
    if (!_isActive) {
      print('⏹️ Keep-alive ya está inactivo');
      return;
    }

    _pingTimer?.cancel();
    _pingTimer = null;
    _isActive = false;
    print('⏹️ Keep-alive service detenido');
  }

  /// Envía un ping al backend para mantenerlo activo
  Future<void> _sendPing() async {
    try {
      final url = '${_endpointsConfig.baseUrl}/api/health';

      print('📡 Enviando ping keep-alive a: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'RestaurantApp-KeepAlive/1.0',
            },
          )
          .timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Ping timeout después de 30 segundos');
            },
          );

      if (response.statusCode == 200 || response.statusCode == 404) {
        // 200 = OK, 404 = endpoint no existe pero servidor responde
        print('✅ Ping exitoso - Backend activo (${response.statusCode})');
      } else {
        print('⚠️ Ping respuesta inesperada: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en ping keep-alive: $e');
      // No hacer nada más - el timer continuará intentando
    }
  }

  /// Verifica si el servicio está activo
  bool get isActive => _isActive;

  /// Obtiene el tiempo hasta el próximo ping
  Duration? get timeToNextPing {
    if (!_isActive || _pingTimer == null) return null;

    // Calcular tiempo aproximado hasta el próximo tick
    return _pingInterval;
  }

  /// Fuerza un ping inmediato (útil para testing)
  Future<void> forcePing() async {
    print('🔧 Forzando ping inmediato...');
    await _sendPing();
  }
}

/// Excepción personalizada para timeouts
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
