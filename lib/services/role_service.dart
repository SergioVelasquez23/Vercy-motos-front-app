import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/role.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:vercy_motos/utils/html_stub.dart'
    as html;
import '../utils/api_error.dart';

class RoleService {
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

  // Obtener todos los roles
  Future<List<Role>> getRoles() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/roles'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> data = body['data'] ?? [];
        return data.map((json) => Role.fromJson(json)).toList();
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al cargar roles');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error de conexión');
    }
  }

  // Obtener rol por ID
  Future<Role?> getRoleById(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/roles/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        return Role.fromJson(body['data']);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener rol');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error de conexión');
    }
  }

  // Crear nuevo rol
  Future<Role> createRole(Role role) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/roles'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(role.toJsonCreate()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        return Role.fromJson(body['data']);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al crear rol');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al crear rol');
    }
  }

  // Actualizar rol
  Future<Role> updateRole(Role role) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/roles/${role.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(role.toJsonCreate()),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        return Role.fromJson(body['data']);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al actualizar rol');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al actualizar rol');
    }
  }

  // Eliminar rol
  Future<bool> deleteRole(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/roles/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      wrapOrThrow(e, context: 'Error al eliminar rol');
    }
  }
}
