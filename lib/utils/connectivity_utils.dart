import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ConnectivityUtils {
  /// Comprueba si hay conexión con el servidor
  static Future<bool> checkServerConnection(String serverUrl) async {
    if (kIsWeb) {
      // En web no podemos hacer ping directamente
      return true;
    }

    try {
      // Extraer host y puerto de la URL
      Uri uri = Uri.parse(serverUrl);
      String host = uri.host;
      int port = uri.port > 0 ? uri.port : 80;

      print('🌐 Comprobando conexión a $host:$port...');

      // Comprobar si se puede establecer una conexión socket
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(seconds: 5),
      );
      socket.destroy();

      print('✅ Conectado correctamente a $host:$port');
      return true;
    } catch (e) {
      print('❌ Error de conexión: $e');
      return false;
    }
  }

  /// Obtiene la dirección IP local del dispositivo (para depuración)
  static Future<List<String>> getLocalIpAddresses() async {
    if (kIsWeb) {
      return ['No disponible en web'];
    }

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      List<String> addresses = [];
      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          addresses.add('${address.address} (${interface.name})');
        }
      }

      return addresses;
    } catch (e) {
      print('❌ Error obteniendo IPs: $e');
      return ['Error: $e'];
    }
  }
}
