import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:vercy_motos/utils/html_stub.dart'
    as html;

import '../config/constants.dart';
import '../models/solicitud_usuario.dart';
import '../utils/api_error.dart';

/// Contrato del servicio de solicitudes de usuario (permite inyectar un fake en las pruebas).
abstract class ISolicitudUsuarioService {
  Future<List<SolicitudUsuario>> pendientes();
  Future<void> autorizar(String id);
  Future<void> rechazar(String id);
}

/// Solicitudes de creación de usuario: solo un SUPERADMIN puede listarlas, autorizarlas o rechazarlas.
class SolicitudUsuarioService implements ISolicitudUsuarioService {
  static String get _baseUrl => kDynamicBackendUrl;
  static const _timeout = Duration(seconds: 30);
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _headers() async {
    String? token;
    try {
      token = kIsWeb ? html.window.localStorage['jwt_token'] : await _storage.read(key: 'jwt_token');
    } catch (_) {
      token = null;
    }
    if (token == null) throw Exception('Token no encontrado');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  @override
  Future<List<SolicitudUsuario>> pendientes() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/solicitudes-usuario/pendientes'), headers: await _headers())
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throwBackendError(response.body, response.statusCode, prefix: 'No se pudieron cargar las solicitudes');
      }
      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded['data'] : decoded;
      return (data as List? ?? const [])
          .map((e) => SolicitudUsuario.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      wrapOrThrow(e, context: 'Error al cargar las solicitudes de usuario');
    }
  }

  @override
  Future<void> autorizar(String id) => _resolver(id, 'autorizar', 'No se pudo autorizar el usuario');

  @override
  Future<void> rechazar(String id) => _resolver(id, 'rechazar', 'No se pudo rechazar la solicitud');

  Future<void> _resolver(String id, String accion, String prefijoError) async {
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl/api/solicitudes-usuario/$id/$accion'), headers: await _headers())
          .timeout(_timeout);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throwBackendError(response.body, response.statusCode, prefix: prefijoError);
      }
    } catch (e) {
      wrapOrThrow(e, context: prefijoError);
    }
  }
}
