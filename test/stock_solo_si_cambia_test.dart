import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/producto.dart';
import 'package:vercy_motos/services/producto_service.dart';

Producto _p({int? almacen, int? bodega}) => Producto(
      id: 'p1',
      nombre: 'CASCO',
      precio: 1000,
      costo: 500,
      utilidad: 500,
      estado: 'Activo',
      almacen: almacen,
      bodega: bodega,
    );

void main() {
  // Regresión: el formulario mandaba siempre el stock que cargó. Si en el medio se vendían unidades, o solo
  // se contaba una de las dos ubicaciones, el número viejo pisaba el stock real.
  test('si no cambió nada, no se envía stock', () {
    final original = _p(almacen: 10, bodega: 4);
    expect(ProductoService.camposDeStockModificados(_p(almacen: 10, bodega: 4), original), isEmpty);
  });

  test('si solo se contó el almacén, la bodega NO se envía (no se pisa con el número viejo)', () {
    final original = _p(almacen: 10, bodega: 4);
    final campos = ProductoService.camposDeStockModificados(_p(almacen: 7, bodega: 4), original);
    expect(campos, {'cantidadAlmacen': 7});
  });

  test('si cambiaron las dos ubicaciones, se envían las dos', () {
    final original = _p(almacen: 10, bodega: 4);
    final campos = ProductoService.camposDeStockModificados(_p(almacen: 3, bodega: 9), original);
    expect(campos, {'cantidadAlmacen': 3, 'cantidadBodega': 9});
  });

  test('un valor nuevo en 0 cuenta como cambio (contar cero es válido)', () {
    final original = _p(almacen: 10, bodega: 4);
    expect(ProductoService.camposDeStockModificados(_p(almacen: 0, bodega: 4), original), {'cantidadAlmacen': 0});
  });

  test('sin producto original se envía lo que haya (comportamiento previo, p. ej. productos nuevos)', () {
    expect(ProductoService.camposDeStockModificados(_p(almacen: 5, bodega: 2), null),
        {'cantidadAlmacen': 5, 'cantidadBodega': 2});
    expect(ProductoService.camposDeStockModificados(_p(), null), isEmpty);
  });
}
