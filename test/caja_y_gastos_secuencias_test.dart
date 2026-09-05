// Tests de secuencias "raras" de usuario sobre los flujos de caja y gastos,
// mismo enfoque que facturacion_screen_secuencias_test.dart y
// facturas_compras_screen_secuencias_test.dart: confirmar que una sola
// accion del usuario no dispara la misma peticion dos veces.
//
// Bugs reales encontrados en la revision:
// - AbrirCajaScreen: el boton "ABRIR CAJA" no tenia NINGUN guard (ni
//   siquiera el de _isLoading) - un doble-tap real podia disparar dos
//   createCuadre() concurrentes, abriendo dos cajas del mismo tipo.
// - CerrarCajaScreen: el boton "CERRAR CAJA" no tenia guard antes de abrir
//   el dialogo de efectivo declarado - un doble-tap podia apilar dos
//   dialogos y, si ambos se confirmaban, disparar dos updateCuadre() con
//   cerrarCaja:true para la misma caja.
// - GastosScreen: el boton "Eliminar" de cada gasto no tenia guard. Como
//   deleteGasto() revierte dinero al cuadre de caja si el gasto fue pagado
//   desde caja (ver gasto_service.dart), un doble-delete exitoso hubiera
//   revertido el dinero dos veces para el mismo gasto.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vercy_motos/models/cuadre_caja.dart';
import 'package:vercy_motos/models/gasto.dart';
import 'package:vercy_motos/models/tipo_gasto.dart';
import 'package:vercy_motos/providers/user_provider.dart';
import 'package:vercy_motos/screens/abrir_caja_screen.dart';
import 'package:vercy_motos/screens/cerrar_caja_screen.dart';
import 'package:vercy_motos/screens/gastos_screen.dart';
import 'package:vercy_motos/services/cuadre_caja_service.dart';
import 'package:vercy_motos/services/gasto_service.dart';
import 'package:vercy_motos/services/proveedor_service.dart';
import 'package:vercy_motos/models/proveedor.dart';

/// Fake de CuadreCajaService via ICuadreCajaService - CuadreCajaService es
/// singleton (factory constructor), por lo que no se puede `extends`.
class FakeCuadreCajaService implements ICuadreCajaService {
  FakeCuadreCajaService({List<CuadreCaja>? cajasAbiertas})
    : cajasAbiertas = cajasAbiertas ?? [];

  List<CuadreCaja> cajasAbiertas;
  int createCuadreCallCount = 0;
  int updateCuadreCallCount = 0;
  final List<String> idsActualizados = [];

  @override
  Future<List<CuadreCaja>> getAllCuadres() async => List.from(cajasAbiertas);

  @override
  Future<CuadreCaja> createCuadre({
    required String nombre,
    required String responsable,
    required double fondoInicial,
    required double efectivoDeclarado,
    required double efectivoEsperado,
    required double tolerancia,
    String? observaciones,
    String? tipoCaja,
  }) async {
    createCuadreCallCount++;
    return CuadreCaja(
      id: 'caja-creada-$createCuadreCallCount',
      nombre: nombre,
      responsable: responsable,
      fechaApertura: DateTime(2026, 1, 1),
      fondoInicial: fondoInicial,
      efectivoDeclarado: efectivoDeclarado,
      efectivoEsperado: efectivoEsperado,
      diferencia: 0,
      cuadrado: true,
      cerrada: false,
      tolerancia: tolerancia,
      tipoCaja: tipoCaja ?? 'LOCAL',
    );
  }

  @override
  Future<CuadreCaja> updateCuadre(
    String id, {
    String? nombre,
    String? responsable,
    double? fondoInicial,
    double? efectivoDeclarado,
    double? efectivoEsperado,
    double? tolerancia,
    String? observaciones,
    bool? cerrarCaja,
    String? estado,
  }) async {
    updateCuadreCallCount++;
    idsActualizados.add(id);
    final original = cajasAbiertas.firstWhere(
      (c) => c.id == id,
      orElse: () => CuadreCaja(
        nombre: nombre ?? 'Caja',
        responsable: responsable ?? 'Test',
        fechaApertura: DateTime(2026, 1, 1),
        fondoInicial: 0,
        efectivoDeclarado: 0,
        efectivoEsperado: 0,
        diferencia: 0,
        cuadrado: true,
        cerrada: false,
        tolerancia: 5,
      ),
    );
    return CuadreCaja(
      id: id,
      nombre: original.nombre,
      responsable: responsable ?? original.responsable,
      fechaApertura: original.fechaApertura,
      fondoInicial: original.fondoInicial,
      efectivoDeclarado: efectivoDeclarado ?? original.efectivoDeclarado,
      efectivoEsperado: original.efectivoEsperado,
      diferencia: 0,
      cuadrado: true,
      cerrada: cerrarCaja ?? original.cerrada,
      tolerancia: original.tolerancia,
      tipoCaja: original.tipoCaja,
    );
  }

  @override
  Future<Map<String, dynamic>> getCuadreCompleto({String? tipoCaja}) async =>
      {};

  @override
  Future<Map<String, dynamic>> getDetallesVentas({String? tipoCaja}) async =>
      {};

  @override
  Future<Map<String, dynamic>> getVentasPorTipoPago() async => {};

  @override
  Future<Map<String, dynamic>> getResumenVentasHoy() async => {};
}

/// Fake de GastoService via IGastoService - mismo motivo (singleton).
class FakeGastoService implements IGastoService {
  FakeGastoService({List<Gasto>? gastos}) : gastos = gastos ?? [];

  List<Gasto> gastos;
  int deleteGastoCallCount = 0;
  final List<String> idsEliminados = [];

  @override
  Future<List<Gasto>> getAllGastos() async => List.from(gastos);

  @override
  Future<List<Gasto>> getGastosByCuadre(String cuadreId) async =>
      List.from(gastos);

  @override
  Future<List<TipoGasto>> getAllTiposGasto() async => [];

  @override
  Future<Gasto> createGasto({
    required String cuadreCajaId,
    required String tipoGastoId,
    required String concepto,
    required double monto,
    required String responsable,
    DateTime? fechaGasto,
    String? numeroRecibo,
    String? numeroFactura,
    String? proveedor,
    String? formaPago,
    double? subtotal,
    double? impuestos,
    bool? pagadoDesdeCaja,
    double? montoEfectivo,
    double? montoTransferencia,
  }) async {
    throw UnimplementedError('no usado en estos tests');
  }

  @override
  Future<Gasto> updateGasto(
    String id, {
    String? cuadreCajaId,
    String? tipoGastoId,
    String? concepto,
    double? monto,
    String? responsable,
    DateTime? fechaGasto,
    String? numeroRecibo,
    String? numeroFactura,
    String? proveedor,
    String? formaPago,
    double? subtotal,
    double? impuestos,
    bool? pagadoDesdeCaja,
    double? montoEfectivo,
    double? montoTransferencia,
  }) async {
    throw UnimplementedError('no usado en estos tests');
  }

  @override
  Future<Map<String, dynamic>> deleteGasto(String id) async {
    deleteGastoCallCount++;
    idsEliminados.add(id);
    return {'success': true, 'message': 'Gasto eliminado exitosamente'};
  }

  @override
  Future<TipoGasto> createTipoGasto({
    required String nombre,
    String? descripcion,
    bool activo = true,
  }) async {
    throw UnimplementedError('no usado en estos tests');
  }
}

/// ProveedorService NO es singleton (constructor publico normal), asi que a
/// diferencia de CuadreCajaService/GastoService si se puede `extends`.
class FakeProveedorService extends ProveedorService {
  @override
  Future<List<Proveedor>> getProveedores() async => [];
}

Widget _wrapConUsuario(Widget child) {
  // UserProvider es singleton (factory constructor) - usar .value para no
  // que el ChangeNotifierProvider lo dispose al desmontar el test.
  return ChangeNotifierProvider<UserProvider>.value(
    value: UserProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  void setViewportGrande(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('AbrirCajaScreen', () {
    testWidgets(
      'doble-tap en "ABRIR CAJA" no crea la caja dos veces',
      (tester) async {
        setViewportGrande(tester);
        final fake = FakeCuadreCajaService(cajasAbiertas: []);

        await tester.pumpWidget(
          _wrapConUsuario(AbrirCajaScreen(cuadreCajaService: fake)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '100000');
        await tester.tap(find.text('ABRIR CAJA'), warnIfMissed: false);
        await tester.tap(find.text('ABRIR CAJA'), warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          fake.createCuadreCallCount,
          1,
          reason:
              'un doble-tap no debe abrir dos cajas del mismo tipo por una '
              'sola accion del usuario',
        );
      },
    );

    testWidgets(
      'con el monto inicial vacio, tocar "ABRIR CAJA" no llama al service',
      (tester) async {
        setViewportGrande(tester);
        final fake = FakeCuadreCajaService(cajasAbiertas: []);

        await tester.pumpWidget(
          _wrapConUsuario(AbrirCajaScreen(cuadreCajaService: fake)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('ABRIR CAJA'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(fake.createCuadreCallCount, 0);
      },
    );
  });

  group('CerrarCajaScreen', () {
    CuadreCaja cajaAbierta() => CuadreCaja(
      id: 'caja-1',
      nombre: 'Caja Local',
      responsable: 'Usuario Test',
      fechaApertura: DateTime(2026, 1, 1),
      fondoInicial: 0,
      efectivoDeclarado: 0,
      efectivoEsperado: 0,
      diferencia: 0,
      cuadrado: true,
      cerrada: false,
      tolerancia: 5,
      tipoCaja: 'LOCAL',
    );

    testWidgets(
      'doble-tap en "CERRAR CAJA" no abre dos dialogos ni actualiza el cuadre dos veces',
      (tester) async {
        setViewportGrande(tester);
        final fake = FakeCuadreCajaService(cajasAbiertas: [cajaAbierta()]);

        await tester.pumpWidget(
          _wrapConUsuario(CerrarCajaScreen(cuadreCajaService: fake)),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        await tester.tap(find.text('CERRAR CAJA'), warnIfMissed: false);
        await tester.tap(find.text('CERRAR CAJA'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          find.byType(AlertDialog),
          findsOneWidget,
          reason: 'el segundo toque debe ser descartado por runGuarded antes '
              'de abrir un segundo dialogo apilado',
        );

        final campoEfectivo = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(campoEfectivo, '0');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmar'), warnIfMissed: false);
        // pump() acotado, NO pumpAndSettle(): tras confirmar, _isLoading
        // muestra un CircularProgressIndicator indeterminado que nunca deja
        // de animar (y luego "_descargandoExcel" hace lo mismo) - settle()
        // esperaria para siempre. updateCuadre() del fake resuelve en un
        // microtask, asi que un par de pumps acotados alcanzan para
        // capturar la llamada sin depender de que la pantalla "se asiente".
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          fake.updateCuadreCallCount,
          1,
          reason: 'un doble-tap no debe cerrar la misma caja dos veces',
        );
        expect(fake.idsActualizados, ['caja-1']);

        // Drenar el timer de 2s de _descargarExcelYMostrarConciliacion (y el
        // de la SnackBar de exito) antes de que termine el test - sin esto,
        // flutter_test falla con "A Timer is still pending even after the
        // widget tree was disposed."
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'cancelar el dialogo de efectivo declarado no llama a updateCuadre',
      (tester) async {
        setViewportGrande(tester);
        final fake = FakeCuadreCajaService(cajasAbiertas: [cajaAbierta()]);

        await tester.pumpWidget(
          _wrapConUsuario(CerrarCajaScreen(cuadreCajaService: fake)),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        await tester.tap(find.text('CERRAR CAJA'), warnIfMissed: false);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(fake.updateCuadreCallCount, 0);
      },
    );
  });

  group('GastosScreen', () {
    Gasto gastoDeEjemplo() => Gasto(
      id: 'gasto-1',
      cuadreCajaId: 'caja-1',
      tipoGastoId: 'tipo-1',
      tipoGastoNombre: 'Servicios',
      concepto: 'Pago de luz',
      monto: 50000,
      responsable: 'Usuario Test',
      fechaGasto: DateTime(2026, 1, 1),
      pagadoDesdeCaja: true,
    );

    testWidgets(
      'doble-tap en "Eliminar" del mismo gasto no lo elimina dos veces',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fake = FakeGastoService(gastos: [gastoDeEjemplo()]);

        await tester.pumpWidget(
          MaterialApp(
            home: GastosScreen(
              gastoService: fake,
              // Sin esto, _initializeData() llama a los singletons reales
              // de CuadreCajaService/ProveedorService, cuyo _getToken() pasa
              // por FlutterSecureStorage - un MethodChannel sin handler
              // registrado en el entorno de test que nunca responde, y
              // pumpAndSettle() queda esperando para siempre.
              cuadreCajaService: FakeCuadreCajaService(),
              proveedorService: FakeProveedorService(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Eliminar').first, warnIfMissed: false);
        await tester.tap(find.text('Eliminar').first, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          find.byType(AlertDialog),
          findsOneWidget,
          reason: 'el segundo toque debe ser descartado por runGuarded antes '
              'de abrir un segundo dialogo apilado',
        );

        final botonEliminarDelDialogo = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Eliminar'),
        );
        await tester.tap(botonEliminarDelDialogo, warnIfMissed: false);
        // pump() acotado, NO pumpAndSettle(): _isLoading muestra un
        // CircularProgressIndicator indeterminado mientras se resuelve
        // deleteGasto() - settle() esperaria para siempre.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          fake.deleteGastoCallCount,
          1,
          reason:
              'deleteGasto revierte dinero a la caja si el gasto fue pagado '
              'desde caja - un doble-delete hubiera revertido el dinero dos '
              'veces para el mismo gasto',
        );
        expect(fake.idsEliminados, ['gasto-1']);
      },
    );
  });
}
