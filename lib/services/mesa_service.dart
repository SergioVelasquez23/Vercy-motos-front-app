import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/mesa.dart';
import '../models/producto.dart';

class MesaService {
  static final MesaService _instance = MesaService._internal();
  factory MesaService() => _instance;
  MesaService._internal();

  final String baseUrl = 'http://192.168.20.24:8081';
  final storage = FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  List<Mesa> _parseListResponse(Map<String, dynamic> responseData) {
    try {
      print(
        '🎯 MesaService: Processing response data: ${json.encode(responseData)}',
      );

      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> mesasJson = responseData['data'];
        final mesas = mesasJson.map((json) {
          final mesa = Mesa.fromJson(json);
          print(
            '🎯 MesaService: Parsed mesa - ID: ${mesa.id}, Nombre: ${mesa.nombre}',
          );
          return mesa;
        }).toList();

        print('🎯 MesaService: Successfully parsed ${mesas.length} mesas');
        return mesas;
      } else {
        print('❌ MesaService: Invalid response format');
        throw Exception('Formato de respuesta inválido');
      }
    } catch (e) {
      print('❌ MesaService: Error parsing mesas: $e');
      throw Exception('Error al procesar la respuesta del servidor: $e');
    }
  }

  Future<List<Mesa>> getMesas() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/mesas'), headers: headers)
          .timeout(Duration(seconds: 10));

      print(
        '🎯 MesaService: Get mesas response - Status: ${response.statusCode}',
      );
      print('🎯 MesaService: Get mesas response - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ MesaService: Error getting mesas: $e');
      throw Exception('No se pudieron cargar las mesas desde el servidor: $e');
    }
  }

  Future<Mesa> createMesa(Mesa mesa) async {
    try {
      final headers = await _getHeaders();

      final requestData = {
        'nombre': mesa.nombre,
        'ocupada': mesa.ocupada,
        'total': mesa.total,
        'productos': mesa.productos.map((p) => p.toJson()).toList(),
      };

      print(
        '🎯 MesaService: Creating mesa - Request data: ${json.encode(requestData)}',
      );

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/mesas'),
            headers: headers,
            body: json.encode(requestData),
          )
          .timeout(Duration(seconds: 10));

      print(
        '🎯 MesaService: Create mesa response - Status: ${response.statusCode}',
      );
      print('🎯 MesaService: Create mesa response - Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final createdMesa = Mesa.fromJson(responseData['data']);
          print(
            '🎯 MesaService: Mesa created successfully - ID: ${createdMesa.id}',
          );
          return createdMesa;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ MesaService: Error creating mesa: $e');
      throw Exception('No se pudo crear la mesa: $e');
    }
  }

  Future<Mesa> updateMesa(Mesa mesa) async {
    try {
      print('🎯 MesaService: Updating mesa - ID: ${mesa.id}');

      final requestData = {
        'nombre': mesa.nombre,
        'ocupada': mesa.ocupada,
        'total': mesa.total,
        'productos': mesa.productos.map((p) => p.toJson()).toList(),
      };

      print('🎯 MesaService: Update data: ${json.encode(requestData)}');

      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse(
              '$baseUrl/api/mesas/${mesa.mongoId}',
            ), // Usando el getter público
            headers: headers,
            body: json.encode(requestData),
          )
          .timeout(Duration(seconds: 10));

      print('🎯 MesaService: Update response - Status: ${response.statusCode}');
      print('🎯 MesaService: Update response - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final updatedMesa = Mesa.fromJson(responseData['data']);
          print(
            '🎯 MesaService: Mesa updated successfully - ID: ${updatedMesa.id}',
          );
          return updatedMesa;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ MesaService: Error updating mesa: $e');
      throw Exception('No se pudo actualizar la mesa: $e');
    }
  }

  Future<void> deleteMesa(String id) async {
    try {
      print('🎯 MesaService: Deleting mesa - ID: $id');

      final headers = await _getHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/api/mesas/$id'), headers: headers)
          .timeout(Duration(seconds: 10));

      print('🎯 MesaService: Delete response - Status: ${response.statusCode}');
      print('🎯 MesaService: Delete response - Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ MesaService: Error deleting mesa: $e');
      throw Exception('No se pudo eliminar la mesa: $e');
    }
  }

  Future<Mesa> getMesaById(String id) async {
    try {
      print('🎯 MesaService: Getting mesa - ID: $id');

      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/mesas/$id'), headers: headers)
          .timeout(Duration(seconds: 10));

      print(
        '🎯 MesaService: Get by ID response - Status: ${response.statusCode}',
      );
      print('🎯 MesaService: Get by ID response - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final mesa = Mesa.fromJson(responseData['data']);
          print('🎯 MesaService: Mesa retrieved successfully - ID: ${mesa.id}');
          return mesa;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ MesaService: Error getting mesa by ID: $e');
      throw Exception('No se pudo obtener la mesa: $e');
    }
  }

  Future<void> vaciarMesa(String id) async {
    try {
      print('🎯 MesaService: Vaciando mesa - ID: $id');
      final mesa = await getMesaById(id);
      mesa.productos = [];
      mesa.total = 0.0;
      mesa.ocupada = false;
      await updateMesa(mesa);
      print('🎯 MesaService: Mesa vaciada exitosamente - ID: $id');
    } catch (e) {
      print('❌ MesaService: Error vaciando mesa: $e');
      throw Exception('No se pudo vaciar la mesa: $e');
    }
  }

  Future<void> moverMesa(Mesa origen, Mesa destino) async {
    try {
      print('🎯 MesaService: Moviendo mesa ${origen.id} a ${destino.id}');

      // Verificar que la mesa destino no esté ocupada
      if (destino.ocupada) {
        throw Exception('La mesa destino está ocupada');
      }

      // Copiar productos a la mesa destino
      destino.productos = List.from(origen.productos);
      destino.total = origen.total;
      destino.ocupada = true;
      destino.pedidoActual = origen.pedidoActual;

      // Actualizar mesa destino
      await updateMesa(destino);
      print('🎯 MesaService: Mesa destino actualizada - ID: ${destino.id}');

      // Vaciar mesa origen
      await vaciarMesa(origen.id);
      print('🎯 MesaService: Mesa origen vaciada - ID: ${origen.id}');
    } catch (e) {
      print('❌ MesaService: Error moviendo mesa: $e');
      throw Exception('No se pudo mover la mesa: $e');
    }
  }
}
