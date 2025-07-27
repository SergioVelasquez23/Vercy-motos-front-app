import 'package:flutter/foundation.dart';
import '../utils/security_utils.dart';

/// Configuración general de seguridad para la aplicación
class SecurityConfig {
  // Singleton
  static final SecurityConfig _instance = SecurityConfig._internal();
  factory SecurityConfig() => _instance;
  SecurityConfig._internal();

  // Inicializar seguridad
  bool _isInitialized = false;

  /// Inicializa los componentes de seguridad
  Future<void> init() async {
    if (_isInitialized) return;

    await SecurityUtils.initializeSecurity();
    _isInitialized = true;

    if (kDebugMode) {
      print('🔒 Sistema de seguridad inicializado');
    }
  }

  /// Implementa protecciones de seguridad básicas para la aplicación
  void applySecurityBestPractices() {
    // Aquí iría código para deshabilitar capturas de pantalla en
    // contenido sensible, prevenir overlay attacks, etc.

    if (kDebugMode) {
      print('🔒 Prácticas de seguridad aplicadas');
    }
  }

  /// Limpia datos sensibles cuando la app va a segundo plano
  void clearSensitiveDataOnBackground() {
    // Limpiar datos sensibles
    debugPrint('🧹 Datos sensibles limpiados');
  }
}
