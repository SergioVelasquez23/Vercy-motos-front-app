import 'package:flutter/foundation.dart';

/// Configuración del entorno de ejecución
///
/// Maneja la detección automática del entorno (desarrollo/producción)
/// y proporciona métodos para verificar el entorno actual.
class EnvironmentConfig {
  // Singleton
  static final EnvironmentConfig _instance = EnvironmentConfig._internal();
  factory EnvironmentConfig() => _instance;
  EnvironmentConfig._internal();

  // Detecta automáticamente si estamos en desarrollo o producción
  // En Flutter, podemos usar kReleaseMode para detectar el modo de compilación
  bool get isDevelopment => !kReleaseMode;

  // Alternativa para forzar el entorno manualmente (útil para pruebas)
  bool _forceDevelopment = false;

  /// Forzar modo desarrollo (usar solo para pruebas)
  void forceDevelopmentMode(bool value) {
    _forceDevelopment = value;
    if (kDebugMode) {
      print('⚠️ Modo desarrollo forzado: $value');
    }
  }

  /// Verifica si estamos en entorno de desarrollo
  bool get isDevEnvironment => _forceDevelopment || isDevelopment;

  /// Verifica si estamos en entorno de producción
  bool get isProdEnvironment => !isDevEnvironment;

  /// Devuelve el nombre del entorno actual
  String get currentEnvironmentName =>
      isDevEnvironment ? 'Desarrollo' : 'Producción';

  /// URL del backend según el entorno
  String get baseApiUrl {
    if (isDevEnvironment) {
      return 'http://192.168.20.24:8081';
    } else {
      return 'https://api.sopaycarbonapp.com';
    }
  }

  /// Comprueba si debemos usar HTTPS
  bool get useHttps => !isDevEnvironment || _forceHttps;

  // Flag para forzar HTTPS incluso en desarrollo (útil para pruebas de seguridad)
  bool _forceHttps = false;

  /// Forzar uso de HTTPS incluso en desarrollo
  void forceHttps(bool value) {
    _forceHttps = value;
    if (kDebugMode) {
      print('🔒 HTTPS forzado: $value');
    }
  }
}
