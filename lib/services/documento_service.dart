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
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return DocumentoFE(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      pedidoId: json['pedidoId']?.toString(),
      facturaId: json['facturaId']?.toString(),
      estado: json['estado']?.toString() ?? 'PENDIENTE',
      cufe: json['cufe']?.toString(),
      qrCode: json['qrCode']?.toString(),
      qrUrl: json['qrUrl']?.toString(),
      numero: json['numero']?.toString(),
      numeroElectronico:
          json['numeroDocumentoElectronico']?.toString() ??
          json['numeroElectronico']?.toString(),
      clienteNombre: json['clienteNombre']?.toString(),
      clienteNit: json['clienteNit']?.toString(),
      total: (json['total'] ?? 0).toDouble(),
      fechaCreacion: parseDate(json['fechaCreacion']),
      fechaEnvio: parseDate(json['fechaEnvio'] ?? json['fechaSolicitud']),
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
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturacionElectronica.documentos),
        headers: headers,
      );

      appLog('📋 Todos los documentos: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> lista = responseData['data'] ?? responseData;
        final docs = lista
            .map((j) => DocumentoFE.fromJson(j as Map<String, dynamic>))
            .toList();

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
      return [];
    } catch (e) {
      appLog('❌ Error getDocumentos: $e');
      return [];
    }
  }

  /// Obtiene todos los documentos/tickets pendientes de facturación o rechazados.
  /// GET /api/facturas-electronicas/documentos/pendientes
  Future<List<DocumentoFE>> getDocumentosPendientes() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.facturacionElectronica.documentosPendientes),
        headers: headers,
      );

      appLog('📋 Documentos pendientes: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> lista = responseData['data'] ?? responseData;
        final docs = lista
            .map((j) => DocumentoFE.fromJson(j as Map<String, dynamic>))
            .toList();

        // Ordenar: rechazados primero, luego pendientes, luego enviados
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
      return [];
    } catch (e) {
      appLog('❌ Error getDocumentosPendientes: $e');
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
      final response = await http.get(
        Uri.parse(_endpoints.facturacionElectronica.documento(id)),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final data = responseData['data'] ?? responseData;
        return DocumentoFE.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      appLog('❌ Error getDocumentoPorId: $e');
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
