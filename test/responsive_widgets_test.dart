import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/item_pedido.dart';
import 'package:vercy_motos/widgets/common/pagination_controls.dart';
import 'package:vercy_motos/widgets/common/screen_header.dart';
import 'package:vercy_motos/widgets/facturacion/botones_accion_facturacion.dart';
import 'package:vercy_motos/widgets/facturacion/totales_section.dart';
import 'package:vercy_motos/widgets/facturacion/metodo_pago_section.dart';

/// Anchos de teléfono pequeño y estándar: si un widget compartido desborda
/// aquí, desborda en el celular del cajero.
const _anchos = <double>[320, 360, 412];

/// Los tests de Flutter dibujan el texto con la fuente "Ahem" (cada letra mide
/// 1 em de ancho), mucho más ancha que Roboto: eso daría desbordes falsos.
/// Se carga la Roboto real que trae el SDK para medir como en el dispositivo.
Future<void> _cargarRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  var alguna = false;
  for (final f in ['Regular', 'Medium', 'Bold']) {
    final archivo = File('$dir/Roboto-$f.ttf');
    if (await archivo.exists()) {
      final bytes = await archivo.readAsBytes();
      loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
      alguna = true;
    }
  }
  if (alguna) await loader.load();
}

Future<void> _montarA(WidgetTester tester, double ancho, Widget hijo) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: hijo)),
  ));
  await tester.pump();
}

const _metodos = <Map<String, dynamic>>[
  {'value': 'efectivo', 'label': 'Efectivo', 'icon': Icons.payments},
  {'value': 'transferencia', 'label': 'Transferencia', 'icon': Icons.account_balance},
  {'value': 'nequi', 'label': 'Nequi', 'icon': Icons.account_balance},
  {'value': 'daviplata', 'label': 'DaviPlata', 'icon': Icons.account_balance},
  {'value': 'bancolombia', 'label': 'Bancolombia', 'icon': Icons.account_balance},
  {'value': 'bold', 'label': 'Bold', 'icon': Icons.point_of_sale},
  {'value': 'addi', 'label': 'Addi', 'icon': Icons.shopping_bag_outlined},
  {'value': 'credilondon', 'label': 'Credilondon', 'icon': Icons.shopping_bag_outlined},
  {'value': 'sistecredito', 'label': 'Sistecredito', 'icon': Icons.card_giftcard},
  {'value': 'credito', 'label': 'A Crédito', 'icon': Icons.account_balance_wallet},
  {'value': 'multiple', 'label': 'Múltiple', 'icon': Icons.payments},
];

final _items = <ItemPedido>[
  const ItemPedido(
    productoId: 'p1',
    productoNombre: 'ESTABILIZADOR TRASERO NKD ACRILICO AGUAMARINA',
    cantidad: 3,
    precioUnitario: 1250000,
    porcentajeImpuesto: 19,
    valorImpuesto: 712500,
    valorDescuento: 50000,
  ),
  const ItemPedido(productoId: 'p2', productoNombre: 'RIATA', cantidad: 1, precioUnitario: 30000),
];

MetodoPagoSection _seccion(String metodo) => MetodoPagoSection(
      metodoPago: metodo,
      metodosPago: _metodos,
      totalAPagar: 1500000,
      onMetodoPagoChanged: (_) {},
      onMontoChanged: () {},
      montoEfectivoController: TextEditingController(text: '1.500.000'),
      montoTransferenciaController: TextEditingController(text: '0'),
      montoNequiController: TextEditingController(text: '0'),
      montoDaviplataController: TextEditingController(text: '0'),
      montoBancolombiaController: TextEditingController(text: '0'),
      montoTarjetaController: TextEditingController(text: '0'),
      montoSistereditoController: TextEditingController(text: '0'),
      montoBoldController: TextEditingController(text: '0'),
      montoAddiController: TextEditingController(text: '0'),
      montoCredilondonController: TextEditingController(text: '0'),
    );

void main() {
  setUpAll(_cargarRoboto);

  for (final ancho in _anchos) {
    for (final metodo in ['efectivo', 'multiple', 'credito']) {
      testWidgets('MetodoPagoSection "$metodo" cabe en ${ancho.toInt()} px', (tester) async {
        await _montarA(tester, ancho, _seccion(metodo));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('TotalesSection cabe en ${ancho.toInt()} px', (tester) async {
      await _montarA(
        tester,
        ancho,
        TotalesSection(
          items: _items,
          retencionController: TextEditingController(text: '2.5'),
          reteIVAController: TextEditingController(text: '15'),
          reteICAController: TextEditingController(text: '0.966'),
          aiuController: TextEditingController(text: '0'),
          dctoGeneralController: TextEditingController(text: '0'),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('BotonesAccionFacturacion cabe en ${ancho.toInt()} px', (tester) async {
      await _montarA(
        tester,
        ancho,
        BotonesAccionFacturacion(
          items: _items,
          isLoading: false,
          onGuardarBorrador: () {},
          onGuardarYPagar: () {},
          onGuardarComoDeuda: () {},
          onVistaPrevia: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ScreenHeader con acciones cabe en ${ancho.toInt()} px', (tester) async {
      await _montarA(
        tester,
        ancho,
        ScreenHeader(
          icon: Icons.inventory_2,
          title: 'Inventario de productos',
          badge: '3162 productos',
          actions: [
            ElevatedButton(onPressed: () {}, child: const Text('Nuevo producto')),
            OutlinedButton(onPressed: () {}, child: const Text('Exportar Excel')),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('PaginationControls cabe en ${ancho.toInt()} px', (tester) async {
      await _montarA(
        tester,
        ancho,
        PaginationControls(
          totalElementos: 3162,
          paginaActual: 12,
          itemsPorPagina: 50,
          onPaginaAnterior: () {},
          onSiguientePagina: () {},
          onItemsPorPaginaChanged: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
