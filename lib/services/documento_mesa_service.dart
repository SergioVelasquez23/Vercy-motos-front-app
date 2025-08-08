import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/documento_mesa.dart';
import '../models/pedido.dart';
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

  /// Genera un número de documento único
  String _generarNumeroDocumento() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(6);
    return timestamp;
  }

  /// Obtiene todos los documentos de una mesa especial
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
        return jsonList.map((json) => DocumentoMesa.fromJson(json)).toList();
      } else {
        print('❌ Error obteniendo documentos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error de conexión obteniendo documentos: $e');
      return [];
    }
  }

  /// Crea un nuevo documento para una mesa especial
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

  /// Agrega un pedido a un documento existente
  Future<DocumentoMesa?> agregarPedidoADocumento({
    required String documentoId,
    required String pedidoId,
  }) async {
    try {
      final headers = await _getHeaders();

      final body = json.encode({'pedidoId': pedidoId});

      final response = await http.put(
        Uri.parse(_endpoints.documentosMesa.agregarPedido(documentoId)),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return DocumentoMesa.fromJson(responseData['data']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error agregando pedido: $e');
      return null;
    }
  }

  /// Paga un documento completo
  Future<DocumentoMesa?> pagarDocumento({
    required String documentoId,
    required String formaPago,
    required String pagadoPor,
    double propina = 0.0,
  }) async {
    try {
      final headers = await _getHeaders();

      final body = json.encode({
        'formaPago': formaPago,
        'pagadoPor': pagadoPor,
        'propina': propina,
      });

      final response = await http.put(
        Uri.parse(_endpoints.documentosMesa.pagar(documentoId)),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return DocumentoMesa.fromJson(responseData['data']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error pagando documento: $e');
      return null;
    }
  }

  /// Elimina un documento (solo si no está pagado)
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

  /// Verifica si una mesa es especial (puede tener múltiples documentos)
  bool esMesaEspecial(String nombreMesa) {
    final mesasEspeciales = ['DOMICILIO', 'CAJA', 'MESA AUXILIAR'];
    return mesasEspeciales.contains(nombreMesa.toUpperCase());
  }

  /// Obtiene todos los documentos pendientes de una mesa especial
  Future<List<DocumentoMesa>> getDocumentosPendientes(String nombreMesa) async {
    final todosDocumentos = await getDocumentosPorMesa(nombreMesa);
    return todosDocumentos.where((doc) => !doc.pagado).toList();
  }

  /// Obtiene todos los documentos pagados de una mesa especial
  Future<List<DocumentoMesa>> getDocumentosPagados(String nombreMesa) async {
    final todosDocumentos = await getDocumentosPorMesa(nombreMesa);
    return todosDocumentos.where((doc) => doc.pagado).toList();
  }

  /// Obtiene el resumen de una mesa especial
  Future<Map<String, dynamic>> getResumenMesa(String nombreMesa) async {
    try {
      final documentos = await getDocumentosPorMesa(nombreMesa);

      final pendientes = documentos.where((doc) => !doc.pagado).toList();
      final pagados = documentos.where((doc) => doc.pagado).toList();

      final totalPendiente = pendientes.fold(
        0.0,
        (sum, doc) => sum + doc.total,
      );
      final totalPagado = pagados.fold(0.0, (sum, doc) => sum + doc.total);

      return {
        'totalDocumentos': documentos.length,
        'documentosPendientes': pendientes.length,
        'documentosPagados': pagados.length,
        'totalPendiente': totalPendiente,
        'totalPagado': totalPagado,
        'totalGeneral': totalPendiente + totalPagado,
      };
    } catch (e) {
      print('❌ Error obteniendo resumen: $e');
      return {};
    }
  }
}
