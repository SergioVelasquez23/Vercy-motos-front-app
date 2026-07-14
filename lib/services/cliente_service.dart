import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/cliente.dart';
import '../config/endpoints_config.dart';
import '../utils/api_error.dart';
import 'base_api_service.dart';

class ClienteService {
  final EndpointsConfig _config = EndpointsConfig();
  final BaseApiService _api = BaseApiService();

  String get baseUrl => '${_config.currentBaseUrl}/api/clientes';
  static const _timeout = Duration(seconds: 30);

  /// Headers con Authorization (Bearer) desde BaseApiService
  Future<Map<String, String>> get _headers => _api.getHeaders();

  /// Headers para multipart: con token pero sin Content-Type,
  /// porque MultipartRequest define su propio boundary
  Future<Map<String, String>> get _headersMultipart async {
    final headers = await _api.getHeaders();
    headers.remove('Content-Type');
    headers['Accept'] = 'application/json';
    return headers;
  }

  // CRUD

  /// Obtener todos los clientes
  Future<List<Cliente>> obtenerClientes() async {
    try {
        
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: await _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
          
        final dynamic responseData = json.decode(response.body);

        // Manejar si viene como lista directa o dentro de un objeto
        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData['data'] != null) {
          data = responseData['data'];
        } else {
            
          throw Exception('Estructura de respuesta inesperada');
        }

          
        return data.map((json) => Cliente.fromJson(json)).toList();
      }

        
      throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener clientes');
    } catch (e) {
        
      rethrow;
    }
  }

  /// Obtener cliente por ID
  Future<Cliente?> obtenerClientePorId(String id) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/$id'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      if (response.statusCode == 404) {
        return null;
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener cliente');
    } catch (e) {
        
      return null;
    }
  }

  /// Obtener cliente por documento
  Future<Cliente?> obtenerClientePorDocumento(String doc) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/documento/$doc'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      if (response.statusCode == 404) {
        return null;
      }

      throw Exception(
        'Error al obtener cliente por documento: ${response.statusCode}',
      );
    } catch (e) {
        
      return null;
    }
  }

  /// Crear cliente
  Future<Cliente> crearCliente(Cliente cliente) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: await _headers,
        body: json.encode(cliente.toJson()),
      ).timeout(_timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al crear cliente');
    } catch (e) {
      rethrow;
    }
  }

  /// Actualizar cliente
  Future<Cliente> actualizarCliente(String id, Cliente cliente) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: await _headers,
        body: json.encode(cliente.toJson()),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al actualizar cliente');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al actualizar cliente');
    }
  }

  /// Eliminar cliente (soft delete - cambia estado a inactivo)
  Future<bool> eliminarCliente(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: await _headers,
        body: json.encode({'estado': 'inactivo'}),
      );
      return response.statusCode == 200;
    } catch (e) {
        
      return false;
    }
  }

  // Búsquedas

  /// Buscar clientes por término
  Future<List<Cliente>> buscarClientes(String q) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/buscar?q=${Uri.encodeComponent(q)}'),
        headers: await _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cliente.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
        
      return [];
    }
  }

  /// Obtener clientes activos
  Future<List<Cliente>> obtenerClientesActivos() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/estado/activos'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cliente.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
        
      return [];
    }
  }

  /// Obtener clientes con saldo pendiente
  Future<List<Cliente>> obtenerClientesConSaldo() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/con-saldo'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cliente.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
        
      return [];
    }
  }

  // Acciones

  /// Bloquear cliente
  Future<Cliente> bloquearCliente(String id, String motivo) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id/bloquear'),
        headers: await _headers,
        body: json.encode({'motivo': motivo}),
      );

      if (response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al bloquear cliente');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al bloquear cliente');
    }
  }

  /// Activar cliente
  Future<Cliente> activarCliente(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id/activar'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al activar cliente');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al activar cliente');
    }
  }

  /// Verificar cupo de crédito
  Future<Map<String, dynamic>> verificarCupoCredito(
    String id,
    double monto,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$id/verificar-cupo'),
        headers: await _headers,
        body: json.encode({'montoFactura': monto}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al verificar cupo');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al verificar cupo');
    }
  }

  /// Obtener estadísticas de clientes
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/estadisticas'), headers: await _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener estadísticas');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener estadísticas');
    }
  }

  // ============================================
  // CARGA MASIVA DESDE EXCEL
  // ============================================

  /// Cargar clientes masivamente desde archivo Excel (usando bytes - para web)
  Future<Map<String, dynamic>> cargarClientesMasivosBytes(
    List<int> bytes,
    String fileName,
  ) async {
    try {
        
        
        

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/carga-masiva'),
      );

      // Headers con token, sin Content-Type (multipart define su boundary)
      request.headers.addAll(await _headersMultipart);

      // El backend espera el campo 'file' no 'archivo'
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType(
            'application',
            'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ),
      );

        
        

      // Enviar con timeout extendido (5 minutos para archivos grandes)
      var streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception(
            'Timeout: El servidor tardó demasiado en responder. Intenta con un archivo más pequeño.',
          );
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // El backend puede devolver errores como número o como lista
        var erroresData = data['errores'];
        List<dynamic> erroresList = [];
        int erroresCount = 0;

        if (erroresData is List) {
          erroresList = erroresData;
          erroresCount = erroresData.length;
        } else if (erroresData is int) {
          erroresCount = erroresData;
        }

        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Clientes cargados exitosamente',
          'clientesCargados':
              data['creados'] ?? data['clientesCargados'] ?? data['total'] ?? 0,
          'actualizados': data['actualizados'] ?? 0,
          'totalProcesados': data['totalProcesados'] ?? 0,
          'errores': erroresList,
          'erroresCount': erroresCount,
          'tiempoMs': data['tiempoMs'] ?? 0,
        };
      }

      // Intentar parsear el error
      try {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al cargar clientes');
      } catch (_) {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al cargar clientes');
      }
    } catch (e) {
        
      rethrow;
    }
  }

  /// Cargar clientes masivamente desde archivo Excel (usando path - para desktop/mobile)
  Future<Map<String, dynamic>> cargarClientesMasivosPath(
    String filePath,
  ) async {
    try {
        

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/carga-masiva'),
      );

      // Headers con token, sin Content-Type (multipart define su boundary)
      request.headers.addAll(await _headersMultipart);

      // El backend espera el campo 'file' no 'archivo'
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

        

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // El backend puede devolver errores como número o como lista
        var erroresData = data['errores'];
        List<dynamic> erroresList = [];
        int erroresCount = 0;

        if (erroresData is List) {
          erroresList = erroresData;
          erroresCount = erroresData.length;
        } else if (erroresData is int) {
          erroresCount = erroresData;
        }

        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Clientes cargados exitosamente',
          'clientesCargados':
              data['creados'] ?? data['clientesCargados'] ?? data['total'] ?? 0,
          'actualizados': data['actualizados'] ?? 0,
          'totalProcesados': data['totalProcesados'] ?? 0,
          'errores': erroresList,
          'erroresCount': erroresCount,
          'tiempoMs': data['tiempoMs'] ?? 0,
        };
      }

      try {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al cargar clientes');
      } catch (_) {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al cargar clientes');
      }
    } catch (e) {
        
      rethrow;
    }
  }
}
