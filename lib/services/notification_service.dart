import 'dart:async';
import '../models/pedido.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _pedidoController = StreamController<Pedido>.broadcast();

  Stream<Pedido> get pedidoStream => _pedidoController.stream;

  void notificarCambioPedido(Pedido pedido) {
    // Validar que el pedido tenga datos válidos antes de notificar
    if (pedido.id.isEmpty) {
      print('⚠️ Advertencia: Intentando notificar un pedido sin ID');
      return;
    }

    print('🔔 Notificando cambio de pedido - ID: ${pedido.id}');
    _pedidoController.add(pedido);
  }

  void dispose() {
    _pedidoController.close();
  }
}
