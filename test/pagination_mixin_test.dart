import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/pagination_mixin.dart';

class _TestHost extends StatefulWidget {
  const _TestHost({super.key});

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost> with PaginacionMixin<_TestHost> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<_TestHostState> _pump(WidgetTester tester) async {
  final key = GlobalKey<_TestHostState>();
  await tester.pumpWidget(MaterialApp(home: _TestHost(key: key)));
  return key.currentState!;
}

void main() {
  group('paginarLista', () {
    testWidgets('lista vacía da lista vacía', (tester) async {
      final state = await _pump(tester);

      expect(state.paginarLista<int>([]), isEmpty);
    });

    testWidgets('con 25 items y 20 por página, la página 0 trae los primeros 20', (tester) async {
      final state = await _pump(tester);
      final items = List.generate(25, (i) => i);

      final pagina = state.paginarLista(items);

      expect(pagina, List.generate(20, (i) => i));
    });

    testWidgets('la página 1 trae el resto (5 items)', (tester) async {
      final state = await _pump(tester);
      final items = List.generate(25, (i) => i);

      state.irPagina(1);
      await tester.pump();
      final pagina = state.paginarLista(items);

      expect(pagina, [20, 21, 22, 23, 24]);
    });
  });

  group('totalPaginas', () {
    testWidgets('redondea hacia arriba', (tester) async {
      final state = await _pump(tester);

      expect(state.totalPaginas(41), 3); // 41/20 -> 2.05 -> 3
      expect(state.totalPaginas(40), 2);
    });

    testWidgets('con 0 items da mínimo 1 página', (tester) async {
      final state = await _pump(tester);

      expect(state.totalPaginas(0), 1);
    });
  });

  group('navegación', () {
    testWidgets('paginaSiguiente avanza hasta la última página y no más allá', (tester) async {
      final state = await _pump(tester);

      state.paginaSiguiente(45); // 3 páginas: 0,1,2
      await tester.pump();
      expect(state.paginaActual, 1);

      state.paginaSiguiente(45);
      await tester.pump();
      expect(state.paginaActual, 2);

      state.paginaSiguiente(45); // ya en la última, no avanza más
      await tester.pump();
      expect(state.paginaActual, 2);
    });

    testWidgets('paginaAnterior no retrocede antes de la página 0', (tester) async {
      final state = await _pump(tester);

      state.paginaAnterior();
      await tester.pump();

      expect(state.paginaActual, 0);
    });

    testWidgets('irPagina cambia directamente a la página indicada', (tester) async {
      final state = await _pump(tester);

      state.irPagina(4);
      await tester.pump();

      expect(state.paginaActual, 4);
    });

    testWidgets('resetPagina vuelve a la página 0', (tester) async {
      final state = await _pump(tester);

      state.irPagina(3);
      await tester.pump();
      state.resetPagina();
      await tester.pump();

      expect(state.paginaActual, 0);
    });
  });

  group('cuando la página actual queda fuera de rango (ej. un filtro redujo la lista)', () {
    testWidgets('no revienta y devuelve un resultado acotado en vez de una lista vacía o un error de rango', (tester) async {
      final state = await _pump(tester);

      state.irPagina(4); // página 4 (items 80-99) de una lista larga
      await tester.pump();

      // Ahora la lista filtrada solo tiene 10 items: la página 4 ya no existe
      // (inicio=80 >= lista.length=10). paginarLista no lanza RangeError ni
      // devuelve vacío — entrega los primeros items mientras se reprograma
      // el reset a la página 0 para el próximo frame (WidgetsBinding
      // .addPostFrameCallback, no verificable de forma determinista con
      // tester.pump() en este mixin porque el widget de prueba nunca queda
      // "sucio" — el reset real se ejerce en las pantallas de lista, donde
      // paginarLista se llama dentro de build()).
      final pagina = state.paginarLista(List.generate(10, (i) => i));
      expect(pagina, List.generate(10, (i) => i));
    });
  });
}