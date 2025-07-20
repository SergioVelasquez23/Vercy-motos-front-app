import 'package:serch_restapp/models/producto.dart';

class ItemPedido {
  final String productoId;
  final Producto? producto;
  final int cantidad;
  final String? notas;
  final double precio;

  ItemPedido({
    required this.productoId,
    this.producto,
    required this.cantidad,
    this.notas,
    required this.precio,
  });

  double get subtotal => precio * cantidad;

  Map<String, dynamic> toJson() => {
    'productoId': productoId,
    'cantidad': cantidad,
    'notas': notas,
    'precio': precio,
  };

  factory ItemPedido.fromJson(Map<String, dynamic> json, {Producto? producto}) {
    return ItemPedido(
      productoId: json['productoId'] ?? '',
      producto: producto,
      cantidad: json['cantidad'] ?? 0,
      notas: json['notas'],
      precio: json['precio']?.toDouble() ?? producto?.precio ?? 0.0,
    );
  }

  @override
  String toString() =>
      'ItemPedido(productoId: $productoId, cantidad: $cantidad, notas: $notas)';
}
