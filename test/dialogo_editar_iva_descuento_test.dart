import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/item_pedido.dart';
import 'package:vercy_motos/widgets/facturacion/dialogo_editar_iva_descuento.dart';

void main() {
  final items = [
    const ItemPedido(
      productoId: 'p1',
      productoNombre: 'Producto A',
      cantidad: 2,
      precioUnitario: 10000,
      porcentajeImpuesto: 19,
      porcentajeDescuento: 0,
    ),
  ];

  testWidgets('muestra el titulo, el producto y los valores iniciales de IVA/descuento', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => mostrarDialogoEditarIvaDescuento(
              context: context,
              titulo: 'Pedido de prueba',
              items: items,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Pedido de prueba'), findsOneWidget);
    expect(find.text('Producto A'), findsOneWidget);

    final ivaField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(ivaField.controller!.text, '19');
    final dctoField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(dctoField.controller!.text, '0');
  });

  testWidgets('editar el IVA y tocar "Aplicar y cargar" devuelve confirmado=true con el valor editado', (tester) async {
    ResultadoEdicionIvaDescuento? resultado;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado = await mostrarDialogoEditarIvaDescuento(
                context: context,
                titulo: 'Pedido de prueba',
                items: items,
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '5');
    await tester.tap(find.text('Aplicar y cargar'));
    await tester.pumpAndSettle();

    expect(resultado, isNotNull);
    expect(resultado!.confirmado, isTrue);
    expect(resultado!.ivaValues, [5.0]);
    expect(resultado!.dctoValues, [0.0]);
  });

  testWidgets('tocar "Sin cambios" devuelve confirmado=false', (tester) async {
    ResultadoEdicionIvaDescuento? resultado;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado = await mostrarDialogoEditarIvaDescuento(
                context: context,
                titulo: 'Pedido de prueba',
                items: items,
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sin cambios'));
    await tester.pumpAndSettle();

    expect(resultado, isNotNull);
    expect(resultado!.confirmado, isFalse);
  });
}
