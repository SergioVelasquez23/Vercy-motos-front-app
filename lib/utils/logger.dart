import 'package:flutter/foundation.dart';

/// Logger centralizado para la aplicación.
///
/// En modo debug imprime a consola. En release no imprime nada,
/// eliminando el overhead de I/O en producción.
///
/// Uso:
///   import '../utils/logger.dart';
///   appLog('Pedido creado: $id');
///   appLog('Error al cargar', level: LogLevel.error);

enum LogLevel { debug, info, warning, error }

void appLog(String message, {LogLevel level = LogLevel.debug, Object? error}) {
  if (!kDebugMode) return;
  final prefix = switch (level) {
    LogLevel.debug   => '🔍',
    LogLevel.info    => 'ℹ️ ',
    LogLevel.warning => '⚠️ ',
    LogLevel.error   => '🔴',
  };
  debugPrint('$prefix $message');
  if (error != null) debugPrint('   └─ $error');
}
