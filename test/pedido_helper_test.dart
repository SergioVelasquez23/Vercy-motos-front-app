import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/item_pedido.dart';
import 'package:vercy_motos/models/producto.dart';
import 'package:vercy_motos/utils/pedido_helper.dart';

Producto _producto({String id = 'prod-1', String nombre = 'Casco', double precio = 50000}) {
  return Producto(id: id, nombre: nombre, precio: precio, costo: 30000, utilidad: 20000);
}

void main() {
  group('PedidoHelper.createPedidoItem', () {
    test('arma el ItemPedido copiando id, nombre y precio del producto', () {
      final item = PedidoHelper.createPedidoItem(
        producto: _producto(id: 'prod-9', nombre: 'Guante', precio: 25000),
        cantidad: 3,
        notas: 'Talla M',
      );

      expect(item.productoId, 'prod-9');
      expect(item.productoNombre, 'Guante');
      expect(item.precioUnitario, 25000);
      expect(item.cantidad, 3);
      expect(item.notas, 'Talla M');
    });

    test('lanza ArgumentError si la cantidad es 0', () {
      expect(
        () => PedidoHelper.createPedidoItem(producto: _producto(), cantidad: 0),
        throwsArgumentError,
      );
    });

    test('lanza ArgumentError si la cantidad es negativa', () {
      expect(
        () => PedidoHelper.createPedidoItem(producto: _producto(), cantidad: -1),
        throwsArgumentError,
      );
    });
  });

  group('PedidoHelper.createPedidoItems', () {
    test('crea un item por cada producto, con cantidad 1 por defecto', () {
      final productos = [
        _producto(id: 'p1', nombre: 'Casco'),
        _producto(id: 'p2', nombre: 'Guante'),
      ];

      final items = PedidoHelper.createPedidoItems(productos);

      expect(items.length, 2);
      expect(items[0].productoId, 'p1');
      expect(items[0].cantidad, 1);
      expect(items[1].productoId, 'p2');
      expect(items[1].cantidad, 1);
    });

    test('lista de productos vacía da lista de items vacía', () {
      expect(PedidoHelper.createPedidoItems([]), isEmpty);
    });
  });

  group('PedidoHelper.validatePedidoItems', () {
    test('true cuando todos los items tienen productoId y cantidad válidos', () {
      final items = [
        const ItemPedido(productoId: 'p1', cantidad: 1, precioUnitario: 1000),
        const ItemPedido(productoId: 'p2', cantidad: 5, precioUnitario: 2000),
      ];

      expect(PedidoHelper.validatePedidoItems(items), isTrue);
    });

    test('false si algún item tiene productoId vacío', () {
      final items = [
        const ItemPedido(productoId: '', cantidad: 1, precioUnitario: 1000),
      ];

      expect(PedidoHelper.validatePedidoItems(items), isFalse);
    });

    test('false si algún item tiene cantidad 0 o negativa', () {
      final items = [
        const ItemPedido(productoId: 'p1', cantidad: 0, precioUnitario: 1000),
      ];

      expect(PedidoHelper.validatePedidoItems(items), isFalse);
    });

    test('lista vacía se considera válida (every() en lista vacía es true)', () {
      expect(PedidoHelper.validatePedidoItems([]), isTrue);
    });
  });
}