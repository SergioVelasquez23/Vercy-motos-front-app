import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../utils/logger.dart';

typedef OnCajaEvent = void Function(Map<String, dynamic> data);
typedef OnConnectionStatusChanged = void Function(bool isConnected);

/// Cliente WebSocket para el aviso instantáneo de cambios en caja: gastos
/// creados/editados/borrados (ver GastoService en el backend). Mismo
/// mecanismo que TrasladoWebSocketService (copiado a propósito en vez de
/// generalizarlo en una base común, para no arriesgar esa conexión que ya
/// está probada en producción) — se conecta a un endpoint WebSocket plano
/// dedicado (`/rt/caja`, ver CajaWebSocketHandler en el backend), sin
/// protocolo STOMP de por medio.
///
/// Para datos financieros, un total vencido es peor que no cachear nada: este
/// canal es lo que permite que GastoService cachee la lista de gastos de un
/// cuadre sin arriesgarse a mostrar un total viejo si otro dispositivo/cajero
/// agrega un gasto mientras tanto.
class CajaWebSocketService {
  static const String _websocketPath = '/rt/caja';
  static const Duration _reconnectDelayBase = Duration(seconds: 5);
  static const Duration _reconnectDelayMax = Duration(minutes: 2);
  // Mismo motivo que TrasladoWebSocketService: sin esto, un socket "zombie"
  // (conectado pero sordo — pestaña suspendida y reanudada, proxy que cierra
  // sin frame de cierre) puede quedar así indefinidamente sin que onError/
  // onDone se disparen nunca.
  static const Duration _watchdogInterval = Duration(minutes: 3);

  WebSocketChannel? _channel;
  OnCajaEvent? _onEvent;
  OnConnectionStatusChanged? _onConnectionStatusChanged;
  bool _isConnected = false;
  bool _isDisposing = false;
  String? _baseUrl;
  Timer? _watchdogTimer;
  int _intentosFallidos = 0;

  bool get isConnected => _isConnected;

  Future<void> connect({
    required String baseUrl,
    required OnCajaEvent onEvent,
    OnConnectionStatusChanged? onConnectionStatusChanged,
  }) async {
    if (_isConnected) return;

    try {
      _baseUrl = baseUrl;
      _onEvent = onEvent;
      _onConnectionStatusChanged = onConnectionStatusChanged;
      _isDisposing = false;

      String wsUrl = baseUrl
          .replaceFirst(RegExp(r'^https://'), 'wss://')
          .replaceFirst(RegExp(r'^http://'), 'ws://');
      wsUrl = '$wsUrl$_websocketPath';

      appLog('🔌 [CajaWS] Conectando a $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;
      _isConnected = true;
      _intentosFallidos = 0;
      _onConnectionStatusChanged?.call(true);
      _iniciarWatchdog();
      appLog('✅ [CajaWS] Conectado');

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          appLog('❌ [CajaWS] Error: $error');
          _isConnected = false;
          _watchdogTimer?.cancel();
          _onConnectionStatusChanged?.call(false);
          if (!_isDisposing) _scheduledReconnect();
        },
        onDone: () {
          appLog('⚠️ [CajaWS] Desconectado');
          _isConnected = false;
          _watchdogTimer?.cancel();
          _onConnectionStatusChanged?.call(false);
          if (!_isDisposing) _scheduledReconnect();
        },
      );
    } catch (e) {
      appLog('❌ [CajaWS] Error conectando: $e');
      _isConnected = false;
      _watchdogTimer?.cancel();
      _onConnectionStatusChanged?.call(false);
      if (!_isDisposing) _scheduledReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = jsonDecode(message as String);
      _onEvent?.call(data);
    } catch (e) {
      appLog('⚠️ [CajaWS] Error procesando mensaje: $e');
    }
  }

  void _iniciarWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) => _forzarReconexion());
  }

  Future<void> _forzarReconexion() async {
    if (_isDisposing || _baseUrl == null || _onEvent == null) return;
    appLog('🔄 [CajaWS] Watchdog: renovando conexión preventivamente');
    try {
      await _channel?.sink.close(status.goingAway);
    } catch (e) {
      // Ignorado: si el socket ya estaba muerto, cerrar solo confirma lo que
      // el watchdog sospechaba.
    }
    _isConnected = false;
    await connect(
      baseUrl: _baseUrl!,
      onEvent: _onEvent!,
      onConnectionStatusChanged: _onConnectionStatusChanged,
    );
  }

  Future<void> _scheduledReconnect() async {
    _intentosFallidos++;
    final backoff = _reconnectDelayBase * (1 << (_intentosFallidos - 1).clamp(0, 10));
    final delay = backoff > _reconnectDelayMax ? _reconnectDelayMax : backoff;

    await Future.delayed(delay);
    if (!_isDisposing && !_isConnected && _baseUrl != null && _onEvent != null) {
      await connect(
        baseUrl: _baseUrl!,
        onEvent: _onEvent!,
        onConnectionStatusChanged: _onConnectionStatusChanged,
      );
    }
  }

  Future<void> disconnect() async {
    _isDisposing = true;
    _intentosFallidos = 0;
    _watchdogTimer?.cancel();
    if (_channel != null) {
      try {
        await _channel!.sink.close(status.goingAway);
      } catch (e) {
        appLog('⚠️ [CajaWS] Error cerrando: $e');
      }
      _isConnected = false;
      _onConnectionStatusChanged?.call(false);
    }
  }
}
