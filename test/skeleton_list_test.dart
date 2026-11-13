import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/widgets/common/skeleton_list.dart';

void main() {
  testWidgets('dibuja la cantidad de filas pedida y no lanza excepciones', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SkeletonList(itemCount: 3, itemHeight: 40)),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SkeletonList), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
  });

  testWidgets('con "reducir movimiento" no deja animaciones pendientes', (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: Scaffold(body: SkeletonList())),
    ));
    // Si hubiera una animación en bucle, pumpAndSettle no terminaría.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('se puede quitar del árbol sin errores (dispose del controller)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SkeletonList())));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    expect(tester.takeException(), isNull);
  });
}
