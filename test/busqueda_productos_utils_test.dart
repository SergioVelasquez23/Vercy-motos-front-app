import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/producto.dart';
import 'package:vercy_motos/utils/busqueda_productos_utils.dart';

Producto _producto({
  String id = 'p1',
  required String nombre,
  String? codigo,
  String? codigoBarras,
}) {
  return Producto(
    id: id,
    nombre: nombre,
    precio: 50000,
    costo: 30000,
    utilidad: 20000,
    codigo: codigo,
    codigoBarras: codigoBarras,
  );
}

void main() {
  group('busquedaInteligente', () {
    test('coincide por nombre sin importar mayúsculas/minúsculas', () {
      final producto = _producto(nombre: 'Casco Integral MT');

      expect(busquedaInteligente(producto, 'casco'), isTrue);
      expect(busquedaInteligente(producto, 'CASCO'), isTrue);
    });

    test('ignora acentos', () {
      final producto = _producto(nombre: 'Cámara de Aire');

      expect(busquedaInteligente(producto, 'camara'), isTrue);
      expect(busquedaInteligente(producto, 'Cámara'), isTrue);
    });

    test('maneja plurales: buscar en singular encuentra el nombre en plural', () {
      final producto = _producto(nombre: 'Carpas para moto');

      expect(busquedaInteligente(producto, 'carpa'), isTrue);
    });

    test('maneja plurales: buscar en plural encuentra el nombre en singular', () {
      final producto = _producto(nombre: 'Casco integral');

      expect(busquedaInteligente(producto, 'cascos'), isTrue);
    });

    test('coincide por código exacto o parcial, aunque el nombre no coincida', () {
      final producto = _producto(nombre: 'Producto sin relación', codigo: 'MOM-123');

      expect(busquedaInteligente(producto, 'MOM-123'), isTrue);
      expect(busquedaInteligente(producto, 'mom'), isTrue);
    });

    test('coincide por código de barras', () {
      final producto = _producto(nombre: 'Aceite 20W50', codigoBarras: '7701234567890');

      expect(busquedaInteligente(producto, '7701234'), isTrue);
    });

    test('con varias palabras clave, requiere que todas coincidan', () {
      final producto = _producto(nombre: 'Casco Integral Rojo');

      expect(busquedaInteligente(producto, 'casco rojo'), isTrue);
      expect(busquedaInteligente(producto, 'casco azul'), isFalse);
    });

    test('una búsqueda vacía nunca coincide', () {
      final producto = _producto(nombre: 'Casco Integral');

      expect(busquedaInteligente(producto, ''), isFalse);
      expect(busquedaInteligente(producto, '   '), isFalse);
    });

    test('un nombre que no contiene la búsqueda no coincide', () {
      final producto = _producto(nombre: 'Guante de cuero');

      expect(busquedaInteligente(producto, 'casco'), isFalse);
    });
  });

  group('calcularRelevancia', () {
    test('una coincidencia exacta de código puntúa más que cualquier otra cosa', () {
      final exacto = _producto(nombre: 'Producto genérico', codigo: 'ABC');
      final soloNombre = _producto(nombre: 'ABC producto que empieza igual');

      expect(calcularRelevancia(exacto, 'ABC'), 1000);
      expect(calcularRelevancia(soloNombre, 'ABC'), lessThan(1000));
    });

    test('un nombre que empieza con la búsqueda puntúa más que uno que solo la contiene', () {
      final empiezaCon = _producto(nombre: 'Casco integral');
      final contiene = _producto(nombre: 'Guante y casco combo');

      expect(
        calcularRelevancia(empiezaCon, 'casco'),
        greaterThan(calcularRelevancia(contiene, 'casco')),
      );
    });

    test('búsqueda vacía da 0', () {
      final producto = _producto(nombre: 'Casco integral');

      expect(calcularRelevancia(producto, ''), 0);
    });

    test('sin ninguna coincidencia da 0', () {
      final producto = _producto(nombre: 'Guante de cuero');

      expect(calcularRelevancia(producto, 'casco'), 0);
    });
  });

  group('filtrarYOrdenarProductos', () {
    final productos = [
      _producto(id: '1', nombre: 'Guante de cuero'),
      _producto(id: '2', nombre: 'Casco Integral Rojo'),
      _producto(id: '3', nombre: 'Casco', codigo: 'CASCO'),
      _producto(id: '4', nombre: 'Combo casco y guante'),
    ];

    test('una búsqueda de menos de 2 caracteres da lista vacía', () {
      expect(filtrarYOrdenarProductos(productos, 'c'), isEmpty);
      expect(filtrarYOrdenarProductos(productos, ''), isEmpty);
    });

    test('filtra solo los productos que coinciden', () {
      final resultado = filtrarYOrdenarProductos(productos, 'guante');

      expect(resultado.map((p) => p.id), containsAll(['1', '4']));
      expect(resultado.any((p) => p.id == '2'), isFalse);
    });

    test('ordena por relevancia: coincidencia exacta de código primero', () {
      final resultado = filtrarYOrdenarProductos(productos, 'CASCO');

      expect(resultado.first.id, '3'); // código exacto = 1000 puntos
    });

    test('respeta el límite de resultados', () {
      final resultado = filtrarYOrdenarProductos(productos, 'casco', limite: 1);

      expect(resultado.length, 1);
    });
  });
}