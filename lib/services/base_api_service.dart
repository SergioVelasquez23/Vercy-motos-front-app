import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/api_response.dart';

class BaseApiService {
  static final BaseApiService _instance = BaseApiService._internal();
  factory BaseApiService() => _instance;
  BaseApiService._internal();

  final String baseUrl = 'http://127.0.0.1:8081/api';
  final storage = FlutterSecureStorage();

  // Headers con autenticación
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Método GET genérico
  Future<ApiResponse<T>> get<T>(
    String endpoint,
    T Function(dynamic)? fromJson, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
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

  // Método GET para listas
  Future<ApiResponse<List<T>>> getList<T>(
    String endpoint,
    T Function(Map<String, dynamic>) fromJson, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
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
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
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
      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
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
      final response = await http
          .delete(Uri.parse('$baseUrl$endpoint'), headers: headers)
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
