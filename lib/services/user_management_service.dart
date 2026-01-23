import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
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
        throw Exception('Error al obtener usuarios: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getAllUsers: $e');
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
      print('❌ Error en updateUserRole: $e');
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
      print('❌ Error en deleteUser: $e');
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
      print('❌ Error en toggleUserStatus: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }
}
