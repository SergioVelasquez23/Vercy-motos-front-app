import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/endpoints_config.dart';
import '../utils/logger.dart';

/// Modelo de un Documento/Ticket de facturación electrónica.
///
/// Estados posibles: PENDIENTE → ENVIADO → ACEPTADO | RECHAZADO
class DocumentoFE {
  final String id;
  final String? pedidoId;
  final String? facturaId;
  final String estado; // PENDIENTE, ENVIADO, ACEPTADO, RECHAZADO
  final String? cufe;
  final String? qrCode;
  final String? qrUrl;
  final String? numero;
  final String? numeroElectronico;
  final String? clienteNombre;
  final String? clienteNit;
  final double total;
  final DateTime? fechaCreacion;
  final DateTime? fechaEnvio;
  final String? motivoRechazo;
  final String? pdfUrl;
  final String? xmlUrl;
  final String? tipoDocumento; // FACTURA, NOTA_CREDITO, NOTA_DEBITO, etc.
  final Map<String, dynamic>? raw;

  const DocumentoFE({
    required this.id,
    this.pedidoId,
    this.facturaId,
    required this.estado,
    this.cufe,
    this.qrCode,
    this.qrUrl,
    this.numero,
    this.numeroElectronico,
    this.clienteNombre,
    this.clienteNit,
    this.total = 0.0,
    this.fechaCreacion,
    this.fechaEnvio,
    this.motivoRechazo,
    this.pdfUrl,
    this.xmlUrl,
    this.tipoDocumento,
    this.raw,
  });

  bool get esPendiente => estado == 'PENDIENTE';
  bool get esEnviado => estado == 'ENVIADO';
  bool get esAceptado => estado == 'ACEPTADO';
  bool get esRechazado => estado == 'RECHAZADO';
  bool get tieneCufe => cufe != null && cufe!.isNotEmpty;

  factory DocumentoFE.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    double parseTotal(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    // Derive estado from Matias API numeric/string flags when 'estado' field is absent
    String deriveEstado() {
      final estadoDirecto = json['estado']?.toString();
      if (estadoDirecto != null && estadoDirecto.isNotEmpty) return estadoDirecto;
      final valida = json['valida']?.toString();
      final reenvio = json['reenvio_necesario']?.toString();
      final isValid = json['is_valid'];
      final resend = json['resend'];
      final validaBool = valida == 'Sí' || isValid == 1 || isValid == true;
      final reenvioNeeded = reenvio == 'Sí' || resend == 1 || resend == true;
      if (validaBool && !reenvioNeeded) return 'ACEPTADO';
      if (reenvioNeeded) return 'RECHAZADO';
      return 'ENVIADO';
    }

    return DocumentoFE(
      id: json['_id']?.toString() ??
          json['id']?.toString() ??
          json['uuid']?.toString() ??
          '',
      pedidoId: json['pedidoId']?.toString() ?? json['order_number']?.toString(),
      facturaId: json['facturaId']?.toString(),
      estado: deriveEstado(),
      cufe: json['cufe']?.toString() ?? json['XmlDocumentKey']?.toString(),
      qrCode: json['qrCode']?.toString(),
      qrUrl: json['qrUrl']?.toString(),
      numero: json['numero']?.toString() ?? json['document_number']?.toString(),
      numeroElectronico:
          json['numeroDocumentoElectronico']?.toString() ??
          json['numeroElectronico']?.toString(),
      clienteNombre: json['clienteNombre']?.toString(),
      clienteNit: json['clienteNit']?.toString(),
      total: parseTotal(json['total'] ?? json['payable_amount']),
      fechaCreacion: parseDate(
        json['fechaCreacion'] ??
        json['creada_en'] ??
        json['fechaEmision'] ??
        json['invoice_date'],
      ),
      fechaEnvio: parseDate(
        json['fechaEnvio'] ??
        json['fechaSolicitud'] ??
        json['actualizada_en'],
      ),
      motivoRechazo: json['motivoRechazo']?.toString(),
      pdfUrl: json['pdfUrl']?.toString(),
      xmlUrl: json['xmlUrl']?.toString(),
      tipoDocumento: json['tipoDocumento']?.toString(),
      raw: json,
    );
  }
}

/// Resultado de operación de facturación electrónica
class FacturacionResult {
  final bool success;
  final String message;
  final String? cufe;
  final String? qrCode;
  final String? qrUrl;
  final String? pdfUrl;
  final String? numeroElectronico;
  final Map<String, dynamic>? raw;

  const FacturacionResult({
    required this.success,
    required this.message,
    this.cufe,
    this.qrCode,
    this.qrUrl,
    this.pdfUrl,
    this.numeroElectronico,
    this.raw,
  });

  factory FacturacionResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return FacturacionResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      cufe: data['cufe']?.toString() ?? data['xmlDocumentKey']?.toString(),
      qrCode: data['qrCode']?.toString() ?? data['qr']?.toString(),
      qrUrl: data['qrUrl']?.toString(),
      pdfUrl: data['pdfUrl']?.toString() ?? data['pdf']?.toString(),
      numeroElectronico:
          data['numeroDocumentoElectronico']?.toString() ??
          data['number']?.toString(),
      raw: json,
    );
  }

  factory FacturacionResult.error(String msg) =>
      FacturacionResult(success: false, message: msg);
}

/// Servicio para gestionar documentos de facturación electrónica DIAN.
///
/// Cubre:
///   • Bandeja de documentos pendientes/rechazados
///   • Facturar un documento (enviar a DIAN)
///   • Reenviar documentos rechazados
class DocumentoService {
  static final DocumentoService _instance = DocumentoService._internal();
  factory DocumentoService() => _instance;
  DocumentoService._internal();

  final EndpointsConfig _endpoints = EndpointsConfig();
  final storage = FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📋 BANDEJA DE DOCUMENTOS PENDIENTES
  // ──────────────────────────────────────────────────────────────────────────

  /// Obtiene TODOS los documentos/facturas de TODOS los estados (pendiente, aceptado, rechazado, enviado).
  /// GET /api/facturas-electronicas/documentos
  Future<List<DocumentoFE>> getDocumentos() async {
    try {
      final url = _endpoints.facturacionElectronica.documentos;
      appLog('🔍 [LISTA] GET: $url');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      appLog('📦 [LISTA] Status: ${response.statusCode}');
      appLog('📦 [LISTA] Body: ${response.body.substring(0, (response.body.length > 500 ? 500 : response.body.length))}');

      if (response.statusCode == 200) {
        dynamic responseData;
        try {
          responseData = json.decode(response.body);
          appLog('✅ [LISTA] JSON parseado');
        } catch (parseError) {
          appLog('❌ [LISTA] Error JSON: $parseError');
          return [];
        }

        // Backend returns {success:true, data:{documentos:[...], cantidad:N}}
        dynamic lista = responseData['documentos'] ??
                        responseData['data'] ??
                        responseData;

        // Unwrap one more level if data is a Map (e.g. data.documentos)
        if (lista is Map) {
          lista = lista['documentos'] ?? lista['data'] ?? lista;
        }

        appLog('📋 [LISTA] Type: ${lista.runtimeType}, es List: ${lista is List}');

        if (lista is! List) {
          appLog('❌ [LISTA] No es List: ${lista.runtimeType}');
          appLog('❌ [LISTA] Estructura recibida: $responseData');
          return [];
        }

        appLog('📋 [LISTA] ${lista.length} documentos');
        
        final docs = <DocumentoFE>[];
        for (int i = 0; i < lista.length; i++) {
          try {
            final doc = DocumentoFE.fromJson(lista[i] as Map<String, dynamic>);
            docs.add(doc);
          } catch (parseError) {
            appLog('⚠️ [LISTA] Error parseando elemento $i: $parseError');
          }
        }

        appLog('✅ [LISTA] ${docs.length} documentos parseados exitosamente');

        // Ordenar: rechazados primero, luego pendientes, luego enviados, luego aceptados
        docs.sort((a, b) {
          const prioridad = {
            'RECHAZADO': 0,
            'PENDIENTE': 1,
            'ENVIADO': 2,
            'ACEPTADO': 3,
          };
          final pa = prioridad[a.estado] ?? 4;
          final pb = prioridad[b.estado] ?? 4;
          if (pa != pb) return pa.compareTo(pb);
          // Dentro del mismo estado, más recientes primero
          final fa = a.fechaCreacion ?? DateTime(1970);
          final fb = b.fechaCreacion ?? DateTime(1970);
          return fb.compareTo(fa);
        });

        return docs;
      }
      
      appLog('❌ [LISTA] Status ${response.statusCode} != 200');
      return [];
    } catch (e, stackTrace) {
      appLog('❌ [LISTA] Error: $e');
      appLog('❌ [LISTA] Stack: $stackTrace');
      return [];
    }
  }

  /// Obtiene todos los documentos/tickets pendientes de facturación o rechazados.
  /// GET /api/facturas-electronicas/documentos/pendientes
  Future<List<DocumentoFE>> getDocumentosPendientes() async {
    try {
      final url = _endpoints.facturacionElectronica.documentosPendientes;
      appLog('🔍 [PENDIENTES] GET: $url');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      appLog('📦 [PENDIENTES] Status: ${response.statusCode}');
      appLog('📦 [PENDIENTES] Body: ${response.body.substring(0, (response.body.length > 500 ? 500 : response.body.length))}');

      if (response.statusCode == 200) {
        dynamic responseData;
        try {
          responseData = json.decode(response.body);
          appLog('✅ [PENDIENTES] JSON parseado');
        } catch (parseError) {
          appLog('❌ [PENDIENTES] Error JSON: $parseError');
          return [];
        }

        // Backend returns {success:true, data:{documentos:[...], cantidad:N}}
        dynamic lista = responseData['documentos'] ??
                        responseData['data'] ??
                        responseData;

        // Unwrap one more level if data is a Map (e.g. data.documentos)
        if (lista is Map) {
          lista = lista['documentos'] ?? lista['data'] ?? lista;
        }

        appLog('📋 [PENDIENTES] Type: ${lista.runtimeType}, es List: ${lista is List}');

        if (lista is! List) {
          appLog('❌ [PENDIENTES] No es List: ${lista.runtimeType}');
          return [];
        }

        appLog('📋 [PENDIENTES] ${lista.length} documentos');
        
        final docs = <DocumentoFE>[];
        for (int i = 0; i < lista.length; i++) {
          try {
            final doc = DocumentoFE.fromJson(lista[i] as Map<String, dynamic>);
            docs.add(doc);
          } catch (parseError) {
            appLog('⚠️ [PENDIENTES] Error parseando elemento $i: $parseError');
          }
        }

        appLog('✅ [PENDIENTES] ${docs.length} documentos parseados');

        // Backend ignores ?estado param — filter locally for pending/rejected
        final docsFiltrados = docs
            .where((d) => d.estado == 'PENDIENTE' || d.estado == 'RECHAZADO')
            .toList();
        appLog('📋 [PENDIENTES] Filtrados: ${docsFiltrados.length} (PENDIENTE/RECHAZADO)');

        // Ordenar: rechazados primero, luego pendientes, luego enviados
        docsFiltrados.sort((a, b) {
          const prioridad = {
            'RECHAZADO': 0,
            'PENDIENTE': 1,
            'ENVIADO': 2,
            'ACEPTADO': 3,
          };
          final pa = prioridad[a.estado] ?? 4;
          final pb = prioridad[b.estado] ?? 4;
          if (pa != pb) return pa.compareTo(pb);
          // Dentro del mismo estado, más recientes primero
          final fa = a.fechaCreacion ?? DateTime(1970);
          final fb = b.fechaCreacion ?? DateTime(1970);
          return fb.compareTo(fa);
        });

        return docsFiltrados;
      }
      
      appLog('❌ [PENDIENTES] Status ${response.statusCode} != 200');
      return [];
    } catch (e, stackTrace) {
      appLog('❌ [PENDIENTES] Error: $e');
      appLog('❌ [PENDIENTES] Stack: $stackTrace');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📄 DETALLE DE DOCUMENTO
  // ──────────────────────────────────────────────────────────────────────────

  /// Obtiene un documento por su ID.
  /// GET /api/facturas-electronicas/documentos/{id}
  Future<DocumentoFE?> getDocumentoPorId(String id) async {
    try {
      final headers = await _getHeaders();
      final url = _endpoints.facturacionElectronica.documento(id);
      
      appLog('🔍 [DOCUMENTO] GET: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      appLog('📦 [DOCUMENTO] Status: ${response.statusCode}');
      appLog('📦 [DOCUMENTO] Body: ${response.body.substring(0, (response.body.length > 500 ? 500 : response.body.length))}');

      if (response.statusCode == 200) {
        dynamic responseData;
        try {
          responseData = json.decode(response.body);
          appLog('✅ [DOCUMENTO] JSON parseado');
        } catch (parseError) {
          appLog('❌ [DOCUMENTO] Error JSON: $parseError');
          return null;
        }

        dynamic data = responseData['data'] ?? responseData;
        appLog('📋 [DOCUMENTO] Type: ${data.runtimeType}');
        
        try {
          final doc = DocumentoFE.fromJson(data as Map<String, dynamic>);
          appLog('✅ [DOCUMENTO] Parseado: ${doc.id}');
          return doc;
        } catch (parseDocError) {
          appLog('❌ [DOCUMENTO] Error parseando DocumentoFE: $parseDocError');
          return null;
        }
      }
      
      appLog('❌ [DOCUMENTO] Status ${response.statusCode} != 200');
      return null;
    } catch (e, stackTrace) {
      appLog('❌ [DOCUMENTO] Error: $e');
      appLog('❌ [DOCUMENTO] Stack: $stackTrace');
      return null;
    }
  }

  /// Obtiene un documento por su pedidoId.
  /// GET /api/documentos?pedidoId=...
  /// ⚠️ Este endpoint devuelve el documento creado automáticamente cuando se vende
  Future<DocumentoFE?> getDocumentoPorPedidoId(String pedidoId) async {
    try {
      final headers = await _getHeaders();
      final baseUrl = _endpoints.currentBaseUrl;
      final url = '$baseUrl/api/documentos?pedidoId=$pedidoId';
      
      appLog('🔍 [DOCUMENTO] GET: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      appLog('📦 [DOCUMENTO] Status: ${response.statusCode}');
      appLog('📦 [DOCUMENTO] Body (primeros 500 chars): ${response.body.substring(0, (response.body.length > 500 ? 500 : response.body.length))}');

      if (response.statusCode == 200) {
        dynamic responseData;
        try {
          responseData = json.decode(response.body);
          appLog('✅ [DOCUMENTO] JSON parseado exitosamente');
        } catch (parseError) {
          appLog('❌ [DOCUMENTO] Error al parsear JSON: $parseError');
          appLog('📦 [DOCUMENTO] Body completo: ${response.body}');
          return null;
        }

        appLog('📊 [DOCUMENTO] Response type: ${responseData.runtimeType}');
        
        // El servidor devuelve { "data": [...], "success": true, ... }
        dynamic data = responseData;
        
        // Si hay un campo 'data', usarlo
        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'];
          appLog('📋 [DOCUMENTO] Extrayendo campo "data"');
        }

        appLog('📋 [DOCUMENTO] Data final type: ${data.runtimeType}');
        
        if (data is List) {
          appLog('📋 [DOCUMENTO] Es un List con ${data.length} elementos');
          if (data.isEmpty) {
            appLog('⚠️ [DOCUMENTO] Lista vacía - no hay documentos para este pedidoId');
            return null;
          }
          
          // 🔍 BUSCAR el documento que tiene este pedidoId en su array pedidosIds
          appLog('🔍 [DOCUMENTO] Buscando documento que contenga pedidoId: $pedidoId');
          
          DocumentoFE? documentoEncontrado;
          for (int i = 0; i < data.length; i++) {
            try {
              final docData = data[i] as Map<String, dynamic>;
              final doc = DocumentoFE.fromJson(docData);

              // Verificar si este documento tiene el pedidoId buscado
              final pedidosIds = docData['pedidosIds'];
              if (pedidosIds is List && pedidosIds.contains(pedidoId)) {
                appLog('✅ [DOCUMENTO] Encontrado en posición $i: ${doc.id}');
                appLog('📄 [DOCUMENTO] Documento: numero=${doc.numero ?? doc.numeroElectronico}, cliente=${doc.clienteNombre}');
                documentoEncontrado = doc;
                break;
              }
            } catch (parseDocError) {
              appLog('⚠️ [DOCUMENTO] Error parseando elemento $i: $parseDocError');
            }
          }
          
          if (documentoEncontrado != null) {
            appLog('✅ [DOCUMENTO] Documento final a enviar: ${documentoEncontrado.id}');
            return documentoEncontrado;
          } else {
            appLog('❌ [DOCUMENTO] No se encontró documento con pedidoId: $pedidoId');
            appLog('📋 [DOCUMENTO] Documentos disponibles:');
            for (int i = 0; i < data.length; i++) {
              try {
                final docData = data[i] as Map<String, dynamic>;
                final pedidosIds = docData['pedidosIds'];
                appLog('  [$i] _id=${docData['_id']}, pedidosIds=$pedidosIds');
              } catch (e) {
                appLog('  [$i] Error leyendo: $e');
              }
            }
            return null;
          }
        } else if (data is Map) {
          appLog('📋 [DOCUMENTO] Es un Map (documento único)');
          try {
            appLog('✅ [DOCUMENTO] Parseando objeto directo');
            final doc = DocumentoFE.fromJson(data as Map<String, dynamic>);
            appLog('✅ [DOCUMENTO] Documento parseado: ${doc.id}');
            return doc;
          } catch (parseDocError) {
            appLog('❌ [DOCUMENTO] Error parseando DocumentoFE: $parseDocError');
            appLog('📦 [DOCUMENTO] Data: $data');
            return null;
          }
        } else {
          appLog('❌ [DOCUMENTO] Data no es List ni Map, es: ${data.runtimeType}');
          appLog('📦 [DOCUMENTO] Value: $data');
          return null;
        }
      } else {
        appLog('❌ [DOCUMENTO] Status ${response.statusCode} != 200');
        appLog('📦 [DOCUMENTO] Response: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      appLog('❌ [DOCUMENTO] Error general: $e');
      appLog('❌ [DOCUMENTO] Stack: $stackTrace');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  🧾 FACTURAR DOCUMENTO (ENVIAR A DIAN)
  // ──────────────────────────────────────────────────────────────────────────

  /// Factura un documento/ticket enviándolo a la DIAN.
  /// POST /api/facturas-electronicas/documentos/{id}/facturar
  ///
  /// Retorna un [FacturacionResult] con CUFE, QR, etc.
  Future<FacturacionResult> facturarDocumento(String documentoId) async {
    try {
      final headers = await _getHeaders();
      appLog('📤 Facturando documento $documentoId');

      final response = await http.post(
        Uri.parse(
          _endpoints.facturacionElectronica.facturarDocumento(documentoId),
        ),
        headers: headers,
      );

      appLog('📥 Facturar resp: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final j = json.decode(response.body) as Map<String, dynamic>;
        return FacturacionResult.fromJson(j);
      } else {
        final j = json.decode(response.body);
        return FacturacionResult.error(
          j['message']?.toString() ?? 'Error ${response.statusCode}',
        );
      }
    } catch (e) {
      appLog('❌ Error facturarDocumento: $e');
      return FacturacionResult.error(e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  🔄 REENVIAR DOCUMENTO RECHAZADO
  // ──────────────────────────────────────────────────────────────────────────

  /// Reenvía un documento genérico (por UUID).
  /// POST /api/matias/documents/{uuid}/resend
  Future<FacturacionResult> reenviarDocumento(String uuid) async {
    try {
      final headers = await _getHeaders();
      appLog('🔄 Reenviando documento $uuid');

      final response = await http.post(
        Uri.parse(_endpoints.facturacionElectronica.reenviarDocumento(uuid)),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final j = json.decode(response.body) as Map<String, dynamic>;
        return FacturacionResult.fromJson(j);
      } else {
        final j = json.decode(response.body);
        return FacturacionResult.error(
          j['message']?.toString() ?? 'Error ${response.statusCode}',
        );
      }
    } catch (e) {
      appLog('❌ Error reenviarDocumento: $e');
      return FacturacionResult.error(e.toString());
    }
  }
}
