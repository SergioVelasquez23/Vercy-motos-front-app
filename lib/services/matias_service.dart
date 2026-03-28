import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/endpoints_config.dart';
import '../utils/logger.dart';

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
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };

      // 🔍 LOGS: Request de autenticación
      appLog('\n========== REQUEST AUTHENTICATE ==========');
      appLog('URL: $url');
      appLog('Método: POST');
      appLog('Headers: $headers');
      appLog('Body: (vacío)');
      appLog('=========================================\n');

      final response = await http.post(Uri.parse(url), headers: headers);

      // 🔍 LOGS: Response de autenticación
      appLog('========== RESPONSE AUTHENTICATE ==========');
      appLog('Status Code: ${response.statusCode}');
      appLog('Response Body: ${response.body}');
      appLog('==========================================\n');

      if (response.statusCode == 200) {
        appLog('✅ Autenticación exitosa con Matias');
        return true;
      }
      appLog('❌ Error autenticando: ${response.body}');
      return false;
    } catch (e) {
      appLog('❌ Exception autenticando: $e');
      return false;
    }
  }

  /// 2️⃣ Verificar status de autenticación
  static Future<bool> checkStatus() async {
    try {
      final url = '${_getBaseUrl()}/status';
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };

      // 🔍 LOGS: Request de status
      appLog('========== REQUEST STATUS ==========');
      appLog('URL: $url');
      appLog('Método: GET');
      appLog('Headers: $headers');
      appLog('====================================\n');

      final response = await http.get(Uri.parse(url), headers: headers);

      // 🔍 LOGS: Response de status
      appLog('========== RESPONSE STATUS ==========');
      appLog('Status Code: ${response.statusCode}');
      appLog('Response Body: ${response.body}');
      appLog('=====================================\n');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['data']['authenticated'] ?? false;
      }
      return false;
    } catch (e) {
      appLog('❌ Exception verificando status: $e');
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
    Map<String, dynamic>? payload,
  }) async {
    try {
      // Primero verificar autenticación
      bool autenticado = await checkStatus();
      if (!autenticado) {
        appLog('⚠️ No autenticado. Intentando autenticar...');
        await authenticate();
      }

      appLog('📄 Facturando pedido: $pedidoId');

      // Construir headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final url = '${_getBaseUrl()}/documento-mesa/$pedidoId/facturar';

      // 🔍 LOGS: Mostrar detalles de la request
      appLog('\n========== REQUEST MATIAS ==========');
      appLog('URL: $url');
      appLog('Método: POST');
      appLog('Headers: $headers');
      appLog('Body: ${payload != null ? jsonEncode(payload) : '(vacío - POST sin body)'}');
      appLog('====================================\n');

      final response = await http.post(
        Uri.parse(url), 
        headers: headers,
        body: payload != null ? jsonEncode(payload) : null,
      );

      // 🔍 LOGS: Mostrar detalles de la response
      appLog('\n========== RESPONSE MATIAS ==========');
      appLog('Status Code: ${response.statusCode}');
      appLog('Response Body: ${response.body}');
      appLog('====================================\n');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['success'] == true) {
          appLog('✅ Pedido $pedidoId facturado exitosamente');
          appLog('CUFE: ${json['data']['xmlDocumentKey']}');
          return json['data'];
        } else {
          appLog('❌ Error al facturar: ${json['message']}');
          return null;
        }
      } else {
        appLog('❌ HTTP Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      appLog('❌ Exception facturando: $e');
      return null;
    }
  }

  /// [DEPRECATED] Usa facturarPedido() en su lugar
  static Future<Map<String, dynamic>?> facturarDocumentoMesa(
    String pedidoId,
  ) async {
    appLog(
      '⚠️ facturarDocumentoMesa() está deprecado. Usa facturarPedido() en su lugar.',
    );
    return facturarPedido(pedidoId);
  }
}
