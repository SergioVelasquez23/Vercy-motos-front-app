import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../config/endpoints_config.dart';
import '../models/proveedor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:vercy_motos/utils/html_stub.dart'
    as html;

class ProveedorService {
  static const String baseUrl = kBackendUrl;
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
            
          return [];
        }

        // Si la respuesta es directamente una lista
        if (decodedData is List) {
          return decodedData.map((json) => Proveedor.fromJson(json)).toList();
        }

                   return [];
      } else {
        throw Exception('Error al cargar proveedores: ${response.statusCode}');
      }
    } catch (e) {
        
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
            
          return [];
        }

        // Si la respuesta es directamente una lista
        if (decodedData is List) {
          return decodedData.map((json) => Proveedor.fromJson(json)).toList();
        }

                  return [];
      } else {
        throw Exception('Error al buscar proveedores: ${response.statusCode}');
      }
    } catch (e) {
        
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

      // ✅ VALIDAR: Eliminar slashes al inicio/final del ID
      final cleanId = proveedor.id.trim().replaceAll(RegExp(r'^/+|/+$'), '');

      if (cleanId.isEmpty) {
        throw Exception('ID de proveedor inválido o vacío');
      }

        
        

      final jsonData = proveedor.toJsonCreate();
        

      final response = await http.put(
        Uri.parse(_endpoints.actualizar(cleanId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(jsonData),
      );

        
        

      if (response.statusCode == 200) {
        return Proveedor.fromJson(json.decode(response.body));
      } else {
        throw Exception(
          'Error al actualizar proveedor: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
        
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

      // ✅ VALIDAR: Eliminar slashes al inicio/final del ID
      final cleanId = id.trim().replaceAll(RegExp(r'^/+|/+$'), '');

      if (cleanId.isEmpty) {
        throw Exception('ID de proveedor inválido o vacío');
      }

                 

      final response = await http.put(
        Uri.parse(_endpoints.cambiarEstado(cleanId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'activo': activo}),
      );

        
        

      bool success = response.statusCode == 200;
         
      return success;
    } catch (e) {
        
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
        
      throw Exception('Error de conexión: $e');
    }
  }

  // ============================================
  // 📤 CARGA MASIVA DE PROVEEDORES (EXCEL)
  // ============================================
  /// Cargar proveedores masivamente desde Excel (igual que productos)
  Future<Map<String, dynamic>> cargaMasivaProveedores(
    List<int> excelBytes,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token no encontrado');
      }

      final headers = {'Authorization': 'Bearer $token'};

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/proveedores/cargar-desde-excel'),
      );

      request.headers.addAll(headers);

      // Agregar el archivo Excel
      request.files.add(
        http.MultipartFile.fromBytes(
          'archivo', // Campo que espera el backend
          excelBytes,
          filename: 'proveedores.xlsx',
        ),
      );

      print('📤 Enviando archivo Excel de proveedores al backend...');

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 180),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Respuesta recibida: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Extraer datos según la estructura del backend
        final data = responseData['data'] ?? responseData;

        print('✅ Carga masiva de proveedores completada');
        print('   Creados: ${data['proveedoresCreados']}');
        print('   Actualizados: ${data['proveedoresActualizados']}');
        print('   Errores: ${data['errores']?.length ?? 0}');

        return data;
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        print('   Respuesta: ${response.body}');
        throw Exception(
          'Error del servidor: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error en carga masiva de proveedores: $e');
      throw Exception('No se pudo procesar la carga masiva: $e');
    }
  }
}
