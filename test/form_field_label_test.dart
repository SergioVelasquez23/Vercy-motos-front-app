import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/facturacion/form_field_label.dart';

void main() {
  testWidgets('muestra la etiqueta y el campo que se le pasa', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FormFieldLabel(label: 'Cliente', field: Text('campo-de-prueba')),
      ),
    ));

    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('campo-de-prueba'), findsOneWidget);
  });
}
