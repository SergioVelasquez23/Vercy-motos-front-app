import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/gasto.dart';
import '../models/tipo_gasto.dart';
import '../config/api_config.dart';

class GastoService {
  static final GastoService _instance = GastoService._internal();
  factory GastoService() => _instance;
  GastoService._internal();

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

  // Obtener todos los gastos
  Future<List<Gasto>> getAllGastos() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/gastos'),
        headers: headers,
      );

      print('GastoService - getAllGastos response: ${response.statusCode}');
      print('GastoService - getAllGastos body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final gastos = jsonList.map((json) => Gasto.fromJson(json)).toList();

        // Ordenar gastos por fecha descendente (más recientes primero)
        gastos.sort((a, b) => b.fechaGasto.compareTo(a.fechaGasto));

        return gastos;
      } else {
        throw Exception('Error al obtener gastos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error completo: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener gasto por ID
  Future<Gasto?> getGastoById(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/gastos/$id'),
        headers: headers,
      );

      print('GastoService - getGastoById response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return Gasto.fromJson(responseData['data']);
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting gasto by id: $e');
      return null;
    }
  }

  // Obtener gastos por cuadre de caja
  Future<List<Gasto>> getGastosByCuadre(String cuadreId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/gastos/cuadre/$cuadreId'),
        headers: headers,
      );

      print(
        'GastoService - getGastosByCuadre response: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final gastos = jsonList.map((json) => Gasto.fromJson(json)).toList();

        // Ordenar gastos por fecha descendente (más recientes primero)
        gastos.sort((a, b) => b.fechaGasto.compareTo(a.fechaGasto));

        return gastos;
      } else {
        throw Exception(
          'Error al obtener gastos del cuadre: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error getting gastos by cuadre: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear nuevo gasto
  Future<Gasto> createGasto({
    required String cuadreCajaId,
    required String tipoGastoId,
    required String concepto,
    required double monto,
    required String responsable,
    DateTime? fechaGasto,
    String? numeroRecibo,
    String? numeroFactura,
    String? proveedor,
    String? formaPago,
    double? subtotal,
    double? impuestos,
    bool? pagadoDesdeCaja,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'cuadreCajaId': cuadreCajaId,
        'tipoGastoId': tipoGastoId,
        'concepto': concepto,
        'monto': monto,
        'responsable': responsable,
        'fechaGasto': (fechaGasto ?? DateTime.now()).toIso8601String(),
        if (numeroRecibo != null) 'numeroRecibo': numeroRecibo,
        if (numeroFactura != null) 'numeroFactura': numeroFactura,
        if (proveedor != null) 'proveedor': proveedor,
        if (formaPago != null) 'formaPago': formaPago,
        if (subtotal != null) 'subtotal': subtotal,
        if (impuestos != null) 'impuestos': impuestos,
        if (pagadoDesdeCaja != null) 'pagadoDesdeCaja': pagadoDesdeCaja,
      };

      print('GastoService - createGasto body: ${json.encode(body)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/gastos'),
        headers: headers,
        body: json.encode(body),
      );

      print('GastoService - createGasto response: ${response.statusCode}');
      print('GastoService - createGasto response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return Gasto.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al crear gasto');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Actualizar gasto
  Future<Gasto> updateGasto(
    String id, {
    String? cuadreCajaId,
    String? tipoGastoId,
    String? concepto,
    double? monto,
    String? responsable,
    DateTime? fechaGasto,
    String? numeroRecibo,
    String? numeroFactura,
    String? proveedor,
    String? formaPago,
    double? subtotal,
    double? impuestos,
    bool? pagadoDesdeCaja,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        if (cuadreCajaId != null) 'cuadreCajaId': cuadreCajaId,
        if (tipoGastoId != null) 'tipoGastoId': tipoGastoId,
        if (concepto != null) 'concepto': concepto,
        if (monto != null) 'monto': monto,
        if (responsable != null) 'responsable': responsable,
        if (fechaGasto != null) 'fechaGasto': fechaGasto.toIso8601String(),
        if (numeroRecibo != null) 'numeroRecibo': numeroRecibo,
        if (numeroFactura != null) 'numeroFactura': numeroFactura,
        if (proveedor != null) 'proveedor': proveedor,
        if (formaPago != null) 'formaPago': formaPago,
        if (subtotal != null) 'subtotal': subtotal,
        if (impuestos != null) 'impuestos': impuestos,
        if (pagadoDesdeCaja != null) 'pagadoDesdeCaja': pagadoDesdeCaja,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/gastos/$id'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return Gasto.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al actualizar gasto');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Eliminar gasto
  Future<bool> deleteGasto(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/gastos/$id'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting gasto: $e');
      return false;
    }
  }

  // Obtener gastos por fechas
  Future<List<Gasto>> getGastosByDateRange(
    DateTime inicio,
    DateTime fin,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/gastos/fechas?inicio=${inicio.toIso8601String()}&fin=${fin.toIso8601String()}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        return jsonList.map((json) => Gasto.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener gastos por fechas: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener todos los tipos de gasto
  Future<List<TipoGasto>> getAllTiposGasto() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/tipos-gasto'),
        headers: headers,
      );

      print('GastoService - getAllTiposGasto response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        return jsonList.map((json) => TipoGasto.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener tipos de gasto: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error getting tipos gasto: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear nuevo tipo de gasto
  Future<TipoGasto> createTipoGasto({
    required String nombre,
    String? descripcion,
    bool activo = true,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'nombre': nombre,
        if (descripcion != null) 'descripcion': descripcion,
        'activo': activo,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/tipos-gasto'),
        headers: headers,
        body: json.encode(body),
      );

      print('GastoService - createTipoGasto response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return TipoGasto.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al crear tipo de gasto');
      }
    } catch (e) {
      print('Error creating tipo gasto: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Actualizar tipo de gasto
  Future<TipoGasto> updateTipoGasto(
    String id, {
    String? nombre,
    String? descripcion,
    bool? activo,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};

      if (nombre != null) body['nombre'] = nombre;
      if (descripcion != null) body['descripcion'] = descripcion;
      if (activo != null) body['activo'] = activo;

      final response = await http.put(
        Uri.parse('$baseUrl/api/tipos-gasto/$id'),
        headers: headers,
        body: json.encode(body),
      );

      print('GastoService - updateTipoGasto response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return TipoGasto.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Error al actualizar tipo de gasto',
        );
      }
    } catch (e) {
      print('Error updating tipo gasto: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Eliminar tipo de gasto
  Future<bool> deleteTipoGasto(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tipos-gasto/$id'),
        headers: headers,
      );

      print('GastoService - deleteTipoGasto response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Error al eliminar tipo de gasto',
        );
      }
    } catch (e) {
      print('Error deleting tipo gasto: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
