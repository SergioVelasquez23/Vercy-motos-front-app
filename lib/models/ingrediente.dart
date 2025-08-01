class Ingrediente {
  final String id;
  final String nombre;
  final String categoria;
  final double cantidad;
  final String unidad;
  final double costo;
  final String estado;

  Ingrediente({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.cantidad,
    required this.unidad,
    required this.costo,
    this.estado = 'Activo',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'categoria': categoria,
    'cantidad': cantidad,
    'unidad': unidad,
    'costo': costo,
    'estado': estado,
  };

  factory Ingrediente.fromJson(Map<String, dynamic> json) {
    return Ingrediente(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? '',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0.0,
      unidad: json['unidad']?.toString() ?? '',
      costo: (json['costo'] as num?)?.toDouble() ?? 0.0,
      estado: json['estado']?.toString() ?? 'Activo',
    );
  }

  Ingrediente copyWith({
    String? id,
    String? nombre,
    String? categoria,
    double? cantidad,
    String? unidad,
    double? costo,
    String? estado,
  }) {
    return Ingrediente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      cantidad: cantidad ?? this.cantidad,
      unidad: unidad ?? this.unidad,
      costo: costo ?? this.costo,
      estado: estado ?? this.estado,
    );
  }
}
