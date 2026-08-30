import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/api_error.dart';
import '../models/user.dart';
import 'base_api_service.dart';

class UserManagementService {
  final String _baseUrl = ApiConfig.instance.baseUrl;

  /// Headers con Authorization (Bearer) desde BaseApiService
  Future<Map<String, String>> get _headers => BaseApiService().getHeaders();

  /// Obtiene la lista de todos los usuarios
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> usersJson = data['users'] ?? data;
        return usersJson.cast<Map<String, dynamic>>();
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener usuarios');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener usuarios');
    }
  }

  /// Elimina un usuario (opcional)
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/users/$userId'),
        headers: await _headers,
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
        
      return {'success': false, 'message': errorMessage(e)};
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
        headers: await _headers,
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
        
      return {'success': false, 'message': errorMessage(e)};
    }
  }

}
