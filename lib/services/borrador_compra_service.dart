import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/borrador_compra.dart';
import '../utils/api_error.dart';
import 'base_api_service.dart';

/// Interfaz mínima para inyectar un fake en tests de widget (mismo patrón que
/// `ICuadreCajaService`).
abstract class IBorradorCompraService {
  /// Borradores del usuario autenticado, del más reciente al más antiguo.
  Future<List<BorradorCompra>> listar();

  /// Guarda el formulario como borrador nuevo del usuario autenticado.
  Future<BorradorCompra> guardar(Map<String, dynamic> datos);

  /// Elimina un borrador propio.
  Future<void> eliminar(String id);
}

/// Borradores de compra guardados en el servidor, por usuario. Antes vivían en
/// SharedPreferences, es decir, solo en el navegador donde se crearon: un
/// borrador hecho en el celular no aparecía en el computador.
class BorradorCompraService implements IBorradorCompraService {
  final ApiConfig _apiConfig = ApiConfig();
  static const _timeout = Duration(seconds: 20);

  String get _url => '${_apiConfig.baseUrl}/api/borradores-compra';

  Future<Map<String, String>> _headers() async {
    final h = await BaseApiService().getHeaders();
    h['Accept'] = 'application/json';
    return h;
  }

  /// El backend responde `{ "data": ... }`.
  dynamic _data(String body) {
    final decoded = json.decode(body);
    return decoded is Map ? decoded['data'] : decoded;
  }

  @override
  Future<List<BorradorCompra>> listar() async {
    try {
      final response = await http.get(Uri.parse(_url), headers: await _headers()).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = _data(response.body);
        if (data is! List) return [];
        return data
            .whereType<Map>()
            .map((m) => BorradorCompra.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener los borradores');
    } catch (e) {
      wrapOrThrow(e, context: 'No se pudieron cargar los borradores');
    }
  }

  @override
  Future<BorradorCompra> guardar(Map<String, dynamic> datos) async {
    try {
      final response = await http
          .post(Uri.parse(_url), headers: await _headers(), body: json.encode(datos))
          .timeout(_timeout);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _data(response.body);
        return BorradorCompra.fromJson(Map<String, dynamic>.from(data as Map));
      }
      throwBackendError(response.body, response.statusCode, prefix: 'Error al guardar el borrador');
    } catch (e) {
      wrapOrThrow(e, context: 'No se pudo guardar el borrador');
    }
  }

  @override
  Future<void> eliminar(String id) async {
    try {
      final response =
          await http.delete(Uri.parse('$_url/$id'), headers: await _headers()).timeout(_timeout);
      if (response.statusCode == 200 || response.statusCode == 204) return;
      throwBackendError(response.body, response.statusCode, prefix: 'Error al eliminar el borrador');
    } catch (e) {
      wrapOrThrow(e, context: 'No se pudo eliminar el borrador');
    }
  }
}
