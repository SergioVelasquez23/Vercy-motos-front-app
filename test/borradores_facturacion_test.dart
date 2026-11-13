import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/pedido.dart';
import 'package:vercy_motos/utils/borradores_utils.dart';

Pedido _borrador({required String mesero, String? guardadoPor}) => Pedido(
      id: 'p-$mesero-${guardadoPor ?? 'x'}',
      fecha: DateTime(2026, 11, 12),
      tipo: TipoPedido.normal,
      mesa: 'FACTURACION',
      mesero: mesero,
      guardadoPor: guardadoPor,
      items: const [],
      total: 0,
      estado: EstadoPedido.activo,
    );

void main() {
  group('filtrarBorradoresDelUsuario (facturación)', () {
    test('cada usuario ve solo sus borradores', () {
      final todos = [
        _borrador(mesero: 'dahiana', guardadoPor: 'dahiana'),
        _borrador(mesero: 'brayan', guardadoPor: 'brayan'),
        _borrador(mesero: 'dahiana', guardadoPor: 'dahiana'),
      ];

      expect(filtrarBorradoresDelUsuario(todos, 'dahiana'), hasLength(2));
      expect(filtrarBorradoresDelUsuario(todos, 'brayan'), hasLength(1));
      expect(filtrarBorradoresDelUsuario(todos, 'otro'), isEmpty);
    });

    test('los borradores antiguos, sin guardadoPor, se asignan por mesero', () {
      final todos = [_borrador(mesero: 'dahiana'), _borrador(mesero: 'brayan')];

      final mios = filtrarBorradoresDelUsuario(todos, 'dahiana');
      expect(mios, hasLength(1));
      expect(mios.single.mesero, 'dahiana');
    });

    test('en ENVÍOS el borrador es de quien lo guardó, no del facturador elegido', () {
      // dahiana guarda, pero elige a brayan como facturador (mesero)
      final envios = [_borrador(mesero: 'brayan', guardadoPor: 'dahiana')];

      expect(filtrarBorradoresDelUsuario(envios, 'dahiana'), hasLength(1));
      expect(filtrarBorradoresDelUsuario(envios, 'brayan'), isEmpty);
    });

    test('ignora mayúsculas y espacios al comparar', () {
      final todos = [_borrador(mesero: 'Dahiana ', guardadoPor: ' Dahiana')];

      expect(filtrarBorradoresDelUsuario(todos, 'dahiana'), hasLength(1));
      expect(filtrarBorradoresDelUsuario(todos, '  DAHIANA '), hasLength(1));
    });

    test('si no se conoce al usuario devuelve todos, en vez de esconder borradores', () {
      final todos = [_borrador(mesero: 'a'), _borrador(mesero: 'b')];

      expect(filtrarBorradoresDelUsuario(todos, null), hasLength(2));
      expect(filtrarBorradoresDelUsuario(todos, '  '), hasLength(2));
    });
  });
}
