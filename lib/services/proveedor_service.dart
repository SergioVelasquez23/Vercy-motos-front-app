import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../config/endpoints_config.dart';
import '../models/proveedor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:serch_restapp/utils/html_stub.dart'
    as html;

class ProveedorService {
  static const String baseUrl = kApiUrl;
  final storage = FlutterSecureStorage();
  final _endpoints = EndpointsConfig().proveedores;

  // Obtener token del storage
  Future<String?> _getToken() async {
    try {
      if (kIsWeb) {
        return html.window.localStorage['jwt_token'];
      } else {
        return await storage.read(key: 'jwt_token');
      }
    } catch (e) {
      print('Error obteniendo token: $e');
      return null;
    }
  }

  // Obtener proveedores activos (para selects/listas)
  Future<List<Proveedor>> getProveedores() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.get(
        Uri.parse(_endpoints.activos),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          return [];
        }

        final decodedData = json.decode(responseBody);

        // Si la respuesta es un objeto con success/data, extraer la data
        if (decodedData is Map<String, dynamic>) {
          if (decodedData.containsKey('data')) {
            final data = decodedData['data'];
            if (data is List) {
              return data.map((json) => Proveedor.fromJson(json)).toList();
            }
          }
          print('Error: Estructura de respuesta inesperada: $decodedData');
          return [];
        }

        // Si la respuesta es directamente una lista
        if (decodedData is List) {
          return decodedData.map((json) => Proveedor.fromJson(json)).toList();
        }

        print(
          'Error: Tipo de respuesta no soportado: ${decodedData.runtimeType}',
        );
        return [];
      } else {
        throw Exception('Error al cargar proveedores: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getProveedores: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Buscar proveedores por texto
  Future<List<Proveedor>> buscarProveedores(String texto) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.get(
        Uri.parse(_endpoints.buscar(texto)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          return [];
        }

        final decodedData = json.decode(responseBody);

        // Si la respuesta es un objeto con success/data, extraer la data
        if (decodedData is Map<String, dynamic>) {
          if (decodedData.containsKey('data')) {
            final data = decodedData['data'];
            if (data is List) {
              return data.map((json) => Proveedor.fromJson(json)).toList();
            }
          }
          print('Error: Estructura de respuesta inesperada: $decodedData');
          return [];
        }

        // Si la respuesta es directamente una lista
        if (decodedData is List) {
          return decodedData.map((json) => Proveedor.fromJson(json)).toList();
        }

        print(
          'Error: Tipo de respuesta no soportado: ${decodedData.runtimeType}',
        );
        return [];
      } else {
        throw Exception('Error al buscar proveedores: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en buscarProveedores: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear un nuevo proveedor
  Future<Proveedor> crearProveedor(Proveedor proveedor) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.post(
        Uri.parse(_endpoints.crear),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(proveedor.toJsonCreate()),
      );

      if (response.statusCode == 201) {
        return Proveedor.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al crear proveedor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en crearProveedor: $e');
      throw Exception('Error al crear proveedor: $e');
    }
  }

  // Actualizar un proveedor
  Future<Proveedor> actualizarProveedor(Proveedor proveedor) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.put(
        Uri.parse(_endpoints.actualizar(proveedor.id)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(proveedor.toJsonCreate()),
      );

      if (response.statusCode == 200) {
        return Proveedor.fromJson(json.decode(response.body));
      } else {
        throw Exception(
          'Error al actualizar proveedor: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error en actualizarProveedor: $e');
      throw Exception('Error al actualizar proveedor: $e');
    }
  }

  // Cambiar estado de un proveedor (activar/desactivar)
  Future<bool> cambiarEstadoProveedor(String id, bool activo) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.put(
        Uri.parse(_endpoints.cambiarEstado(id)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'activo': activo}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error en cambiarEstadoProveedor: $e');
      throw Exception('Error al cambiar estado del proveedor: $e');
    }
  }

  // Eliminar un proveedor (mantener por compatibilidad)
  Future<bool> eliminarProveedor(String id) async {
    // En lugar de eliminar, desactivar el proveedor
    return await cambiarEstadoProveedor(id, false);
  }

  // Obtener proveedores para facturas de compras
  Future<List<Proveedor>> getProveedoresParaFacturas() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final response = await http.get(
        Uri.parse(_endpoints.paraFacturas),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Proveedor.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al cargar proveedores para facturas: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error en getProveedoresParaFacturas: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
