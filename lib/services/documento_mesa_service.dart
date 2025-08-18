import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/documento_mesa.dart';
import '../config/endpoints_config.dart';

class DocumentoMesaService {
  static final DocumentoMesaService _instance =
      DocumentoMesaService._internal();
  factory DocumentoMesaService() => _instance;
  DocumentoMesaService._internal();

  final EndpointsConfig _endpoints = EndpointsConfig();
  final storage = FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Obtiene todos los documentos de una mesa específica
  Future<List<DocumentoMesa>> getDocumentosPorMesa(String nombreMesa) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.documentosMesa.mesa(nombreMesa)),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> jsonList = responseData['data'] ?? [];
        final documentos = jsonList
            .map((json) => DocumentoMesa.fromJson(json))
            .toList();

        // Ordenar documentos por fecha descendente (más recientes primero)
        documentos.sort((a, b) {
          final fechaA = a.fechaCreacion ?? a.fecha;
          final fechaB = b.fechaCreacion ?? b.fecha;
          return fechaB.compareTo(fechaA);
        });

        return documentos;
      } else {
        print('❌ Error obteniendo documentos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error de conexión obteniendo documentos: $e');
      return [];
    }
  }

  /// Crea un nuevo documento para cualquier mesa
  Future<DocumentoMesa?> crearDocumento({
    required String mesaNombre,
    required String vendedor,
    required List<String> pedidosIds,
  }) async {
    try {
      final headers = await _getHeaders();

      final body = json.encode({
        'mesaNombre': mesaNombre,
        'vendedor': vendedor,
        'pedidosIds': pedidosIds,
      });

      final response = await http.post(
        Uri.parse(_endpoints.documentosMesa.crear),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return DocumentoMesa.fromJson(responseData['data']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error creando documento: $e');
      return null;
    }
  }

  /// Paga un documento existente
  Future<bool> pagarDocumento({
    required String documentoId,
    required String formaPago,
    required String pagadoPor,
    double? propina,
  }) async {
    try {
      final headers = await _getHeaders();

      final body = json.encode({
        'formaPago': formaPago,
        'pagadoPor': pagadoPor,
        if (propina != null && propina > 0) 'propina': propina,
      });

      final response = await http.put(
        Uri.parse(_endpoints.documentosMesa.pagar(documentoId)),
        headers: headers,
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error pagando documento: $e');
      return false;
    }
  }

  /// Elimina un documento
  Future<bool> eliminarDocumento(String documentoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse(_endpoints.documentosMesa.eliminar(documentoId)),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error eliminando documento: $e');
      return false;
    }
  }

  /// Obtiene todos los documentos
  Future<List<DocumentoMesa>> getDocumentos() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.documentosMesa.listaCompleta),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> jsonList = responseData['data'] ?? [];
        final documentos = jsonList
            .map((json) => DocumentoMesa.fromJson(json))
            .toList();

        // Ordenar documentos por fecha descendente (más recientes primero)
        documentos.sort((a, b) {
          final fechaA = a.fechaCreacion ?? a.fecha;
          final fechaB = b.fechaCreacion ?? b.fecha;
          return fechaB.compareTo(fechaA);
        });

        return documentos;
      } else {
        print(
          '❌ Error obteniendo todos los documentos: ${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      print('❌ Error de conexión obteniendo todos los documentos: $e');
      return [];
    }
  }

  /// Anula un documento
  Future<bool> anularDocumento(String documentoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(_endpoints.documentosMesa.anular(documentoId)),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error anulando documento: $e');
      return false;
    }
  }
}
