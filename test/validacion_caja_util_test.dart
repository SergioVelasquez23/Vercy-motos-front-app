import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/validacion_caja_util.dart';

Map<String, dynamic> _json({dynamic totalEfectivoEnCaja = 100000}) {
  return {
    'fondoInicial': 50000,
    'totalVentas': 200000,
    'ventasEfectivo': 100000,
    'ventasTransferencias': 80000,
    'ventasTarjetas': 20000,
    'totalPedidos': 10,
    'cantidadEfectivo': 5,
    'cantidadTransferencias': 3,
    'cantidadTarjetas': 2,
    'totalGastos': 30000,
    'gastosDesdeCaja': 20000,
    'gastosNoDesdeCaja': 10000,
    'efectivoEsperadoPorVentas': 120000,
    'totalEfectivoEnCaja': totalEfectivoEnCaja,
  };
}

void main() {
  group('DetallesEfectivo.fromJson', () {
    test('parsea correctamente cuando los montos vienen como int', () {
      final detalles = DetallesEfectivo.fromJson(_json(totalEfectivoEnCaja: 100000));

      expect(detalles.totalEfectivoEnCaja, 100000.0);
      expect(detalles.fondoInicial, 50000.0);
      expect(detalles.totalPedidos, 10);
    });

    test('parsea correctamente cuando un monto viene como double', () {
      final detalles = DetallesEfectivo.fromJson(_json(totalEfectivoEnCaja: 100000.5));

      expect(detalles.totalEfectivoEnCaja, 100000.5);
    });

    test('parsea correctamente cuando un monto viene como String (el backend a veces lo manda así)', () {
      final detalles = DetallesEfectivo.fromJson(_json(totalEfectivoEnCaja: '100000'));

      expect(detalles.totalEfectivoEnCaja, 100000.0);
    });

    test('un monto nulo se convierte en 0.0 en vez de lanzar', () {
      final detalles = DetallesEfectivo.fromJson(_json(totalEfectivoEnCaja: null));

      expect(detalles.totalEfectivoEnCaja, 0.0);
    });

    test('un String no numérico se convierte en 0.0 en vez de lanzar', () {
      final detalles = DetallesEfectivo.fromJson(_json(totalEfectivoEnCaja: 'no-es-un-numero'));

      expect(detalles.totalEfectivoEnCaja, 0.0);
    });

    test('campos enteros ausentes del JSON se convierten en 0', () {
      final json = _json()..remove('totalPedidos');
      final detalles = DetallesEfectivo.fromJson(json);

      expect(detalles.totalPedidos, 0);
    });
  });
}