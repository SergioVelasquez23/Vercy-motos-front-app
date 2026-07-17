import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/facturacion/tipo_factura_dropdown.dart';

Widget _wrap(String tipoFactura, ValueChanged<String> onChanged) {
  return MaterialApp(
    home: Scaffold(
      body: TipoFacturaDropdown(tipoFactura: tipoFactura, onChanged: onChanged),
    ),
  );
}

void main() {
  testWidgets('con tipoFactura="FACTURA" muestra el aviso de Factura Electrónica', (tester) async {
    await tester.pumpWidget(_wrap('FACTURA', (_) {}));

    expect(find.textContaining('Factura Electrónica'), findsWidgets);
  });

  testWidgets('con tipoFactura="POS" muestra el aviso de documento POS', (tester) async {
    await tester.pumpWidget(_wrap('POS', (_) {}));

    expect(find.textContaining('documento POS'), findsOneWidget);
  });

  testWidgets('con tipoFactura="LOCAL" no muestra ningún aviso de DIAN', (tester) async {
    await tester.pumpWidget(_wrap('LOCAL', (_) {}));

    expect(find.textContaining('DIAN'), findsNothing);
  });
}
