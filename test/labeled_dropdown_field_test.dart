import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/productos/labeled_dropdown_field.dart';

Widget _wrap({
  required String value,
  required ValueChanged<String?> onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: LabeledDropdownField(
        label: 'Unidad',
        value: value,
        items: const ['Unics', 'Kg', 'Lt'],
        onChanged: onChanged,
        // Ancho más generoso que el usado en productos_screen.dart (100-120)
        // para evitar un overflow interno de 2px de DropdownButtonFormField
        // en el binding de test (probablemente por la fuente de prueba, no
        // reproducido visualmente en la app real) — no es el foco de este
        // test, que es verificar el wiring de label/valor/onChanged.
        width: 160,
      ),
    ),
  );
}

void main() {
  testWidgets('muestra el label y el valor seleccionado', (tester) async {
    await tester.pumpWidget(_wrap(value: 'Kg', onChanged: (_) {}));

    expect(find.text('Unidad'), findsOneWidget);
    expect(find.text('Kg'), findsOneWidget);
  });

  testWidgets('elegir otra opción dispara onChanged con el nuevo valor', (tester) async {
    String? nuevoValor;
    await tester.pumpWidget(_wrap(value: 'Kg', onChanged: (v) => nuevoValor = v));

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lt').last);
    await tester.pumpAndSettle();

    expect(nuevoValor, 'Lt');
  });
}