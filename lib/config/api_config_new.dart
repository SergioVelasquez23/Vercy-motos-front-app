import 'dart:io';
import 'endpoints_config_new.dart';
import '../services/network_discovery_service.dart';
import 'constants.dart';

/// Configuración centralizada mejorada para la API
///
/// MEJORAS IMPLEMENTADAS:
/// - Detección automática de IP del servidor
/// - Soporte para variables de entorno
/// - Fallbacks múltiples para mayor robustez
/// - Cache inteligente para optimizar performance
/// - Diferentes modos de configuración (desarrollo/producción)
class ApiConfig {
  // Instancia singleton
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  // Instancias de servicios dependientes
  final NetworkDiscoveryService _networkDiscovery = NetworkDiscoveryService();
  late final EndpointsConfig _endpointsConfig;

  // Cache de configuración
  String? _cachedBaseUrl;
  bool _initialized = false;

  // Configuraciones por ambiente
  static const Map<String, AppEnvironment> _environments = {
    'development': AppEnvironment(
      name: 'Desarrollo',
      defaultPort: 8081,
      enableAutoDiscovery: true,
      enableLogging: true,
    ),
    'staging': AppEnvironment(
      name: 'Staging',
      defaultPort: 8081,
      enableAutoDiscovery: true,
      enableLogging: true,
    ),
    'production': AppEnvironment(
      name: 'Producción',
      defaultPort: 8080,
      enableAutoDiscovery: false,
      enableLogging: false,
    ),
  };

  /// Configuración del timeout para peticiones HTTP
  static const int requestTimeout = 15; // Timeout en segundos

  /// Inicializa la configuración de la API
  ///
  /// Este método debe ser llamado al inicio de la aplicación
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Determinar URL base usando múltiples estrategias
      _cachedBaseUrl = await _determineBaseUrl();

      // Inicializar EndpointsConfig con la URL base
      _endpointsConfig = EndpointsConfig(_cachedBaseUrl!);

      _initialized = true;
    } catch (e) {
      // Usar URL fallback para no bloquear la aplicación
      _cachedBaseUrl = _getFallbackUrl();
      _endpointsConfig = EndpointsConfig(_cachedBaseUrl!);
      _initialized = true;
    }
  }

  /// Determina la URL base usando múltiples estrategias
  Future<String> _determineBaseUrl() async {
    final environment = currentEnvironment;

    // Estrategia 1: Variable de entorno explícita
    final envUrl = _getEnvironmentUrl();
    if (envUrl != null) {
      if (await _validateUrl(envUrl)) {
        return envUrl;
      }
    }

    // Estrategia 2: Detección automática (si está habilitada)
    if (environment.enableAutoDiscovery) {
      final autoUrl = await _networkDiscovery.getServerBaseUrl();
      if (autoUrl != null) {
        return autoUrl;
      }
    }

    // Estrategia 3: URL fallback
    final fallbackUrl = _getFallbackUrl();
    return fallbackUrl;
  }

  /// Obtiene URL desde variables de entorno
  String? _getEnvironmentUrl() {
    // Prioridad de variables de entorno
    final envVars = [
      'API_BASE_URL',
      'BACKEND_URL',
      'SERVER_URL',
      'APP_SERVER_URL',
    ];

    for (final envVar in envVars) {
      final url =
          Platform.environment[envVar] ?? String.fromEnvironment(envVar);
      if (url.isNotEmpty) {
        return url;
      }
    }

    return null;
  }

  /// Obtiene URL fallback basada en ambiente
  String _getFallbackUrl([String? environmentName]) {
    // URLs fallback por ambiente - localhost en desarrollo
    final fallbackUrls = {
      'development': 'http://localhost:8080',
      'staging': 'https://sopa-y-carbon.onrender.com',
      'production': 'https://sopa-y-carbon.onrender.com',
    };

    return fallbackUrls[environmentName] ?? kDynamicBackendUrl;
  }

  /// Valida si una URL está accesible
  Future<bool> _validateUrl(String url) async {
    try {
      return await _networkDiscovery.testServerConnection(url);
    } catch (e) {
      return false;
    }
  }

  /// Obtiene el ambiente actual
  AppEnvironment get currentEnvironment {
    final envName = environmentName;
    return _environments[envName] ?? _environments['development']!;
  }

  /// Obtiene el nombre del ambiente actual
  String get environmentName {
    return Platform.environment['FLUTTER_ENV'] ??
        Platform.environment['NODE_ENV'] ??
        const String.fromEnvironment(
          'FLUTTER_ENV',
          defaultValue: 'development',
        );
  }

  /// Determina si estamos en entorno de desarrollo
  bool get isDevelopment => environmentName == 'development';

  /// Determina si estamos en entorno de producción
  bool get isProduction => environmentName == 'production';

  /// Obtiene la URL base actual
  String get baseUrl {
    if (!_initialized) {
      throw StateError(
        'ApiConfig no ha sido inicializado. Llama a initialize() primero.',
      );
    }
    return _cachedBaseUrl!;
  }

  /// Acceso a los endpoints organizados por categoría
  EndpointsConfig get endpoints {
    if (!_initialized) {
      throw StateError(
        'ApiConfig no ha sido inicializado. Llama a initialize() primero.',
      );
    }
    return _endpointsConfig;
  }

  /// Establece una URL base personalizada
  void setCustomBaseUrl(String url) {
    _cachedBaseUrl = url;
    _endpointsConfig = EndpointsConfig(url);
  }

  /// Restablece la configuración y re-detecta el servidor
  Future<void> refresh() async {
    _initialized = false;
    _cachedBaseUrl = null;
    _networkDiscovery.clearCache();
    await initialize();
  }

  /// Fuerza nueva detección de servidor
  Future<void> forceRediscover() async {
    final newUrl = await _networkDiscovery.forceRediscover();
    if (newUrl != null) {
      final fullUrl = 'http://$newUrl:${currentEnvironment.defaultPort}';
      setCustomBaseUrl(fullUrl);
    }
  }

  /// Genera headers básicos de autenticación
  Map<String, String> getSecureHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'SopaCarbon-Flutter/${currentEnvironment.name}',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Configuración de encabezados básicos de seguridad
  Map<String, String> getSecurityHeaders() {
    return {
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-XSS-Protection': '1; mode=block',
      'X-Requested-With': 'XMLHttpRequest',
    };
  }

  /// Información de debug de la configuración actual
  Map<String, dynamic> getDebugInfo() {
    return {
      'initialized': _initialized,
      'baseUrl': _cachedBaseUrl,
      'environment': environmentName,
      'environmentConfig': currentEnvironment.toMap(),
      'autoDiscoveryEnabled': currentEnvironment.enableAutoDiscovery,
      'networkCacheValid': _networkDiscovery.hasValidCache,
      'lastKnownServerIp': _networkDiscovery.lastKnownServerIp,
    };
  }

  /// Obtiene la instancia global de ApiConfig
  static ApiConfig get instance => _instance;
}

/// Configuración específica por ambiente
class AppEnvironment {
  final String name;
  final int defaultPort;
  final bool enableAutoDiscovery;
  final bool enableLogging;

  const AppEnvironment({
    required this.name,
    required this.defaultPort,
    required this.enableAutoDiscovery,
    required this.enableLogging,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'defaultPort': defaultPort,
    'enableAutoDiscovery': enableAutoDiscovery,
    'enableLogging': enableLogging,
  };
}
