// Tests de secuencias "raras" de usuario sobre FacturasComprasScreen,
// mismo enfoque que facturacion_screen_secuencias_test.dart: confirmar que
// una sola accion del usuario (eliminar una factura de compra) no dispara
// la misma peticion de reversion de inventario mas de una vez.
//
// Bug real encontrado en la revision: el boton "Eliminar" de cada factura
// (y el boton "Eliminar" del dialogo de confirmacion) no tenian ningun guard
// contra doble-tap. Como el flujo ejecuta revertirInventarioCompra() y LUEGO
// eliminarFacturaCompra() en secuencia, un doble-tap real podia revertir el
// inventario dos veces para la misma compra, aunque el segundo intento de
// eliminar la factura en el backend fallara (error capturado, pero el stock
// ya habia sido devuelto de mas).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/factura_compra.dart';
import 'package:vercy_motos/screens/facturas_compras_screen.dart';
import 'package:vercy_motos/services/factura_compra_service.dart';

/// Fake que extiende FacturaCompraService (no es singleton, constructor
/// publico normal) solo para contar llamadas y controlar su respuesta -
/// mismo patron a mano que ya usa el resto de la suite (sin mockito/mocktail).
class FakeFacturaCompraService extends FacturaCompraService {
  FakeFacturaCompraService({required this.facturasIniciales});

  final List<FacturaCompra> facturasIniciales;

  int getFacturasCallCount = 0;
  int revertirInventarioCallCount = 0;
  int eliminarFacturaCallCount = 0;
  final List<String> idsEliminados = [];

  /// Si no es null, eliminarFacturaCompra lanza esto en vez de responder ok.
  Object? eliminarFacturaError;

  /// Retraso artificial antes de resolver cada llamada - permite simular una
  /// peticion "en vuelo" real para probar dobles-toques con una ventana de
  /// tiempo genuina (controlado por el reloj falso de flutter_test).
  Duration respuestaDelay = Duration.zero;

  Future<void> _simularLatencia() async {
    if (respuestaDelay > Duration.zero) {
      await Future.delayed(respuestaDelay);
    }
  }

  @override
  Future<List<FacturaCompra>> getFacturasCompras() async {
    getFacturasCallCount++;
    return List.from(facturasIniciales);
  }

  @override
  Future<void> revertirInventarioCompra(FacturaCompra factura) async {
    revertirInventarioCallCount++;
    await _simularLatencia();
  }

  @override
  Future<Map<String, dynamic>> eliminarFacturaCompra(
    String id, {
    String? motivoEliminacion,
  }) async {
    eliminarFacturaCallCount++;
    idsEliminados.add(id);
    await _simularLatencia();
    if (eliminarFacturaError != null) throw eliminarFacturaError!;
    return {'success': true, 'message': 'Factura eliminada correctamente'};
  }
}

FacturaCompra _facturaDeEjemplo({
  String id = 'factura-1',
  String numeroFactura = 'C-20260101-0001',
}) {
  return FacturaCompra(
    id: id,
    numeroFactura: numeroFactura,
    proveedorNombre: 'Proveedor de prueba',
    fechaFactura: DateTime(2026, 1, 1),
    fechaVencimiento: DateTime(2026, 2, 1),
    estado: 'PROCESADA',
    items: [
      ItemFacturaCompra(
        ingredienteId: 'p1',
        ingredienteNombre: 'MOFLE MF NKD CROMADO',
        cantidad: 1,
        unidad: 'UND',
        precioUnitario: 80000,
        subtotal: 80000,
      ),
    ],
    fechaCreacion: DateTime(2026, 1, 1),
    fechaActualizacion: DateTime(2026, 1, 1),
  );
}

void main() {
  Future<FakeFacturaCompraService> montarPantalla(
    WidgetTester tester, {
    Duration respuestaDelay = Duration.zero,
    Object? eliminarFacturaError,
  }) async {
    // Layout de escritorio - evita overflow de Row en el tamaño chico por
    // defecto de flutter_test.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = FakeFacturaCompraService(
      facturasIniciales: [_facturaDeEjemplo()],
    )
      ..respuestaDelay = respuestaDelay
      ..eliminarFacturaError = eliminarFacturaError;

    await tester.pumpWidget(
      MaterialApp(
        home: FacturasComprasScreen(facturaCompraService: fake),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    return fake;
  }

  /// Boton "Eliminar" de la FILA de la factura - distinto del boton
  /// "Eliminar" dentro del dialogo de confirmacion, que aparece despues.
  Finder botonEliminarDeLaFila() => find.text('Eliminar').first;

  Finder botonEliminarDelDialogo() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('Eliminar'),
  );

  testWidgets(
    'doble-tap en "Eliminar" de la misma factura no abre dos dialogos ni revierte el inventario dos veces',
    (tester) async {
      final fake = await montarPantalla(
        tester,
        respuestaDelay: const Duration(milliseconds: 80),
      );

      // Dos toques rapidos sobre el mismo boton de la fila, antes de que el
      // primer dialogo llegue a pintarse.
      await tester.tap(botonEliminarDeLaFila(), warnIfMissed: false);
      await tester.tap(botonEliminarDeLaFila(), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'el segundo toque debe ser descartado por runGuarded antes '
            'de abrir un segundo dialogo apilado',
      );

      await tester.tap(botonEliminarDelDialogo(), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(
        fake.revertirInventarioCallCount,
        1,
        reason: 'un doble-tap no debe revertir el inventario dos veces para '
            'la misma compra eliminada',
      );
      expect(fake.eliminarFacturaCallCount, 1);
      expect(fake.idsEliminados, ['factura-1']);
    },
  );

  testWidgets(
    'un solo tap y confirmar elimina la factura una sola vez y refresca la lista',
    (tester) async {
      final fake = await montarPantalla(tester);

      await tester.tap(botonEliminarDeLaFila(), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(botonEliminarDelDialogo(), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(fake.revertirInventarioCallCount, 1);
      expect(fake.eliminarFacturaCallCount, 1);
      // _cargarFacturas() se llama una vez al montar y otra vez al refrescar
      // despues de eliminar exitosamente.
      expect(fake.getFacturasCallCount, 2);
    },
  );

  testWidgets(
    'cancelar el dialogo de confirmacion no llama a ningun metodo del service',
    (tester) async {
      final fake = await montarPantalla(tester);

      await tester.tap(botonEliminarDeLaFila(), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(fake.revertirInventarioCallCount, 0);
      expect(fake.eliminarFacturaCallCount, 0);
    },
  );

  testWidgets(
    'si eliminarFacturaCompra falla DESPUES de revertir el inventario, el error se muestra y no se propaga sin capturar',
    (tester) async {
      final fake = await montarPantalla(
        tester,
        eliminarFacturaError: Exception('backend caido a mitad de camino'),
      );

      await tester.tap(botonEliminarDeLaFila(), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(botonEliminarDelDialogo(), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // El inventario SI se revierte (pasa primero en el codigo) aunque
      // eliminarFacturaCompra falle justo despues - riesgo real documentado
      // en el reporte: el stock quedo revertido pero la factura sigue
      // existiendo en el backend (estado inconsistente), no es algo que este
      // test deba "arreglar".
      expect(fake.revertirInventarioCallCount, 1);
      expect(fake.eliminarFacturaCallCount, 1);
      expect(
        tester.takeException(),
        isNull,
        reason: 'el error debe quedar capturado y mostrado en un SnackBar, '
            'no propagarse como excepcion no manejada',
      );
    },
  );
}
