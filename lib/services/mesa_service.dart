import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/mesa.dart';

class MesaService {
  static final MesaService _instance = MesaService._internal();
  factory MesaService() => _instance;
  MesaService._internal();

  final String baseUrl = 'https://sopa-y-carbon-production.up.railway.app';
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
      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> mesasJson = responseData['data'];
        final mesas = mesasJson.map((json) {
          final mesa = Mesa.fromJson(json);
          return mesa;
        }).toList();

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

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final createdMesa = Mesa.fromJson(responseData['data']);
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
      // ✅ MEJORADO: Validar que tenemos un ID válido
      final mesaId = mesa.mongoId;
      if (mesaId.isEmpty) {
        print('❌ MesaService: ID de mesa vacío - mongoId: ${mesa.mongoId}');
        throw Exception('ID de mesa vacío para actualización');
      }

      final requestData = {
        'nombre': mesa.nombre,
        'ocupada': mesa.ocupada,
        'total': mesa.total,
        'productos': mesa.productos.map((p) => p.toJson()).toList(),
      };

      print('🔄 MesaService: Actualizando mesa ${mesa.nombre} (ID: $mesaId)');
      print('   - Ocupada: ${mesa.ocupada}');
      print('   - Total: ${mesa.total}');
      print('   - Productos: ${mesa.productos.length}');

      final headers = await _getHeaders();
      final url = '$baseUrl/api/mesas/$mesaId';
      print('📡 MesaService: PUT request a: $url');

      final response = await http
          .put(Uri.parse(url), headers: headers, body: json.encode(requestData))
          .timeout(Duration(seconds: 10));

      print('📥 MesaService: Response status: ${response.statusCode}');
      print('📥 MesaService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final updatedMesa = Mesa.fromJson(responseData['data']);
          print('✅ MesaService: Mesa actualizada exitosamente');
          return updatedMesa;
        } else {
          print(
            '❌ MesaService: Formato de respuesta inválido: ${response.body}',
          );
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        print(
          '❌ MesaService: Error del servidor ${response.statusCode}: ${response.body}',
        );
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
