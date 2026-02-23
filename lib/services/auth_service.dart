import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../screens/dashboard_screen_v2.dart';
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
      );
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
      return {'success': false, 'message': 'Error: $e'};
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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey('token')) {
          String token = data['token'];

          // Update the user provider with the new token
          await userProvider.setToken(token);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreenV2()),
          );
        } else {
          throw Exception('La respuesta no contiene el campo "token".');
        }
      } else {
          
          
        throw Exception('Error de inicio de sesión');
      }
    } catch (e) {
        

      String errorMessage = 'Error al iniciar sesión';

      // Mensaje más específico según el tipo de error
      if (e.toString().contains('SocketException')) {
        errorMessage +=
            ': No se pudo conectar al servidor. Comprueba tu conexión a internet y que estás en la misma red que el servidor.';
      } else if (e.toString().contains('HttpException')) {
        errorMessage += ': Error en la solicitud HTTP.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage += ': Error en el formato de respuesta.';
      } else {
        errorMessage += ': $e';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
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
      );

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
      } else if (response.statusCode == 401) {
          
        return {'error': 'Usuario o contraseña incorrectos', 'status': 401};
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
        
      return {'error': 'Error de conexión: $e', 'status': 0};
    }
  }

  Future<Map<String, dynamic>?> validarCodigo(String code) async {
    final url = ApiConfig.instance.endpoints.auth.validateCode(code);
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

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
      );

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
