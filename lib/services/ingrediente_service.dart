import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/ingrediente.dart';
import '../config/api_config.dart';

class IngredienteService {
  static final IngredienteService _instance = IngredienteService._internal();
  factory IngredienteService() => _instance;
  IngredienteService._internal();

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();

  // Headers con autenticación
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Obtener todos los ingredientes
  Future<List<Ingrediente>> getAllIngredientes() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/ingredientes'),
        headers: headers,
      );

      print(
        'IngredienteService - getAllIngredientes response: ${response.statusCode}',
      );
      print('IngredienteService - getAllIngredientes body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList;

        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            jsonList = responseData['data'];
          } else if (responseData.containsKey('ingredientes')) {
            jsonList = responseData['ingredientes'];
          } else {
            jsonList = [];
          }
        } else if (responseData is List) {
          jsonList = responseData;
        } else {
          throw Exception('Formato de respuesta inesperado');
        }

        return jsonList.map((json) => Ingrediente.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener ingredientes: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error completo: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener ingredientes de categoría "carne"
  Future<List<Ingrediente>> getIngredientesCarnes() async {
    try {
      final todosIngredientes = await getAllIngredientes();

      print('DEBUG: Total ingredientes obtenidos: ${todosIngredientes.length}');

      if (todosIngredientes.isEmpty) {
        print(
          'DEBUG: No hay ingredientes en el backend, retornando lista vacía',
        );
        return [];
      }

      // Imprimir todos los ingredientes para debug
      for (var ingrediente in todosIngredientes) {
        print(
          'DEBUG: Ingrediente: ${ingrediente.nombre} - Categoría: ${ingrediente.categoria}',
        );
      }

      // Filtrar por categoría que contenga "carne" (case insensitive)
      final ingredientesCarnes = todosIngredientes.where((ingrediente) {
        return ingrediente.categoria.toLowerCase().contains('carne') ||
            ingrediente.categoria.toLowerCase().contains('proteina') ||
            ingrediente.categoria.toLowerCase().contains('proteína');
      }).toList();

      print(
        'DEBUG: getIngredientesCarnes found: ${ingredientesCarnes.length} ingredientes de carne',
      );

      if (ingredientesCarnes.isEmpty) {
        print(
          'DEBUG: No se encontraron ingredientes de carne, retornando lista vacía',
        );
      }

      return ingredientesCarnes;
    } catch (e) {
      print('Error obteniendo ingredientes de carne: $e');
      throw Exception('Error al obtener ingredientes de carne: $e');
    }
  }

  // Obtener ingredientes disponibles para un producto específico
  Future<List<Ingrediente>> getIngredientesDisponiblesParaProducto(
    String productoId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/productos/$productoId/ingredientes'),
        headers: headers,
      );

      print(
        'IngredienteService - getIngredientesDisponiblesParaProducto response: ${response.statusCode}',
      );
      print(
        'IngredienteService - getIngredientesDisponiblesParaProducto body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList;

        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            jsonList = responseData['data'];
          } else if (responseData.containsKey('ingredientes')) {
            jsonList = responseData['ingredientes'];
          } else {
            jsonList = [];
          }
        } else if (responseData is List) {
          jsonList = responseData;
        } else {
          throw Exception('Formato de respuesta inesperado');
        }

        return jsonList.map((json) => Ingrediente.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener ingredientes del producto: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error obteniendo ingredientes del producto: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear ingrediente
  Future<Ingrediente> createIngrediente(Ingrediente ingrediente) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/ingredientes'),
        headers: headers,
        body: json.encode(ingrediente.toJson()),
      );

      print(
        'IngredienteService - createIngrediente response: ${response.statusCode}',
      );
      print('IngredienteService - createIngrediente body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            return Ingrediente.fromJson(responseData['data']);
          } else {
            return Ingrediente.fromJson(responseData);
          }
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception('Error al crear ingrediente: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creando ingrediente: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Actualizar ingrediente
  Future<Ingrediente> updateIngrediente(Ingrediente ingrediente) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/ingredientes/${ingrediente.id}'),
        headers: headers,
        body: json.encode(ingrediente.toJson()),
      );

      print(
        'IngredienteService - updateIngrediente response: ${response.statusCode}',
      );
      print('IngredienteService - updateIngrediente body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            return Ingrediente.fromJson(responseData['data']);
          } else {
            return Ingrediente.fromJson(responseData);
          }
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception(
          'Error al actualizar ingrediente: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error actualizando ingrediente: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Eliminar ingrediente
  Future<bool> deleteIngrediente(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/ingredientes/$id'),
        headers: headers,
      );

      print(
        'IngredienteService - deleteIngrediente response: ${response.statusCode}',
      );
      print('IngredienteService - deleteIngrediente body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception(
          'Error al eliminar ingrediente: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error eliminando ingrediente: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
