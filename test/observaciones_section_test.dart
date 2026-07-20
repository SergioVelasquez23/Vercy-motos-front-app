import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/facturacion/observaciones_section.dart';

Widget _wrap(TextEditingController controller) {
  return MaterialApp(
    home: Scaffold(
      body: ObservacionesSection(observacionesController: controller),
    ),
  );
}

void main() {
  testWidgets('muestra el título "Observaciones" y el hint del campo', (tester) async {
    await tester.pumpWidget(_wrap(TextEditingController()));

    expect(find.text('Observaciones'), findsOneWidget);
    expect(find.text('Ej: Abonado \$50,000 - Paquete 1, etc...'), findsOneWidget);
  });

  testWidgets('el campo arranca con el texto que ya tenga el controller', (tester) async {
    final controller = TextEditingController(text: 'Cliente pidió factura a nombre de la empresa');
    await tester.pumpWidget(_wrap(controller));

    expect(find.text('Cliente pidió factura a nombre de la empresa'), findsOneWidget);
  });

  testWidgets('escribir en el campo actualiza el controller pasado', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(controller));

    await tester.enterText(find.byType(TextField), 'Abonado \$50.000');

    expect(controller.text, 'Abonado \$50.000');
  });
}