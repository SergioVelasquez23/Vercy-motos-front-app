class Permission {
  final String? id;
  final String nombre;
  final String? descripcion;
  final String? modulo;
  final String? accion;
  final bool activo;

  Permission({
    this.id,
    required this.nombre,
    this.descripcion,
    this.modulo,
    this.accion,
    this.activo = true,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      modulo: json['modulo'],
      accion: json['accion'],
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'modulo': modulo,
      'accion': accion,
      'activo': activo,
    };
  }
}
