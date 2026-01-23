class PermissionsService {
  // Roles permitidos para facturar
  static const List<String> rolesConAccesoFacturacion = [
    'admin',
    'gerente',
    'cajero',
  ];

  // Roles con acceso limitado
  static const List<String> rolesConAccesoLimitado = ['asesor'];

  /// Verifica si el usuario puede acceder a la facturación
  static bool puedeFacturar(String? rol) {
    if (rol == null) return false;
    return rolesConAccesoFacturacion.contains(rol.toLowerCase());
  }

  /// Verifica si el usuario puede acceder a facturación (incluyendo asesores en modo limitado)
  static bool puedeAccederFacturacion(String? rol) {
    if (rol == null) return false;
    // Asesores pueden acceder pero solo para guardar (no pagar)
    return rolesConAccesoFacturacion.contains(rol.toLowerCase()) ||
        rolesConAccesoLimitado.contains(rol.toLowerCase());
  }

  /// Verifica si el usuario solo puede guardar pedidos (no procesar pagos)
  static bool soloGuardarPedidos(String? rol) {
    if (rol == null) return false;
    return rolesConAccesoLimitado.contains(rol.toLowerCase());
  }

  /// Verifica si el usuario tiene acceso limitado
  static bool esAccesoLimitado(String? rol) {
    if (rol == null) return false;
    return rolesConAccesoLimitado.contains(rol.toLowerCase());
  }

  /// Obtiene la ruta de inicio según el rol
  static String getRutaInicioPorRol(String? rol) {
    if (rol == null) return '/dashboard';

    switch (rol.toLowerCase()) {
      case 'asesor':
        return '/asesor-pedidos'; // Redirige directo a pedidos de asesor
      case 'admin':
      case 'gerente':
      case 'cajero':
        return '/dashboard'; // Acceso normal al dashboard
      default:
        return '/dashboard';
    }
  }

  /// Obtiene un mensaje de restricción personalizado por rol
  static String getMensajeRestriccion(String? rol) {
    if (rol == null) return 'No tienes permisos para acceder a esta función.';

    switch (rol.toLowerCase()) {
      case 'asesor':
        return 'Como asesor, puedes guardar pedidos pero no procesarlos.\nContacta al administrador para completar el pago.';
      default:
        return 'No tienes permisos para acceder a esta función.';
    }
  }

  /// Verifica si el usuario es administrador
  static bool esAdmin(String? rol) {
    if (rol == null) return false;
    return rol.toLowerCase() == 'admin';
  }

  /// Verifica si el usuario puede acceder a inventario
  static bool puedeAccederInventario(String? rol) {
    if (rol == null) return false;
    return ['admin', 'gerente'].contains(rol.toLowerCase());
  }

  /// Verifica si el usuario puede acceder a reportes
  static bool puedeAccederReportes(String? rol) {
    if (rol == null) return false;
    return ['admin', 'gerente'].contains(rol.toLowerCase());
  }

  /// Verifica si el usuario puede acceder a configuración
  static bool puedeAccederConfiguracion(String? rol) {
    if (rol == null) return false;
    return rol.toLowerCase() == 'admin';
  }
}
