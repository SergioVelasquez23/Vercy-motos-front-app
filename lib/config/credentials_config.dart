import 'package:flutter/foundation.dart';

/// Configuración de credenciales sensibles
///
/// Este archivo contiene todas las credenciales y claves sensibles
/// que NO deben incluirse en el control de versiones.
/// Idealmente, estas variables deberían obtenerse de variables de entorno,
/// servicios seguros como Firebase Remote Config o almacenamiento seguro.
class CredentialsConfig {
  // Singleton
  static final CredentialsConfig _instance = CredentialsConfig._internal();
  factory CredentialsConfig() => _instance;
  CredentialsConfig._internal();

  // API Keys - En producción, estas claves deberían obtenerse de forma segura
  // y NO estar hardcodeadas en el código
  String get apiKey => _getSecureApiKey();

  // Fingerprints de certificados para certificate pinning
  List<String> get trustedCertificateFingerprints => [
    // Agrega aquí los fingerprints SHA-256 de tus certificados de confianza
    // Ejemplo: 'AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12'
  ];

  // Método para obtener la API key de forma segura
  // En producción, esto debería cargar la clave desde un almacenamiento seguro
  String _getSecureApiKey() {
    // IMPORTANTE: Esta implementación es solo para desarrollo
    // En producción, reemplazar con obtención desde almacenamiento seguro

    if (kReleaseMode) {
      // En una aplicación real, aquí obtendríamos la clave de:
      // 1. Un servicio como Firebase Remote Config
      // 2. Un almacén seguro en el dispositivo
      // 3. Un servicio de secretos en la nube
      return 'PROD_sopa_carbon_api_key_2025';
    } else {
      // Clave de desarrollo
      return 'DEV_sopa_carbon_api_key_2025';
    }
  }
}
