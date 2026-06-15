import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/api_error.dart';
import '../models/user.dart';

class UserManagementService {
  final String _baseUrl = ApiConfig.instance.baseUrl;

  /// Obtiene la lista de todos los usuarios
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> usersJson = data['users'] ?? data;
        return usersJson.cast<Map<String, dynamic>>();
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener usuarios');
      }
    } catch (e) {
        
      throw Exception('Error de conexión al obtener usuarios');
    }
  }

  /// Actualiza el rol de un usuario
  Future<Map<String, dynamic>> updateUserRole(
    String userId,
    String newRole,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId/role'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rol': newRole}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Rol actualizado correctamente'};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Error al actualizar el rol',
        };
      }
    } catch (e) {
        
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Elimina un usuario (opcional)
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Usuario eliminado correctamente'};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Error al eliminar el usuario',
        };
      }
    } catch (e) {
        
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Actualiza el estado activo/inactivo de un usuario
  Future<Map<String, dynamic>> toggleUserStatus(
    String userId,
    bool isActive,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'activo': isActive}),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': isActive
              ? 'Usuario activado correctamente'
              : 'Usuario desactivado correctamente',
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Error al cambiar el estado',
        };
      }
    } catch (e) {
        
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Obtiene usuarios pendientes de autorización
  Future<List<Map<String, dynamic>>> getUsersPendientesAutorizacion() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/pendientes-autorizacion'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> usersJson = data['users'] ?? data;
        return usersJson.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
          'Error al obtener usuarios pendientes: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Autoriza un usuario para acceder a la plataforma
  Future<Map<String, dynamic>> autorizarUsuario(String userId) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/users/$userId/autorizar'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Usuario autorizado correctamente'};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Error al autorizar el usuario',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Deniega/revoca autorización de un usuario
  Future<Map<String, dynamic>> negarUsuario(String userId) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/users/$userId/denegar'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Autorización revocada correctamente',
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Error al revocar autorización',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }
}
