import 'package:serch_restapp/models/producto.dart';

class ItemPedido {
  final String productoId;
  final Producto? producto;
  final int cantidad;
  final String? notas;
  final double precio;
  final List<String> ingredientesSeleccionados; // Nuevo campo

  ItemPedido({
    required this.productoId,
    this.producto,
    required this.cantidad,
    this.notas,
    required this.precio,
    this.ingredientesSeleccionados = const [], // Valor por defecto
  });

  double get subtotal => precio * cantidad;

  Map<String, dynamic> toJson() => {
    'productoId': productoId,
    'productoNombre': producto?.nombre, // Enviamos el nombre del producto
    'cantidad': cantidad,
    'notas': notas,
    'precio': precio,
    'ingredientesSeleccionados': ingredientesSeleccionados,
  };

  factory ItemPedido.fromJson(Map<String, dynamic> json, {Producto? producto}) {
    // If we have a product name in the JSON but no full product object, create a minimal product object
    Producto? finalProducto = producto;
    if (finalProducto == null && json.containsKey('productoNombre')) {
      finalProducto = Producto(
        id: json['productoId'] ?? '',
        nombre: json['productoNombre'] ?? 'Producto desconocido',
        precio: json['precio']?.toDouble() ?? 0.0,
        costo: 0.0,
        utilidad: 0.0,
        cantidad: 0,
      );
    }

    return ItemPedido(
      productoId: json['productoId'] ?? '',
      producto: finalProducto,
      cantidad: json['cantidad'] ?? 0,
      notas: json['notas'],
      precio: json['precio']?.toDouble() ?? finalProducto?.precio ?? 0.0,
      ingredientesSeleccionados: json['ingredientesSeleccionados'] != null
          ? List<String>.from(json['ingredientesSeleccionados'])
          : [],
    );
  }

  @override
  String toString() =>
      'ItemPedido(productoId: $productoId, cantidad: $cantidad, notas: $notas)';
}
