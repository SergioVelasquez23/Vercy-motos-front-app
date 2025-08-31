import 'package:kronos_restbar/models/producto.dart';

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
    'esCombo': producto?.esCombo ?? false, // Indicar si es un producto combo
    'tipoProducto': producto?.tipoProducto ?? 'individual', // Tipo de producto
  };

  factory ItemPedido.fromJson(Map<String, dynamic> json, {Producto? producto}) {
    // If we have a product name in the JSON but no full product object, create a minimal product object
    Producto? finalProducto = producto;
    if (finalProducto == null && json.containsKey('productoNombre')) {
      finalProducto = Producto(
        id: json['productoId'] ?? '',
        nombre: json['productoNombre'] ?? 'Producto desconocido',
        precio:
            json['precio']?.toDouble() ??
            json['precioUnitario']?.toDouble() ??
            0.0,
        costo: 0.0,
        utilidad: 0.0,
        cantidad: 0,
      );
    }

    // Handle the case where we don't have a product name but have other data
    if (finalProducto == null) {
      finalProducto = Producto(
        id: json['productoId'] ?? '',
        nombre: json['productoNombre'] ?? 'Producto sin nombre',
        precio:
            json['precio']?.toDouble() ??
            json['precioUnitario']?.toDouble() ??
            0.0,
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
      precio:
          json['precio']?.toDouble() ??
          json['precioUnitario']?.toDouble() ??
          finalProducto.precio,
      ingredientesSeleccionados: json['ingredientesSeleccionados'] != null
          ? List<String>.from(json['ingredientesSeleccionados'])
          : [],
    );
  }

  @override
  String toString() =>
      'ItemPedido(productoId: $productoId, cantidad: $cantidad, notas: $notas)';
}
