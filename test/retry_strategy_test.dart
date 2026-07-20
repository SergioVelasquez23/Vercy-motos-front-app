import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/retry_strategy.dart';

const _fast = RetryStrategy(
  maxRetries: 2,
  initialDelay: Duration(milliseconds: 1),
  maxDelay: Duration(milliseconds: 5),
);

void main() {
  group('RetryStrategy.execute', () {
    test('si la operación funciona a la primera, no reintenta', () async {
      var llamadas = 0;

      final resultado = await _fast.execute(
        operation: () async {
          llamadas++;
          return 'ok';
        },
      );

      expect(resultado, 'ok');
      expect(llamadas, 1);
    });

    test('si falla y luego funciona, reintenta hasta lograrlo', () async {
      var llamadas = 0;

      final resultado = await _fast.execute(
        operation: () async {
          llamadas++;
          if (llamadas < 3) throw Exception('falla temporal');
          return 'ok';
        },
      );

      expect(resultado, 'ok');
      expect(llamadas, 3);
    });

    test('agota maxRetries y relanza el último error', () async {
      var llamadas = 0;

      await expectLater(
        _fast.execute(
          operation: () async {
            llamadas++;
            throw Exception('siempre falla');
          },
        ),
        throwsException,
      );

      // maxRetries: 2 -> 1 intento inicial + 2 reintentos = 3 llamadas.
      expect(llamadas, 3);
    });

    test('shouldRetry=false detiene los reintentos en el primer error', () async {
      var llamadas = 0;

      await expectLater(
        _fast.execute(
          operation: () async {
            llamadas++;
            throw Exception('no reintentable');
          },
          shouldRetry: (_) => false,
        ),
        throwsException,
      );

      expect(llamadas, 1);
    });

    test('onRetry se llama con el número de intento en cada reintento', () async {
      var llamadas = 0;
      final intentosNotificados = <int>[];

      await _fast.execute(
        operation: () async {
          llamadas++;
          if (llamadas < 2) throw Exception('falla una vez');
          return 'ok';
        },
        onRetry: (attempt, delay) => intentosNotificados.add(attempt),
      );

      expect(intentosNotificados, [1]);
    });
  });

  group('RetryStrategyFactory.forEnvironment', () {
    test('URLs de render.com usan RenderRetryStrategy', () {
      expect(
        RetryStrategyFactory.forEnvironment('https://api.onrender.com'),
        isA<RenderRetryStrategy>(),
      );
    });

    test('localhost y 127.0.0.1 usan LocalRetryStrategy', () {
      expect(
        RetryStrategyFactory.forEnvironment('http://localhost:8080'),
        isA<LocalRetryStrategy>(),
      );
      expect(
        RetryStrategyFactory.forEnvironment('http://127.0.0.1:8080'),
        isA<LocalRetryStrategy>(),
      );
    });

    test('cualquier otro dominio usa ProductionRetryStrategy', () {
      expect(
        RetryStrategyFactory.forEnvironment('https://api.vercymotos.com'),
        isA<ProductionRetryStrategy>(),
      );
    });
  });
}