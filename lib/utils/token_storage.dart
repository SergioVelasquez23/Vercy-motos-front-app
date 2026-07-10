import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:vercy_motos/utils/html_stub.dart'
    as html;

/// Lee el JWT guardado, con el mismo criterio de plataforma que usa
/// UserProvider/AuthService al iniciar sesión: en web, del
/// window.localStorage donde se guarda (ahí es donde AuthService.saveToken
/// y UserProvider.setToken lo escriben en web); en móvil/desktop, de
/// FlutterSecureStorage.
///
/// Antes varios servicios leían el token solo con
/// `FlutterSecureStorage().read(key: 'jwt_token')`, que en web NUNCA
/// encuentra el token (se guarda en localStorage, no en el storage seguro
/// nativo) — mandaban las peticiones sin header Authorization y el backend
/// las rechazaba. No se notaba mientras la API no exigía autenticación.
Future<String?> readJwtToken() async {
  if (kIsWeb) {
    // ignore: undefined_prefixed_name
    return html.window.localStorage['jwt_token'];
  }
  const storage = FlutterSecureStorage();
  return storage.read(key: 'jwt_token');
}

/// Contraparte de [readJwtToken] para logout: borra el token del mismo
/// lugar de donde se lee según la plataforma.
Future<void> clearJwtToken() async {
  if (kIsWeb) {
    // ignore: undefined_prefixed_name
    html.window.localStorage.remove('jwt_token');
    return;
  }
  const storage = FlutterSecureStorage();
  await storage.delete(key: 'jwt_token');
}
