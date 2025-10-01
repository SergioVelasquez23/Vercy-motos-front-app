/// ConfiguraciÃ³n global para debug y logging en producciÃ³n
///
/// Para PRODUCCIÃ“N: Cambiar `kDebugMode` a `false`
/// Para DESARROLLO: Mantener `kDebugMode` en `true`

import 'package:flutter/foundation.dart';

class DebugConfig {
  /// Switch principal para activar/desactivar todos los logs de debug
  ///
  /// En PRODUCCIÃ“N: cambiar a `false` para eliminar todos los prints
  /// En DESARROLLO: mantener en `true` para ver logs
  static const bool enableDebugPrints = kDebugMode;

  /// Niveles especÃ­ficos de logging (opcional - para control granular)
  static const bool enableApiLogs = kDebugMode;
  static const bool enableImageLogs = kDebugMode;
  static const bool enablePedidoLogs = kDebugMode;
  static const bool enableMesaLogs = kDebugMode;
  static const bool enablePagoLogs = kDebugMode;

  /// FunciÃ³n helper para prints condicionales
  static void debugPrint(String message) {
    if (enableDebugPrints) {
      // print(message);
    }
  }

  /// FunciÃ³n helper para logs de API
  static void apiLog(String message) {
    if (enableApiLogs) {
      // print('ðŸŒ API: $message');
    }
  }

  /// FunciÃ³n helper para logs de imÃ¡genes
  static void imageLog(String message) {
    if (enableImageLogs) {
      // print('ðŸ–¼ï¸ IMAGE: $message');
    }
  }

  /// FunciÃ³n helper para logs de pedidos
  static void pedidoLog(String message) {
    if (enablePedidoLogs) {
      // print('ðŸ“‹ PEDIDO: $message');
    }
  }

  /// FunciÃ³n helper para logs de mesas
  static void mesaLog(String message) {
    if (enableMesaLogs) {
      // print('ðŸª‘ MESA: $message');
    }
  }

  /// FunciÃ³n helper para logs de pagos
  static void pagoLog(String message) {
    if (enablePagoLogs) {
      // print('ðŸ’° PAGO: $message');
    }
  }
}
