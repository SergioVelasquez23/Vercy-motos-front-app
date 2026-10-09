import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../config/endpoints_config.dart';
import '../models/proveedor.dart';
import '../utils/logger.dart';
import '../utils/token_storage.dart' show readJwtToken;
import '../utils/api_error.dart';

class ProveedorService {
  static String get baseUrl => kDynamicBackendUrl;
  final _endpoints = EndpointsConfig().proveedores;

  // Obtener token del storage — delega en token_storage.dart (cacheado en
  // memoria, ver el comentario de readJwtToken).
  Future<String?> _getToken() async {
    try {
      return await readJwtToken();
    } catch (e) {

      return null;
    }
  }

  // Caché en memoria de getProveedores() — static: compartido por todas las
  // instancias (cada pantalla crea la suya, no es singleton), mismo patrón
  // que ClienteService. 7 pantallas (Compras, Crear Factura Compra, Cuentas
  // por Pagar, Gastos, Proveedores, Documento Soporte...) pedían la lista
  // completa de proveedores cada una por su cuenta.
  static List<Proveedor>? _cache;
  static DateTime? _cacheEn;
  static const _cacheTtl = Duration(minutes: 3);
  static Future<List<Proveedor>>? _cargaEnCurso;

  bool get _cacheVigente =>
      _cache != null &&
      _cacheEn != null &&
      DateTime.now().difference(_cacheEn!) < _cacheTtl;

  /// Olvida el caché de getProveedores() — llamar tras crear/editar/borrar
  /// un proveedor para que la próxima lectura traiga el dato fresco.
  static void invalidarCache() {
    _cache = null;
    _cacheEn = null;
  }

  /// Obtener proveedores activos (para selects/listas). Cacheado en memoria
  /// (ver [_cache]); pasar [forzar] para saltarse el caché.
  Future<List<Proveedor>> getProveedores({bool forzar = false}) async {
    if (!forzar && _cacheVigente) return _cache!;
    if (!forzar && _cargaEnCurso != null) return _cargaEnCurso!;

    final future = _obtenerProveedoresDesdeRed();
    _cargaEnCurso = future;
    try {
      return await future;
    } finally {
      _cargaEnCurso = null;
    }
  }

  Future<List<Proveedor>> _obtenerProveedoresDesdeRed() async {
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

        List<Proveedor> proveedores;
        // Si la respuesta es un objeto con success/data, extraer la data
        if (decodedData is Map<String, dynamic>) {
          final data = decodedData['data'];
          proveedores = data is List
              ? data.map((json) => Proveedor.fromJson(json)).toList()
              : [];
        } else if (decodedData is List) {
          // Si la respuesta es directamente una lista
          proveedores = decodedData.map((json) => Proveedor.fromJson(json)).toList();
        } else {
          proveedores = [];
        }

        _cache = proveedores;
        _cacheEn = DateTime.now();
        return proveedores;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al cargar proveedores');
      }
    } catch (e) {
      // Si falló pero hay un caché vencido, devolver eso antes que nada.
      if (_cache != null) return _cache!;
      wrapOrThrow(e, context: 'Error al cargar proveedores');
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
        throwBackendError(response.body, response.statusCode, prefix: 'Error al buscar proveedores');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al buscar proveedores');
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
        invalidarCache();
        return Proveedor.fromJson(json.decode(response.body));
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al crear proveedor');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al crear proveedor');
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
        invalidarCache();
        return Proveedor.fromJson(json.decode(response.body));
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al actualizar proveedor');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al actualizar proveedor');
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
      if (success) invalidarCache();
      return success;
    } catch (e) {
      wrapOrThrow(e, context: 'Error al cambiar estado del proveedor');
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
        throwBackendError(response.body, response.statusCode, prefix: 'Error al cargar proveedores para facturas');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al cargar proveedores para facturas');
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

      appLog('📤 Enviando archivo Excel de proveedores al backend...');

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 180),
      );
      final response = await http.Response.fromStream(streamedResponse);

      appLog('📥 Respuesta recibida: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Extraer datos según la estructura del backend
        final data = responseData['data'] ?? responseData;

        appLog('✅ Carga masiva de proveedores completada');
        appLog('   Creados: ${data['proveedoresCreados']}');
        appLog('   Actualizados: ${data['proveedoresActualizados']}');
        appLog('   Errores: ${data['errores']?.length ?? 0}');

        return data;
      } else {
        appLog('❌ Error del servidor: ${response.statusCode}');
        throwBackendError(response.body, response.statusCode, prefix: 'Error en carga masiva de proveedores');
      }
    } catch (e) {
      appLog('❌ Error en carga masiva de proveedores: $e');
      wrapOrThrow(e, context: 'No se pudo procesar la carga masiva');
    }
  }
}
