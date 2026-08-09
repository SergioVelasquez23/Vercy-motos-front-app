import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../utils/logger.dart';

typedef OnTrasladoEvent = void Function(Map<String, dynamic> data);
typedef OnConnectionStatusChanged = void Function(bool isConnected);

/// Cliente WebSocket para el aviso instantáneo de traslados nuevos.
///
/// A diferencia de MatiasWebhookService (que intenta conectar directo a una
/// ruta de tipo STOMP topic y por eso nunca llegó a funcionar — está
/// deshabilitado con ENABLED=false), este se conecta a un endpoint WebSocket
/// plano dedicado (`/rt/traslados`, ver TrasladoWebSocketHandler en el
/// backend), sin protocolo STOMP de por medio.
class TrasladoWebSocketService {
  // No puede empezar con "/ws/" — el backend ya registra un endpoint
  // STOMP/SockJS en "/ws" que reclama el patrón comodín "/ws/**" para sus
  // propias sub-rutas, así que cualquier endpoint plano bajo "/ws/algo" queda
  // atrapado por ese handler y nunca llega al de traslados (404 en el
  // handshake, confirmado con curl). Por eso el backend expone este canal
  // bajo "/rt" en su lugar.
  static const String _websocketPath = '/rt/traslados';
  static const Duration _reconnectDelayBase = Duration(seconds: 5);
  static const Duration _reconnectDelayMax = Duration(minutes: 2);
  // Renovación preventiva de la conexión: en algunos escenarios (pestaña
  // suspendida y reanudada, proxy/red que cierra el socket sin mandar un
  // frame de cierre) ni onError ni onDone llegan a dispararse nunca, y
  // _isConnected se queda pegado en true con un socket zombie que ya no
  // recibe nada — sin esto, la app nunca vuelve a intentar reconectar por su
  // cuenta y el usuario deja de recibir cambios en tiempo real hasta que
  // recarga a mano. Al forzar un ciclo de reconexión cada cierto tiempo, el
  // peor caso de "conectado pero sordo" queda acotado a este intervalo.
  static const Duration _watchdogInterval = Duration(minutes: 3);

  WebSocketChannel? _channel;
  OnTrasladoEvent? _onEvent;
  OnConnectionStatusChanged? _onConnectionStatusChanged;
  bool _isConnected = false;
  bool _isDisposing = false;
  String? _baseUrl;
  Timer? _watchdogTimer;
  // Backoff exponencial: si el endpoint no está disponible (backend caído,
  // ruta no desplegada, etc.) evita machacar la consola y la red con un
  // intento cada 5s indefinidamente — el intervalo se duplica en cada fallo
  // hasta un tope, y se resetea apenas conecta bien una vez.
  int _intentosFallidos = 0;

  bool get isConnected => _isConnected;

  Future<void> connect({
    required String baseUrl,
    required OnTrasladoEvent onEvent,
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

      appLog('🔌 [TrasladoWS] Conectando a $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;
      _isConnected = true;
      _intentosFallidos = 0;
      _onConnectionStatusChanged?.call(true);
      _iniciarWatchdog();
      appLog('✅ [TrasladoWS] Conectado');

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          appLog('❌ [TrasladoWS] Error: $error');
          _isConnected = false;
          _watchdogTimer?.cancel();
          _onConnectionStatusChanged?.call(false);
          if (!_isDisposing) _scheduledReconnect();
        },
        onDone: () {
          appLog('⚠️ [TrasladoWS] Desconectado');
          _isConnected = false;
          _watchdogTimer?.cancel();
          _onConnectionStatusChanged?.call(false);
          if (!_isDisposing) _scheduledReconnect();
        },
      );
    } catch (e) {
      appLog('❌ [TrasladoWS] Error conectando: $e');
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
      appLog('⚠️ [TrasladoWS] Error procesando mensaje: $e');
    }
  }

  void _iniciarWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) => _forzarReconexion());
  }

  Future<void> _forzarReconexion() async {
    if (_isDisposing || _baseUrl == null || _onEvent == null) return;
    appLog('🔄 [TrasladoWS] Watchdog: renovando conexión preventivamente');
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
    // Duplica el delay en cada fallo consecutivo (5s, 10s, 20s, 40s...) hasta
    // el tope de 2 min, en vez de reintentar cada 5s para siempre cuando el
    // endpoint simplemente no está disponible.
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
        appLog('⚠️ [TrasladoWS] Error cerrando: $e');
      }
      _isConnected = false;
      _onConnectionStatusChanged?.call(false);
    }
  }
}
