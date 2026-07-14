import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../providers/user_provider.dart';
import '../../utils/jwt_utils.dart';
import '../../utils/token_storage.dart';
import 'base_api_service.dart';

/// Excepción personalizada para errores de API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic responseData;

  ApiException(this.message, {this.statusCode, this.responseData});

  /// Solo el mensaje legible — para que `Text(e.toString())` o `errorMessage(e)`
  /// en la UI no muestren "ApiException: ... (Status: 500)" al usuario.
  @override
  String toString() => message;
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

  static const int _timeoutSeconds = 15;

  @override
  String get baseUrl => ApiConfig.instance.baseUrl;

  @override
  Future<Map<String, String>> getHeaders() async {
    final token = await readJwtToken();
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
        // Token expirado o inválido: cerrar sesión de verdad (no solo
        // borrar el storage) para que UserProvider.isAuthenticated pase a
        // false y el router (que escucha a UserProvider) redirija a login
        // solo. Antes esto dejaba el storage vacío pero el estado en
        // memoria seguía "logueado", así que la app quedaba colgada en
        // pantallas que fallan en silencio sin volver nunca al login.
        await UserProvider().logout();
        throw ApiException(
          'Sesión expirada. Por favor inicia sesión nuevamente.',
          statusCode: 401,
        );
      case 403:
        // El backend hoy no distingue "no tienes el rol" de "tu token ya
        // no es válido" — ambos casos responden 403 (ver SecurityConfig,
        // no hay AuthenticationEntryPoint que separe 401 de 403). Si el
        // token que tenemos guardado ya venció, tratamos este 403 igual
        // que un 401 y forzamos logout; si el token sigue vigente, es un
        // 403 real de permisos y solo se informa, sin cerrar la sesión.
        final tokenActual = await readJwtToken();
        bool tokenVencido = false;
        if (tokenActual != null) {
          try {
            tokenVencido = JwtUtils.isTokenExpired(tokenActual);
          } catch (e) {
            tokenVencido = true;
          }
        }
        if (tokenVencido) {
          await UserProvider().logout();
          throw ApiException(
            'Sesión expirada. Por favor inicia sesión nuevamente.',
            statusCode: 401,
          );
        }
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
      throw ApiException('Error de conexión. Verifica tu conectividad a internet.');
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
      throw ApiException('Error de conexión. Verifica tu conectividad a internet.');
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
      throw ApiException('Error de conexión. Verifica tu conectividad a internet.');
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
      throw ApiException('Error de conexión. Verifica tu conectividad a internet.');
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
    await clearJwtToken();
  }

  /// Verifica si hay un token de autenticación almacenado
  Future<bool> hasAuthToken() async {
    final token = await readJwtToken();
    return token != null && token.isNotEmpty;
  }
}
