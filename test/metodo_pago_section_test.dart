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
  double totalAPagar = 100000,
  String efectivo = '',
  String transferencia = '',
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
          totalAPagar: totalAPagar,
          onMetodoPagoChanged: onMetodoPagoChanged,
          onMontoChanged: onMontoChanged ?? () {},
          montoEfectivoController: TextEditingController(text: efectivo),
          montoTransferenciaController: TextEditingController(text: transferencia),
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

  group('indicador de suma en Pago Múltiple: los montos se ven con separador de miles', () {
    testWidgets('cuando cuadra: "\$100.000 de \$100.000" y no avisa diferencia', (tester) async {
      await tester.pumpWidget(_wrap(
        metodoPago: 'multiple',
        onMetodoPagoChanged: (_) {},
        efectivo: '60000',
        transferencia: '40000',
      ));

      expect(find.text('\$100.000 de \$100.000'), findsOneWidget);
      expect(find.textContaining('Faltan'), findsNothing);
      expect(find.textContaining('Sobran'), findsNothing);
    });

    testWidgets('cuando falta: "Faltan \$40.000"', (tester) async {
      await tester.pumpWidget(_wrap(
        metodoPago: 'multiple',
        onMetodoPagoChanged: (_) {},
        efectivo: '60000',
      ));

      expect(find.text('\$60.000 de \$100.000'), findsOneWidget);
      expect(find.text('Faltan \$40.000'), findsOneWidget);
    });

    testWidgets('cuando sobra: "Sobran \$20.000"', (tester) async {
      await tester.pumpWidget(_wrap(
        metodoPago: 'multiple',
        onMetodoPagoChanged: (_) {},
        efectivo: '120000',
      ));

      expect(find.text('\$120.000 de \$100.000'), findsOneWidget);
      expect(find.text('Sobran \$20.000'), findsOneWidget);
    });

    testWidgets('con millones agrupa de tres en tres: "\$1.000.000 de \$1.500.000"', (tester) async {
      await tester.pumpWidget(_wrap(
        metodoPago: 'multiple',
        onMetodoPagoChanged: (_) {},
        totalAPagar: 1500000,
        efectivo: '1000000',
      ));

      expect(find.text('\$1.000.000 de \$1.500.000'), findsOneWidget);
      expect(find.text('Faltan \$500.000'), findsOneWidget);
    });
  });
}
