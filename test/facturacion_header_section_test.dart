import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/facturacion/facturacion_header_section.dart';

Widget _wrap({required VoidCallback onMostrarBorradores, double width = 800}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: FacturacionHeaderSection(onMostrarBorradores: onMostrarBorradores),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra el título "Crear factura" y el botón de borradores', (tester) async {
    await tester.pumpWidget(_wrap(onMostrarBorradores: () {}));

    expect(find.text('Crear factura'), findsOneWidget);
    expect(find.text('Facturas en borrador'), findsOneWidget);
  });

  testWidgets('tocar el botón de borradores dispara onMostrarBorradores', (tester) async {
    var llamado = false;
    await tester.pumpWidget(_wrap(onMostrarBorradores: () => llamado = true));

    await tester.tap(find.text('Facturas en borrador'));
    await tester.pump();

    expect(llamado, isTrue);
  });

  testWidgets('en un ancho angosto (mobile) también muestra título y botón', (tester) async {
    await tester.pumpWidget(_wrap(onMostrarBorradores: () {}, width: 320));

    expect(find.text('Crear factura'), findsOneWidget);
    expect(find.text('Facturas en borrador'), findsOneWidget);
  });

  testWidgets('en un ancho angosto (mobile), tocar el botón también dispara el callback', (tester) async {
    var llamado = false;
    await tester.pumpWidget(_wrap(onMostrarBorradores: () => llamado = true, width: 320));

    await tester.tap(find.text('Facturas en borrador'));
    await tester.pump();

    expect(llamado, isTrue);
  });
}