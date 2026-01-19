// Archivo temporal - Modelo Ingrediente para compatibilidad
// TODO: Eliminar cuando se quite la funcionalidad de ingredientes del proyecto

class Ingrediente {
  final String id;
  final String nombre;
  final String categoria;
  final String unidadMedida;
  final double cantidad;
  final double precioUnitario;
  final String? descripcion;

  // Alias para compatibilidad
  String get unidad => unidadMedida;

  Ingrediente({
    required this.id,
    required this.nombre,
    this.categoria = '',
    this.unidadMedida = 'unidad',
    this.cantidad = 0,
    this.precioUnitario = 0,
    this.descripcion,
  });

  factory Ingrediente.fromJson(Map<String, dynamic> json) {
    return Ingrediente(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? '',
      unidadMedida: json['unidadMedida']?.toString() ?? 'unidad',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
      precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0,
      descripcion: json['descripcion']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'categoria': categoria,
    'unidadMedida': unidadMedida,
    'cantidad': cantidad,
    'precioUnitario': precioUnitario,
    'descripcion': descripcion,
  };
}
