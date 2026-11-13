import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/resumen_cierre_completo.dart';

Map<String, dynamic> _json({Object? efectivo = _ausente, double desdeCaja = 500}) => {
      'gastosPorTipo': <String, dynamic>{},
      'totalGastos': 500.0,
      'totalRegistros': 1,
      'totalGastosIncluyendoFacturas': 500.0,
      'totalGastosDesdeCaja': desdeCaja,
      if (efectivo != _ausente) 'totalGastosEfectivoDesdeCaja': efectivo,
      'detallesGastos': <dynamic>[],
      'gastosPorFormaPago': <String, dynamic>{},
      'facturasPagadasDesdeCaja': 0.0,
      'cantidadPorTipo': <String, dynamic>{},
    };

const Object _ausente = Object();

void main() {
  group('ResumenGastosCompleto - gasto mixto desde caja', () {
    test('un gasto mixto: 500 desde caja pero solo 250 salió del efectivo', () {
      final r = ResumenGastosCompleto.fromJson(_json(efectivo: 250.0));

      expect(r.totalGastosDesdeCaja, 500.0);
      expect(r.totalGastosEfectivoDesdeCaja, 250.0);
      expect(r.hayGastoMixtoDesdeCaja, isTrue);
    });

    test('si todo salió en efectivo no hay línea extra', () {
      final r = ResumenGastosCompleto.fromJson(_json(efectivo: 500.0));

      expect(r.hayGastoMixtoDesdeCaja, isFalse);
    });

    test('un backend anterior sin el campo: se asume todo efectivo, sin línea extra', () {
      final r = ResumenGastosCompleto.fromJson(_json());

      expect(r.totalGastosEfectivoDesdeCaja, 500.0);
      expect(r.hayGastoMixtoDesdeCaja, isFalse);
    });

    test('acepta el valor como texto o entero', () {
      expect(ResumenGastosCompleto.fromJson(_json(efectivo: '250')).totalGastosEfectivoDesdeCaja, 250.0);
      expect(ResumenGastosCompleto.fromJson(_json(efectivo: 250)).totalGastosEfectivoDesdeCaja, 250.0);
    });

    test('sin gastos desde caja: cero y sin línea extra', () {
      final r = ResumenGastosCompleto.fromJson(_json(efectivo: 0.0, desdeCaja: 0));

      expect(r.hayGastoMixtoDesdeCaja, isFalse);
    });
  });
}
