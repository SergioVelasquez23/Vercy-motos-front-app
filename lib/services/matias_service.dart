import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../config/endpoints_config.dart';
import '../utils/logger.dart';

/// Servicio para integración con API de Facturación Matias
/// Cubre: Facturas, Nota Crédito, Nota Débito, Doc. Soporte,
///        Nota Ajuste DS, POS Electrónico, Nómina y ajustes.
class MatiasService {
  static String get _base => '${EndpointsConfig().currentBaseUrl}/api/matias';
  static const Duration _timeout = Duration(seconds: 60);
  static const String TAG = '🔌 MATIAS';

  // ──────────────────────────────────────────────────────────────────────────
  //  🔐 AUTENTICACIÓN
  // ──────────────────────────────────────────────────────────────────────────

  static Future<bool> authenticate() async {
    try {
      appLog('$TAG 🔐 Autenticando con Matias API...');
      final res = await http.post(
        Uri.parse('$_base/authenticate'),
        headers: _headers(),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout en autenticación');
      });
      
      if (res.statusCode == 200) {
        appLog('$TAG ✅ Autenticación exitosa');
        return true;
      } else {
        appLog('$TAG ❌ Autenticación falló: ${res.statusCode} - ${res.body}');
        return false;
      }
    } catch (e) {
      appLog('$TAG ❌ authenticate: $e');
      return false;
    }
  }

  static Future<bool> checkStatus() async {
    try {
      appLog('$TAG 🔍 Verificando status de autenticación...');
      final res = await http.get(
        Uri.parse('$_base/status'),
        headers: _headers(),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout verificando status');
      });
      
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final isAuth = j['data']?['authenticated'] ?? false;
        if (isAuth) {
          appLog('$TAG ✅ Autenticado');
        } else {
          appLog('$TAG ⚠️ No autenticado');
        }
        return isAuth;
      } else {
        appLog('$TAG ⚠️ Status: ${res.statusCode}');
        return false;
      }
    } catch (e) {
      appLog('$TAG ❌ checkStatus: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📊 TABLAS MAESTRAS (LOOKUP)
  // ──────────────────────────────────────────────────────────────────────────

  /// Obtener tipos de documento disponibles (CC, NIT, CE, etc.)
  static Future<List<String>> obtenerTiposDocumento() async {
    return _getLookupList('lookup/tipos-documento', 'tipos de documento');
  }

  /// Obtener formas de pago (01, 02, 03, etc.)
  static Future<List<String>> obtenerFormasPago() async {
    return _getLookupList('lookup/formas-pago', 'formas de pago');
  }

  /// Obtener medios de pago (10, 20, 41, etc.)
  static Future<List<String>> obtenerMediosPago() async {
    return _getLookupList('lookup/medios-pago', 'medios de pago');
  }

  /// Obtener tipos de organización (1, 2, 3, etc.)
  static Future<List<String>> obtenerTiposOrganizacion() async {
    return _getLookupList('lookup/tipos-organizacion', 'tipos de organización');
  }

  /// Obtener tipos de operación
  static Future<List<String>> obtenerTiposOperacion() async {
    return _getLookupList('lookup/tipos-operacion', 'tipos de operación');
  }

  /// Obtener tipos de documento electrónico (01, 02, 03, etc.)
  static Future<List<String>> obtenerTiposDocumentoElectronico() async {
    return _getLookupList('lookup/tipos-documento-electronico', 'tipos de documento electrónico');
  }

  /// Obtener unidades de medida (94, 69, ACR, etc.)
  static Future<List<String>> obtenerUnidadesMedida() async {
    return _getLookupList('lookup/unidades-medida', 'unidades de medida');
  }

  /// Obtener conceptos de nota de corrección
  static Future<List<String>> obtenerConceptosNotaCorreccion() async {
    return _getLookupList('lookup/conceptos-nota-correccion', 'conceptos de nota de corrección');
  }

  /// Obtener monedas disponibles (COP, USD, etc.)
  static Future<List<String>> obtenerMonedas() async {
    return _getLookupList('lookup/monedas', 'monedas');
  }

  /// Helper privado para obtener listas de lookup con manejo de errores robusto
  static Future<List<String>> _getLookupList(String endpoint, String nombre) async {
    try {
      appLog('$TAG 📥 Obteniendo $nombre...');
      final url = '$_base/$endpoint';
      final res = await http.get(
        Uri.parse(url),
        headers: _headers(),
      ).timeout(_timeout);

      appLog('$TAG 📊 $endpoint: StatusCode ${res.statusCode}');

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        
        if (j['success'] != true) {
          appLog('$TAG ⚠️ Respuesta con success=false: ${j['message']}');
          return [];
        }
        
        final data = j['data'];
        if (data == null) {
          appLog('$TAG ⚠️ No hay datos en la respuesta');
          return [];
        }
        
        List<String> list = [];
        if (data is List) {
          list = List<String>.from(data);
        }
        appLog('$TAG ✅ $nombre: ${list.length} registros');
        return list;
      } else {
        appLog('$TAG ❌ Error HTTP ${res.statusCode}: ${res.body}');
        return [];
      }
    } catch (e) {
      appLog('$TAG ❌ _getLookupList($endpoint): $e');
      return [];
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
  /// 1️⃣ AUTO-INCREMENT (Factura con consecutivo automático)
  /// Requiere: documentoId existente en local (creado del pedido pagado)
  /// POST /api/matias/invoices/auto-increment
  static Future<MatiasDocumentoResult> emitirFacturaElectronica(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    final body = {...payload};
    appLog('$TAG 📤 POST /invoices/auto-increment');
    return _postDocumento('$_base/invoices/auto-increment', body, token: token);
  }

  /// 2️⃣ POS ELECTRÓNICO (Sin datos de cliente obligatorios)
  /// No requiere: Cliente previo, genera consumidor final automático
  /// POST /api/matias/pos/documents
  static Future<MatiasDocumentoResult> emitirDocumentoPOS(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    final body = {...payload, 'type_document_id': 20};
    appLog('$TAG 📤 POST /pos/documents (Tipo: POS Electrónico)');
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
      appLog('$TAG 📥 Descargando PDF: /api/facturas/$id/download-pdf');
      final baseUrl = EndpointsConfig().currentBaseUrl;
      final res = await http.get(
        Uri.parse('$baseUrl/api/facturas/$id/download-pdf'),
        headers: _headers(),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout descargando PDF');
      });
      
      if (res.statusCode == 200) {
        appLog('$TAG ✅ PDF descargado: ${res.bodyBytes.length} bytes');
        return res.bodyBytes;
      } else {
        appLog('$TAG ❌ Error descargando PDF: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      appLog('$TAG ❌ descargarPDFFactura: $e');
      return null;
    }
  }

  /// Consultar estado del documento en la DIAN.
  /// [cufe] - Código Único de Factura Electrónica
  /// Retorna: Map con estado actual (status, message, processedAt)
  static Future<Map<String, dynamic>?> consultarStatusDIAN(String cufe) async {
    try {
      appLog('$TAG 🔍 Consultando status DIAN: $cufe');
      final res = await http.get(
        Uri.parse('$_base/documentos/status/$cufe'),
        headers: _headers(),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout consultando status DIAN');
      });
      
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final data = j['data'] as Map<String, dynamic>?;
        if (data != null) {
          appLog('$TAG ✅ Status DIAN: ${data['status']} - ${data['message']}');
          return data;
        } else {
          appLog('$TAG ⚠️ Sin datos en la respuesta');
          return null;
        }
      } else {
        appLog('$TAG ❌ Error consultando status: ${res.statusCode} - ${res.body}');
        return null;
      }
    } catch (e) {
      appLog('$TAG ❌ consultarStatusDIAN: $e');
      return null;
    }
  }

  /// Obtener código QR del documento.
  /// [cufe] - Código Único de Factura Electrónica
  /// Retorna: bytes de la imagen QR
  static Future<Uint8List?> obtenerQRDocumento(String cufe) async {
    try {
      appLog('$TAG 🔲 Obteniendo QR: $cufe');
      final res = await http.get(
        Uri.parse('$_base/documentos/qr/$cufe'),
        headers: _headers(),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout obteniendo QR');
      });
      
      if (res.statusCode == 200) {
        appLog('$TAG ✅ QR obtenido: ${res.bodyBytes.length} bytes');
        return res.bodyBytes;
      } else {
        appLog('$TAG ❌ Error obteniendo QR: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      appLog('$TAG ❌ obtenerQRDocumento: $e');
      return null;
    }
  }

  /// Obtener XML del documento.
  /// [cufe] - Código Único de Factura Electrónica
  /// Retorna: contenido XML como String
  static Future<String?> obtenerXMLDocumento(String cufe) async {
    try {
      appLog('$TAG 📄 Obteniendo XML: $cufe');
      final res = await http.get(
        Uri.parse('$_base/documentos/xml/$cufe'),
        headers: _headers(),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout obteniendo XML');
      });

      if (res.statusCode == 200) {
        appLog('$TAG ✅ XML obtenido: ${res.body.length} chars');
        return res.body;
      } else {
        appLog('$TAG ❌ Error obteniendo XML: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      appLog('$TAG ❌ obtenerXMLDocumento: $e');
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

  /// POST que devuelve MatiasDocumentoResult CON TIMEOUT y mejor logging
  static Future<MatiasDocumentoResult> _postDocumento(
    String url,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      appLog('$TAG 📤 POST: $url');
      final bodyJson = jsonEncode(body);
      final bodyPreview = bodyJson.length > 200 
        ? '${bodyJson.substring(0, 200)}...' 
        : bodyJson;
      appLog('$TAG 📋 Body: $bodyPreview');
      
      final res = await http.post(
        Uri.parse(url),
        headers: _headers(token: token),
        body: bodyJson,
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout esperando respuesta de $url después de ${_timeout.inSeconds}s');
      });

      appLog('$TAG 📥 Status: ${res.statusCode}');
      final respBody = res.body.length > 500 
        ? '${res.body.substring(0, 500)}...' 
        : res.body;
      appLog('$TAG 📥 Response: $respBody');

      if (res.statusCode != 200 && res.statusCode != 201) {
        appLog('$TAG ❌ HTTP Error ${res.statusCode}');
        appLog('$TAG 📥 Response headers: ${res.headers}');
        appLog('$TAG 📥 Response body length: ${res.body.length}');
        
        // Parsear mensaje de error — backend usa formato ApiResponse
        String errorMessage = 'Error HTTP ${res.statusCode}';
        try {
          if (res.body.isEmpty) {
            errorMessage = 'Error HTTP ${res.statusCode}: Respuesta vacía del servidor';
          } else {
            final errorJson = jsonDecode(res.body) as Map<String, dynamic>;
            // ApiResponse: { success, code, message, data (detalles), timestamp }
            errorMessage = errorJson['message']?.toString() ??
                           errorJson['error']?.toString() ??
                           'Error desconocido';

            // Incluir código de error si está disponible
            final code = errorJson['code']?.toString();
            if (code != null && code.isNotEmpty) {
              errorMessage = '[$code] $errorMessage';
            }

            // Incluir detalles de validación si data es un Map de errores
            final data = errorJson['data'];
            if (data is Map && data.isNotEmpty) {
              final fieldErrors = data.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(', ');
              errorMessage = '$errorMessage\n$fieldErrors';
            } else if (data is String && data.isNotEmpty) {
              errorMessage = '$errorMessage\n$data';
            }
          }
        } catch (e) {
          final bodyPreview = res.body.length > 300
              ? '${res.body.substring(0, 300)}...'
              : res.body;
          errorMessage = 'Error HTTP ${res.statusCode}: $bodyPreview';
        }
        
        appLog('$TAG ❌ Error parseado: $errorMessage');
        return MatiasDocumentoResult.error(errorMessage);
      }

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final result = MatiasDocumentoResult.fromJson(j);
      
      if (result.success) {
        appLog('$TAG ✅ Éxito: ${result.documentKey}');
      } else {
        appLog('$TAG ⚠️ Fallo: ${result.message}');
      }
      
      return result;
    } on TimeoutException catch (e) {
      appLog('$TAG ❌ TIMEOUT: $e');
      return MatiasDocumentoResult.error('Timeout: $e');
    } catch (e) {
      appLog('$TAG ❌ _postDocumento: $e');
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
      appLog('$TAG 📤 POST (legacy): $url');
      
      final res = await http.post(
        Uri.parse(url),
        headers: _headers(token: token),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout en POST $url');
      });

      appLog('$TAG 📥 Status: ${res.statusCode}');
      
      if (res.statusCode != 200 && res.statusCode != 201) {
        appLog('$TAG ❌ HTTP Error ${res.statusCode}: ${res.body}');
        return null;
      }

      final j = jsonDecode(res.body);
      if (j['success'] == true) {
        appLog('$TAG ✅ Respuesta exitosa');
        return j['data'];
      } else {
        appLog('$TAG ⚠️ success=false: ${j['message']}');
        return null;
      }
    } on TimeoutException catch (e) {
      appLog('$TAG ❌ TIMEOUT: $e');
      return null;
    } catch (e) {
      appLog('$TAG ❌ _post legacy: $e');
      return null;
    }
  }

  /// PATCH para reenvíos
  static Future<MatiasDocumentoResult> _patch(
    String url, {
    String? token,
  }) async {
    try {
      appLog('$TAG 📤 PATCH: $url');
      
      final res = await http.patch(
        Uri.parse(url),
        headers: _headers(token: token),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout en PATCH $url');
      });

      appLog('$TAG 📥 Status: ${res.statusCode}');
      final respBody = res.body.length > 300 
        ? '${res.body.substring(0, 300)}...' 
        : res.body;
      appLog('$TAG 📥 Response: $respBody');

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final result = MatiasDocumentoResult.fromJson(j);
      
      if (result.success) {
        appLog('$TAG ✅ PATCH exitoso');
      } else {
        appLog('$TAG ⚠️ PATCH falló: ${result.message}');
      }
      
      return result;
    } on TimeoutException catch (e) {
      appLog('$TAG ❌ TIMEOUT: $e');
      return MatiasDocumentoResult.error('Timeout: $e');
    } catch (e) {
      appLog('$TAG ❌ _patch: $e');
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
    // data puede ser Map (éxito) o String/null (detalle de error del backend)
    final rawData = j['data'];
    final data = rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};
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
