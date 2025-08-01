import 'endpoints_config.dart';

/// Configuración centralizada para la API
class ApiConfig {
  // Instancia singleton
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  // Instancia de configuración de endpoints
  final EndpointsConfig _endpointsConfig = EndpointsConfig();

  /// Configuración del timeout para peticiones HTTP
  static const int requestTimeout = 15; // Timeout en segundos

  /// Determina si estamos en entorno de desarrollo (simplificado)
  bool get isDevelopment => true; // Por defecto desarrollo

  /// Acceso a los endpoints organizados por categoría
  EndpointsConfig get endpoints => _endpointsConfig;

  /// Obtiene la URL base actual
  String get baseUrl => _endpointsConfig.currentBaseUrl;

  /// Establece una URL base personalizada
  void setCustomBaseUrl(String url) {
    _endpointsConfig.setCustomBaseUrl(url);
  }

  /// Restablece la URL base predeterminada
  void resetToDefaultBaseUrl() {
    _endpointsConfig.resetToDefaultBaseUrl();
  }

  /// Verifica si se está usando una URL personalizada
  bool get isUsingCustomUrl => _endpointsConfig.isUsingCustomUrl;

  /// Genera headers básicos de autenticación
  Map<String, String> getSecureHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Configuración de encabezados básicos de seguridad
  Map<String, String> getSecurityHeaders() {
    return {
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-XSS-Protection': '1; mode=block',
    };
  }

  /// Obtiene la instancia global de ApiConfig
  static ApiConfig get instance => _instance;
}
