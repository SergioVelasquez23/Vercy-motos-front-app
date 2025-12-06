import 'dart:async';
import 'dart:math';

/// Estrategia de reintentos inteligente con backoff exponencial
/// Útil para manejar endpoints lentos o timeouts
class RetryStrategy {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double exponentialBase;
  final double jitter;

  const RetryStrategy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.exponentialBase = 2.0,
    this.jitter = 0.1,
  });

  /// Ejecuta una función con reintentos automáticos
  /// [operation]: La función a ejecutar
  /// [timeoutPerAttempt]: Timeout por cada intento (opcional, aumenta con cada reintento)
  /// [shouldRetry]: Función para determinar si un error específico debe reintentar
  Future<T> execute<T>({
    required Future<T> Function() operation,
    Duration? timeoutPerAttempt,
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;
    Duration currentTimeout = timeoutPerAttempt ?? const Duration(seconds: 180);

    while (true) {
      attempt++;
      print('🔄 Intento $attempt de ${maxRetries + 1}');

      try {
        if (timeoutPerAttempt != null) {
          // Aumentar timeout con cada intento
          // Para el primer intento, usar un timeout más generoso
          if (attempt == 1) {
            currentTimeout = Duration(
              seconds: 300,
            ); // 5 minutos para primer intento
          } else {
            currentTimeout = Duration(
              milliseconds:
                  (timeoutPerAttempt.inMilliseconds *
                          pow(exponentialBase, attempt - 1))
                      .toInt(),
            );
            if (currentTimeout > maxDelay * 10) {
              currentTimeout = maxDelay * 10; // Máximo 10 minutos
            }
          }
          print('⏱️ Timeout para este intento: ${currentTimeout.inSeconds}s');
        }

        return await operation().timeout(currentTimeout);
      } catch (error) {
        print('❌ Error en intento $attempt: $error');

        // Si es el último intento, lanzar el error
        if (attempt > maxRetries) {
          print('🚫 Máximo de reintentos alcanzado');
          rethrow;
        }

        // Verificar si deberíamos reintentar este error específico
        if (shouldRetry != null && !shouldRetry(error)) {
          print('🚫 Error no recuperable, no se reintenta');
          rethrow;
        }

        // Calcular delay con backoff exponencial y jitter
        currentDelay = _calculateDelay(attempt);

        if (onRetry != null) {
          onRetry(attempt, currentDelay);
        }

        print(
          '⏳ Esperando ${currentDelay.inSeconds}s antes del siguiente intento...',
        );
        await Future.delayed(currentDelay);
      }
    }
  }

  /// Calcula el delay con backoff exponencial y jitter aleatorio
  Duration _calculateDelay(int attempt) {
    // Backoff exponencial: initialDelay * base^(attempt-1)
    final exponentialDelay =
        initialDelay.inMilliseconds * pow(exponentialBase, attempt - 1);

    // Aplicar jitter aleatorio (±10% por defecto)
    final random = Random();
    final jitterAmount =
        exponentialDelay * jitter * (random.nextDouble() * 2 - 1);
    final delayWithJitter = exponentialDelay + jitterAmount;

    // No exceder maxDelay
    final finalDelay = min(delayWithJitter, maxDelay.inMilliseconds.toDouble());

    return Duration(milliseconds: finalDelay.toInt());
  }
}

/// Estrategias predefinidas para diferentes escenarios

/// Para Render.com (muy lento, requiere paciencia)
class RenderRetryStrategy extends RetryStrategy {
  RenderRetryStrategy()
    : super(
        maxRetries: 4, // 5 intentos totales
        initialDelay: const Duration(seconds: 5),
        maxDelay: const Duration(seconds: 60),
        exponentialBase: 1.5,
        jitter: 0.2,
      );
}

/// Para servidores normales en producción
class ProductionRetryStrategy extends RetryStrategy {
  ProductionRetryStrategy()
    : super(
        maxRetries: 3, // 4 intentos totales
        initialDelay: const Duration(seconds: 2),
        maxDelay: const Duration(seconds: 30),
        exponentialBase: 2.0,
        jitter: 0.15,
      );
}

/// Para desarrollo local (rápido, pocos reintentos)
class LocalRetryStrategy extends RetryStrategy {
  LocalRetryStrategy()
    : super(
        maxRetries: 2, // 3 intentos totales
        initialDelay: const Duration(milliseconds: 500),
        maxDelay: const Duration(seconds: 5),
        exponentialBase: 2.0,
        jitter: 0.1,
      );
}

/// Factory para obtener la estrategia apropiada según el entorno
class RetryStrategyFactory {
  static RetryStrategy forEnvironment(String baseUrl) {
    if (baseUrl.contains('render.com')) {
      print('🔄 Usando RenderRetryStrategy (optimizada para Render.com)');
      return RenderRetryStrategy();
    } else if (baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1')) {
      print('🔄 Usando LocalRetryStrategy (optimizada para desarrollo local)');
      return LocalRetryStrategy();
    } else {
      print('🔄 Usando ProductionRetryStrategy (optimizada para producción)');
      return ProductionRetryStrategy();
    }
  }
}
