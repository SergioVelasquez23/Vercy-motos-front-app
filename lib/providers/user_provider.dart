import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Importación condicional para no afectar builds móviles
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:serch_restapp/utils/html_stub.dart'
    as html;
import '../utils/jwt_utils.dart';

class UserProvider extends ChangeNotifier {
  String? _token;
  List<String> _roles = [];
  String? _userId;
  String? _userName;
  String? _userEmail;

  final storage = FlutterSecureStorage();

  String? get token => _token;
  List<String> get roles => _roles;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  bool get isAuthenticated => _token != null;

  bool get isSuperAdmin => _roles.contains('SUPERADMIN');
  bool get isAdmin => _roles.contains('ADMIN') || _roles.contains('SUPERADMIN');
  bool get isMesero => _roles.contains('MESERO');

  // Check if user has specific role
  bool hasRole(String role) {
    return _roles.contains(role);
  }

  // Check if user has any of the specified roles
  bool hasAnyRole(List<String> requiredRoles) {
    for (var role in requiredRoles) {
      if (_roles.contains(role)) {
        return true;
      }
    }
    return false;
  }

  Future<void> initializeFromStorage() async {
    String? storedToken;

    if (kIsWeb) {
      storedToken = html.window.localStorage['jwt_token'];
    } else {
      storedToken = await storage.read(key: 'jwt_token');
    }

    if (storedToken != null) {
      await setToken(storedToken);
    }
  }

  Future<void> setToken(String token) async {
    _token = token;

    try {
      // Extract user information from token
      final payload = JwtUtils.decodeToken(token);
      _userId = payload['_id'];
      _userName = payload['name'];
      _userEmail = payload['email'];

      print('👤 JWT Payload completo: $payload');

      // Extract roles
      if (payload.containsKey('roles')) {
        final rolesData = payload['roles'];
        print(
          '👤 Datos de roles sin procesar: $rolesData (tipo: ${rolesData.runtimeType})',
        );

        if (rolesData is List) {
          // Convertir cada elemento a String para asegurar compatibilidad
          _roles = rolesData.map((role) => role.toString()).toList();
          print('👤 Roles convertidos desde Lista: $_roles');
        } else if (rolesData is String) {
          // Si es una cadena, posiblemente sea un solo rol
          _roles = [rolesData];
          print('👤 Roles como única cadena: $_roles');
        } else {
          // Para otros casos, intentar convertir a String
          try {
            _roles = [rolesData.toString()];
            print('👤 Rol convertido a String: $_roles');
          } catch (e) {
            _roles = [];
            print('⚠️ No se pudo convertir el rol a String: $e');
          }
          print(
            '⚠️ Formato de roles desconocido (usando toString): $rolesData',
          );
        }

        print('👤 Roles extraídos del token: $_roles');

        // Verificar roles específicos para depuración
        print('👤 ¿Es SUPERADMIN? ${_roles.contains("SUPERADMIN")}');
        print('👤 ¿Es ADMIN? ${_roles.contains("ADMIN")}');
        print('👤 ¿Es MESERO? ${_roles.contains("MESERO")}');
      } else {
        _roles = [];
        print('⚠️ No se encontraron roles en el token JWT');
      } // Save token to storage
      if (kIsWeb) {
        html.window.localStorage['jwt_token'] = token;
      } else {
        await storage.write(key: 'jwt_token', value: token);
      }

      notifyListeners();
    } catch (e) {
      print('Error processing token: $e');
      _roles = [];
    }
  }

  void logout() {
    _token = null;
    _roles = [];
    _userId = null;
    _userName = null;
    _userEmail = null;

    if (kIsWeb) {
      html.window.localStorage.remove('jwt_token');
    } else {
      storage.delete(key: 'jwt_token');
    }

    notifyListeners();
  }

  // Método para actualizar los roles desde el backend
  Future<void> actualizarRoles(List<String> roles) async {
    print('🔄 Actualizando roles de usuario: $roles');
    _roles = roles;
    notifyListeners();
    print(
      '✅ Roles actualizados. isAdmin: $isAdmin, isSuperAdmin: $isSuperAdmin, isMesero: $isMesero',
    );
  }
}
