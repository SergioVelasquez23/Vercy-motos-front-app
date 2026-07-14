import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Importación condicional para no afectar builds móviles
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:vercy_motos/utils/html_stub.dart'
    as html;
import '../utils/jwt_utils.dart';

class UserProvider extends ChangeNotifier {
  // Singleton: HttpApiService necesita poder forzar un logout completo
  // (estado en memoria + storage) cuando el backend responde 401/403, sin
  // depender de un BuildContext. Antes de este cambio solo existía la
  // instancia creada en main.dart y nada fuera del árbol de widgets podía
  // llegar a ella, así que un token inválido se borraba del storage pero la
  // UI seguía "viéndose logueada" indefinidamente.
  static final UserProvider _instance = UserProvider._internal();
  factory UserProvider() => _instance;
  UserProvider._internal();

  String? _token;
  List<String> _roles = [];
  String? _userId;
  String? _userName;
  String? _userEmail;
  bool _initialized = false;

  final storage = FlutterSecureStorage();

  String? get token => _token;
  List<String> get roles => _roles;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isInitialized => _initialized;

  bool get isAuthenticated => _token != null;

  bool get isSuperAdmin => _roles.contains('SUPERADMIN');
  bool get isAdmin => _roles.contains('ADMIN') || _roles.contains('SUPERADMIN');
  bool get isMesero => _roles.contains('MESERO');
  bool get isAsesor {
    // Hacer búsqueda case-insensitive para compatibilidad
    return _roles.any((role) => role.toUpperCase() == 'ASESOR');
  }

  // Método para verificar si es únicamente mesero (sin otros roles administrativos)
  bool get isOnlyMesero =>
      _roles.contains('MESERO') &&
      !_roles.contains('ADMIN') &&
      !_roles.contains('SUPERADMIN');

  // Método para verificar si es únicamente asesor (sin otros roles administrativos)
  bool get isOnlyAsesor =>
      _roles.contains('ASESOR') &&
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
    if (_initialized) return;

    String? storedToken;

    if (kIsWeb) {
      storedToken = html.window.localStorage['jwt_token'];
    } else {
      storedToken = await storage.read(key: 'jwt_token');
    }

    if (storedToken != null) {
      // No basta con que exista un token guardado: hay que confirmar que
      // sigue vigente antes de dar la sesión por buena. Sin esto, un token
      // vencido (o emitido antes de que el backend activara @PreAuthorize)
      // hacía que la app saltara la pantalla de login e intentara cargar
      // todo con un token que el backend ya rechaza con 401/403 en cada
      // request, dejando pantallas vacías sin ninguna pista de por qué.
      bool tokenValido;
      try {
        tokenValido = !JwtUtils.isTokenExpired(storedToken);
      } catch (e) {
        tokenValido = false;
      }

      if (tokenValido) {
        await setToken(storedToken, saveToStorage: false);
      } else {
        debugPrint(
            '🔑 [UserProvider] Token guardado vencido o inválido — se descarta, requiere login');
        await _clearStoredToken();
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _clearStoredToken() async {
    if (kIsWeb) {
      html.window.localStorage.remove('jwt_token');
    } else {
      await storage.delete(key: 'jwt_token');
    }
  }

  Future<void> setToken(String token, {bool saveToStorage = true}) async {
    _token = token;

    try {
      // Extract user information from token
      final payload = JwtUtils.decodeToken(token);
      _userId = payload['_id'] ?? payload['id'] ?? payload['userId'];
      _userName = payload['name'] ?? payload['nombre'] ?? payload['username'] ??
          payload['email'];
      _userEmail = payload['email'] ?? payload['correo'] ?? payload['userEmail'];

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
      }

      debugPrint('🔑 [UserProvider] Roles del usuario "$_userName": $_roles '
          '(isAdmin=$isAdmin, isSuperAdmin=$isSuperAdmin, isAsesor=$isAsesor, isMesero=$isMesero)');

      if (saveToStorage) {
        if (kIsWeb) {
          html.window.localStorage['jwt_token'] = token;
        } else {
          await storage.write(key: 'jwt_token', value: token);
        }
      }

      notifyListeners();
    } catch (e) {
      _roles = [];
    }
  }

  Future<void> logout() async {
    _token = null;
    _roles = [];
    _userId = null;
    _userName = null;
    _userEmail = null;

    // El email/password guardados se conservan a propósito para que el
    // usuario no tenga que volver a escribirlos tras cerrar sesión — pero
    // el flag de auto-login sí se apaga: si no, LoginScreen ve
    // remember_credentials=true al montarse y vuelve a loguear solo con esas
    // credenciales, dejando "cerrar sesión" sin efecto aparente.
    await storage.delete(key: 'remember_credentials');

    await _clearStoredToken();

    notifyListeners();
  }

  // Método para actualizar los roles desde el backend
  Future<void> actualizarRoles(List<String> roles) async {
    _roles = roles;
    notifyListeners();
  }
}
