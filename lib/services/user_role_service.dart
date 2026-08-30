import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/user_role.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:vercy_motos/utils/html_stub.dart'
    as html;
import '../utils/api_error.dart';

class UserRoleService {
  static String get baseUrl => kDynamicBackendUrl;
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
        throwBackendError(response.body, response.statusCode, prefix: 'Error al cargar relaciones usuario-rol');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al cargar relaciones usuario-rol');
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
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener relación');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener relación');
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
          final Map<String, dynamic> body = json.decode(responseBody);
          final data = body['data'];
          if (data != null) {
            return UserRole.fromJson(data);
          }
        }
      }
      return null;
    } catch (e) {
      wrapOrThrow(e, context: 'Error al asignar rol');
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
        throwBackendError(response.body, response.statusCode, prefix: 'Error al actualizar relación');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al actualizar relación');
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
      wrapOrThrow(e, context: 'Error al eliminar relación');
    }
  }

  // Obtener las relaciones User<->Role de un usuario (con el _id real de la
  // relación, no el del Role) — necesario para poder borrarlas antes de
  // asignar un rol nuevo. NO usar /api/usersroles/user/$userId: ese endpoint
  // devuelve los Role directamente (sin el _id de la relación) por
  // compatibilidad con otras pantallas que sí solo necesitan mostrar el rol.
  Future<List<UserRole>> getRolesByUser(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/usersroles/user/$userId/relaciones'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> data = body['data'] ?? [];
        return data.map((json) => UserRole.fromJson(json)).toList();
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al cargar roles del usuario');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al cargar roles del usuario');
    }
  }
}
