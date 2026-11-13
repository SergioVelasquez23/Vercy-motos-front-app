import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/borrador_compra_service.dart';

/// Clave donde las versiones anteriores guardaban los borradores de compra,
/// solo en este navegador o dispositivo.
const String kClaveBorradoresCompraLocales = 'factura_compra_borradores';

/// Sube al servidor los borradores de compra que quedaron guardados solo en
/// este navegador, para que no se pierdan al pasar a borradores por usuario.
///
/// Sube del más antiguo al más nuevo (así el más nuevo queda como el más
/// reciente en el servidor) y va quitando de la copia local cada uno que sube:
/// si algo falla a mitad, los pendientes se conservan y se reintentan la
/// próxima vez, sin volver a subir los que ya pasaron (no hay duplicados).
///
/// Devuelve cuántos borradores subió.
Future<int> migrarBorradoresCompraLocales(IBorradorCompraService servicio) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kClaveBorradoresCompraLocales);
  if (raw == null || raw.isEmpty) return 0;

  List<dynamic> pendientes;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      await prefs.remove(kClaveBorradoresCompraLocales);
      return 0;
    }
    pendientes = List<dynamic>.from(decoded);
  } catch (_) {
    // Copia local corrupta: no hay nada rescatable.
    await prefs.remove(kClaveBorradoresCompraLocales);
    return 0;
  }

  var subidos = 0;
  while (pendientes.isNotEmpty) {
    final borrador = pendientes.first;
    if (borrador is Map && borrador.isNotEmpty) {
      try {
        await servicio.guardar(Map<String, dynamic>.from(borrador));
        subidos++;
      } catch (_) {
        break; // se conserva este y los siguientes para reintentar
      }
    }
    pendientes.removeAt(0);
    await prefs.setString(kClaveBorradoresCompraLocales, jsonEncode(pendientes));
  }

  if (pendientes.isEmpty) {
    await prefs.remove(kClaveBorradoresCompraLocales);
  }
  return subidos;
}
