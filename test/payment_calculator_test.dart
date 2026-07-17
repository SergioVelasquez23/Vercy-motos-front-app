import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/item_pedido.dart';
import 'package:vercy_motos/models/pedido.dart';
import 'package:vercy_motos/utils/payment_calculator.dart';

ItemPedido _item({required double precio, required int cantidad}) {
  return ItemPedido(productoId: 'p1', cantidad: cantidad, precioUnitario: precio);
}

Pedido _pedido({
  List<ItemPedido> items = const [],
  double descuento = 0,
  double propina = 0,
  double totalPagado = 0,
  EstadoPedido estado = EstadoPedido.activo,
}) {
  return Pedido(
    id: 'id-1',
    fecha: DateTime(2026, 7, 1),
    tipo: TipoPedido.normal,
    mesa: 'FACTURACION',
    mesero: 'cajero',
    items: items,
    total: 0,
    estado: estado,
    descuento: descuento,
    propina: propina,
    totalPagado: totalPagado,
  );
}

void main() {
  group('calcularSubtotal', () {
    test('suma precioUnitario x cantidad de todos los items', () {
      final pedido = _pedido(items: [
        _item(precio: 10000, cantidad: 2),
        _item(precio: 5000, cantidad: 3),
      ]);

      expect(PaymentCalculator.calcularSubtotal(pedido), 35000);
    });

    test('un pedido sin items tiene subtotal 0', () {
      expect(PaymentCalculator.calcularSubtotal(_pedido()), 0);
    });
  });

  group('aplicarDescuento', () {
    test('aplica solo descuento por porcentaje', () {
      expect(PaymentCalculator.aplicarDescuento(100000, 10, 0), 90000);
    });

    test('aplica solo descuento por valor fijo', () {
      expect(PaymentCalculator.aplicarDescuento(100000, 0, 5000), 95000);
    });

    test('aplica porcentaje primero y luego el valor fijo', () {
      // 100000 - 10% = 90000, luego -5000 = 85000
      expect(PaymentCalculator.aplicarDescuento(100000, 10, 5000), 85000);
    });

    test('nunca devuelve un total negativo', () {
      expect(PaymentCalculator.aplicarDescuento(1000, 0, 5000), 0);
    });

    test('sin descuentos devuelve el total original', () {
      expect(PaymentCalculator.aplicarDescuento(50000, 0, 0), 50000);
    });
  });

  group('calcularTotalConPropina', () {
    test('suma la propina al total con descuento', () {
      expect(PaymentCalculator.calcularTotalConPropina(90000, 5000), 95000);
    });
  });

  group('calcularTotalReal', () {
    test('subtotal de items - descuento + propina', () {
      final pedido = _pedido(
        items: [_item(precio: 50000, cantidad: 2)], // subtotal 100000
        descuento: 10000,
        propina: 5000,
      );

      expect(PaymentCalculator.calcularTotalReal(pedido), 95000);
    });
  });

  group('calcularTotalRealDetalle', () {
    test('totalBase - descuento + propina', () {
      expect(PaymentCalculator.calcularTotalRealDetalle(100000, 10000, 5000), 95000);
    });
  });

  group('calcularTotalItems', () {
    test('suma el subtotal (precio x cantidad) de cada item', () {
      final items = [
        _item(precio: 10000, cantidad: 1),
        _item(precio: 20000, cantidad: 2),
      ];

      expect(PaymentCalculator.calcularTotalItems(items), 50000);
    });

    test('una lista vacia da 0', () {
      expect(PaymentCalculator.calcularTotalItems(const []), 0);
    });
  });

  group('calcularEstadisticasVentas', () {
    test('solo cuenta pedidos pagados y usa totalPagado cuando esta disponible', () {
      final pedidos = [
        _pedido(estado: EstadoPedido.pagado, totalPagado: 100000, descuento: 5000, propina: 2000),
        _pedido(estado: EstadoPedido.pagado, totalPagado: 50000, descuento: 0, propina: 1000),
        _pedido(estado: EstadoPedido.activo, totalPagado: 0), // no pagado, se ignora
      ];

      final stats = PaymentCalculator.calcularEstadisticasVentas(pedidos);

      expect(stats['pedidosPagados'], 2);
      expect(stats['totalVentas'], 150000);
      expect(stats['totalDescuentos'], 5000);
      expect(stats['totalPropinas'], 3000);
      expect(stats['promedioVenta'], 75000);
    });

    test('sin pedidos pagados el promedio es 0 (no divide por cero)', () {
      final stats = PaymentCalculator.calcularEstadisticasVentas(
        [_pedido(estado: EstadoPedido.activo)],
      );

      expect(stats['pedidosPagados'], 0);
      expect(stats['promedioVenta'], 0.0);
    });

    test('un pedido pagado sin totalPagado cae al calculo local (items - descuento + propina)', () {
      final pedidos = [
        _pedido(
          estado: EstadoPedido.pagado,
          totalPagado: 0,
          items: [_item(precio: 40000, cantidad: 1)],
          descuento: 0,
          propina: 0,
        ),
      ];

      final stats = PaymentCalculator.calcularEstadisticasVentas(pedidos);

      expect(stats['totalVentas'], 40000);
    });
  });
}
