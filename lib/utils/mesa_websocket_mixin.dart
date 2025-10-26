import 'dart:async';
import '../models/mesa.dart';
import '../services/websocket_service.dart';

mixin MesaWebSocketMixin {
  StreamSubscription<WebSocketEventData>? _mesaWebSocketSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);

  void setupMesaWebSockets(Function refreshCallback) {
    try {
      final ws = WebSocketService();

      // Enable keep-alive mode to maintain the WebSocket connection
      ws.setKeepAlive(true);

      // Ensure connection
      ws.connect();

      // Subscribe to mesa events with improved sync mechanism
      _mesaWebSocketSubscription = ws.mesaEvents.listen(
        (event) async {
          print('🔄 [WebSocket] Mesa event received: ${event.event}');

          // Reset reconnect attempts on successful event
          _reconnectAttempts = 0;

          // Add small delay to ensure backend has processed everything
          await Future.delayed(Duration(milliseconds: 500));

          // Refresh mesas
          refreshCallback();
        },
        onError: (error) {
          print('❌ [WebSocket] Error in mesa events stream: $error');
          _attemptReconnection(refreshCallback);
        },
        onDone: () {
          print('⚠️ [WebSocket] Mesa events stream closed');
          _attemptReconnection(refreshCallback);
        },
      );
    } catch (e) {
      print('❌ [WebSocket] Error configuring listeners: $e');
      _attemptReconnection(refreshCallback);
    }
  }

  void _attemptReconnection(Function refreshCallback) {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      print(
        '🔄 [WebSocket] Attempting reconnection ${_reconnectAttempts}/${_maxReconnectAttempts}...',
      );

      _reconnectTimer = Timer(_reconnectDelay, () {
        setupMesaWebSockets(refreshCallback);
      });
    } else {
      print(
        '❌ [WebSocket] Max reconnection attempts reached. Manual reconnection required.',
      );
    }
  }

  void disposeMesaWebSockets() {
    _mesaWebSocketSubscription?.cancel();
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
  }
}
