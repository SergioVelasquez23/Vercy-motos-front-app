import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/pagination_mixin.dart';

class _TestHost extends StatefulWidget {
  const _TestHost({super.key});

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost> with PaginacionMixin<_TestHost> {
  int cambios = 0;

  @override
  void onCambioPagina() => cambios++;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<_TestHostState> _pump(WidgetTester tester) async {
  final key = GlobalKey<_TestHostState>();
  await tester.pumpWidget(MaterialApp(home: _TestHost(key: key)));
  return key.currentState!;
}

/// Deja pasar el debounce de navegación (280 ms) para que no queden timers
/// pendientes al terminar el test.
Future<void> _pasarDebounce(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 320));

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
      await _pasarDebounce(tester);
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
      await _pasarDebounce(tester);
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
      await _pasarDebounce(tester);

      expect(state.paginaActual, 4);
    });

    testWidgets('resetPagina vuelve a la página 0', (tester) async {
      final state = await _pump(tester);

      state.irPagina(3);
      await tester.pump();
      state.resetPagina();
      await _pasarDebounce(tester);

      expect(state.paginaActual, 0);
    });

    testWidgets('varios avances rápidos = una sola llamada a onCambioPagina (debounce)', (tester) async {
      final state = await _pump(tester);

      state.paginaSiguiente(200); // -> 1
      state.paginaSiguiente(200); // -> 2
      state.paginaSiguiente(200); // -> 3
      await tester.pump(); // aún dentro del debounce
      expect(state.paginaActual, 3);
      expect(state.cambios, 0, reason: 'todavía no se disparó el callback');

      await _pasarDebounce(tester);
      expect(state.cambios, 1, reason: 'un solo callback para toda la ráfaga');
    });
  });

  group('cuando la página actual queda fuera de rango (ej. un filtro redujo la lista)', () {
    testWidgets('no revienta y devuelve un resultado acotado en vez de una lista vacía o un error de rango', (tester) async {
      final state = await _pump(tester);

      state.irPagina(4);
      await _pasarDebounce(tester);

      final pagina = state.paginarLista(List.generate(10, (i) => i));
      expect(pagina, List.generate(10, (i) => i));
    });
  });

  group('slotsPaginacion — regla de "…" estandarizada y ancho estable', () {
    testWidgets('caben todas si no superan el máximo sin elipsis', (tester) async {
      final state = await _pump(tester);
      // sibling=1 -> máx sin elipsis = 2*1 + 2*1 + 3 = 7
      expect(state.slotsPaginacion(7, 1), [1, 2, 3, 4, 5, 6, 7]);
    });

    testWidgets('primera y última SIEMPRE presentes', (tester) async {
      final state = await _pump(tester);
      for (final page in [0, 4, 11, 23]) {
        state.irPagina(page);
        await _pasarDebounce(tester);
        final slots = state.slotsPaginacion(24, 1);
        expect(slots.first, 1, reason: 'página ${page + 1}');
        expect(slots.last, 24, reason: 'página ${page + 1}');
      }
    });

    testWidgets('el número de slots NO cambia al navegar (ancho estable), sibling=1', (tester) async {
      final state = await _pump(tester);
      final anchos = <int>{};
      for (var page = 0; page < 24; page++) {
        state.irPagina(page);
        await _pasarDebounce(tester);
        anchos.add(state.slotsPaginacion(24, 1).length);
      }
      expect(anchos.length, 1, reason: 'todas las páginas producen el mismo número de slots');
      expect(anchos.single, 2 * 1 + 5); // first + … + (2*sib+1) + … + last
    });

    testWidgets('el número de slots NO cambia al navegar, sibling=2', (tester) async {
      final state = await _pump(tester);
      final anchos = <int>{};
      for (var page = 0; page < 24; page++) {
        state.irPagina(page);
        await _pasarDebounce(tester);
        anchos.add(state.slotsPaginacion(24, 2).length);
      }
      expect(anchos.length, 1);
      expect(anchos.single, 2 * 2 + 5);
    });

    testWidgets('nunca hay "…" tapando una sola página (se muestra la página)', (tester) async {
      final state = await _pump(tester);
      for (var page = 0; page < 24; page++) {
        state.irPagina(page);
        await _pasarDebounce(tester);
        final slots = state.slotsPaginacion(24, 1);
        for (var i = 0; i < slots.length - 1; i++) {
          final a = slots[i];
          final b = slots[i + 1];
          if (a >= 0 && b >= 0) {
            // dos números consecutivos mostrados: o son adyacentes, o debería
            // haber una elipsis entre ellos (nunca un salto de exactamente 2
            // sin elipsis, porque esa página intermedia debería mostrarse).
            expect(b - a == 1 || b - a > 2, isTrue,
                reason: 'salto de 2 sin elipsis entre $a y $b (página ${page + 1})');
          }
          if (slots[i] == -1) {
            // una elipsis siempre salta MÁS de una página
            final prev = slots[i - 1];
            final next = slots[i + 1];
            expect(next - prev, greaterThan(2),
                reason: 'elipsis entre $prev y $next tapa una sola página');
          }
        }
      }
    });

    testWidgets('página 3 y página 5 de 24 tienen el mismo ancho', (tester) async {
      final state = await _pump(tester);
      state.irPagina(2);
      await _pasarDebounce(tester);
      final p3 = state.slotsPaginacion(24, 2);
      state.irPagina(4);
      await _pasarDebounce(tester);
      final p5 = state.slotsPaginacion(24, 2);
      expect(p3.length, p5.length);
    });
  });

  group('buildPaginacion — no desborda ni recorta', () {
    testWidgets('renderiza dentro de un ancho chico sin overflow', (tester) async {
      final key = GlobalKey<_TestHostState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _HostConBarra(hostKey: key),
        ),
      ));
      await tester.pump();

      // Sin excepciones de overflow (FlutterError) al pintar en 320px de ancho.
      expect(tester.takeException(), isNull);
      // Se pinta la primera y la última página.
      expect(find.text('1'), findsWidgets);
      expect(find.text('24'), findsOneWidget);
    });
  });
}

class _HostConBarra extends StatefulWidget {
  const _HostConBarra({required this.hostKey});
  final GlobalKey<_TestHostState> hostKey;
  @override
  State<_HostConBarra> createState() => _HostConBarraState();
}

class _HostConBarraState extends State<_HostConBarra> with PaginacionMixin<_HostConBarra> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 320,
        child: buildPaginacion(totalItems: 24 * 20), // 24 páginas de 20
      ),
    );
  }
}
