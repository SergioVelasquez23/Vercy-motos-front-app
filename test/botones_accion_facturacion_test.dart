import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/item_pedido.dart';
import 'package:vercy_motos/utils/currency_utils.dart';
import 'package:vercy_motos/widgets/facturacion/botones_accion_facturacion.dart';

final _items = [
  const ItemPedido(
    productoId: 'p1',
    productoNombre: 'Producto A',
    cantidad: 2,
    precioUnitario: 50000, // subtotal 100000
    valorImpuesto: 19000,
    valorDescuento: 5000,
  ),
];

Widget _wrap({
  List<ItemPedido>? items,
  bool isLoading = false,
  VoidCallback? onGuardarBorrador,
  VoidCallback? onGuardarYPagar,
  VoidCallback? onGuardarComoDeuda,
  VoidCallback? onVistaPrevia,
  TextEditingController? dctoGeneralController,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BotonesAccionFacturacion(
        items: items ?? _items,
        isLoading: isLoading,
        onGuardarBorrador: onGuardarBorrador ?? () {},
        onGuardarYPagar: onGuardarYPagar ?? () {},
        onGuardarComoDeuda: onGuardarComoDeuda ?? () {},
        onVistaPrevia: onVistaPrevia,
        dctoGeneralController: dctoGeneralController,
      ),
    ),
  );
}

void main() {
  testWidgets('el total mostrado es subtotal + impuestos - descuentos de los items', (tester) async {
    await tester.pumpWidget(_wrap());

    // subtotal(100000) + impuesto(19000) - descuento(5000) = 114000
    expect(find.text(CurrencyUtils.format(114000)), findsOneWidget);
  });

  testWidgets('el descuento general del controller se resta del total', (tester) async {
    await tester.pumpWidget(_wrap(
      dctoGeneralController: TextEditingController(text: '4000'),
    ));

    // 114000 - 4000 = 110000
    expect(find.text(CurrencyUtils.format(110000)), findsOneWidget);
  });

  testWidgets('tocar "Guardar y Pagar" dispara onGuardarYPagar', (tester) async {
    var llamado = false;
    await tester.pumpWidget(_wrap(onGuardarYPagar: () => llamado = true));

    await tester.tap(find.text('Guardar y Pagar'));
    await tester.pump();

    expect(llamado, isTrue);
  });

  testWidgets('tocar "Guardar Borrador" dispara onGuardarBorrador', (tester) async {
    var llamado = false;
    await tester.pumpWidget(_wrap(onGuardarBorrador: () => llamado = true));

    await tester.tap(find.text('Guardar Borrador'));
    await tester.pump();

    expect(llamado, isTrue);
  });

  testWidgets('con isLoading=true, tocar "Guardar y Pagar" no dispara el callback', (tester) async {
    var llamado = false;
    await tester.pumpWidget(_wrap(isLoading: true, onGuardarYPagar: () => llamado = true));

    await tester.tap(find.text('Guardar y Pagar'), warnIfMissed: false);
    await tester.pump();

    expect(llamado, isFalse);
  });

  testWidgets('sin onVistaPrevia no muestra el botón de vista previa', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.textContaining('Vista previa'), findsNothing);
  });

  testWidgets('con onVistaPrevia lo muestra y, con items, dispara el callback al tocarlo', (tester) async {
    var llamado = false;
    await tester.pumpWidget(_wrap(onVistaPrevia: () => llamado = true));

    expect(find.textContaining('Vista previa'), findsOneWidget);

    await tester.tap(find.textContaining('Vista previa'));
    await tester.pump();

    expect(llamado, isTrue);
  });

  testWidgets('con la lista de items vacía, el botón de vista previa queda deshabilitado', (tester) async {
    var llamado = false;
    await tester.pumpWidget(_wrap(items: [], onVistaPrevia: () => llamado = true));

    await tester.tap(find.textContaining('Vista previa'), warnIfMissed: false);
    await tester.pump();

    expect(llamado, isFalse);
  });
}