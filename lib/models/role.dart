class Role {
  final String? id;
  final String nombre;
  final String? descripcion;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;
  final bool activo;

  Role({
    this.id,
    required this.nombre,
    this.descripcion,
    this.fechaCreacion,
    this.fechaActualizacion,
    this.activo = true,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['_id'] ?? json['id'],
      nombre: json['name'] ?? json['nombre'] ?? '',
      descripcion: json['description'] ?? json['descripcion'],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : null,
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'fechaCreacion': fechaCreacion?.toIso8601String(),
      'fechaActualizacion': fechaActualizacion?.toIso8601String(),
      'activo': activo,
    };
  }

  Map<String, dynamic> toJsonCreate() {
    return {'nombre': nombre, 'descripcion': descripcion, 'activo': activo};
  }

  Role copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    bool? activo,
  }) {
    return Role(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      activo: activo ?? this.activo,
    );
  }
}
