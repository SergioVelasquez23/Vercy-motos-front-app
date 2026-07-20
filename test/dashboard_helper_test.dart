import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/pedido.dart';
import 'package:vercy_motos/utils/dashboard_helper.dart';

Pedido _pedido({
  required EstadoPedido estado,
  double total = 0.0,
  double totalPagado = 0.0,
  DateTime? fechaPago,
  String? formaPago,
  String? pagadoPor,
}) {
  return Pedido(
    id: 'p-${DateTime.now().microsecondsSinceEpoch}',
    fecha: DateTime(2026, 7, 1),
    tipo: TipoPedido.normal,
    mesa: '1',
    mesero: 'Mesero de prueba',
    items: const [],
    total: total,
    estado: estado,
    totalPagado: totalPagado,
    fechaPago: fechaPago,
    formaPago: formaPago,
    pagadoPor: pagadoPor,
  );
}

void main() {
  group('DashboardHelper.esPedidoPagado', () {
    test('delega en Pedido.estaPagado', () {
      final pagado = _pedido(estado: EstadoPedido.pagado);
      final activo = _pedido(estado: EstadoPedido.activo);

      expect(DashboardHelper.esPedidoPagado(pagado), isTrue);
      expect(DashboardHelper.esPedidoPagado(activo), isFalse);
    });
  });

  group('DashboardHelper.calcularTotalVentas', () {
    test('suma solo los pedidos pagados, ignora los activos/cancelados', () {
      final pedidos = [
        _pedido(estado: EstadoPedido.pagado, total: 100000),
        _pedido(estado: EstadoPedido.activo, total: 999999),
        _pedido(estado: EstadoPedido.cancelado, total: 999999),
        _pedido(estado: EstadoPedido.pagado, total: 50000),
      ];

      expect(DashboardHelper.calcularTotalVentas(pedidos), 150000);
    });

    test('usa totalPagado cuando es mayor a 0, en vez del total original', () {
      final pedido = _pedido(estado: EstadoPedido.pagado, total: 100000, totalPagado: 80000);

      expect(DashboardHelper.calcularTotalVentas([pedido]), 80000);
    });

    test('usa total cuando totalPagado es 0', () {
      final pedido = _pedido(estado: EstadoPedido.pagado, total: 100000, totalPagado: 0);

      expect(DashboardHelper.calcularTotalVentas([pedido]), 100000);
    });

    test('cuenta cortesía como pagado (estaPagado lo incluye)', () {
      final cortesia = _pedido(estado: EstadoPedido.cortesia, total: 30000);

      expect(DashboardHelper.calcularTotalVentas([cortesia]), 30000);
    });

    test('un pedido activo con fechaPago asignada cuenta como pagado', () {
      final pedido = _pedido(
        estado: EstadoPedido.activo,
        total: 45000,
        fechaPago: DateTime(2026, 7, 5),
      );

      expect(DashboardHelper.calcularTotalVentas([pedido]), 45000);
    });

    test('lista vacía da 0', () {
      expect(DashboardHelper.calcularTotalVentas([]), 0.0);
    });
  });
}