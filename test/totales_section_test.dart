import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/item_pedido.dart';
import 'package:vercy_motos/utils/currency_utils.dart';
import 'package:vercy_motos/widgets/facturacion/totales_section.dart';

Widget _wrap({
  required List<ItemPedido> items,
  String retencion = '',
  String reteIVA = '',
  String reteICA = '',
  String aiu = '',
  String dctoGeneral = '',
}) {
  return MaterialApp(
    home: Scaffold(
      body: TotalesSection(
        items: items,
        retencionController: TextEditingController(text: retencion),
        reteIVAController: TextEditingController(text: reteIVA),
        reteICAController: TextEditingController(text: reteICA),
        aiuController: TextEditingController(text: aiu),
        dctoGeneralController: TextEditingController(text: dctoGeneral),
      ),
    ),
  );
}

void main() {
  testWidgets('sin descuentos ni retenciones, solo muestra Subtotal, Impuesto y TOTAL', (tester) async {
    final items = [
      const ItemPedido(
        productoId: 'p1',
        cantidad: 1,
        precioUnitario: 100000,
        valorImpuesto: 19000,
      ),
    ];
    await tester.pumpWidget(_wrap(items: items));

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(100000)), findsOneWidget);
    expect(find.text('Impuesto'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(19000)), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    // total = 100000 + 19000 = 119000
    expect(find.text(CurrencyUtils.format(119000)), findsOneWidget);

    expect(find.textContaining('Dcto'), findsNothing);
    expect(find.textContaining('Retención'), findsNothing);
    expect(find.textContaining('ReteIVA'), findsNothing);
    expect(find.textContaining('ReteICA'), findsNothing);
    expect(find.textContaining('AIU'), findsNothing);
  });

  testWidgets('con descuento de producto, dcto general, retenciones y AIU, calcula el TOTAL correcto', (tester) async {
    final items = [
      const ItemPedido(
        productoId: 'p1',
        cantidad: 1,
        precioUnitario: 100000, // subtotal 100000
        valorImpuesto: 19000,
        valorDescuento: 5000,
      ),
    ];
    await tester.pumpWidget(_wrap(
      items: items,
      retencion: '2', // 100000 * 2% = 2000
      reteIVA: '1', // 100000 * 1% = 1000
      reteICA: '0.5', // 100000 * 0.5% = 500
      aiu: '10', // 100000 * 10% = 10000
      dctoGeneral: '3000',
    ));

    expect(find.text('Dcto Producto'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(-5000)), findsOneWidget);

    expect(find.text('Dcto General'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(-3000)), findsOneWidget);

    expect(find.text('Retención (2.0%)'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(-2000)), findsOneWidget);

    expect(find.text('ReteIVA (1.0%)'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(-1000)), findsOneWidget);

    expect(find.text('ReteICA (0.5%)'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(-500)), findsOneWidget);

    expect(find.text('AIU (10.0%)'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(10000)), findsOneWidget);

    // 100000 (subtotal) + 19000 (impuesto) + 10000 (aiu)
    //   - 5000 (dcto producto) - 3000 (dcto general)
    //   - (2000 + 1000 + 500) (retenciones)
    // = 117500
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(117500)), findsOneWidget);
  });

  testWidgets('con varios items, el subtotal e impuesto se suman entre todos', (tester) async {
    final items = [
      const ItemPedido(
        productoId: 'p1',
        cantidad: 2,
        precioUnitario: 20000, // subtotal 40000
        valorImpuesto: 7600,
      ),
      const ItemPedido(
        productoId: 'p2',
        cantidad: 1,
        precioUnitario: 60000, // subtotal 60000
        valorImpuesto: 11400,
      ),
    ];
    await tester.pumpWidget(_wrap(items: items));

    // subtotal = 40000 + 60000 = 100000
    expect(find.text(CurrencyUtils.format(100000)), findsOneWidget);
    // impuesto = 7600 + 11400 = 19000
    expect(find.text(CurrencyUtils.format(19000)), findsOneWidget);
    // total = 100000 + 19000 = 119000
    expect(find.text(CurrencyUtils.format(119000)), findsOneWidget);
  });
}