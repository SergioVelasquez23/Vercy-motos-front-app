import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import '../config/endpoints_config.dart';
import '../utils/logger.dart';

/// Servicio para integración con API de Facturación Matias
/// Cubre: Facturas, Nota Crédito, Nota Débito, Doc. Soporte,
///        Nota Ajuste DS, POS Electrónico, Nómina y ajustes.
class MatiasService {
  static String get _base => '${EndpointsConfig().currentBaseUrl}/api/matias';

  // ──────────────────────────────────────────────────────────────────────────
  //  🔐 AUTENTICACIÓN
  // ──────────────────────────────────────────────────────────────────────────

  static Future<bool> authenticate() async {
    try {
      final res = await http.post(
        Uri.parse('$_base/authenticate'),
        headers: _headers(),
      );
      appLog('AUTH ${res.statusCode}: ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      appLog('❌ authenticate: $e');
      return false;
    }
  }

  static Future<bool> checkStatus() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/status'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return j['data']?['authenticated'] ?? false;
      }
      return false;
    } catch (e) {
      appLog('❌ checkStatus: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📝 FACTURA (POS / Pedido)
  // ──────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> facturarPedido(
    String pedidoId, {
    String? token,
    Map<String, dynamic>? payload,
  }) async {
    await _ensureAuth();

    // Si enviamos el payload, removemos document_number para usar el autoincrement del backend
    if (payload != null) {
      payload.remove('document_number');
    }

    return _post(
      '$_base/documento-mesa/$pedidoId/facturar',
      payload,
      token: token,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📝 NOTA CRÉDITO
  // ──────────────────────────────────────────────────────────────────────────

  /// Emite una Nota Crédito sobre una factura existente.
  /// [facturaNumero]  número de la factura (ej: "LZT836")
  /// [facturaCufe]    CUFE de la factura
  /// [facturaFecha]   fecha de la factura (YYYY-MM-DD)
  /// [motivoId]       1=Anulación, 2=Devolución parcial, 3=Rebaja precio,
  /// Emite una Nota Crédito sobre una factura existente.
  /// [facturaNumero]  número de la factura (ej: "LZT836")
  /// [facturaCufe]    CUFE de la factura
  /// [facturaFecha]   fecha de la factura (YYYY-MM-DD)
  /// [motivoId]       1=Anulación, 2=Devolución parcial, 3=Rebaja precio,
  ///                  4=Ajuste precio, 5=Otra
  /// [motivo]         descripción libre del motivo
  /// [invoicePayload] cuerpo completo de la nota crédito (líneas, totales, etc.)
  static Future<MatiasDocumentoResult> emitirNotaCredito({
    required String facturaNumero,
    required String facturaCufe,
    required String facturaFecha,
    required int motivoId,
    required String motivo,
    required Map<String, dynamic> invoicePayload,
    String? token,
  }) async {
    await _ensureAuth();
    final body = {
      ...invoicePayload,
      'type_document_id': 5,
      'billing_reference': {
        'number': facturaNumero,
        'uuid': facturaCufe,
        'date': facturaFecha,
      },
      'discrepancy_response': {'reference_id': motivoId, 'description': motivo},
    };
    return _postDocumento('$_base/notes/credit', body, token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📝 NOTA DÉBITO
  // ──────────────────────────────────────────────────────────────────────────

  /// Emite una Nota Débito sobre una factura a crédito.
  /// [motivoId] 1=Intereses, 2=Gastos por cobrar, 3=Cambio en valor
  static Future<MatiasDocumentoResult> emitirNotaDebito({
    required String facturaNumero,
    required String facturaCufe,
    required String facturaFecha,
    required int motivoId,
    required String motivo,
    required Map<String, dynamic> invoicePayload,
    String? token,
  }) async {
    await _ensureAuth();
    final body = {
      ...invoicePayload,
      'type_document_id': 4,
      'billing_reference': {
        'number': facturaNumero,
        'uuid': facturaCufe,
        'date': facturaFecha,
      },
      'discrepancy_response': {'reference_id': motivoId, 'description': motivo},
    };
    return _postDocumento('$_base/notes/debit', body, token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📄 DOCUMENTO SOPORTE
  // ──────────────────────────────────────────────────────────────────────────

  /// Crea un Documento Soporte para proveedores no obligados a facturar.
  static Future<MatiasDocumentoResult> crearDocumentoSoporte(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    final body = {...payload, 'type_document_id': 5};
    return _postDocumento('$_base/ds/document', body, token: token);
  }

  /// Nota de Ajuste de un Documento Soporte.
  /// [motivoId] tipo de ajuste (ver endpoint /ep/adjustment-note-type)
  static Future<MatiasDocumentoResult> ajustarDocumentoSoporte({
    required String dsNumero,
    required String dsCude,
    required String dsFecha,
    required int motivoId,
    required String motivo,
    required Map<String, dynamic> invoicePayload,
    String? token,
  }) async {
    await _ensureAuth();
    final body = {
      ...invoicePayload,
      'billing_reference': {
        'number': dsNumero,
        'uuid': dsCude,
        'date': dsFecha,
      },
      'discrepancy_response': {'reference_id': motivoId, 'description': motivo},
    };
    return _postDocumento('$_base/ds/adjustment-note', body, token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  🏪 DOCUMENTO POS
  // ──────────────────────────────────────────────────────────────────────────

  /// Emite una Factura Electrónica Normal con consecutivo manejado manualmente.
  static Future<MatiasDocumentoResult> emitirFacturaElectronica(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    final body = {...payload};
    return _postDocumento('$_base/invoices', body, token: token);
  }

  /// Emite un Documento POS.
  static Future<MatiasDocumentoResult> emitirDocumentoPOS(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    final body = {...payload, 'type_document_id': 20};
    return _postDocumento('$_base/pos/documents', body, token: token);
  }

  /// Reenvía un POS rechazado por la DIAN.
  static Future<MatiasDocumentoResult> reenviarPOS(
    String uuid, {
    String? token,
  }) async {
    await _ensureAuth();
    return _patch('$_base/pos/documents/$uuid/resend', token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  💼 NÓMINA
  // ──────────────────────────────────────────────────────────────────────────

  static Future<MatiasDocumentoResult> enviarNomina(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    return _postDocumento('$_base/ep/payroll', payload, token: token);
  }

  static Future<MatiasDocumentoResult> reemplazarNomina(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    return _postDocumento('$_base/ep/payroll/replace', payload, token: token);
  }

  static Future<MatiasDocumentoResult> eliminarNomina(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    return _postDocumento('$_base/ep/payroll/delete', payload, token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  🔄 REENVÍO GENÉRICO (auto-increment PATCH)
  // ──────────────────────────────────────────────────────────────────────────

  /// tipo: 'invoices' | 'credit-notes' | 'debit-notes' |
  ///        'adjustment-notes' | 'support-documents'
  static Future<MatiasDocumentoResult> reenviarDocumentoAutoIncrement(
    String tipo,
    String uuid, {
    String? token,
  }) async {
    await _ensureAuth();
    return _patch('$_base/auto-increment/$tipo/$uuid/resend', token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  � DESCARGAS Y CONSULTAS
  // ──────────────────────────────────────────────────────────────────────────

  /// Descargar PDF de la factura.
  /// [id] - ID de la factura
  /// Retorna: bytes del PDF
  static Future<Uint8List?> descargarPDFFactura(String id) async {
    try {
      appLog('📥 Descargando PDF: /api/facturas/$id/download-pdf');
      final baseUrl = EndpointsConfig().currentBaseUrl;
      final res = await http.get(
        Uri.parse('$baseUrl/api/facturas/$id/download-pdf'),
        headers: _headers(),
      );
      
      if (res.statusCode == 200) {
        appLog('✅ PDF descargado: ${res.bodyBytes.length} bytes');
        return res.bodyBytes;
      } else {
        appLog('❌ Error descargando PDF: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      appLog('❌ descargarPDFFactura: $e');
      return null;
    }
  }

  /// Consultar estado del documento en la DIAN.
  /// [cufe] - Código Único de Factura Electrónica
  /// Retorna: Map con estado actual
  static Future<Map<String, dynamic>?> consultarStatusDIAN(String cufe) async {
    try {
      appLog('🔍 Consultando status DIAN: $cufe');
      final res = await http.get(
        Uri.parse('$_base/documentos/status/$cufe'),
        headers: _headers(),
      );
      
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        appLog('✅ Status DIAN: ${j['data']}');
        return j['data'] as Map<String, dynamic>?;
      } else {
        appLog('❌ Error consultando status: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      appLog('❌ consultarStatusDIAN: $e');
      return null;
    }
  }

  /// Obtener código QR del documento.
  /// [cufe] - Código Único de Factura Electrónica
  /// Retorna: bytes de la imagen QR
  static Future<Uint8List?> obtenerQRDocumento(String cufe) async {
    try {
      appLog('🔲 Obteniendo QR: $cufe');
      final res = await http.get(
        Uri.parse('$_base/documentos/qr/$cufe'),
        headers: _headers(),
      );
      
      if (res.statusCode == 200) {
        appLog('✅ QR obtenido: ${res.bodyBytes.length} bytes');
        return res.bodyBytes;
      } else {
        appLog('❌ Error obteniendo QR: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      appLog('❌ obtenerQRDocumento: $e');
      return null;
    }
  }

  /// Obtener XML del documento.
  /// [cufe] - Código Único de Factura Electrónica
  /// Retorna: contenido XML como String
  static Future<String?> obtenerXMLDocumento(String cufe) async {
    try {
      appLog('📄 Obteniendo XML: $cufe');
      final res = await http.get(
        Uri.parse('$_base/documentos/xml/$cufe'),
        headers: _headers(),
      );

      if (res.statusCode == 200) {
        appLog('✅ XML obtenido: ${res.body.length} chars');
        return res.body;
      } else {
        appLog('❌ Error obteniendo XML: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      appLog('❌ obtenerXMLDocumento: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  �🛠️ PRIVADOS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> _ensureAuth() async {
    final ok = await checkStatus();
    if (!ok) await authenticate();
  }

  static Map<String, String> _headers({String? token}) {
    final h = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// POST que devuelve MatiasDocumentoResult
  static Future<MatiasDocumentoResult> _postDocumento(
    String url,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      appLog('📤 POST $url');
      final res = await http.post(
        Uri.parse(url),
        headers: _headers(token: token),
        body: jsonEncode(body),
      );
      appLog(
        '📥 ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 400))}',
      );
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return MatiasDocumentoResult.fromJson(j);
    } catch (e) {
      appLog('❌ _postDocumento $url: $e');
      return MatiasDocumentoResult.error(e.toString());
    }
  }

  /// POST legacy (retorna Map nullable — mantiene compatibilidad con facturarPedido)
  static Future<Map<String, dynamic>?> _post(
    String url,
    Map<String, dynamic>? body, {
    String? token,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers(token: token),
        body: body != null ? jsonEncode(body) : null,
      );
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) return j['data'];
      }
      return null;
    } catch (e) {
      appLog('❌ _post $url: $e');
      return null;
    }
  }

  /// PATCH para reenvíos
  static Future<MatiasDocumentoResult> _patch(
    String url, {
    String? token,
  }) async {
    try {
      appLog('📤 PATCH $url');
      final res = await http.patch(
        Uri.parse(url),
        headers: _headers(token: token),
      );
      appLog('📥 ${res.statusCode}: ${res.body}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return MatiasDocumentoResult.fromJson(j);
    } catch (e) {
      appLog('❌ _patch $url: $e');
      return MatiasDocumentoResult.error(e.toString());
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
//  📦 Modelo de resultado unificado
// ────────────────────────────────────────────────────────────────────────────

class MatiasDocumentoResult {
  final bool success;
  final String message;

  /// CUFE / CUNE / CUDE según el tipo de documento
  final String? documentKey;
  final String? pdfUrl;
  final String? xmlUrl;
  final Map<String, dynamic>? raw;

  const MatiasDocumentoResult({
    required this.success,
    required this.message,
    this.documentKey,
    this.pdfUrl,
    this.xmlUrl,
    this.raw,
  });

  factory MatiasDocumentoResult.fromJson(Map<String, dynamic> j) {
    final data = j['data'] as Map<String, dynamic>? ?? {};
    return MatiasDocumentoResult(
      success: j['success'] == true,
      message: j['message']?.toString() ?? '',
      documentKey:
          data['cufe']?.toString() ??
          data['cune']?.toString() ??
          data['xmlDocumentKey']?.toString(),
      pdfUrl: data['pdf']?.toString(),
      raw: j,
    );
  }

  factory MatiasDocumentoResult.error(String msg) =>
      MatiasDocumentoResult(success: false, message: msg);
}
