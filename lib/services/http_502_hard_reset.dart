import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import '../utils/logger.dart';

/// Cuenta endpoints DISTINTOS que respondieron 502 (Bad Gateway) durante la
/// sesión actual. Cuando más de [umbral] endpoints distintos han fallado con
/// 502 (típico cuando el backend en Render está caído o reiniciando), hace un
/// hard reset: recarga la página completa, lo que de paso limpia todo el
/// estado/caché en memoria (providers, DatosCacheProvider, etc.) sin tener
/// que ir provider por provider limpiando manualmente.
class Http502Tracker {
  Http502Tracker._internal();
  static final Http502Tracker instance = Http502Tracker._internal();

  static const int umbral = 8;

  final Set<String> _endpointsCon502 = {};
  bool _reinicioDisparado = false;

  void registrarRespuesta(String path, int statusCode) {
    if (statusCode != 502) return;
    if (_reinicioDisparado) return;

    final esNuevo = _endpointsCon502.add(path);
    if (!esNuevo) return;

    appLog(
      '⚠️ [Http502Tracker] 502 en "$path" (${_endpointsCon502.length}/$umbral endpoints distintos)',
    );

    if (_endpointsCon502.length > umbral) {
      _dispararHardReset();
    }
  }

  void _dispararHardReset() {
    if (_reinicioDisparado) return;
    _reinicioDisparado = true;
    appLog(
      '🔄 [Http502Tracker] Más de $umbral endpoints dieron 502 — recargando la app',
    );
    html.window.location.reload();
  }
}

/// Cliente HTTP que envuelve al cliente real y reporta cada respuesta a
/// [Http502Tracker]. Se instala una sola vez en main.dart vía
/// `http.runWithClient`, así que intercepta TODAS las llamadas de la app
/// (incluidas las que llaman a `http.get`/`http.post` directamente, sin pasar
/// por ningún service base), sin tener que tocar cada servicio uno por uno.
class Http502TrackingClient extends http.BaseClient {
  Http502TrackingClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    Http502Tracker.instance.registrarRespuesta(
      request.url.path,
      response.statusCode,
    );
    return response;
  }

  @override
  void close() => _inner.close();
}
