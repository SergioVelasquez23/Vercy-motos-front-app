class UserRole {
  final String? id;
  final String userId;
  final String roleId;
  final DateTime? fechaAsignacion;
  final bool activo;

  // Propiedades adicionales para mostrar información completa
  final String? userNombre;
  final String? userEmail;
  final String? roleName;

  UserRole({
    this.id,
    required this.userId,
    required this.roleId,
    this.fechaAsignacion,
    this.activo = true,
    this.userNombre,
    this.userEmail,
    this.roleName,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'],
      userId: json['userId'] ?? '',
      roleId: json['roleId'] ?? '',
      fechaAsignacion: json['fechaAsignacion'] != null
          ? DateTime.parse(json['fechaAsignacion'])
          : null,
      activo: json['activo'] ?? true,
      userNombre: json['userNombre'],
      userEmail: json['userEmail'],
      roleName: json['roleName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'roleId': roleId,
      'fechaAsignacion': fechaAsignacion?.toIso8601String(),
      'activo': activo,
      'userNombre': userNombre,
      'userEmail': userEmail,
      'roleName': roleName,
    };
  }

  Map<String, dynamic> toJsonCreate() {
    return {'userId': userId, 'roleId': roleId, 'activo': activo};
  }
}
