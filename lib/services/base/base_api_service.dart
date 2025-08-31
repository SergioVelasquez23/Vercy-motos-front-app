import 'dart:convert';
import 'package:http/http.dart' as http;

/// Clase abstracta que define la interfaz común para todos los servicios API
/// 
/// Esta clase proporciona una interfaz estándar para realizar operaciones HTTP
/// y manejar respuestas de manera consistente en toda la aplicación.
abstract class BaseApiService {
  /// Obtiene los headers necesarios para las peticiones HTTP
  Future<Map<String, String>> getHeaders();

  /// Maneja las respuestas HTTP de manera estándar
  /// 
  /// [response] La respuesta HTTP recibida
  /// [parser] Función opcional para parsear datos específicos
  Future<T> handleResponse<T>(
    http.Response response, {
    T Function(dynamic data)? parser,
  });

  /// Realiza una petición GET
  /// 
  /// [endpoint] El endpoint relativo (ej: '/api/pedidos')
  /// [queryParams] Parámetros de query opcionales
  /// [parser] Función para parsear la respuesta
  Future<T> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    T Function(dynamic data)? parser,
  });

  /// Realiza una petición POST
  /// 
  /// [endpoint] El endpoint relativo
  /// [body] El cuerpo de la petición
  /// [parser] Función para parsear la respuesta
  Future<T> post<T>(
    String endpoint, {
    dynamic body,
    T Function(dynamic data)? parser,
  });

  /// Realiza una petición PUT
  /// 
  /// [endpoint] El endpoint relativo
  /// [body] El cuerpo de la petición
  /// [parser] Función para parsear la respuesta
  Future<T> put<T>(
    String endpoint, {
    dynamic body,
    T Function(dynamic data)? parser,
  });

  /// Realiza una petición DELETE
  /// 
  /// [endpoint] El endpoint relativo
  /// [parser] Función para parsear la respuesta
  Future<T> delete<T>(
    String endpoint, {
    T Function(dynamic data)? parser,
  });

  /// Obtiene la URL base para las peticiones
  String get baseUrl;
}
