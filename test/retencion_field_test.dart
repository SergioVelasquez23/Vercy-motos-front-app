import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/compras/retencion_field.dart';

Widget _wrap({required TextEditingController controller, VoidCallback? onChanged}) {
  return MaterialApp(
    home: Scaffold(
      body: RetencionField(
        label: 'Retención',
        controller: controller,
        onChanged: onChanged ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('muestra el label y el valor inicial del controller', (tester) async {
    await tester.pumpWidget(_wrap(controller: TextEditingController(text: '5')));

    expect(find.text('Retención'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('escribir en el campo actualiza el controller y dispara onChanged', (tester) async {
    var llamadas = 0;
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(controller: controller, onChanged: () => llamadas++));

    await tester.enterText(find.byType(TextField), '10');

    expect(controller.text, '10');
    expect(llamadas, greaterThan(0));
  });
}