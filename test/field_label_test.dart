import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/compras/field_label.dart';

void main() {
  testWidgets('muestra el texto del label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Row(children: [FieldLabel('Cantidad')])),
    ));

    expect(find.text('Cantidad'), findsOneWidget);
  });

  testWidgets('se envuelve en Expanded con el flex indicado', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Row(children: [FieldLabel('Nombre', flex: 3)])),
    ));

    final expanded = tester.widget<Expanded>(find.byType(Expanded));
    expect(expanded.flex, 3);
  });

  testWidgets('flex por defecto es 1', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Row(children: [FieldLabel('Código')])),
    ));

    final expanded = tester.widget<Expanded>(find.byType(Expanded));
    expect(expanded.flex, 1);
  });
}