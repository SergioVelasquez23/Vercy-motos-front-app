import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/historial_edicion.dart';
import '../config/api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio para gestionar el historial de ediciones de pedidos
///
/// Integra con el backend que registra automáticamente los cambios
class HistorialEdicionService {
  static final HistorialEdicionService _instance =
      HistorialEdicionService._internal();
  factory HistorialEdicionService() => _instance;
  HistorialEdicionService._internal();

  final ApiConfig _apiConfig = ApiConfig();
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  String get baseUrl => _apiConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Obtiene el historial de ediciones de un pedido específico
  Future<List<HistorialEdicion>> getHistorialPedido(String pedidoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/$pedidoId/historial'),
        headers: headers,
      );

      print('📊 Historial pedido response: ${response.statusCode}');
      print('📊 Historial pedido body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Manejar respuesta con wrapper de éxito
        List<dynamic> historialData;
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          historialData = responseData['data'] as List<dynamic>;
        } else if (responseData is List<dynamic>) {
          historialData = responseData;
        } else {
          throw Exception('Formato de respuesta inválido');
        }

        return historialData
            .map(
              (item) => HistorialEdicion.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw Exception('Error al obtener historial: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error obteniendo historial de ediciones: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtiene el historial de ediciones de todos los pedidos de una mesa
  Future<List<HistorialEdicion>> getHistorialMesa(String mesaNombre) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/mesa/$mesaNombre/historial'),
        headers: headers,
      );

      print('📊 Historial mesa response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> historialData;
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          historialData = responseData['data'] as List<dynamic>;
        } else if (responseData is List<dynamic>) {
          historialData = responseData;
        } else {
          throw Exception('Formato de respuesta inválido');
        }

        return historialData
            .map(
              (item) => HistorialEdicion.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw Exception(
          'Error al obtener historial de mesa: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error obteniendo historial de mesa: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtiene el historial de ediciones por usuario (mesero/admin)
  Future<List<HistorialEdicion>> getHistorialUsuario(String usuario) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/historial/usuario/$usuario'),
        headers: headers,
      );

      print('📊 Historial usuario response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> historialData;
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          historialData = responseData['data'] as List<dynamic>;
        } else if (responseData is List<dynamic>) {
          historialData = responseData;
        } else {
          throw Exception('Formato de respuesta inválido');
        }

        return historialData
            .map(
              (item) => HistorialEdicion.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw Exception(
          'Error al obtener historial de usuario: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error obteniendo historial de usuario: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtiene el historial de ediciones recientes (últimas 24 horas)
  Future<List<HistorialEdicion>> getHistorialReciente() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/historial/recientes'),
        headers: headers,
      );

      print('📊 Historial reciente response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> historialData;
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          historialData = responseData['data'] as List<dynamic>;
        } else if (responseData is List<dynamic>) {
          historialData = responseData;
        } else {
          throw Exception('Formato de respuesta inválido');
        }

        return historialData
            .map(
              (item) => HistorialEdicion.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw Exception(
          'Error al obtener historial reciente: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error obteniendo historial reciente: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
