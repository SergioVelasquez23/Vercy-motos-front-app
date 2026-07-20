import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/producto.dart';
import 'package:vercy_motos/utils/currency_utils.dart';
import 'package:vercy_motos/widgets/productos/codigo_barras_preview.dart';

Producto _producto({String? codigo, String? codigoBarras}) {
  return Producto(
    id: 'p1',
    nombre: 'Casco Integral',
    precio: 150000,
    costo: 90000,
    utilidad: 60000,
    codigo: codigo,
    codigoBarras: codigoBarras,
  );
}

Widget _wrap(Producto producto, {bool mostrarPrecio = true}) {
  return MaterialApp(
    home: Scaffold(
      body: CodigoBarrasPreview(
        producto: producto,
        mostrarPrecio: mostrarPrecio,
        unidadMedida: 'Unics',
        tipoFecha: '-Fect',
        tipoLista: 'Detal',
        tipoPrecio: 'Base',
      ),
    ),
  );
}

void main() {
  testWidgets('muestra el nombre del producto y las etiquetas de unidad/fecha/lista/precio', (tester) async {
    await tester.pumpWidget(_wrap(_producto(codigo: 'ABC123')));

    expect(find.text('Casco Integral'), findsOneWidget);
    expect(find.text('Unics'), findsOneWidget);
    expect(find.text('-Fect'), findsOneWidget);
    expect(find.text('Detal'), findsOneWidget);
    expect(find.text('Base'), findsOneWidget);
  });

  testWidgets('con mostrarPrecio=true muestra el precio formateado', (tester) async {
    await tester.pumpWidget(_wrap(_producto(codigo: 'ABC123'), mostrarPrecio: true));

    expect(find.text(CurrencyUtils.format(150000)), findsOneWidget);
  });

  testWidgets('con mostrarPrecio=false no muestra el precio', (tester) async {
    await tester.pumpWidget(_wrap(_producto(codigo: 'ABC123'), mostrarPrecio: false));

    expect(find.text(CurrencyUtils.format(150000)), findsNothing);
  });

  testWidgets('prefiere codigoBarras sobre codigo para el número mostrado', (tester) async {
    await tester.pumpWidget(_wrap(_producto(codigo: 'ABC123', codigoBarras: '7701234567890')));

    expect(find.text('7701234567890'), findsOneWidget);
  });

  testWidgets('usa codigo cuando no hay codigoBarras', (tester) async {
    await tester.pumpWidget(_wrap(_producto(codigo: 'ABC123')));

    expect(find.text('ABC123'), findsOneWidget);
  });

  testWidgets('sin codigo ni codigoBarras muestra el aviso de "Sin código de barras"', (tester) async {
    await tester.pumpWidget(_wrap(_producto()));

    expect(find.text('Sin código de barras'), findsOneWidget);
    expect(find.text('N/A'), findsOneWidget);
  });
}