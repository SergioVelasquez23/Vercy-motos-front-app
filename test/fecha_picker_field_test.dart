import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/facturacion/fecha_picker_field.dart';

void main() {
  testWidgets('muestra la fecha en formato yyyy-MM-dd', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FechaPickerField(
          fecha: DateTime(2026, 7, 16),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          onFechaSeleccionada: (_) {},
        ),
      ),
    ));

    expect(find.text('2026-07-16'), findsOneWidget);
  });

  testWidgets('tocar el campo abre el selector de fecha', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FechaPickerField(
          fecha: DateTime(2026, 7, 16),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          onFechaSeleccionada: (_) {},
        ),
      ),
    ));

    await tester.tap(find.text('2026-07-16'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
