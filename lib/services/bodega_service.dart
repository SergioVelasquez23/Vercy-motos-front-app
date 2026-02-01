import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/bodega.dart';

/// Servicio para gestionar bodegas/almacenes/ubicaciones de inventario
class BodegaService {
  final ApiConfig _apiConfig = ApiConfig();

  String get baseUrl => '${_apiConfig.baseUrl}/api/bodegas';

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ====================================
  // 📋 OBTENER TODAS LAS BODEGAS
  // ====================================
  Future<List<Bodega>> obtenerBodegas({bool? soloActivas}) async {
    try {
      String url = baseUrl;
      if (soloActivas == true) {
        url += '?activa=true';
      }

        
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);

        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] != null) {
            data = decoded['data'] is List ? decoded['data'] : [];
          } else if (decoded['content'] != null) {
            data = decoded['content'] is List ? decoded['content'] : [];
          } else {
            data = [];
          }
        } else {
          data = [];
        }

          
        return data.map((json) => Bodega.fromJson(json)).toList();
      }

      throw Exception('Error al obtener bodegas: ${response.statusCode}');
    } catch (e) {
        
      // Retornar lista por defecto en caso de error
      return _getBodegasDefault();
    }
  }

  // ====================================
  // 🔍 OBTENER BODEGA POR ID
  // ====================================
  Future<Bodega?> obtenerBodegaPorId(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return Bodega.fromJson(data);
      }

      if (response.statusCode == 404) {
        return null;
      }

      throw Exception('Error al obtener bodega: ${response.statusCode}');
    } catch (e) {
        
      return null;
    }
  }

  // ====================================
  // 📝 CREAR BODEGA
  // ====================================
  Future<Bodega> crearBodega({
    required String nombre,
    String? codigo,
    String? tipo,
    String? descripcion,
    String? direccion,
    String? telefono,
    String? responsable,
    bool activa = true,
  }) async {
    try {
        

      final body = json.encode({
        'nombre': nombre,
        if (codigo != null && codigo.isNotEmpty) 'codigo': codigo,
        if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
        if (descripcion != null && descripcion.isNotEmpty)
          'descripcion': descripcion,
        if (direccion != null && direccion.isNotEmpty) 'direccion': direccion,
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
        if (responsable != null && responsable.isNotEmpty)
          'responsable': responsable,
        'activa': activa,
      });

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return Bodega.fromJson(data);
      }

      // Intentar parsear el error
      try {
        final errorBody = json.decode(response.body);
        throw Exception(
          errorBody['message'] ??
              'Error al crear bodega: ${response.statusCode}',
        );
      } catch (_) {
        throw Exception('Error al crear bodega: ${response.statusCode}');
      }
    } catch (e) {
        
      rethrow;
    }
  }

  // ====================================
  // ✏️ ACTUALIZAR BODEGA
  // ====================================
  Future<Bodega> actualizarBodega(
    String id, {
    String? nombre,
    String? codigo,
    String? tipo,
    String? descripcion,
    String? direccion,
    String? telefono,
    String? responsable,
    bool? activa,
  }) async {
    try {
        

      final Map<String, dynamic> bodyMap = {};
      if (nombre != null) bodyMap['nombre'] = nombre;
      if (codigo != null) bodyMap['codigo'] = codigo;
      if (tipo != null) bodyMap['tipo'] = tipo;
      if (descripcion != null) bodyMap['descripcion'] = descripcion;
      if (direccion != null) bodyMap['direccion'] = direccion;
      if (telefono != null) bodyMap['telefono'] = telefono;
      if (responsable != null) bodyMap['responsable'] = responsable;
      if (activa != null) bodyMap['activa'] = activa;

      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
        body: json.encode(bodyMap),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return Bodega.fromJson(data);
      }

      try {
        final errorBody = json.decode(response.body);
        throw Exception(
          errorBody['message'] ??
              'Error al actualizar bodega: ${response.statusCode}',
        );
      } catch (_) {
        throw Exception('Error al actualizar bodega: ${response.statusCode}');
      }
    } catch (e) {
        
      rethrow;
    }
  }

  // ====================================
  // 🗑️ ELIMINAR BODEGA
  // ====================================
  Future<bool> eliminarBodega(String id) async {
    try {
        

      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }

      if (response.statusCode == 400) {
        final errorBody = json.decode(response.body);
        throw Exception(
          errorBody['message'] ??
              'No se puede eliminar: hay productos asociados a esta bodega',
        );
      }

      throw Exception('Error al eliminar bodega: ${response.statusCode}');
    } catch (e) {
        
      rethrow;
    }
  }

  // ====================================
  // 🔄 ACTIVAR/DESACTIVAR BODEGA
  // ====================================
  Future<Bodega> toggleActivaBodega(String id, bool activa) async {
    return actualizarBodega(id, activa: activa);
  }

  // ====================================
  // 📊 OBTENER STOCK DE UN PRODUCTO EN UNA BODEGA ESPECÍFICA
  // ====================================
  Future<double> obtenerStockProductoEnBodega(
    String bodegaId,
    String productoId,
  ) async {
    try {
      // Usar endpoint: GET /api/bodegas/stock/{tipoItem}/{itemId}
      final response = await http.get(
        Uri.parse(
          '${_apiConfig.baseUrl}/api/bodegas/stock/producto/$productoId',
        ),
        headers: headers,
      );

        
      print(
        '   URL: ${_apiConfig.baseUrl}/api/bodegas/stock/producto/$productoId',
      );
        

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;

        // data es una lista de StockBodegaDTO
        if (data is List) {
            

          // Buscar el stock en la bodega específica
          for (var stock in data) {
            final stockBodegaId = stock['bodegaId'] ?? stock['ubicacionId'];
            final stockCantidad =
                (stock['stockActual'] ?? stock['cantidad'] ?? 0.0);

              

            if (stockBodegaId == bodegaId) {
                
              return (stockCantidad is int)
                  ? stockCantidad.toDouble()
                  : stockCantidad.toDouble();
            }
          }

            
          return 0.0;
        }
      }

        
      return 0.0;
    } catch (e) {
        
      return 0.0;
    }
  }

  // ====================================
  // 📊 OBTENER STOCK DE UN PRODUCTO EN TODAS LAS BODEGAS
  // ====================================
  Future<Map<String, double>> obtenerStockProductoTodasBodegas(
    String productoId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${_apiConfig.baseUrl}/api/bodegas/stock/producto/$productoId',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;

        final Map<String, double> stockPorBodega = {};

        if (data is List) {
          for (var stock in data) {
            final bodegaId = stock['bodegaId'] ?? stock['ubicacionId'];
            final bodegaNombre =
                stock['bodegaNombre'] ?? stock['ubicacionNombre'] ?? bodegaId;
            final cantidad = (stock['stockActual'] ?? stock['cantidad'] ?? 0.0);

            if (bodegaId != null) {
              final cantidadDouble = (cantidad is int)
                  ? cantidad.toDouble()
                  : cantidad.toDouble();
              stockPorBodega[bodegaId] = cantidadDouble;
                
            }
          }
        }

        return stockPorBodega;
      }

      return {};
    } catch (e) {
        
      return {};
    }
  }

  // ====================================
  // 📊 OBTENER STOCK POR BODEGA
  // ====================================
  Future<List<Map<String, dynamic>>> obtenerStockPorBodega(
    String bodegaId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$bodegaId/stock'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
        return [];
      }

      return [];
    } catch (e) {
        
      return [];
    }
  }

  // ====================================
  // 🏭 BODEGAS POR DEFECTO
  // ====================================
  List<Bodega> _getBodegasDefault() {
    return [
      Bodega(
        id: 'BODEGA',
        nombre: 'BODEGA',
        codigo: 'BOD',
        tipo: 'BODEGA',
        descripcion: 'Bodega principal de almacenamiento',
        activa: true,
      ),
      Bodega(
        id: 'ALMACEN',
        nombre: 'ALMACEN',
        codigo: 'ALM',
        tipo: 'ALMACEN',
        descripcion: 'Almacén de productos para venta',
        activa: true,
      ),
    ];
  }

  // ====================================
  // 📋 TIPOS DE BODEGA DISPONIBLES
  // ====================================
  List<String> getTiposBodega() {
    return ['BODEGA', 'ALMACEN', 'PUNTO_VENTA', 'TALLER', 'DEPOSITO', 'OTRO'];
  }
}
