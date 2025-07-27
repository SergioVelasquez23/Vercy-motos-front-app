import 'environment_config.dart';

/// Configuración de endpoints de la API
///
/// Organiza todos los endpoints de la API por categoría
/// y permite acceder a ellos de manera estructurada.
class EndpointsConfig {
  // Singleton
  static final EndpointsConfig _instance = EndpointsConfig._internal();
  factory EndpointsConfig() => _instance;
  EndpointsConfig._internal();

  // URL base obtenida del entorno
  String get baseUrl => EnvironmentConfig().baseApiUrl;

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

  /// Endpoints de autenticación y usuarios
  AuthEndpoints get auth => AuthEndpoints(currentBaseUrl);

  /// Endpoints de productos
  ProductEndpoints get products => ProductEndpoints(currentBaseUrl);

  /// Endpoints de mesas
  TableEndpoints get tables => TableEndpoints(currentBaseUrl);

  /// Endpoints de pedidos
  OrderEndpoints get orders => OrderEndpoints(currentBaseUrl);
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

/// Endpoints relacionados con productos
class ProductEndpoints {
  final String baseUrl;

  ProductEndpoints(this.baseUrl);

  /// Endpoint para obtener todos los productos
  String get all => '$baseUrl/api/productos';

  /// Endpoint para obtener un producto por ID
  String byId(int id) => '$baseUrl/api/productos/$id';

  /// Endpoint para obtener productos por categoría
  String byCategory(int categoryId) =>
      '$baseUrl/api/categorias/$categoryId/productos';
}

/// Endpoints relacionados con mesas
class TableEndpoints {
  final String baseUrl;

  TableEndpoints(this.baseUrl);

  /// Endpoint para obtener todas las mesas
  String get all => '$baseUrl/api/mesas';

  /// Endpoint para obtener una mesa por ID
  String byId(int id) => '$baseUrl/api/mesas/$id';

  /// Endpoint para cambiar el estado de una mesa
  String status(int id) => '$baseUrl/api/mesas/$id/estado';
}

/// Endpoints relacionados con pedidos
class OrderEndpoints {
  final String baseUrl;

  OrderEndpoints(this.baseUrl);

  /// Endpoint para obtener todos los pedidos
  String get all => '$baseUrl/api/pedidos';

  /// Endpoint para obtener un pedido por ID
  String byId(int id) => '$baseUrl/api/pedidos/$id';

  /// Endpoint para crear un nuevo pedido
  String get create => '$baseUrl/api/pedidos';

  /// Endpoint para actualizar el estado de un pedido
  String status(int id) => '$baseUrl/api/pedidos/$id/estado';
}
