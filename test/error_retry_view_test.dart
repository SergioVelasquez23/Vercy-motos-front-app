import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/common/error_retry_view.dart';

void main() {
  testWidgets('muestra título y mensaje, y Reintentar llama a onRetry', (tester) async {
    var reintentos = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorRetryView(
          title: 'Error al cargar cuentas',
          message: 'Sin conexión con el servidor',
          onRetry: () => reintentos++,
        ),
      ),
    ));

    expect(find.text('Error al cargar cuentas'), findsOneWidget);
    expect(find.text('Sin conexión con el servidor'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    expect(reintentos, 1);
  });

  testWidgets('sin mensaje muestra "Error desconocido"', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ErrorRetryView(title: 'Falló', onRetry: () {})),
    ));
    expect(find.text('Error desconocido'), findsOneWidget);
  });

  testWidgets('cabe en una pantalla pequeña sin desbordar', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorRetryView(title: 'Error al cargar datos', message: 'x ' * 200, onRetry: () {}),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
