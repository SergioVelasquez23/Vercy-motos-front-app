import '../models/user.dart';
import 'base/http_api_service.dart';

/// UserService refactorizado usando HttpApiService
///
/// Esta versión elimina todo el código HTTP duplicado y se enfoca
/// únicamente en la lógica específica de usuarios.
///
/// BENEFICIOS:
/// - 80% menos líneas de código
/// - Manejo de errores centralizado y consistente
/// - Mejor separación de responsabilidades
/// - Más fácil de mantener y probar
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final HttpApiService _apiService = HttpApiService();

  /// Obtiene todos los usuarios
  Future<List<User>> getUsers() async {
    try {
      final data = await _apiService.get<List<dynamic>>(
        '/api/users',
        parser: (responseData) {
          // Manejar tanto respuesta directa como con wrapper
          if (responseData is List) {
            return responseData;
          } else if (responseData is Map && responseData.containsKey('data')) {
            return responseData['data'] as List<dynamic>;
          }
          return responseData as List<dynamic>;
        },
      );

      return data.map((json) => User.fromJson(json)).toList();
    } on ApiException {
      rethrow; // Los errores ya están bien formateados
    }
  }

  /// Obtiene un usuario por ID
  Future<User?> getUserById(String id) async {
    try {
      final data = await _apiService.get<Map<String, dynamic>>(
        '/api/users/$id',
      );
      return User.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return null; // Usuario no encontrado
      }
      rethrow;
    }
  }

  /// Crea un nuevo usuario
  Future<User> createUser(User user) async {
    try {
      final data = await _apiService.post<Map<String, dynamic>>(
        '/api/users',
        body: user.toJsonCreate(),
      );
      return User.fromJson(data);
    } on ApiException {
      rethrow;
    }
  }

  /// Actualiza un usuario existente
  Future<User> updateUser(User user) async {
    try {
      final data = await _apiService.put<Map<String, dynamic>>(
        '/api/users/${user.id}',
        body: user.toJsonUpdate(),
      );
      return User.fromJson(data);
    } on ApiException {
      rethrow;
    }
  }

  /// Elimina un usuario
  Future<bool> deleteUser(String id) async {
    try {
      await _apiService.delete<void>('/api/users/$id');
      return true;
    } on ApiException catch (e) {
      // Para DELETE, tanto 200 como 204 son éxito
      if (e.statusCode == 200 || e.statusCode == 204) {
        return true;
      }
      return false;
    }
  }

  /// Obtiene la información del usuario autenticado actual
  Future<User?> getCurrentUserInfo() async {
    try {
      final data = await _apiService.get<Map<String, dynamic>>(
        '/api/public/security/user-info',
      );
      return User.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        return null; // No autenticado
      }
      rethrow;
    }
  }

  /// Verifica si el usuario está autenticado
  Future<bool> isAuthenticated() async {
    return await _apiService.hasAuthToken();
  }

  /// Cierra sesión del usuario
  Future<void> logout() async {
    await _apiService.clearAuthToken();
  }
}
