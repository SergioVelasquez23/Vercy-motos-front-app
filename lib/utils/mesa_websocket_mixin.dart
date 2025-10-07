import 'dart:async';
import '../models/mesa.dart';
import '../services/websocket_service.dart';

mixin MesaWebSocketMixin {
  StreamSubscription<WebSocketEventData>? _mesaWebSocketSubscription;

  void setupMesaWebSockets(Function refreshCallback) {
    try {
      final ws = WebSocketService();

      // Enable keep-alive mode to maintain the WebSocket connection
      ws.setKeepAlive(true);

      // Ensure connection
      ws.connect();

      // Subscribe to mesa events with improved sync mechanism
      _mesaWebSocketSubscription = ws.mesaEvents.listen((event) async {
        print('🔄 [WebSocket] Mesa event received: ${event.event}');

        // Add small delay to ensure backend has processed everything
        await Future.delayed(Duration(milliseconds: 300));

        // Refresh mesas
        refreshCallback();
      });
    } catch (e) {
      print('❌ [WebSocket] Error configuring listeners: $e');
    }
  }

  void disposeMesaWebSockets() {
    _mesaWebSocketSubscription?.cancel();
  }
}
