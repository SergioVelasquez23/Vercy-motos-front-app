class Inventario {
  final String id;
  final String categoria;
  final String codigo;
  final String nombre;
  final String unidad;
  final double precioCompra;
  final double stockActual;
  final double stockMinimo;
  final String estado;

  Inventario({
    required this.id,
    required this.categoria,
    required this.codigo,
    required this.nombre,
    required this.unidad,
    required this.precioCompra,
    required this.stockActual,
    required this.stockMinimo,
    required this.estado,
  });

  factory Inventario.fromJson(Map<String, dynamic> json) {
    return Inventario(
      id: json['_id'] ?? '',
      categoria: json['categoria'] ?? json['categoriaId'] ?? '',
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      unidad: json['unidad'] ?? '',
      precioCompra: (json['precioCompra'] ?? json['costo'] ?? 0).toDouble(),
      stockActual: (json['stockActual'] ?? json['cantidadActual'] ?? 0)
          .toDouble(),
      stockMinimo: (json['stockMinimo'] ?? 0).toDouble(),
      estado: json['estado'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'categoria': categoria,
      'codigo': codigo,
      'nombre': nombre,
      'unidad': unidad,
      'precioCompra': precioCompra,
      'stockActual': stockActual,
      'stockMinimo': stockMinimo,
      'estado': estado,
    };
  }
}
