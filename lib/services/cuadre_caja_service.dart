import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/cuadre_caja.dart';
import '../config/api_config.dart';

class CuadreCajaService {
  static final CuadreCajaService _instance = CuadreCajaService._internal();
  factory CuadreCajaService() => _instance;
  CuadreCajaService._internal();

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

  // Obtener todos los cuadres de caja
  Future<List<CuadreCaja>> getAllCuadres() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja'),
        headers: headers,
      );

      print(
        'CuadreCajaService - getAllCuadres response: ${response.statusCode}',
      );
      print('CuadreCajaService - getAllCuadres body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        return jsonList.map((json) => CuadreCaja.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener cuadres: ${response.statusCode}');
      }
    } catch (e) {
      print('Error completo: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener cuadre por ID
  Future<CuadreCaja?> getCuadreById(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Error al obtener cuadre: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener cuadres por responsable
  Future<List<CuadreCaja>> getCuadresByResponsable(String responsable) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/responsable/$responsable'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        return jsonList.map((json) => CuadreCaja.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener cuadres por responsable: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener cuadres por estado
  Future<List<CuadreCaja>> getCuadresByEstado(String estado) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/estado/$estado'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        return jsonList.map((json) => CuadreCaja.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener cuadres por estado: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener cuadres de hoy
  Future<List<CuadreCaja>> getCuadresHoy() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/hoy'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        return jsonList.map((json) => CuadreCaja.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener cuadres de hoy: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener cajas abiertas
  Future<List<CuadreCaja>> getCajasAbiertas() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/abiertas'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        return jsonList.map((json) => CuadreCaja.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener cajas abiertas: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener efectivo esperado
  Future<Map<String, dynamic>> getEfectivoEsperado() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/efectivo-esperado'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throw Exception(
          'Error al obtener efectivo esperado: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear cuadre de caja
  Future<CuadreCaja> createCuadre({
    required String nombre,
    required String responsable,
    required double fondoInicial,
    required double efectivoDeclarado,
    required double efectivoEsperado,
    required double tolerancia,
    String? observaciones,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'nombre': nombre,
        'responsable': responsable,
        'fondoInicial': fondoInicial,
        'efectivoDeclarado': efectivoDeclarado,
        'efectivoEsperado': efectivoEsperado,
        'tolerancia': tolerancia,
        'observaciones': observaciones ?? '',
      };

      print('CuadreCajaService - createCuadre body: ${json.encode(body)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/cuadres-caja'),
        headers: headers,
        body: json.encode(body),
      );

      print(
        'CuadreCajaService - createCuadre response: ${response.statusCode}',
      );
      print('CuadreCajaService - createCuadre body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al crear cuadre');
      }
    } catch (e) {
      print('Error completo: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Actualizar cuadre de caja
  Future<CuadreCaja> updateCuadre(
    String id, {
    String? nombre,
    String? responsable,
    double? fondoInicial,
    double? efectivoDeclarado,
    double? efectivoEsperado,
    double? tolerancia,
    String? observaciones,
    bool? cerrarCaja, // Cambio de cerrada a cerrarCaja
    String? estado,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        if (nombre != null) 'nombre': nombre,
        if (responsable != null) 'responsable': responsable,
        if (fondoInicial != null) 'fondoInicial': fondoInicial,
        if (efectivoDeclarado != null) 'efectivoDeclarado': efectivoDeclarado,
        if (efectivoEsperado != null) 'efectivoEsperado': efectivoEsperado,
        if (tolerancia != null) 'tolerancia': tolerancia,
        if (observaciones != null) 'observaciones': observaciones,
        if (cerrarCaja != null)
          'cerrarCaja': cerrarCaja, // Campo correcto para el backend
        if (estado != null) 'estado': estado,
      };

      print('CuadreCajaService - updateCuadre body: ${json.encode(body)}');

      final response = await http.put(
        Uri.parse('$baseUrl/api/cuadres-caja/$id'),
        headers: headers,
        body: json.encode(body),
      );

      print(
        'CuadreCajaService - updateCuadre response: ${response.statusCode}',
      );
      print('CuadreCajaService - updateCuadre response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al actualizar cuadre');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Aprobar cuadre
  Future<CuadreCaja> aprobarCuadre(String id, String aprobador) async {
    try {
      final headers = await _getHeaders();
      final body = {'aprobador': aprobador};

      final response = await http.put(
        Uri.parse('$baseUrl/api/cuadres-caja/$id/aprobar'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al aprobar cuadre');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Rechazar cuadre
  Future<CuadreCaja> rechazarCuadre(
    String id,
    String aprobador, {
    String? observacion,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'aprobador': aprobador,
        if (observacion != null) 'observacion': observacion,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/cuadres-caja/$id/rechazar'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al rechazar cuadre');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Eliminar cuadre
  Future<bool> deleteCuadre(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/cuadres-caja/$id'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
