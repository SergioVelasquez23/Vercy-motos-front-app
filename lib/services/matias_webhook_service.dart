import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';
import '../models/matias_webhook_event.dart';
import '../utils/logger.dart';

typedef OnWebhookEvent = void Function(MatiasWebhookEvent event);
typedef OnConnectionStatusChanged = void Function(bool isConnected);

/// Servicio para escuchar eventos de webhooks de Matias a través de WebSocket
///
/// Se conecta al endpoint `/topic/matias-webhooks` del backend y distribuye
/// los eventos recibidos a través de callbacks.
class MatiasWebhookService {
  static const String WEBSOCKET_PATH = '/topic/matias-webhooks';
  static const Duration RECONNECT_DELAY = Duration(seconds: 5);

  /// Interruptor maestro: si es false, [connect] retorna sin intentar conectar
  /// y no se programan reintentos. Útil mientras el backend WS no esté listo.
  // ignore: constant_identifier_names
  static const bool ENABLED = false;

  WebSocketChannel? _channel;
  OnWebhookEvent? _onEvent;
  OnConnectionStatusChanged? _onConnectionStatusChanged;
  bool _isConnected = false;
  bool _isDisposing = false;
  String? _baseUrl;

  bool get isConnected => _isConnected;

  /// Conecta al WebSocket del backend
  ///
  /// [baseUrl]: URL base del backend (ej: "wss://vercy-motos-app.onrender.com" o "ws://localhost:8081")
  /// [onEvent]: Callback para procesar eventos recibidos
  /// [onConnectionStatusChanged]: Callback opcional para cambios de estado de conexión
  Future<void> connect({
    required String baseUrl,
    required OnWebhookEvent onEvent,
    OnConnectionStatusChanged? onConnectionStatusChanged,
  }) async {
    if (!ENABLED) {
      appLog('🔕 WebSocket Matias deshabilitado (MatiasWebhookService.ENABLED = false)');
      _onConnectionStatusChanged = onConnectionStatusChanged;
      _onConnectionStatusChanged?.call(false);
      return;
    }
    if (_isConnected) {
      appLog('⚠️ WebSocket ya está conectado');
      return;
    }

    try {
      _baseUrl = baseUrl;
      _onEvent = onEvent;
      _onConnectionStatusChanged = onConnectionStatusChanged;
      _isDisposing = false;

      // Convertir URL HTTP a WebSocket (ws:// o wss://)
      String wsUrl = baseUrl
          .replaceFirst(RegExp(r'^https://'), 'wss://')
          .replaceFirst(RegExp(r'^http://'), 'ws://');

      wsUrl = '$wsUrl$WEBSOCKET_PATH';

      appLog('🔌 Conectando a WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Esperar a que se establezca la conexión
      await _channel!.ready;
      _isConnected = true;
      _onConnectionStatusChanged?.call(true);

      appLog('✅ WebSocket conectado correctamente');

      // Escuchar mensajes
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) {
          appLog('❌ Error WebSocket: $error');
          _isConnected = false;
          _onConnectionStatusChanged?.call(false);
          if (!_isDisposing) {
            _scheduledReconnect();
          }
        },
        onDone: () {
          appLog('⚠️ WebSocket desconectado');
          _isConnected = false;
          _onConnectionStatusChanged?.call(false);
          if (!_isDisposing) {
            _scheduledReconnect();
          }
        },
      );
    } catch (e) {
      appLog('❌ Error conectando WebSocket: $e');
      _isConnected = false;
      _onConnectionStatusChanged?.call(false);
      if (!_isDisposing) {
        _scheduledReconnect();
      }
    }
  }

  /// Procesa mensajes recibidos del WebSocket
  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);

      appLog('📨 Evento recibido: ${data['event']}');

      // Si el tipo es WEBHOOK_EVENTO, parsear como MatiasWebhookEvent
      if (data['tipo'] == 'WEBHOOK_EVENTO') {
        final event = MatiasWebhookEvent(
          id: data['id'],
          event: data['event'] ?? '',
          timestamp: data['timestamp'] != null
              ? DateTime.tryParse(data['timestamp'])
              : null,
          data: data['data'] != null
              ? WebhookData.fromJson(data['data'])
              : null,
        );

        _onEvent?.call(event);
      }
    } catch (e) {
      appLog('⚠️ Error procesando mensaje WebSocket: $e');
    }
  }

  /// Programa una reconexión automática después de un delay
  Future<void> _scheduledReconnect() async {
    appLog('🔄 Reintentando conexión en ${RECONNECT_DELAY.inSeconds}s...');
    await Future.delayed(RECONNECT_DELAY);
    if (!_isDisposing &&
        !_isConnected &&
        _baseUrl != null &&
        _onEvent != null) {
      await connect(
        baseUrl: _baseUrl!,
        onEvent: _onEvent!,
        onConnectionStatusChanged: _onConnectionStatusChanged,
      );
    }
  }

  /// Desconecta del WebSocket de forma limpia
  Future<void> disconnect() async {
    _isDisposing = true;
    if (_channel != null) {
      try {
        await _channel!.sink.close(status.goingAway);
      } catch (e) {
        appLog('⚠️ Error cerrando WebSocket: $e');
      }
      _isConnected = false;
      _onConnectionStatusChanged?.call(false);
      appLog('🔌 WebSocket desconectado');
    }
  }
}
