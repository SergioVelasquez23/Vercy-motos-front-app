import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/factura_compra.dart';
import 'package:vercy_motos/utils/currency_utils.dart';
import 'package:vercy_motos/widgets/compras/resumen_compra_lateral.dart';

Widget _wrap({
  required List<ItemFacturaCompra> items,
  String descuentoGeneral = '',
  String tipoDescuentoGeneral = 'Valor',
  ValueChanged<String>? onTipoDescuentoGeneralChanged,
  VoidCallback? onDescuentoGeneralChanged,
  String retencion = '',
  String reteIva = '',
  String reteIca = '',
}) {
  return MaterialApp(
    home: Scaffold(
      body: ResumenCompraLateral(
        items: items,
        descuentoGeneralValorController: TextEditingController(text: descuentoGeneral),
        tipoDescuentoGeneral: tipoDescuentoGeneral,
        onTipoDescuentoGeneralChanged: onTipoDescuentoGeneralChanged ?? (_) {},
        onDescuentoGeneralChanged: onDescuentoGeneralChanged ?? () {},
        porcentajeRetencionController: TextEditingController(text: retencion),
        porcentajeReteIvaController: TextEditingController(text: reteIva),
        porcentajeReteIcaController: TextEditingController(text: reteIca),
      ),
    ),
  );
}

void main() {
  testWidgets('sin descuentos ni retenciones, TOTAL = subtotal + impuesto', (tester) async {
    final items = [
      ItemFacturaCompra(
        ingredienteId: 'i1',
        ingredienteNombre: 'Aceite',
        cantidad: 1,
        unidad: 'UND',
        precioUnitario: 100000,
        subtotal: 100000,
        valorImpuesto: 19000,
      ),
    ];
    await tester.pumpWidget(_wrap(items: items));

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(100000)), findsOneWidget);
    expect(find.text('Impuesto'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(19000)), findsOneWidget);
    // total = 100000 + 19000 = 119000
    expect(find.text(CurrencyUtils.format(119000)), findsOneWidget);
  });

  testWidgets('con descuento de producto, descuento general en valor, y retenciones, calcula el TOTAL correcto', (tester) async {
    final items = [
      ItemFacturaCompra(
        ingredienteId: 'i1',
        ingredienteNombre: 'Aceite',
        cantidad: 1,
        unidad: 'UND',
        precioUnitario: 100000,
        subtotal: 100000, // subtotal
        valorImpuesto: 19000, // impuesto
        valorDescuento: 5000, // dcto producto
      ),
    ];
    await tester.pumpWidget(_wrap(
      items: items,
      descuentoGeneral: '3000', // dcto general en $ (tipo Valor)
      retencion: '2', // 2% sobre baseGravable
      reteIva: '1', // 1% sobre totalImpuestos
      reteIca: '0.5', // 0.5% sobre baseGravable
    ));

    // baseGravable = 100000 - 5000 (dcto producto) - 3000 (dcto general) = 92000
    // retencion = 92000 * 2% = 1840
    // reteIva = 19000 * 1% = 190
    // reteIca = 92000 * 0.5% = 460
    // total = 92000 + 19000 - 1840 - 190 - 460 = 108510
    expect(find.text(CurrencyUtils.format(108510)), findsOneWidget);
  });

  testWidgets('con descuento general en porcentaje, se calcula sobre el subtotal (no sobre la base ya descontada)', (tester) async {
    final items = [
      ItemFacturaCompra(
        ingredienteId: 'i1',
        ingredienteNombre: 'Aceite',
        cantidad: 1,
        unidad: 'UND',
        precioUnitario: 200000,
        subtotal: 200000,
      ),
    ];
    await tester.pumpWidget(_wrap(
      items: items,
      tipoDescuentoGeneral: 'Porcentaje',
      descuentoGeneral: '10', // 10% de 200000 = 20000
    ));

    // baseGravable = 200000 - 0 (sin dcto producto) - 20000 = 180000
    // sin impuestos ni retenciones -> total = 180000
    expect(find.text(CurrencyUtils.format(180000)), findsOneWidget);
  });

  testWidgets('cambiar el dropdown de tipo de descuento dispara onTipoDescuentoGeneralChanged con el valor traducido', (tester) async {
    String? nuevoTipo;
    await tester.pumpWidget(_wrap(
      items: const [],
      tipoDescuentoGeneral: 'Valor',
      onTipoDescuentoGeneralChanged: (v) => nuevoTipo = v,
    ));

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('%').last);
    await tester.pumpAndSettle();

    expect(nuevoTipo, 'Porcentaje');
  });

  testWidgets('escribir en el campo de descuento general dispara onDescuentoGeneralChanged', (tester) async {
    var llamado = false;
    await tester.pumpWidget(_wrap(items: const [], onDescuentoGeneralChanged: () => llamado = true));

    // El campo de valor de descuento general es el único TextField visible
    // (los de retención viven en DescripcionYRetencionesCompacto, no aquí).
    await tester.enterText(find.byType(TextField), '5000');

    expect(llamado, isTrue);
  });

  testWidgets('lista de items vacía no revienta y da TOTAL 0', (tester) async {
    await tester.pumpWidget(_wrap(items: const []));

    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text(CurrencyUtils.format(0)), findsWidgets);
  });
}