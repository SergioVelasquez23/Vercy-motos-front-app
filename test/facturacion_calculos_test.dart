import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/facturacion_calculos.dart';

void main() {
  group('extraerPrecioBaseDeGravado', () {
    test('extrae el precio neto de un precio con IVA del 19% incluido', () {
      expect(extraerPrecioBaseDeGravado(119, 19), closeTo(100, 0.001));
    });

    test('con IVA 0% devuelve el mismo precio', () {
      expect(extraerPrecioBaseDeGravado(50000, 0), 50000);
    });

    test('con un porcentaje >= 100 (dato inválido) devuelve el precio tal cual', () {
      expect(extraerPrecioBaseDeGravado(50000, 100), 50000);
      expect(extraerPrecioBaseDeGravado(50000, 150), 50000);
    });

    test('con un porcentaje negativo (dato inválido) devuelve el precio tal cual', () {
      expect(extraerPrecioBaseDeGravado(50000, -5), 50000);
    });
  });

  group('calcularItemFactura', () {
    test('caso típico: descuento en porcentaje + IVA 19%', () {
      final r = calcularItemFactura(
        cantidad: 2,
        precioUnitario: 50000,
        porcentajeImpuesto: 19,
        descuentoIngresado: 10, // 10%
      );

      expect(r.subtotal, 100000);
      expect(r.valorDescuento, 10000);
      expect(r.porcentajeDescuento, 10);
      expect(r.valorImpuesto, closeTo(17100, 0.001)); // (100000-10000)*0.19
      expect(r.total, closeTo(107100, 0.001));
    });

    test('descuento como valor fijo en pesos calcula el porcentaje equivalente', () {
      final r = calcularItemFactura(
        cantidad: 1,
        precioUnitario: 100000,
        porcentajeImpuesto: 19,
        descuentoIngresado: 5000,
        descuentoEsPorcentaje: false,
      );

      expect(r.valorDescuento, 5000);
      expect(r.porcentajeDescuento, 5);
    });

    test('descuento fijo con subtotal 0 no divide por cero', () {
      final r = calcularItemFactura(
        cantidad: 0,
        precioUnitario: 100000,
        porcentajeImpuesto: 19,
        descuentoIngresado: 5000,
        descuentoEsPorcentaje: false,
      );

      expect(r.subtotal, 0);
      expect(r.porcentajeDescuento, 0);
    });

    test('IVA 0% no genera impuesto', () {
      final r = calcularItemFactura(
        cantidad: 1,
        precioUnitario: 10000,
        porcentajeImpuesto: 0,
        descuentoIngresado: 0,
      );

      expect(r.valorImpuesto, 0);
      expect(r.total, 10000);
    });

    test('sin descuento el total es subtotal + IVA', () {
      final r = calcularItemFactura(
        cantidad: 3,
        precioUnitario: 20000,
        porcentajeImpuesto: 19,
        descuentoIngresado: 0,
      );

      expect(r.subtotal, 60000);
      expect(r.valorDescuento, 0);
      expect(r.total, closeTo(60000 * 1.19, 0.001));
    });
  });

  group('recalcularBaseDesdeTotal', () {
    test('es la inversa de calcularItemFactura: recompone el precio unitario original', () {
      const cantidad = 2.0;
      const precioOriginal = 50000.0;
      const iva = 19.0;
      const descuentoPct = 10.0;

      final directo = calcularItemFactura(
        cantidad: cantidad,
        precioUnitario: precioOriginal,
        porcentajeImpuesto: iva,
        descuentoIngresado: descuentoPct,
      );

      final inverso = recalcularBaseDesdeTotal(
        nuevoTotal: directo.total,
        cantidad: cantidad,
        porcentajeImpuesto: iva,
        porcentajeDescuento: descuentoPct,
      );

      expect(inverso.precioUnitario, closeTo(precioOriginal, 0.01));
      expect(inverso.valorDescuento, closeTo(directo.valorDescuento, 0.01));
      expect(inverso.valorImpuesto, closeTo(directo.valorImpuesto, 0.01));
    });

    test('con cantidad 0 no divide por cero', () {
      final r = recalcularBaseDesdeTotal(
        nuevoTotal: 100000,
        cantidad: 0,
        porcentajeImpuesto: 19,
        porcentajeDescuento: 0,
      );

      expect(r.precioUnitario.isFinite, isTrue);
    });

    test('con 100% de descuento (denominador 0) no divide por cero', () {
      final r = recalcularBaseDesdeTotal(
        nuevoTotal: 100000,
        cantidad: 1,
        porcentajeImpuesto: 19,
        porcentajeDescuento: 100,
      );

      expect(r.precioUnitario.isFinite, isTrue);
    });
  });
}
