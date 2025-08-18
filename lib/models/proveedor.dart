class Proveedor {
  final String id;
  final String nombre;
  final String? nombreComercial;
  final String? documento;
  final String? email;
  final String? telefono;
  final String? direccion;
  final String? paginaWeb;
  final String? contacto;
  final String? nota;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  Proveedor({
    required this.id,
    required this.nombre,
    this.nombreComercial,
    this.documento,
    this.email,
    this.telefono,
    this.direccion,
    this.paginaWeb,
    this.contacto,
    this.nota,
    required this.fechaCreacion,
    required this.fechaActualizacion,
  });

  factory Proveedor.fromJson(Map<String, dynamic> json) {
    return Proveedor(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      nombreComercial: json['nombreComercial'],
      documento: json['documento'],
      email: json['email'],
      telefono: json['telefono'],
      direccion: json['direccion'],
      paginaWeb: json['paginaWeb'],
      contacto: json['contacto'],
      nota: json['nota'],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : DateTime.now(),
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'nombreComercial': nombreComercial,
      'documento': documento,
      'email': email,
      'telefono': telefono,
      'direccion': direccion,
      'paginaWeb': paginaWeb,
      'contacto': contacto,
      'nota': nota,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonCreate() {
    final json = <String, dynamic>{'nombre': nombre};

    if (nombreComercial != null && nombreComercial!.isNotEmpty) {
      json['nombreComercial'] = nombreComercial;
    }
    if (documento != null && documento!.isNotEmpty) {
      json['documento'] = documento;
    }
    if (email != null && email!.isNotEmpty) {
      json['email'] = email;
    }
    if (telefono != null && telefono!.isNotEmpty) {
      json['telefono'] = telefono;
    }
    if (direccion != null && direccion!.isNotEmpty) {
      json['direccion'] = direccion;
    }
    if (paginaWeb != null && paginaWeb!.isNotEmpty) {
      json['paginaWeb'] = paginaWeb;
    }
    if (contacto != null && contacto!.isNotEmpty) {
      json['contacto'] = contacto;
    }
    if (nota != null && nota!.isNotEmpty) {
      json['nota'] = nota;
    }

    return json;
  }
}
