import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../config/api_config.dart';
import '../utils/logger.dart';
import '../utils/api_error.dart';
import '../utils/token_storage.dart' show readJwtToken;

/// Clase base para todos los servicios de API
/// Centraliza la lógica común de autenticación, headers y manejo de errores
class BaseApiService {
  static final BaseApiService _instance = BaseApiService._internal();
  factory BaseApiService() => _instance;
  BaseApiService._internal();

  // Cliente HTTP reutilizable
  http.Client _httpClient = http.Client();
  static const Duration _defaultTimeout = Duration(seconds: 15);

  /// Getter para acceso al cliente HTTP
  http.Client get httpClient => _httpClient;

  /// Método para forzar una reconexión
  void resetConnection() {
    _httpClient.close();
    _httpClient = http.Client();
  }

  /// Obtiene la URL base de la API
  String get baseUrl => ApiConfig.instance.baseUrl;

  /// Obtiene el token de autenticación. Delega en token_storage.dart (antes
  /// esto era una implementación propia y duplicada: leía FlutterSecureStorage
  /// directo en vez de localStorage en web — nunca encontraba el token ahí —
  /// y sin la caché en memoria que ya tiene readJwtToken(), que evita releer
  /// el storage seguro en cada petición de las muchas pantallas que encadenan
  /// varias llamadas.
  Future<String?> getToken() async {
    try {
      return await readJwtToken();
    } catch (e) {
      return null;
    }
  }

  /// Construye la URL completa para un endpoint
  /// Maneja correctamente rutas que ya incluyen /api/ y las que no
  String buildUrl(String endpoint) {
    // Normalizar el endpoint eliminando barras iniciales o finales extras
    String normalizedEndpoint = endpoint.trim();
    
    // Si el endpoint ya empieza con /api/, lo usamos tal como está
    if (normalizedEndpoint.startsWith('/api/')) {
      return '$baseUrl$normalizedEndpoint';
    }
    
    // Si empieza solo con /, agregamos api después del baseUrl
    if (normalizedEndpoint.startsWith('/')) {
      return '$baseUrl/api$normalizedEndpoint';
    }
    
    // Si no empieza con /, agregamos /api/ completo
    return '$baseUrl/api/$normalizedEndpoint';
  }

  /// Genera headers con autenticación
  /// Nota: X-Content-Type-Options / X-Frame-Options / X-XSS-Protection son
  /// headers de respuesta — enviarlos en requests no aporta seguridad y en web
  /// dispara un preflight CORS que el backend no admite (request queda colgado).
  Future<Map<String, String>> getHeaders() async {
    final String? token = await getToken();

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Maneja errores de respuesta HTTP de manera estandarizada
  Exception handleErrorResponse(http.Response response) {
    try {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['error'] != null) {
        return Exception(data['error']);
      }
      if (data['message'] != null) {
        return Exception(data['message']);
      }
    } catch (e) {
      // Si no podemos parsear el JSON, usamos mensaje genérico
    }
    return Exception('Error HTTP ${response.statusCode}');
  }

  // Método GET genérico
  Future<ApiResponse<T>> get<T>(
    String endpoint,
    T Function(dynamic)? fromJson, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await getHeaders();
      final url = buildUrl(endpoint);
      
      appLog('GET $url');

      // Usar cliente seguro
      final response = await _httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      appLog('Error en request', level: LogLevel.error, error: e);
      return ApiResponse<T>(
        success: false,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  // Método GET para listas
  Future<ApiResponse<List<T>>> getList<T>(
    String endpoint,
    T Function(Map<String, dynamic>) fromJson, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await getHeaders();
      final url = buildUrl(endpoint);
      
      final response = await _httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return ApiResponse.fromJsonList(jsonResponse, fromJson);
      } else {
        return ApiResponse<List<T>>(
          success: false,
          message: 'Error HTTP: ${response.statusCode}',
          timestamp: DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      appLog('Error en request', level: LogLevel.error, error: e);
      return ApiResponse<List<T>>(
        success: false,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  // Método POST genérico
  Future<ApiResponse<T>> post<T>(
    String endpoint,
    Map<String, dynamic> data,
    T Function(dynamic)? fromJson, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await getHeaders();
      final url = buildUrl(endpoint);

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(data),
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      appLog('Error en request', level: LogLevel.error, error: e);
      return ApiResponse<T>(
        success: false,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  // Método PUT genérico
  Future<ApiResponse<T>> put<T>(
    String endpoint,
    Map<String, dynamic> data,
    T Function(dynamic)? fromJson, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await getHeaders();
      final url = buildUrl(endpoint);

      final response = await _httpClient
          .put(
            Uri.parse(url),
            headers: headers,
            body: json.encode(data),
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      appLog('Error en request', level: LogLevel.error, error: e);
      return ApiResponse<T>(
        success: false,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  // Método DELETE genérico
  Future<ApiResponse<void>> delete(
    String endpoint, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await getHeaders();
      final url = buildUrl(endpoint);

      final response = await _httpClient
          .delete(Uri.parse(url), headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return ApiResponse<void>(
          success: jsonResponse['success'] ?? true,
          message: jsonResponse['message'] ?? 'Eliminado exitosamente',
          timestamp:
              jsonResponse['timestamp'] ?? DateTime.now().toIso8601String(),
        );
      } else {
        return ApiResponse<void>(
          success: false,
          message: 'Error HTTP: ${response.statusCode}',
          timestamp: DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      appLog('Error en request', level: LogLevel.error, error: e);
      return ApiResponse<void>(
        success: false,
        message: errorMessage(e),
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  // Manejar respuesta genérica
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? fromJson,
  ) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      return ApiResponse.fromJson(jsonResponse, fromJson);
    } else {
      // Intentar extraer mensaje de error del backend
      try {
        final Map<String, dynamic> errorResponse = json.decode(response.body);
        return ApiResponse<T>(
          success: false,
          message:
              errorResponse['message'] ?? 'Error HTTP: ${response.statusCode}',
          timestamp:
              errorResponse['timestamp'] ?? DateTime.now().toIso8601String(),
        );
      } catch (e) {
        return ApiResponse<T>(
          success: false,
          message: 'Error HTTP: ${response.statusCode}',
          timestamp: DateTime.now().toIso8601String(),
        );
      }
    }
  }
}
