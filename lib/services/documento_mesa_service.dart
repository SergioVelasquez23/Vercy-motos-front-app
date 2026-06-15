import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/documento_mesa.dart';
import '../config/endpoints_config.dart';
import '../utils/api_error.dart';

/// Servicio para gestionar documentos de mesa
class DocumentoMesaService {
  final EndpointsConfig _config = EndpointsConfig();

  String get baseUrl => '${_config.currentBaseUrl}/api/documentos-mesa';

  /// Crear nuevo documento de mesa
  /// POST /api/documentos-mesa
  Future<DocumentoMesa> crearDocumento({
    required String mesaNombre,
    required String vendedor,
    required List<String> pedidosIds,
  }) async {
    try {
        

      final body = {
        'mesaNombre': mesaNombre,
        'vendedor': vendedor,
        'pedidosIds': pedidosIds,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return DocumentoMesa.fromJson(data);
      }

        
      throwBackendError(response.body, response.statusCode, prefix: 'Error al crear documento');
    } catch (e) {
        
      rethrow;
    }
  }

  /// Obtener documentos por mesa
  /// GET /api/documentos-mesa/mesa/{mesaNombre}
  Future<List<DocumentoMesa>> obtenerDocumentosPorMesa(
    String mesaNombre,
  ) async {
    try {
        

      final response = await http.get(
        Uri.parse('$baseUrl/mesa/$mesaNombre'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData['data'] != null) {
          data = responseData['data'];
        } else {
            
          return [];
        }

        return data.map((json) => DocumentoMesa.fromJson(json)).toList();
      }

      if (response.statusCode == 404) {
        return [];
      }

        
      throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener documentos');
    } catch (e) {
        
      rethrow;
    }
  }

  /// Obtener documento por ID
  /// GET /api/documentos-mesa/{id}
  Future<DocumentoMesa?> obtenerDocumentoPorId(String id) async {
    try {
        

      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DocumentoMesa.fromJson(data);
      }

      if (response.statusCode == 404) {
        return null;
      }

        
      return null;
    } catch (e) {
        
      return null;
    }
  }

  /// Agregar pedido a documento
  /// PUT /api/documentos-mesa/{id}/agregar-pedido
  Future<DocumentoMesa> agregarPedido({
    required String documentoId,
    required String pedidoId,
  }) async {
    try {
        

      final body = {'pedidoId': pedidoId};

      final response = await http.put(
        Uri.parse('$baseUrl/$documentoId/agregar-pedido'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DocumentoMesa.fromJson(data);
      }

        
      throwBackendError(response.body, response.statusCode, prefix: 'Error al agregar pedido');
    } catch (e) {
        
      rethrow;
    }
  }

  /// Pagar un documento
  /// PUT /api/documentos-mesa/{id}/pagar
  Future<DocumentoMesa> pagarDocumento({
    required String documentoId,
    required String formaPago,
    String? pagadoPor,
    double propina = 0.0,
  }) async {
    try {
        

      final body = {
        'formaPago': formaPago,
        if (pagadoPor != null) 'pagadoPor': pagadoPor,
        'propina': propina,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/$documentoId/pagar'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DocumentoMesa.fromJson(data);
      }

        
      throwBackendError(response.body, response.statusCode, prefix: 'Error al pagar documento');
    } catch (e) {
        
      rethrow;
    }
  }

  /// Eliminar documento
  /// DELETE /api/documentos-mesa/{id}
  Future<bool> eliminarDocumento(String id) async {
    try {
        

      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      }

      if (response.statusCode == 404) {
        return false;
      }

        
      throwBackendError(response.body, response.statusCode, prefix: 'Error al eliminar documento');
    } catch (e) {
        
      rethrow;
    }
  }

  /// Obtener documentos pendientes de una mesa
  /// GET /api/documentos-mesa/mesa/{mesaNombre}/pendientes
  Future<List<DocumentoMesa>> obtenerDocumentosPendientes(
    String mesaNombre,
  ) async {
    try {
        

      final response = await http.get(
        Uri.parse('$baseUrl/mesa/$mesaNombre/pendientes'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData['data'] != null) {
          data = responseData['data'];
        } else {
          return [];
        }

        return data.map((json) => DocumentoMesa.fromJson(json)).toList();
      }

      if (response.statusCode == 404) {
        return [];
      }

        
      return [];
    } catch (e) {
        
      return [];
    }
  }

  /// Obtener documentos pagados de una mesa
  /// GET /api/documentos-mesa/mesa/{mesaNombre}/pagados
  Future<List<DocumentoMesa>> obtenerDocumentosPagados(
    String mesaNombre,
  ) async {
    try {
        

      final response = await http.get(
        Uri.parse('$baseUrl/mesa/$mesaNombre/pagados'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData['data'] != null) {
          data = responseData['data'];
        } else {
          return [];
        }

        return data.map((json) => DocumentoMesa.fromJson(json)).toList();
      }

      if (response.statusCode == 404) {
        return [];
      }

        
      return [];
    } catch (e) {
        
      return [];
    }
  }

  /// Obtener resumen de una mesa
  /// GET /api/documentos-mesa/mesa/{mesaNombre}/resumen
  Future<Map<String, dynamic>?> obtenerResumenMesa(String mesaNombre) async {
    try {
        

      final response = await http.get(
        Uri.parse('$baseUrl/mesa/$mesaNombre/resumen'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 404) {
        return null;
      }

        
      return null;
    } catch (e) {
        
      return null;
    }
  }

  /// Verificar si una mesa es especial
  /// GET /api/documentos-mesa/verificar-mesa-especial/{mesaNombre}
  Future<bool> verificarMesaEspecial(String mesaNombre) async {
    try {
        

      final response = await http.get(
        Uri.parse('$baseUrl/verificar-mesa-especial/$mesaNombre'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['esEspecial'] == true || data == true;
      }

      return false;
    } catch (e) {
        
      return false;
    }
  }

  /// Obtener documentos con pedidos completos
  /// GET /api/documentos-mesa/mesa/{mesaNombre}/completos
  Future<List<DocumentoMesa>> obtenerDocumentosCompletos(
    String mesaNombre,
  ) async {
    try {
        

      final response = await http.get(
        Uri.parse('$baseUrl/mesa/$mesaNombre/completos'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData['data'] != null) {
          data = responseData['data'];
        } else {
          return [];
        }

        return data.map((json) => DocumentoMesa.fromJson(json)).toList();
      }

      if (response.statusCode == 404) {
        return [];
      }

        
      return [];
    } catch (e) {
        
      return [];
    }
  }

  /// Obtener todas las mesas con documentos
  Future<List<String>> obtenerMesasConDocumentos() async {
    try {
        

      final response = await http.get(
        Uri.parse('$baseUrl/mesas'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        if (responseData is List) {
          return List<String>.from(responseData);
        } else if (responseData is Map && responseData['data'] != null) {
          return List<String>.from(responseData['data']);
        }

        return [];
      }

      return [];
    } catch (e) {
        
      return [];
    }
  }
}
