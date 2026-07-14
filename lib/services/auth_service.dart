import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
// Importación condicional para no afectar builds móviles
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:vercy_motos/utils/html_stub.dart'
    as html;
import '../providers/user_provider.dart';
import '../utils/jwt_utils.dart';
import '../utils/connectivity_utils.dart';
import '../config/api_config.dart';
import '../utils/api_error.dart';

class AuthService {
  // Registro de usuario - Por defecto se registra como ASESOR
  Future<dynamic> registerUser(
    String name,
    String email,
    String password,
  ) async {
    final url = ApiConfig.instance.endpoints.auth.register;
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'roles': ['asesor'], // Rol por defecto para nuevos usuarios
        }),
      ).timeout(Duration(seconds: ApiConfig.requestTimeout));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Usuario registrado exitosamente'};
      } else {
        final data = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;
        if (data != null && data['message'] != null) {
          return {'success': false, 'message': data['message']};
        }
        return {'success': false, 'message': 'Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': errorMessage(e)};
    }
  }

  String get baseUrl => ApiConfig.instance.endpoints.auth.login;
  final storage = FlutterSecureStorage();

  Future<void> iniciarSesion(
    BuildContext context,
    String email,
    String password, {
    required UserProvider userProvider,
  }) async {
    try {
        
        

      // Verificar conectividad antes de intentar login
      bool isConnected = await ConnectivityUtils.checkServerConnection(
        ApiConfig.instance.baseUrl,
      );

      if (!isConnected) {
        throw Exception(
          'No se puede conectar al servidor. Verifica tu conexión a internet y que estés en la misma red que el servidor.',
        );
      }

      // Mostrar información de red para depuración (solo en depuración)
      List<String> localIps = await ConnectivityUtils.getLocalIpAddresses();
        
        

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(Duration(seconds: ApiConfig.requestTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey('token')) {
          String token = data['token'];

          // Update the user provider with the new token
          await userProvider.setToken(token);

          if (context.mounted) context.go('/dashboard');
        } else {
          throw Exception('La respuesta no contiene el campo "token".');
        }
      } else {
          
          
        throw Exception('Error de inicio de sesión');
      }
    } catch (e) {
      String errorMsg;
      if (e.toString().contains('SocketException')) {
        errorMsg =
            'No se pudo conectar al servidor. Comprueba tu conexión a internet y que estás en la misma red que el servidor.';
      } else {
        errorMsg = errorMessage(e);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
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
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(Duration(seconds: ApiConfig.requestTimeout));

      if (response.statusCode == 200) {
        final data = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : null;

        // Guardar el token si existe
        if (data != null && data.containsKey('token')) {
          await saveToken(data['token']);
        } else {
            
        }

        return data;
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        // El backend usa 400 para credenciales inválidas en login (no solo 401).
        // Si trae un mensaje propio lo respetamos; si no, mostramos el genérico.
        final backendMsg = parseBackendError(response.body, response.statusCode);
        final esGenerico = backendMsg.trim().isEmpty ||
            backendMsg.startsWith('Error ${response.statusCode}');
        return {
          'error': esGenerico ? 'Usuario o contraseña incorrectos' : backendMsg,
          'status': response.statusCode,
        };
      } else if (response.statusCode == 403) {
        // Autorización pendiente
        return {
          'error':
              'Tu cuenta aún no ha sido autorizada por un administrador. Por favor espera confirmación.',
          'status': 403,
          'authorizationPending': true,
        };
      } else {
          
        return {
          'error': 'Error del servidor: ${response.statusCode}',
          'status': response.statusCode,
        };
      }
    } catch (e) {
      return {'error': errorMessage(e), 'status': 0};
    }
  }

  Future<Map<String, dynamic>?> validarCodigo(String code) async {
    final url = ApiConfig.instance.endpoints.auth.validateCode(code);
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: ApiConfig.requestTimeout));

      if (response.statusCode == 200) {
        return response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : null;
      } else {
          
        return null;
      }
    } catch (e) {
        
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    try {
      if (kIsWeb) {
        // Para web, usa localStorage
        // ignore: undefined_prefixed_name
        await Future.value(html.window.localStorage['jwt_token'] = token);
      } else {
        await storage.write(key: 'jwt_token', value: token);
      }
    } catch (e) {
        
      rethrow; // Re-lanzar la excepción para manejarla en el nivel superior
    }
  }

  // Método para verificar si un token es válido
  Future<bool> verificarToken(String token) async {
    try {
      // Decodificar el token para depuración
      try {
        final payload = JwtUtils.decodeToken(token);
      } catch (e) {
          
      }

      final response = await http.get(
        Uri.parse(ApiConfig.instance.endpoints.auth.userInfo),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: ApiConfig.requestTimeout));

      // Si la respuesta es exitosa, analizamos el contenido para asegurarnos de que el token es válido
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return true;
        } else {
          return false;
        }
      }

      return false;
    } catch (e) {
        
      return false;
    }
  }
}
