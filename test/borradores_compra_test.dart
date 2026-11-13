import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vercy_motos/models/borrador_compra.dart';
import 'package:vercy_motos/services/borrador_compra_service.dart';
import 'package:vercy_motos/utils/migracion_borradores_compra.dart';

/// Servicio falso en memoria: guarda en una lista y puede fallar a propósito.
class _FakeBorradorService implements IBorradorCompraService {
  final List<Map<String, dynamic>> guardados = [];
  int? fallarEnElGuardado; // 1-based: falla al intentar el N-ésimo guardado

  int _intentos = 0;

  @override
  Future<BorradorCompra> guardar(Map<String, dynamic> datos) async {
    _intentos++;
    if (fallarEnElGuardado == _intentos) throw Exception('sin conexión');
    guardados.add(datos);
    return BorradorCompra(id: 'b$_intentos', datos: datos);
  }

  @override
  Future<List<BorradorCompra>> listar() async => [];

  @override
  Future<void> eliminar(String id) async {}
}

void main() {
  group('migrarBorradoresCompraLocales', () {
    test('sin nada guardado en el navegador no sube nada', () async {
      SharedPreferences.setMockInitialValues({});
      final servicio = _FakeBorradorService();

      expect(await migrarBorradoresCompraLocales(servicio), 0);
      expect(servicio.guardados, isEmpty);
    });

    test('sube del más antiguo al más nuevo y limpia la copia local', () async {
      SharedPreferences.setMockInitialValues({
        kClaveBorradoresCompraLocales:
            '[{"proveedorNombre":"A","items":[]},{"proveedorNombre":"B","items":[]},{"proveedorNombre":"C","items":[]}]',
      });
      final servicio = _FakeBorradorService();

      expect(await migrarBorradoresCompraLocales(servicio), 3);
      expect(servicio.guardados.map((d) => d['proveedorNombre']), ['A', 'B', 'C']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kClaveBorradoresCompraLocales), isNull);
    });

    test('si falla a mitad conserva los pendientes y al reintentar no duplica', () async {
      SharedPreferences.setMockInitialValues({
        kClaveBorradoresCompraLocales:
            '[{"proveedorNombre":"A"},{"proveedorNombre":"B"},{"proveedorNombre":"C"}]',
      });
      final servicio = _FakeBorradorService()..fallarEnElGuardado = 2;

      // sube A, falla en B
      expect(await migrarBorradoresCompraLocales(servicio), 1);
      expect(servicio.guardados.map((d) => d['proveedorNombre']), ['A']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kClaveBorradoresCompraLocales), contains('"B"'));
      expect(prefs.getString(kClaveBorradoresCompraLocales), isNot(contains('"A"')));

      // reintento (ya sin fallo): suben B y C, A no se repite
      expect(await migrarBorradoresCompraLocales(servicio), 2);
      expect(servicio.guardados.map((d) => d['proveedorNombre']), ['A', 'B', 'C']);
      expect(prefs.getString(kClaveBorradoresCompraLocales), isNull);
    });

    test('una copia local corrupta se descarta sin lanzar', () async {
      SharedPreferences.setMockInitialValues({kClaveBorradoresCompraLocales: 'esto no es json'});
      final servicio = _FakeBorradorService();

      expect(await migrarBorradoresCompraLocales(servicio), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kClaveBorradoresCompraLocales), isNull);
    });
  });

  group('BorradorCompra.fromJson', () {
    test('lee el formato del servidor', () {
      final b = BorradorCompra.fromJson({
        '_id': 'abc123',
        'usuarioNombre': 'ana',
        'proveedorNombre': 'Industrias Pg',
        'cantidadItems': 2,
        'fechaCreacion': '2026-11-12T22:10:03.123',
        'datos': {'numeroFactura': 'F-1', 'items': [{}, {}]},
      });

      expect(b.id, 'abc123');
      expect(b.proveedorNombre, 'Industrias Pg');
      expect(b.cantidadItems, 2);
      expect(b.fechaCreacion, DateTime(2026, 11, 12, 22, 10, 3, 123));
      expect(b.datos['numeroFactura'], 'F-1');
    });

    test('tolera campos ausentes', () {
      final b = BorradorCompra.fromJson({'_id': 'x'});

      expect(b.id, 'x');
      expect(b.cantidadItems, 0);
      expect(b.fechaCreacion, isNull);
      expect(b.datos, isEmpty);
    });
  });
}
