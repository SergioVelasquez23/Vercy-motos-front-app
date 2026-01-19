import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/user.dart';
import '../models/role.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:vercy_motos/utils/html_stub.dart'
    as html;

class UserService {
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

  // Obtener roles de un usuario por su ID usando endpoint V2
  Future<List<Role>> getRolesByUserIdV2(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }
      final response = await http.get(
        Uri.parse('$baseUrl/api/usersroles/user2/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return decoded.map((json) => Role.fromJson(json)).toList();
        } else {
          throw Exception('Respuesta inesperada del backend: $decoded');
        }
      } else {
        throw Exception('Error al obtener roles V2: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getRolesByUserIdV2: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener roles de un usuario por su ID
  Future<List<Role>> getRolesByUserId(String userId) async {
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
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return decoded.map((json) => Role.fromJson(json)).toList();
        } else {
          throw Exception('Respuesta inesperada del backend: $decoded');
        }
      } else {
        throw Exception('Error al obtener roles: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getRolesByUserId: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener todos los usuarios
  Future<List<User>> getUsers() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }
      final response = await http.get(
        Uri.parse('$baseUrl/api/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return decoded.map((json) => User.fromJson(json)).toList();
        } else if (decoded is Map) {
          if (decoded.containsKey('data') && decoded['data'] is List) {
            return (decoded['data'] as List)
                .map((json) => User.fromJson(json))
                .toList();
          } else if (decoded.containsKey('error')) {
            throw Exception('Error del backend: ${decoded['error']}');
          } else {
            throw Exception('Respuesta inesperada del backend: $decoded');
          }
        } else {
          throw Exception('Respuesta inesperada del backend: $decoded');
        }
      } else {
        throw Exception('Error al cargar usuarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getUsers: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener usuario por ID
  Future<User?> getUserById(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Error al obtener usuario: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getUserById: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear nuevo usuario
  Future<User> createUser(User user) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }
      final response = await http.post(
        Uri.parse('$baseUrl/api/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(user.toJsonCreate()),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al crear usuario: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en createUser: $e');
      throw Exception('Error al crear usuario: $e');
    }
  }

  // Actualizar usuario
  Future<User> updateUser(User user) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }
      final payload = user.toJsonUpdate();
      print(
        '🔧 DEBUG UserService.updateUser - URL: $baseUrl/api/users/${user.id}',
      );
      print(
        '🔧 DEBUG UserService.updateUser - Payload: ${json.encode(payload)}',
      );
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/${user.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );
      print(
        '🔧 DEBUG UserService.updateUser - Status Code: ${response.statusCode}',
      );
      print(
        '🔧 DEBUG UserService.updateUser - Response Body: ${response.body}',
      );
      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al actualizar usuario: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en updateUser: $e');
      throw Exception('Error al actualizar usuario: $e');
    }
  }

  // Eliminar usuario
  Future<bool> deleteUser(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }
      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('Error en deleteUser: $e');
      throw Exception('Error al eliminar usuario: $e');
    }
  }

  // Obtener información del usuario autenticado
  Future<User?> getCurrentUserInfo() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }
      final response = await http.get(
        Uri.parse('$baseUrl/api/public/security/user-info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      print('Error en getCurrentUserInfo: $e');
      return null;
    }
  }
}
