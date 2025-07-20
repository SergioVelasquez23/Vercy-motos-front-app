import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../screens/dashboard_screen_v2.dart';
import 'dart:convert';

class AuthService {
  final String baseUrl = 'http://127.0.0.1:8081/api/public/security/login';
  final storage = FlutterSecureStorage();

  Future<void> iniciarSesion(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: '{"email": "$email", "password": "$password"}',
      );

      if (response.statusCode == 200) {
        // Almacenar el token en el almacenamiento seguro
        await storage.write(key: 'jwt_token', value: response.body);

        // Navegar al Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreenV2()),
        );
      } else {
        throw Exception('Error de inicio de sesión: \\${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<Map<String, dynamic>?> iniciarSesionWithResponse(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: '{"email": "$email", "password": "$password"}',
      );

      if (response.statusCode == 200) {
        // Devuelve el body como Map para manejar el flujo de dos factores
        return response.body.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(response.body))
            : null;
      } else {
        throw Exception('Error de inicio de sesión: \\${response.body}');
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> validarCodigo(String code) async {
    final url =
        'http://127.0.0.1:8081/api/public/security/login/validate/$code';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return response.body.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(response.body))
            : null;
      } else {
        throw Exception('Error al validar el código: \\${response.body}');
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }
}
