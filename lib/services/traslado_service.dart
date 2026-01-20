import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/traslado.dart';

class TrasladoService {
  final ApiConfig _apiConfig = ApiConfig();
  final storage = FlutterSecureStorage();

  String get baseUrl => '${_apiConfig.baseUrl}/api/inventario/traslados';

  // Obtener headers con token
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Listar traslados
  Future<List<Traslado>> listarTraslados({
    String? estado,
    String? bodegaId,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = baseUrl;

      List<String> params = [];
      if (estado != null && estado != 'TODOS') {
        params.add('estado=$estado');
      }
      if (bodegaId != null && bodegaId.isNotEmpty) {
        params.add('bodegaId=$bodegaId');
      }

      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Traslado.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar traslados: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en listarTraslados: $e');
      rethrow;
    }
  }

  // Obtener un traslado por ID
  Future<Traslado> obtenerTraslado(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return Traslado.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al obtener traslado: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerTraslado: $e');
      rethrow;
    }
  }

  // Crear traslado
  Future<Traslado> crearTraslado({
    required String productoId,
    required String origenBodegaId,
    required String destinoBodegaId,
    required double cantidad,
    required String solicitante,
    String? observaciones,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'productoId': productoId,
        'origenBodegaId': origenBodegaId,
        'destinoBodegaId': destinoBodegaId,
        'cantidad': cantidad,
        'solicitante': solicitante,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones,
      });

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Traslado.fromJson(json.decode(response.body));
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Error al crear traslado');
      }
    } catch (e) {
      print('Error en crearTraslado: $e');
      rethrow;
    }
  }

  // Procesar traslado (aceptar o rechazar)
  Future<Traslado> procesarTraslado({
    required String trasladoId,
    required String accion, // ACEPTAR o RECHAZAR
    required String aprobador,
    String? observaciones,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'trasladoId': trasladoId,
        'accion': accion,
        'aprobador': aprobador,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones,
      });

      final response = await http.put(
        Uri.parse('$baseUrl/procesar'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        return Traslado.fromJson(json.decode(response.body));
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Error al procesar traslado');
      }
    } catch (e) {
      print('Error en procesarTraslado: $e');
      rethrow;
    }
  }
}
