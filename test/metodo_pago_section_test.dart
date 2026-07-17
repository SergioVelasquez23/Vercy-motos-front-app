import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/facturacion/metodo_pago_section.dart';

final _metodosPago = [
  {'value': 'efectivo', 'label': 'Efectivo', 'icon': Icons.attach_money},
  {'value': 'credito', 'label': 'A Crédito', 'icon': Icons.account_balance_wallet},
  {'value': 'multiple', 'label': 'Múltiple', 'icon': Icons.payments},
];

Widget _wrap({
  required String metodoPago,
  required ValueChanged<String> onMetodoPagoChanged,
  VoidCallback? onMontoChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      // En la pantalla real este widget vive dentro de un scroll — sin eso,
      // el layout de "Pago Múltiple" (varios campos) no entra en el viewport
      // fijo que usa el test harness.
      body: SingleChildScrollView(
        child: MetodoPagoSection(
          metodoPago: metodoPago,
          metodosPago: _metodosPago,
          onMetodoPagoChanged: onMetodoPagoChanged,
          onMontoChanged: onMontoChanged ?? () {},
          montoEfectivoController: TextEditingController(),
          montoTransferenciaController: TextEditingController(),
          montoNequiController: TextEditingController(),
          montoDaviplataController: TextEditingController(),
          montoBancolombiaController: TextEditingController(),
          montoTarjetaController: TextEditingController(),
          montoSistereditoController: TextEditingController(),
          montoBoldController: TextEditingController(),
          montoAddiController: TextEditingController(),
          montoCredilondonController: TextEditingController(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra un chip por cada método de pago', (tester) async {
    await tester.pumpWidget(_wrap(metodoPago: 'efectivo', onMetodoPagoChanged: (_) {}));

    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('A Crédito'), findsOneWidget);
    expect(find.text('Múltiple'), findsOneWidget);
  });

  testWidgets('tocar un chip dispara onMetodoPagoChanged con su value', (tester) async {
    String? cambiadoA;
    await tester.pumpWidget(_wrap(
      metodoPago: 'efectivo',
      onMetodoPagoChanged: (value) => cambiadoA = value,
    ));

    await tester.tap(find.text('A Crédito'));
    await tester.pump();

    expect(cambiadoA, 'credito');
  });

  testWidgets('con metodoPago="credito" muestra la advertencia de deuda automática', (tester) async {
    await tester.pumpWidget(_wrap(metodoPago: 'credito', onMetodoPagoChanged: (_) {}));

    expect(find.textContaining('deuda automáticamente'), findsOneWidget);
  });

  testWidgets('sin metodoPago="credito" no muestra la advertencia', (tester) async {
    await tester.pumpWidget(_wrap(metodoPago: 'efectivo', onMetodoPagoChanged: (_) {}));

    expect(find.textContaining('deuda automáticamente'), findsNothing);
  });

  testWidgets('con metodoPago="multiple" muestra los campos de distribución de pago', (tester) async {
    await tester.pumpWidget(_wrap(metodoPago: 'multiple', onMetodoPagoChanged: (_) {}));

    expect(find.text('Distribución del pago'), findsOneWidget);
    expect(find.text('Efectivo'), findsWidgets); // chip + label del campo
    expect(find.text('Sistecredito'), findsOneWidget);
    expect(find.text('Bold'), findsOneWidget);
    expect(find.text('Addi'), findsOneWidget);
    expect(find.text('Credilondon'), findsOneWidget);
  });

  testWidgets('sin metodoPago="multiple" no muestra los campos de distribución', (tester) async {
    await tester.pumpWidget(_wrap(metodoPago: 'efectivo', onMetodoPagoChanged: (_) {}));

    expect(find.text('Distribución del pago'), findsNothing);
  });

  testWidgets('escribir en el campo Efectivo dispara onMontoChanged', (tester) async {
    var llamadas = 0;
    await tester.pumpWidget(_wrap(
      metodoPago: 'multiple',
      onMetodoPagoChanged: (_) {},
      onMontoChanged: () => llamadas++,
    ));

    await tester.enterText(find.byType(TextField).first, '50000');

    expect(llamadas, greaterThan(0));
  });
}
