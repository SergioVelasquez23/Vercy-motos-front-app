import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/api_response.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../config/api_config.dart';

/// Clase base para todos los servicios de API
/// Centraliza la lógica común de autenticación, headers y manejo de errores
class BaseApiService {
  static final BaseApiService _instance = BaseApiService._internal();
  factory BaseApiService() => _instance;
  BaseApiService._internal();

  // Cliente HTTP reutilizable
  http.Client _httpClient = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
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

  /// Obtiene el token de autenticación desde el almacenamiento seguro
  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        return html.window.localStorage['jwt_token'];
      } else {
        return await _storage.read(key: 'jwt_token');
      }
    } catch (e) {
      if (kDebugMode) {
          
      }
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

  /// Genera headers con autenticación y configuración de seguridad
  Future<Map<String, String>> getHeaders() async {
    final String? token = await getToken();
    
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    // Añadir headers de seguridad
    headers.addAll(ApiConfig.instance.getSecurityHeaders());
    
    return headers;
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
      
      if (kDebugMode) {
          
      }

      // Usar cliente seguro
      final response = await _httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      if (kDebugMode) {
          
      }
      return ApiResponse<T>(
        success: false,
        message: 'Error de conexión: $e',
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
      
      if (kDebugMode) {
          
      }
      
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
      if (kDebugMode) {
          
      }
      return ApiResponse<List<T>>(
        success: false,
        message: 'Error de conexión: $e',
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
      
      if (kDebugMode) {
          
          
      }

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(data),
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      if (kDebugMode) {
          
      }
      return ApiResponse<T>(
        success: false,
        message: 'Error de conexión: $e',
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
      
      if (kDebugMode) {
          
          
      }

      final response = await _httpClient
          .put(
            Uri.parse(url),
            headers: headers,
            body: json.encode(data),
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      if (kDebugMode) {
          
      }
      return ApiResponse<T>(
        success: false,
        message: 'Error de conexión: $e',
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

      // Agregar encabezados de seguridad adicionales
      final securityHeaders = ApiConfig.instance.getSecurityHeaders();
      headers.addAll(securityHeaders);
      
      if (kDebugMode) {
          
      }

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
      if (kDebugMode) {
          
      }
      return ApiResponse<void>(
        success: false,
        message: 'Error de conexión: $e',
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
