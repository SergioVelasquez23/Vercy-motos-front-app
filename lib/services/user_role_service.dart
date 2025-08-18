import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/user_role.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:serch_restapp/utils/html_stub.dart'
    as html;

class UserRoleService {
  static const String baseUrl = kApiUrl;
  final storage = FlutterSecureStorage();

  // Obtener token del storage
  Future<String?> _getToken() async {
    try {
      if (kIsWeb) {
        return html.window.localStorage['jwt_token'];
      } else {
        return await storage.read(key: 'jwt_token');
      }
    } catch (e) {
      print('Error obteniendo token: $e');
      return null;
    }
  }

  // Obtener todas las relaciones usuario-rol
  Future<List<UserRole>> getUserRoles() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/usersroles'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserRole.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al cargar relaciones usuario-rol: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error en getUserRoles: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener relación por ID
  Future<UserRole?> getUserRoleById(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/usersroles/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return UserRole.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Error al obtener relación: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getUserRoleById: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Asignar rol a usuario
  Future<UserRole?> assignRoleToUser(String userId, String roleId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/usersroles/user/$userId/role/$roleId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isNotEmpty && responseBody != 'null') {
          return UserRole.fromJson(json.decode(responseBody));
        }
      }
      return null;
    } catch (e) {
      print('Error en assignRoleToUser: $e');
      throw Exception('Error al asignar rol: $e');
    }
  }

  // Actualizar relación usuario-rol
  Future<UserRole> updateUserRole(UserRole userRole) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/usersroles/${userRole.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(userRole.toJsonCreate()),
      );

      if (response.statusCode == 200) {
        return UserRole.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al actualizar relación: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en updateUserRole: $e');
      throw Exception('Error al actualizar relación: $e');
    }
  }

  // Eliminar relación usuario-rol
  Future<bool> deleteUserRole(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/usersroles/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('Error en deleteUserRole: $e');
      throw Exception('Error al eliminar relación: $e');
    }
  }

  // Obtener roles de un usuario
  Future<List<UserRole>> getRolesByUser(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/usersroles/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserRole.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al cargar roles del usuario: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error en getRolesByUser: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
