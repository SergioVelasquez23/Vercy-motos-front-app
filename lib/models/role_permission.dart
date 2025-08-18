class RolePermission {
  final String? id;
  final String roleId;
  final String permissionId;
  final DateTime? fechaAsignacion;
  final bool activo;

  // Propiedades adicionales para mostrar información completa
  final String? roleName;
  final String? permissionName;
  final String? permissionModulo;

  RolePermission({
    this.id,
    required this.roleId,
    required this.permissionId,
    this.fechaAsignacion,
    this.activo = true,
    this.roleName,
    this.permissionName,
    this.permissionModulo,
  });

  factory RolePermission.fromJson(Map<String, dynamic> json) {
    return RolePermission(
      id: json['id'],
      roleId: json['roleId'] ?? '',
      permissionId: json['permissionId'] ?? '',
      fechaAsignacion: json['fechaAsignacion'] != null
          ? DateTime.parse(json['fechaAsignacion'])
          : null,
      activo: json['activo'] ?? true,
      roleName: json['roleName'],
      permissionName: json['permissionName'],
      permissionModulo: json['permissionModulo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roleId': roleId,
      'permissionId': permissionId,
      'fechaAsignacion': fechaAsignacion?.toIso8601String(),
      'activo': activo,
      'roleName': roleName,
      'permissionName': permissionName,
      'permissionModulo': permissionModulo,
    };
  }

  Map<String, dynamic> toJsonCreate() {
    return {'roleId': roleId, 'permissionId': permissionId, 'activo': activo};
  }
}
