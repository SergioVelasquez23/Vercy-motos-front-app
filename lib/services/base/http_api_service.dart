import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/api_config.dart';
import 'base_api_service.dart';

/// Excepción personalizada para errores de API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic responseData;

  ApiException(this.message, {this.statusCode, this.responseData});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Implementación concreta del BaseApiService
///
/// Esta clase contiene toda la lógica HTTP común que estaba duplicada
/// en más de 20 servicios diferentes. Centraliza:
/// - Manejo de headers de autenticación
/// - Parsing de respuestas estándar
/// - Manejo de errores HTTP
/// - Logging de peticiones (desarrollo)
class HttpApiService extends BaseApiService {
  static final HttpApiService _instance = HttpApiService._internal();
  factory HttpApiService() => _instance;
  HttpApiService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const int _timeoutSeconds = 15;

  @override
  String get baseUrl => ApiConfig.instance.baseUrl;

  @override
  Future<Map<String, String>> getHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<T> handleResponse<T>(
    http.Response response, {
    T Function(dynamic data)? parser,
  }) async {
    // Log de la respuesta en modo debug
    if (ApiConfig.instance.isDevelopment) {
        
        
        
    }

    // Manejar diferentes códigos de estado
    switch (response.statusCode) {
      case 200:
      case 201:
        return _parseSuccessResponse<T>(response.body, parser);
      case 401:
        // Token expirado o inválido
        await _storage.delete(key: 'jwt_token');
        throw ApiException(
          'Sesión expirada. Por favor inicia sesión nuevamente.',
          statusCode: 401,
        );
      case 403:
        throw ApiException(
          'No tienes permisos para realizar esta acción.',
          statusCode: 403,
        );
      case 404:
        throw ApiException('Recurso no encontrado.', statusCode: 404);
      case 422:
        final errorData = _tryParseJson(response.body);
        final message = errorData?['message'] ?? 'Datos de entrada inválidos.';
        throw ApiException(message, statusCode: 422, responseData: errorData);
      case 500:
        throw ApiException('Error interno del servidor.', statusCode: 500);
      default:
        final errorData = _tryParseJson(response.body);
        final message = errorData?['message'] ?? 'Error desconocido.';
        throw ApiException(
          message,
          statusCode: response.statusCode,
          responseData: errorData,
        );
    }
  }

  /// Parsea una respuesta exitosa
  T _parseSuccessResponse<T>(
    String responseBody,
    T Function(dynamic data)? parser,
  ) {
    final responseData = json.decode(responseBody);

    // Si hay un parser personalizado, usarlo
    if (parser != null) {
      return parser(responseData);
    }

    // Manejo estándar de respuestas de la API
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('success') &&
          responseData['success'] == true) {
        // Respuesta con wrapper estándar
        if (responseData.containsKey('data')) {
          return responseData['data'] as T;
        }
        return responseData as T;
      } else if (responseData.containsKey('data')) {
        // Respuesta con data pero sin campo success
        return responseData['data'] as T;
      }
    }

    // Si no hay estructura especial, devolver los datos directamente
    return responseData as T;
  }

  /// Intenta parsear JSON, retorna null si falla
  dynamic _tryParseJson(String responseBody) {
    try {
      return json.decode(responseBody);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<T> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final headers = await getHeaders();
      final uri = _buildUri(endpoint, queryParams);

      // Log de la petición en modo debug
      if (ApiConfig.instance.isDevelopment) {
          
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: _timeoutSeconds));

      return handleResponse<T>(response, parser: parser);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error de conexión: $e');
    }
  }

  @override
  Future<T> post<T>(
    String endpoint, {
    dynamic body,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final headers = await getHeaders();
      final uri = _buildUri(endpoint);

      // Log de la petición en modo debug
      if (ApiConfig.instance.isDevelopment) {
          
          
      }

      final response = await http
          .post(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          )
          .timeout(const Duration(seconds: _timeoutSeconds));

      return handleResponse<T>(response, parser: parser);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error de conexión: $e');
    }
  }

  @override
  Future<T> put<T>(
    String endpoint, {
    dynamic body,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final headers = await getHeaders();
      final uri = _buildUri(endpoint);

      // Log de la petición en modo debug
      if (ApiConfig.instance.isDevelopment) {
          
          
      }

      final response = await http
          .put(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          )
          .timeout(const Duration(seconds: _timeoutSeconds));

      return handleResponse<T>(response, parser: parser);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error de conexión: $e');
    }
  }

  @override
  Future<T> delete<T>(
    String endpoint, {
    T Function(dynamic data)? parser,
  }) async {
    try {
      final headers = await getHeaders();
      final uri = _buildUri(endpoint);

      // Log de la petición en modo debug
      if (ApiConfig.instance.isDevelopment) {
          
      }

      final response = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: _timeoutSeconds));

      return handleResponse<T>(response, parser: parser);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error de conexión: $e');
    }
  }

  /// Construye la URI completa a partir del endpoint y parámetros
  Uri _buildUri(String endpoint, [Map<String, String>? queryParams]) {
    final fullUrl = endpoint.startsWith('http')
        ? endpoint
        : '$baseUrl$endpoint';
    final uri = Uri.parse(fullUrl);

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(
        queryParameters: {...uri.queryParameters, ...queryParams},
      );
    }

    return uri;
  }

  /// Limpia el token de autenticación (para logout)
  Future<void> clearAuthToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  /// Verifica si hay un token de autenticación almacenado
  Future<bool> hasAuthToken() async {
    final token = await _storage.read(key: 'jwt_token');
    return token != null && token.isNotEmpty;
  }
}
