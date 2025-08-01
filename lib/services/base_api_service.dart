import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/api_response.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:serch_restapp/utils/html_stub.dart'
    as html;
import '../config/api_config.dart';

class BaseApiService {
  static final BaseApiService _instance = BaseApiService._internal();
  factory BaseApiService() => _instance;
  BaseApiService._internal();

  // Método para forzar una reconexión
  void resetConnection() {
    _httpClient.close();
    _httpClient = http.Client();
  }

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();
  // Using a non-final variable to allow reset
  http.Client _httpClient = http.Client();

  // Headers con autenticación y seguridad mejorada
  Future<Map<String, String>> _getHeaders() async {
    String? token;

    // Try to get token from storage based on platform
    try {
      if (kIsWeb) {
        // Para web, usamos localStorage
        token = html.window.localStorage['jwt_token'];
      } else {
        // Para móvil, usamos FlutterSecureStorage
        token = await storage.read(key: 'jwt_token');
      }
    } catch (e) {
      // Error silencioso al leer token
    }

    // Obtener cabeceras de seguridad base
    final baseHeaders = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    // Añadir cabeceras de seguridad adicionales
    final secureHeaders = ApiConfig.instance.getSecureHeaders(token: token);
    baseHeaders.addAll(secureHeaders);

    // Añadir cabeceras de seguridad HTTP
    baseHeaders.addAll({
      'X-Content-Type-Options': 'nosniff',
      'X-XSS-Protection': '1; mode=block',
    });

    return baseHeaders;
  }

  // Método GET genérico
  Future<ApiResponse<T>> get<T>(
    String endpoint,
    T Function(dynamic)? fromJson, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/api$endpoint';

      // Usar cliente seguro
      final response = await _httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: 'Error de conexión: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  } // Método GET para listas

  Future<ApiResponse<List<T>>> getList<T>(
    String endpoint,
    T Function(Map<String, dynamic>) fromJson, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/api$endpoint'), headers: headers)
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
      final headers = await _getHeaders();

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/api$endpoint'),
            headers: headers,
            body: json.encode(data),
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
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
      final headers = await _getHeaders();

      final response = await _httpClient
          .put(
            Uri.parse('$baseUrl/api$endpoint'),
            headers: headers,
            body: json.encode(data),
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
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
      final headers = await _getHeaders();

      // Agregar encabezados de seguridad adicionales
      final securityHeaders = ApiConfig.instance.getSecurityHeaders();
      headers.addAll(securityHeaders);

      final response = await _httpClient
          .delete(Uri.parse('$baseUrl/api$endpoint'), headers: headers)
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
