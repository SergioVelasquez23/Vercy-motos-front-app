import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/cuadre_caja.dart';

CuadreCaja _caja(String estado) => CuadreCaja.fromJson({
      '_id': 'c1',
      'nombre': 'Caja',
      'responsable': 'x',
      'estado': estado,
    });

void main() {
  // Regresión: registrarIngreso buscaba estado == 'pendiente', pero el backend manda
  // 'ABIERTA' para una caja abierta: el ingreso quedaba sin caja y nada lo contaba.
  test('una caja ABIERTA del backend cuenta como abierta', () {
    expect(_caja('ABIERTA').estaAbierta, isTrue);
  });

  test('una caja CERRADA no cuenta como abierta', () {
    expect(_caja('CERRADA').estaAbierta, isFalse);
  });
}
