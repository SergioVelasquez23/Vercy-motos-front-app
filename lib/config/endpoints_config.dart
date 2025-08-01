/// Configuración de endpoints de la API
///
/// Organiza los endpoints de autenticación de manera estructurada.
class EndpointsConfig {
  // Singleton
  static final EndpointsConfig _instance = EndpointsConfig._internal();
  factory EndpointsConfig() => _instance;
  EndpointsConfig._internal();

  // URL base por defecto (simplificada)
  String get baseUrl => _customBaseUrl ?? 'http://192.168.20.24:8081';

  // Variable para almacenar una URL base personalizada
  String? _customBaseUrl;

  /// Establece una URL base personalizada
  void setCustomBaseUrl(String url) {
    _customBaseUrl = url;
    if (url.isNotEmpty) {
      print('📡 URL base personalizada establecida: $url');
    }
  }

  /// Elimina la URL base personalizada y vuelve a la URL por defecto
  void resetToDefaultBaseUrl() {
    _customBaseUrl = null;
    print('📡 URL base restaurada al valor predeterminado: $baseUrl');
  }

  /// Verifica si se está usando una URL base personalizada
  bool get isUsingCustomUrl => _customBaseUrl != null;

  /// Devuelve la URL base actual (personalizada o predeterminada)
  String get currentBaseUrl => _customBaseUrl ?? baseUrl;

  /// Endpoints de autenticación y usuarios (único endpoints usado)
  AuthEndpoints get auth => AuthEndpoints(currentBaseUrl);
}

/// Endpoints relacionados con autenticación y usuarios
class AuthEndpoints {
  final String baseUrl;

  AuthEndpoints(this.baseUrl);

  /// Endpoint para iniciar sesión sin autenticación previa
  String get login => '$baseUrl/api/public/security/login-no-auth';

  /// Endpoint para obtener información del usuario actual
  String get userInfo => '$baseUrl/api/user-info/current';

  /// Endpoint para registrar un nuevo usuario
  String get register => '$baseUrl/api/users';

  /// Endpoint para validar un código de autenticación
  String validateCode(String code) =>
      '$baseUrl/api/public/security/login/validate/$code';
}
