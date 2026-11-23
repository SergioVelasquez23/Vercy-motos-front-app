/// Solicitud de creación de un usuario que espera la autorización de un SUPERADMIN. Mientras no se
/// autorice, el usuario no existe en el sistema.
class SolicitudUsuario {
  final String id;
  final String nombre;
  final String email;
  final String? solicitadoPor;
  final DateTime? fechaSolicitud;

  const SolicitudUsuario({
    required this.id,
    required this.nombre,
    required this.email,
    this.solicitadoPor,
    this.fechaSolicitud,
  });

  factory SolicitudUsuario.fromJson(Map<String, dynamic> json) {
    return SolicitudUsuario(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      solicitadoPor: json['solicitadoPor']?.toString(),
      fechaSolicitud: json['fechaSolicitud'] != null
          ? DateTime.tryParse(json['fechaSolicitud'].toString())
          : null,
    );
  }
}
