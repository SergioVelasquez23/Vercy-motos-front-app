import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Importación condicional para no afectar builds móviles
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:serch_restapp/utils/html_stub.dart'
    as html;
import '../utils/jwt_utils.dart';
import 'datos_cache_provider.dart';

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

  // Método para verificar si es únicamente mesero (sin otros roles administrativos)
  bool get isOnlyMesero =>
      _roles.contains('MESERO') &&
      !_roles.contains('ADMIN') &&
      !_roles.contains('SUPERADMIN');

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

      // Extract roles
      if (payload.containsKey('roles')) {
        final rolesData = payload['roles'];

        if (rolesData is List) {
          // Convertir cada elemento a String para asegurar compatibilidad
          _roles = rolesData.map((role) => role.toString()).toList();
        } else if (rolesData is String) {
          // Si es una cadena, posiblemente sea un solo rol
          _roles = [rolesData];
        } else {
          // Para otros casos, intentar convertir a String
          try {
            _roles = [rolesData.toString()];
          } catch (e) {
            _roles = [];
          }
        }
      } else {
        _roles = [];
      } // Save token to storage
      if (kIsWeb) {
        html.window.localStorage['jwt_token'] = token;
      } else {
        await storage.write(key: 'jwt_token', value: token);
      }

      notifyListeners();

      // Inicializar cache de datos cuando se autentica
      try {
        final cacheProvider = DatosCacheProvider();
        await cacheProvider.initialize();
      } catch (e) {
        print('⚠️ Error inicializando cache al autenticar: $e');
      }
    } catch (e) {
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
    _roles = roles;
    notifyListeners();
  }
}
