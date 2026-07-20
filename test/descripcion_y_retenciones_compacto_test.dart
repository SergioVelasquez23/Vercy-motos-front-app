import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/compras/descripcion_y_retenciones_compacto.dart';

Widget _wrap({VoidCallback? onRetencionChanged}) {
  return MaterialApp(
    home: Scaffold(
      body: DescripcionYRetencionesCompacto(
        descripcionController: TextEditingController(),
        porcentajeRetencionController: TextEditingController(text: '1'),
        porcentajeReteIvaController: TextEditingController(text: '2'),
        porcentajeReteIcaController: TextEditingController(text: '3'),
        onRetencionChanged: onRetencionChanged ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('muestra el título de descripción y los 3 campos de retención con su valor', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Descripción'), findsOneWidget);
    expect(find.text('Retención'), findsOneWidget);
    expect(find.text('Reteiva'), findsOneWidget);
    expect(find.text('Reteica'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('escribir en el campo de descripción actualiza su controller (independiente de las retenciones)', (tester) async {
    final descripcionController = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DescripcionYRetencionesCompacto(
          descripcionController: descripcionController,
          porcentajeRetencionController: TextEditingController(),
          porcentajeReteIvaController: TextEditingController(),
          porcentajeReteIcaController: TextEditingController(),
          onRetencionChanged: () {},
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField).first, 'Compra de repuestos');

    expect(descripcionController.text, 'Compra de repuestos');
  });

  testWidgets('editar cualquier campo de retención dispara onRetencionChanged', (tester) async {
    var llamadas = 0;
    await tester.pumpWidget(_wrap(onRetencionChanged: () => llamadas++));

    // El primer TextField es Descripción; los 3 siguientes son las retenciones.
    await tester.enterText(find.byType(TextField).at(1), '9');

    expect(llamadas, greaterThan(0));
  });
}