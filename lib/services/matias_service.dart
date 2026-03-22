import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/endpoints_config.dart';

/// Servicio para integración con API de Facturación Matias
/// Maneja autenticación y facturación de Pedidos
class MatiasService {
  static String _getBaseUrl() {
    return '${EndpointsConfig().currentBaseUrl}/api/matias';
  }

  /// 1️⃣ Autenticar con el servicio Matias
  static Future<bool> authenticate() async {
    try {
      final url = '${_getBaseUrl()}/authenticate';
      final headers = {'Content-Type': 'application/json'};

      // 🔍 LOGS: Request de autenticación
      print('\n========== REQUEST AUTHENTICATE ==========');
      print('URL: $url');
      print('Método: POST');
      print('Headers: $headers');
      print('Body: (vacío)');
      print('=========================================\n');

      final response = await http.post(Uri.parse(url), headers: headers);

      // 🔍 LOGS: Response de autenticación
      print('========== RESPONSE AUTHENTICATE ==========');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('==========================================\n');

      if (response.statusCode == 200) {
        print('✅ Autenticación exitosa con Matias');
        return true;
      }
      print('❌ Error autenticando: ${response.body}');
      return false;
    } catch (e) {
      print('❌ Exception autenticando: $e');
      return false;
    }
  }

  /// 2️⃣ Verificar status de autenticación
  static Future<bool> checkStatus() async {
    try {
      final url = '${_getBaseUrl()}/status';
      final headers = {'Content-Type': 'application/json'};

      // 🔍 LOGS: Request de status
      print('========== REQUEST STATUS ==========');
      print('URL: $url');
      print('Método: GET');
      print('Headers: $headers');
      print('====================================\n');

      final response = await http.get(Uri.parse(url), headers: headers);

      // 🔍 LOGS: Response de status
      print('========== RESPONSE STATUS ==========');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('=====================================\n');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['data']['authenticated'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Exception verificando status: $e');
      return false;
    }
  }

  /// 3️⃣ Facturar un Pedido
  /// Usa endpoint: POST /api/matias/documento-mesa/{pedidoId}/facturar
  /// Parámetros:
  ///   - pedidoId: ID del pedido a facturar
  ///   - token: Token de autorización (opcional)
  /// Retorna mapa con datos de la facturación (CUFE, status, etc)
  /// o null si hay error
  static Future<Map<String, dynamic>?> facturarPedido(
    String pedidoId, {
    String? token,
  }) async {
    try {
      // Primero verificar autenticación
      bool autenticado = await checkStatus();
      if (!autenticado) {
        print('⚠️ No autenticado. Intentando autenticar...');
        await authenticate();
      }

      print('📄 Facturando pedido: $pedidoId');

      // Construir headers
      final headers = {'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final url = '${_getBaseUrl()}/documento-mesa/$pedidoId/facturar';

      // 🔍 LOGS: Mostrar detalles de la request
      print('\n========== REQUEST MATIAS ==========');
      print('URL: $url');
      print('Método: POST');
      print('Headers: $headers');
      print('Body: (vacío - POST sin body)');
      print('====================================\n');

      final response = await http.post(Uri.parse(url), headers: headers);

      // 🔍 LOGS: Mostrar detalles de la response
      print('\n========== RESPONSE MATIAS ==========');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('====================================\n');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['success'] == true) {
          print('✅ Pedido $pedidoId facturado exitosamente');
          print('CUFE: ${json['data']['xmlDocumentKey']}');
          return json['data'];
        } else {
          print('❌ Error al facturar: ${json['message']}');
          return null;
        }
      } else {
        print('❌ HTTP Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception facturando: $e');
      return null;
    }
  }

  /// [DEPRECATED] Usa facturarPedido() en su lugar
  static Future<Map<String, dynamic>?> facturarDocumentoMesa(
    String pedidoId,
  ) async {
    print(
      '⚠️ facturarDocumentoMesa() está deprecado. Usa facturarPedido() en su lugar.',
    );
    return facturarPedido(pedidoId);
  }
}
