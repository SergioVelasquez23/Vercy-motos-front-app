import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../config/api_config.dart';

/// Eventos que puede recibir el WebSocket
enum WebSocketEvent {
  pedidoCreado,
  pedidoPagado,
  pedidoCancelado,
  mesaOcupada,
  mesaLiberada,
  dashboardUpdate,
  inventarioActualizado,
  error,
}

/// Datos del evento WebSocket
class WebSocketEventData {
  final WebSocketEvent event;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  WebSocketEventData({
    required this.event,
    required this.data,
    required this.timestamp,
  });

  factory WebSocketEventData.fromJson(Map<String, dynamic> json) {
    WebSocketEvent event = WebSocketEvent.error;

    // Mapear string del backend a enum
    switch (json['event']?.toString().toLowerCase()) {
      case 'pedido_creado':
        event = WebSocketEvent.pedidoCreado;
        break;
      case 'pedido_pagado':
        event = WebSocketEvent.pedidoPagado;
        break;
      case 'pedido_cancelado':
        event = WebSocketEvent.pedidoCancelado;
        break;
      case 'mesa_ocupada':
        event = WebSocketEvent.mesaOcupada;
        break;
      case 'mesa_liberada':
        event = WebSocketEvent.mesaLiberada;
        break;
      case 'dashboard_update':
        event = WebSocketEvent.dashboardUpdate;
        break;
      case 'inventario_actualizado':
        event = WebSocketEvent.inventarioActualizado;
        break;
      default:
        event = WebSocketEvent.error;
    }

    return WebSocketEventData(
      event: event,
      data: json['data'] ?? {},
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<WebSocketEventData>? _eventController;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _heartbeatInterval = Duration(
    seconds: 60,
  ); // Reducido para menos tráfico
  static const Duration _reconnectDelay = Duration(seconds: 5);

  /// Stream público para escuchar eventos
  Stream<WebSocketEventData> get events {
    _eventController ??= StreamController<WebSocketEventData>.broadcast();
    return _eventController!.stream;
  }

  /// Estado de la conexión
  bool get isConnected => _isConnected;

  /// Conectar al WebSocket del servidor
  Future<void> connect() async {
    if (_isConnected || _isReconnecting) {
      // ✅ COMENTADO: Log de WebSocket ya conectado removido
      // print('INFO: WebSocket: Ya conectado o reconectando');
      return;
    }

    // TODO: Implementar WebSocket STOMP correctamente
    // ✅ OPTIMIZACIÓN: Log comentado para mejorar rendimiento
    // print('⚠️ WebSocket: Deshabilitado temporalmente - usando polling');
    return;

    try {
      print('INFO: WebSocket: Intentando conectar...');

      // Obtener la URL base y convertirla a WebSocket
      final baseUrl = ApiConfig.instance.baseUrl;
      final wsUrl = baseUrl
          .replaceAll('http://', 'ws://')
          .replaceAll('https://', 'wss://');
      final fullWsUrl =
          '$wsUrl/ws-native'; // Endpoint WebSocket nativo del backend

      print('🔗 WebSocket URL: $fullWsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(fullWsUrl));

      // Configurar el stream de eventos
      _eventController ??= StreamController<WebSocketEventData>.broadcast();

      // Escuchar mensajes del WebSocket
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
      );

      // Configurar heartbeat para mantener la conexión viva
      _setupHeartbeat();

      _isConnected = true;
      _isReconnecting = false;
      _reconnectAttempts = 0;

      print('✅ WebSocket: Conectado exitosamente');

      // Enviar mensaje de registro al servidor
      _sendMessage({
        'type': 'register',
        'client': 'dashboard',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ WebSocket: Error de conexión: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  /// Desconectar del WebSocket
  Future<void> disconnect() async {
    // No desconectar si la aplicación está en la pantalla de mesas
    // Esto es para mantener la conexión viva incluso cuando el usuario cambia de pantalla
    if (_keepAlive) {
      print('INFO: WebSocket: Desconexión ignorada - modo keep-alive activo');
      return;
    }

    print('INFO: WebSocket: Desconectando...');

    _isConnected = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    await _channel?.sink.close(status.normalClosure);
    _channel = null;

    print('✅ WebSocket: Desconectado');
  }

  // Variable para mantener activa la conexión
  bool _keepAlive = false;

  /// Establece el modo keep-alive para evitar desconexiones
  void setKeepAlive(bool keepAlive) {
    _keepAlive = keepAlive;
    if (keepAlive && !_isConnected) {
      connect(); // Reconectar si se activa keep-alive y no hay conexión
    }
  }

  /// Enviar mensaje al servidor
  void _sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      try {
        final jsonMessage = json.encode(message);
        _channel!.sink.add(jsonMessage);
        print('📤 WebSocket: Mensaje enviado: $jsonMessage');
      } catch (e) {
        print('❌ WebSocket: Error enviando mensaje: $e');
      }
    }
  }

  /// Manejar mensajes recibidos
  void _onMessage(dynamic message) {
    try {
      print('📥 WebSocket: Mensaje recibido: $message');

      final Map<String, dynamic> data = json.decode(message);

      // Ignorar respuestas del heartbeat
      if (data['type'] == 'pong') {
        print('💗 WebSocket: Heartbeat OK');
        return;
      }

      // Procesar eventos del dashboard
      final eventData = WebSocketEventData.fromJson(data);
      _eventController?.add(eventData);
    } catch (e) {
      print('❌ WebSocket: Error procesando mensaje: $e');
    }
  }

  /// Manejar errores de conexión
  void _onError(error) {
    print('❌ WebSocket: Error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  /// Manejar desconexión
  void _onDisconnected() {
    print('INFO: WebSocket: Conexión cerrada');
    _isConnected = false;
    _heartbeatTimer?.cancel();

    if (!_isReconnecting) {
      _scheduleReconnect();
    }
  }

  /// Configurar heartbeat para mantener la conexión
  void _setupHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected) {
        _sendMessage({
          'type': 'ping',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// Programar reconexión automática
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ WebSocket: Máximo número de reintentos alcanzado');
      return;
    }

    if (_isReconnecting) {
      print('🔄 WebSocket: Ya hay una reconexión en progreso');
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;

    print(
      '🔄 WebSocket: Programando reconexión (intento $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  /// Limpiar recursos
  void dispose() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _eventController?.close();
    disconnect();
  }
}

/// Extensión de utilidades para el servicio WebSocket
extension WebSocketServiceUtils on WebSocketService {
  /// Stream específico para eventos del dashboard
  Stream<WebSocketEventData> get dashboardEvents {
    return events.where(
      (event) =>
          event.event == WebSocketEvent.dashboardUpdate ||
          event.event == WebSocketEvent.pedidoPagado ||
          event.event == WebSocketEvent.pedidoCreado ||
          event.event == WebSocketEvent.pedidoCancelado,
    );
  }

  /// Stream específico para eventos de mesas
  Stream<WebSocketEventData> get mesaEvents {
    return events.where(
      (event) =>
          event.event == WebSocketEvent.mesaOcupada ||
          event.event == WebSocketEvent.mesaLiberada ||
          event.event == WebSocketEvent.pedidoCreado ||
          event.event == WebSocketEvent.pedidoPagado ||
          event.event == WebSocketEvent.pedidoCancelado,
    );
  }

  /// Stream específico para eventos de inventario
  Stream<WebSocketEventData> get inventarioEvents {
    return events.where(
      (event) => event.event == WebSocketEvent.inventarioActualizado,
    );
  }

  /// Reconectar manualmente
  Future<void> reconnect() async {
    await disconnect();
    await Future.delayed(Duration(seconds: 1));
    await connect();
  }

  /// Resetear contador de reconexiones
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }
}
