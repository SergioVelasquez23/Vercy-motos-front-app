/// Disponibilidad de inventario de un producto de una cotización, tal como la
/// devuelve POST /api/cotizaciones/verificar-disponibilidad.
class DisponibilidadItem {
  final String? productoId;
  final String nombre;
  final int solicitado;
  final int bodega;
  final int almacen;

  /// OK | SOLO_ALMACEN | SIN_STOCK | NO_ENCONTRADO
  final String estado;

  const DisponibilidadItem({
    this.productoId,
    required this.nombre,
    required this.solicitado,
    required this.bodega,
    required this.almacen,
    required this.estado,
  });

  bool get esOk => estado == 'OK';

  factory DisponibilidadItem.fromJson(Map<String, dynamic> json) => DisponibilidadItem(
        productoId: json['productoId'],
        nombre: (json['productoNombre'] ?? 'Producto').toString(),
        solicitado: (json['solicitado'] as num?)?.toInt() ?? 0,
        bodega: (json['bodega'] as num?)?.toInt() ?? 0,
        almacen: (json['almacen'] as num?)?.toInt() ?? 0,
        estado: (json['estado'] ?? 'SIN_STOCK').toString(),
      );
}
