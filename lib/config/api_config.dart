import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'environment_config.dart';
import 'credentials_config.dart';
import 'endpoints_config.dart';

/// Configuración centralizada para la API
///
/// Esta clase coordina todas las configuraciones relacionadas con la API,
/// delegando las responsabilidades específicas a clases especializadas:
/// - Credenciales: CredentialsConfig
/// - Entorno: EnvironmentConfig
/// - Endpoints: EndpointsConfig
class ApiConfig {
  // Instancia singleton
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  // Instancias de las configuraciones especializadas
  final EnvironmentConfig _environmentConfig = EnvironmentConfig();
  final CredentialsConfig _credentialsConfig = CredentialsConfig();
  final EndpointsConfig _endpointsConfig = EndpointsConfig();

  /// Configuración del timeout para peticiones HTTP
  static const int requestTimeout = 15; // Timeout en segundos

  /// Habilitar certificate pinning
  static const bool enableCertificatePinning = true;

  /// Determina si estamos en entorno de desarrollo
  bool get isDevelopment => _environmentConfig.isDevEnvironment;

  /// Acceso a los endpoints organizados por categoría
  EndpointsConfig get endpoints => _endpointsConfig;

  /// Obtiene la API key de forma segura
  String get apiKey => _credentialsConfig.apiKey;

  /// Obtiene los fingerprints de certificados confiables
  List<String> get trustedCertificateFingerprints =>
      _credentialsConfig.trustedCertificateFingerprints;

  /// Obtiene la URL base actual
  String get baseUrl => _endpointsConfig.currentBaseUrl;

  /// Determina si se debe usar HTTPS
  bool get useHttps => _environmentConfig.useHttps;

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

  /// Genera un hash seguro para las contraseñas y datos sensibles
  String hashSensitiveData(String data, String salt) {
    final key = utf8.encode('$data$salt');
    final bytes = sha256.convert(key).bytes;
    return base64.encode(bytes);
  }

  /// Genera un header de autenticación con timestamp para evitar replay attacks
  Map<String, String> getSecureHeaders({String? token}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = base64.encode(
      List<int>.generate(
        16,
        (_) => DateTime.now().millisecondsSinceEpoch % 255,
      ),
    );

    // Crear firma para verificar la integridad de la solicitud
    final signature = hashSensitiveData('$apiKey$timestamp$nonce', apiKey);

    return {
      'Content-Type': 'application/json',
      'X-Api-Key': apiKey,
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Configuración de encabezados HSTS simulados para mayor seguridad
  Map<String, String> getSecurityHeaders() {
    return {
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-XSS-Protection': '1; mode=block',
      'Referrer-Policy': 'no-referrer',
      'Content-Security-Policy': "default-src 'self'",
    };
  }

  /// Valida si un certificado es confiable
  bool isTrustedCertificate(String certificateFingerprint) {
    // Si estamos en desarrollo, aceptamos cualquier certificado
    if (isDevelopment) {
      return true;
    }
    // En producción, solo aceptamos certificados conocidos
    return trustedCertificateFingerprints.contains(certificateFingerprint);
  }

  /// Verifica la seguridad de una conexión
  bool isConnectionSecure(String url) {
    return url.startsWith('https://') ||
        url.contains('localhost') ||
        url.contains('127.0.0.1') ||
        RegExp(r'192\.168\.\d{1,3}\.\d{1,3}').hasMatch(url);
  }

  /// Convierte HTTP a HTTPS si es posible y está configurado
  String secureUrl(String url) {
    if (useHttps && url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  /// Obtiene la instancia global de ApiConfig
  static ApiConfig get instance => _instance;
}
