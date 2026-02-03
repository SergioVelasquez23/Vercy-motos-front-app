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
    this.maxRetries = 2, // ⚡ OPTIMIZADO: Reducido de 3 a 2 reintentos
    this.initialDelay = const Duration(
      milliseconds: 500,
    ), // ⚡ OPTIMIZADO: Reducido de 1s a 500ms
    this.maxDelay = const Duration(
      seconds: 15,
    ), // ⚡ OPTIMIZADO: Reducido de 30s a 15s
    this.exponentialBase =
        1.5, // ⚡ OPTIMIZADO: Reducido de 2.0 a 1.5 para delays menores
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
        

      try {
        if (timeoutPerAttempt != null) {
          // ⚡ OPTIMIZADO: Timeouts más cortos para evitar esperas largas
          if (attempt == 1) {
            currentTimeout =
                timeoutPerAttempt; // Usar timeout base para primer intento
          } else {
            // Aumentar timeout moderadamente con cada intento
            currentTimeout = Duration(
              milliseconds:
                  (timeoutPerAttempt.inMilliseconds *
                          pow(exponentialBase, attempt - 1))
                      .toInt(),
            );
            // ⚡ OPTIMIZADO: Máximo de 60 segundos por intento
            if (currentTimeout > Duration(seconds: 60)) {
              currentTimeout = Duration(seconds: 60);
            }
          }
        }

        return await operation().timeout(currentTimeout);
      } catch (error) {
          

        // Si es el último intento, lanzar el error
        if (attempt > maxRetries) {
            
          rethrow;
        }

        // Verificar si deberíamos reintentar este error específico
        if (shouldRetry != null && !shouldRetry(error)) {
            
          rethrow;
        }

        // Calcular delay con backoff exponencial y jitter
        currentDelay = _calculateDelay(attempt);

        if (onRetry != null) {
          onRetry(attempt, currentDelay);
        }

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

/// Para Render.com (⚡ OPTIMIZADO para velocidad)
class RenderRetryStrategy extends RetryStrategy {
  RenderRetryStrategy()
    : super(
        maxRetries: 2, // ⚡ OPTIMIZADO: Reducido de 4 a 2 intentos
        initialDelay: const Duration(seconds: 2), // ⚡ OPTIMIZADO: Reducido de 5s a 2s
        maxDelay: const Duration(seconds: 20), // ⚡ OPTIMIZADO: Reducido de 60s a 20s
        exponentialBase: 1.5,
        jitter: 0.2,
      );
}

/// Para servidores normales en producción
class ProductionRetryStrategy extends RetryStrategy {
  ProductionRetryStrategy()
    : super(
        maxRetries: 2, // ⚡ OPTIMIZADO: Reducido de 3 a 2 intentos
        initialDelay: const Duration(
          seconds: 1,
        ), // ⚡ OPTIMIZADO: Reducido de 2s a 1s
        maxDelay: const Duration(
          seconds: 15,
        ), // ⚡ OPTIMIZADO: Reducido de 30s a 15s
        exponentialBase: 1.5, // ⚡ OPTIMIZADO: Reducido de 2.0 a 1.5
        jitter: 0.15,
      );
}

/// Para desarrollo local (rápido, pocos reintentos)
class LocalRetryStrategy extends RetryStrategy {
  LocalRetryStrategy()
    : super(
        maxRetries: 1, // ⚡ OPTIMIZADO: Reducido de 2 a 1 intento
        initialDelay: const Duration(
          milliseconds: 300,
        ), // ⚡ OPTIMIZADO: Reducido de 500ms a 300ms
        maxDelay: const Duration(
          seconds: 3,
        ), // ⚡ OPTIMIZADO: Reducido de 5s a 3s
        exponentialBase: 1.5, // ⚡ OPTIMIZADO: Reducido de 2.0 a 1.5
        jitter: 0.1,
      );
}

/// Factory para obtener la estrategia apropiada según el entorno
class RetryStrategyFactory {
  static RetryStrategy forEnvironment(String baseUrl) {
    if (baseUrl.contains('render.com')) {
      return RenderRetryStrategy();
    } else if (baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1')) {
      return LocalRetryStrategy();
    } else {
      return ProductionRetryStrategy();
    }
  }
}
