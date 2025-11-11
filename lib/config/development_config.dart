import 'package:flutter/foundation.dart';

/// Configuración específica para desarrollo local
class DevelopmentConfig {
  static const bool enableCorsWorkaround = kDebugMode;

  /// Headers adicionales para desarrollo (simulando CORS)
  static Map<String, String> getCorsHeaders() {
    if (!enableCorsWorkaround) return {};

    return {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };
  }

  /// URL de desarrollo
  static String getDevelopmentUrl() {
    // En desarrollo usar el backend local
    return 'http://localhost:8080';
  }

  /// Detecta si estamos en entorno de desarrollo local
  static bool isLocalDevelopment() {
    if (!kIsWeb) return false;

    final host = Uri.base.host;
    return host == 'localhost' || host == '127.0.0.1';
  }

  /// Mensaje de ayuda para CORS en desarrollo
  static String getCorsHelpMessage() {
    return '''
    CORS Error - Soluciones:
    
    1. Configurar CORS en el backend de Render
    2. Usar Chrome con --disable-web-security para testing
    3. Desplegar a Firebase Hosting (producción)
    
    Para testing rápido ejecuta:
    chrome --user-data-dir="C:/temp/chrome-dev" --disable-web-security --allow-running-insecure-content http://localhost:5300
    ''';
  }

  /// Configuración de timeout extendida para desarrollo
  static Duration getTimeout() {
    return kDebugMode ? Duration(seconds: 120) : Duration(seconds: 90);
  }
}
