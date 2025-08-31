import '../models/role.dart';
import 'base/http_api_service.dart';
import 'base/base_api_service.dart';

/// RoleService refactorizado usando BaseApiService
/// 
/// COMPARACIÓN:
/// - Servicio original: ~165 líneas con mucho código duplicado
/// - Servicio nuevo: ~80 líneas enfocadas en lógica de negocio
/// - Reducción: ~52% menos código
/// - Manejo de errores: Centralizado y consistente
class RoleService {
  static final RoleService _instance = RoleService._internal();
  factory RoleService() => _instance;
  RoleService._internal();

  final BaseApiService _apiService = HttpApiService();

  /// Obtiene todos los roles disponibles
  Future<List<Role>> getRoles() async {
    try {
      final data = await _apiService.get<List<dynamic>>(
        '/api/roles',
        parser: (responseData) {
          if (responseData is List) {
            return responseData;
          } else if (responseData is Map && responseData.containsKey('data')) {
            return responseData['data'] as List<dynamic>;
          }
          return responseData as List<dynamic>;
        },
      );

      return data.map((json) => Role.fromJson(json)).toList();
    } on ApiException {
      rethrow;
    }
  }

  /// Obtiene un rol específico por su ID
  Future<Role?> getRoleById(String id) async {
    try {
      final data = await _apiService.get<Map<String, dynamic>>('/api/roles/$id');
      return Role.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return null; // Rol no encontrado
      }
      rethrow;
    }
  }

  /// Crea un nuevo rol en el sistema
  Future<Role> createRole(Role role) async {
    try {
      final data = await _apiService.post<Map<String, dynamic>>(
        '/api/roles',
        body: role.toJsonCreate(),
      );
      return Role.fromJson(data);
    } on ApiException {
      rethrow;
    }
  }

  /// Actualiza un rol existente
  Future<Role> updateRole(Role role) async {
    try {
      final data = await _apiService.put<Map<String, dynamic>>(
        '/api/roles/${role.id}',
        body: role.toJsonCreate(), // Usar el mismo método que el original
      );
      return Role.fromJson(data);
    } on ApiException {
      rethrow;
    }
  }

  /// Elimina un rol del sistema
  Future<bool> deleteRole(String id) async {
    try {
      await _apiService.delete<void>('/api/roles/$id');
      return true;
    } on ApiException catch (e) {
      // Para DELETE, tanto 200 como 204 indican éxito
      if (e.statusCode == 200 || e.statusCode == 204) {
        return true;
      }
      return false;
    }
  }
}
