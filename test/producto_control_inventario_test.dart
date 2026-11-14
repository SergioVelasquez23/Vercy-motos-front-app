import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/producto.dart';

Producto _nuevo({String? control}) => Producto(
      id: '',
      nombre: 'CASCO',
      precio: 1000,
      costo: 500,
      utilidad: 500,
      estado: 'Activo',
      controlInventario: control,
    );

void main() {
  test("un producto nuevo con 'SI' envía controlInventario=true al backend", () {
    expect(_nuevo(control: 'SI').toJson()['controlInventario'], isTrue);
  });

  test("con 'NO' envía false; sin valor no envía nada (el backend lo crea controlado)", () {
    expect(_nuevo(control: 'NO').toJson()['controlInventario'], isFalse);
    expect(_nuevo().toJson().containsKey('controlInventario'), isFalse);
  });
}
