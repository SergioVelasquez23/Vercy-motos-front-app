class TipoGasto {
  final String? id;
  final String nombre;
  final String? descripcion;
  final bool activo;

  TipoGasto({
    this.id,
    required this.nombre,
    this.descripcion,
    this.activo = true,
  });

  factory TipoGasto.fromJson(Map<String, dynamic> json) {
    return TipoGasto(
      id: json['_id'],
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      'activo': activo,
    };
  }

  TipoGasto copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    bool? activo,
  }) {
    return TipoGasto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      activo: activo ?? this.activo,
    );
  }
}
