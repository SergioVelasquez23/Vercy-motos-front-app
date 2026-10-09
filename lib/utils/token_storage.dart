import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:vercy_motos/utils/html_stub.dart'
    as html;

/// Devuelve el token preferido cuando hay una sesión activa en memoria y un
/// valor guardado en storage. En iOS/web esto evita que se quede sin
/// Authorization si el storage seguro no devuelve el valor de forma fiable.
String? pickPreferredToken({String? memoryToken, String? storageToken}) {
  final preferredMemoryToken = memoryToken?.trim();
  final preferredStorageToken = storageToken?.trim();

  if (preferredMemoryToken != null && preferredMemoryToken.isNotEmpty) {
    return preferredMemoryToken;
  }

  if (preferredStorageToken != null && preferredStorageToken.isNotEmpty) {
    return preferredStorageToken;
  }

  return null;
}

// Caché en memoria del JWT — en móvil/desktop, FlutterSecureStorage().read()
// es una llamada a un canal de plataforma nativo: cualquier pantalla con
// varias peticiones (y hay pantallas con 8-10) la repetía una vez por
// petición solo para leer el mismo valor. En web no hace falta (localStorage
// ya es sincrónico), pero mantener una sola ruta evita otra bifurcación.
// [cacheJwtTokenInMemory] la mantiene sincronizada: login/logout deben
// llamarla junto con escribir/borrar el token real (ver UserProvider).
String? _memoryToken;

void cacheJwtTokenInMemory(String? token) {
  _memoryToken = token?.trim().isEmpty == true ? null : token;
}

/// Lee el JWT guardado, con el mismo criterio de plataforma que usa
/// UserProvider/AuthService al iniciar sesión: en web, del
/// window.localStorage donde se guarda (ahí es donde AuthService.saveToken
/// y UserProvider.setToken lo escriben en web); en móvil/desktop, de
/// FlutterSecureStorage (o de la caché en memoria de arriba, si ya se leyó
/// una vez en esta sesión).
///
/// Antes varios servicios leían el token solo con
/// `FlutterSecureStorage().read(key: 'jwt_token')`, que en web NUNCA
/// encontraba el token (se guarda en localStorage, no en el storage seguro
/// nativo) — mandaban las peticiones sin header Authorization y el backend
/// las rechazaba. No se notaba mientras la API no exigía autenticación.
Future<String?> readJwtToken() async {
  if (kIsWeb) {
    // ignore: undefined_prefixed_name
    final storageToken = html.window.localStorage['jwt_token'];
    return pickPreferredToken(memoryToken: _memoryToken, storageToken: storageToken);
  }

  if (_memoryToken != null) return _memoryToken;

  const storage = FlutterSecureStorage();
  final storageToken = await storage.read(key: 'jwt_token');
  final token = pickPreferredToken(memoryToken: _memoryToken, storageToken: storageToken);
  _memoryToken = token;
  return token;
}

/// Contraparte de [readJwtToken] para logout: borra el token del mismo
/// lugar de donde se lee según la plataforma, y de la caché en memoria.
Future<void> clearJwtToken() async {
  _memoryToken = null;
  if (kIsWeb) {
    // ignore: undefined_prefixed_name
    html.window.localStorage.remove('jwt_token');
    return;
  }
  const storage = FlutterSecureStorage();
  await storage.delete(key: 'jwt_token');
}
