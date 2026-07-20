import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/categoria.dart';
import 'package:vercy_motos/widgets/productos/categoria_filter_row.dart';

final _categorias = [
  Categoria(id: 'c1', nombre: 'Cascos'),
  Categoria(id: 'c2', nombre: 'Guantes'),
];

Widget _wrap({
  required String? selectedCategoriaId,
  required ValueChanged<String?> onCategoriaSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CategoriaFilterRow(
        categorias: _categorias,
        selectedCategoriaId: selectedCategoriaId,
        onCategoriaSelected: onCategoriaSelected,
      ),
    ),
  );
}

void main() {
  testWidgets('muestra "Todas" y un chip por cada categoría', (tester) async {
    await tester.pumpWidget(_wrap(selectedCategoriaId: null, onCategoriaSelected: (_) {}));

    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Cascos'), findsOneWidget);
    expect(find.text('Guantes'), findsOneWidget);
  });

  testWidgets('tocar una categoría dispara onCategoriaSelected con su id', (tester) async {
    String? seleccionado = 'no-tocado';
    await tester.pumpWidget(_wrap(
      selectedCategoriaId: null,
      onCategoriaSelected: (id) => seleccionado = id,
    ));

    await tester.tap(find.text('Guantes'));
    await tester.pump();

    expect(seleccionado, 'c2');
  });

  testWidgets('tocar "Todas" dispara onCategoriaSelected con null', (tester) async {
    String? seleccionado = 'no-tocado';
    await tester.pumpWidget(_wrap(
      selectedCategoriaId: 'c1',
      onCategoriaSelected: (id) => seleccionado = id,
    ));

    await tester.tap(find.text('Todas'));
    await tester.pump();

    expect(seleccionado, isNull);
  });

  testWidgets('con categorias vacías solo muestra "Todas"', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CategoriaFilterRow(
          categorias: const [],
          selectedCategoriaId: null,
          onCategoriaSelected: (_) {},
        ),
      ),
    ));

    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Cascos'), findsNothing);
  });
}