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

class RoleService {
  static const String baseUrl = kBackendUrl;
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
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Role.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar roles: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getRoles: $e');
      throw Exception('Error de conexión: $e');
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
        return Role.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Error al obtener rol: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getRoleById: $e');
      throw Exception('Error de conexión: $e');
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
        return Role.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al crear rol: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en createRole: $e');
      throw Exception('Error al crear rol: $e');
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
        return Role.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al actualizar rol: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en updateRole: $e');
      throw Exception('Error al actualizar rol: $e');
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
      print('Error en deleteRole: $e');
      throw Exception('Error al eliminar rol: $e');
    }
  }
}
