import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../config/api_config.dart';

class ProductoService {
  static final ProductoService _instance = ProductoService._internal();
  factory ProductoService() => _instance;
  ProductoService._internal();

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Obtener todos los productos con nombres de ingredientes resueltos (NUEVO ENDPOINT OPTIMIZADO)
  Future<List<Producto>> getProductos() async {
    try {
      final headers = await _getHeaders();

      // Asegurar que la URL esté correctamente formada
      final url = '$baseUrl/api/productos/con-nombres-ingredientes';
      print('📦 Obteniendo productos de URL: $url');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 10));

      print('📦 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        print(
          '❌ Endpoint optimizado no disponible (${response.statusCode}), usando endpoint básico...',
        );
        // Fallback al endpoint original
        return await _getProductosBasico();
      }
    } catch (e) {
      print('❌ Error con endpoint optimizado, usando endpoint básico...: $e');
      // Fallback al endpoint original
      return await _getProductosBasico();
    }
  }

  // Obtener todos los productos (endpoint básico como fallback)
  Future<List<Producto>> _getProductosBasico() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/productos'), headers: headers)
          .timeout(Duration(seconds: 10));

      print('📦 Response status (básico): ${response.statusCode}');
      print('📦 Response body (básico): ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error cargando productos desde backend: $e');
      throw Exception(
        'No se pudieron cargar los productos desde el servidor: $e',
      );
    }
  }

  // Obtener todas las categorías
  Future<List<Categoria>> getCategorias() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/categorias'), headers: headers)
          .timeout(Duration(seconds: 10));

      print('📂 Response status: ${response.statusCode}');
      print('📂 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseCategoriaListResponse(responseData);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error cargando categorías desde backend: $e');
      throw Exception(
        'No se pudieron cargar las categorías desde el servidor: $e',
      );
    }
  }

  // Crear producto
  Future<Producto> addProducto(Producto producto) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/productos'),
            headers: headers,
            body: json.encode(producto.toJson()),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 201) {
        print('✅ Producto creado exitosamente');
        return Producto.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error creando producto: $e');
      throw Exception('No se pudo crear el producto: $e');
    }
  }

  // Crear producto con ingredientes disponibles
  Future<Producto> crearProductoConIngredientes({
    required String nombre,
    required double precio,
    required double costo,
    required String categoriaId,
    List<String> ingredientesDisponibles = const [],
    String? descripcion,
  }) async {
    try {
      final headers = await _getHeaders();

      final productoData = {
        'nombre': nombre,
        'precio': precio,
        'costo': costo,
        'categoriaId': categoriaId,
        'ingredientesDisponibles': ingredientesDisponibles,
        if (descripcion != null) 'descripcion': descripcion,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/productos'),
            headers: headers,
            body: json.encode(productoData),
          )
          .timeout(Duration(seconds: 10));

      print(
        '📦 Crear producto con ingredientes response: ${response.statusCode}',
      );
      print('📦 Crear producto con ingredientes body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          // Si la respuesta es un objeto con "data"
          if (responseData.containsKey('data')) {
            return Producto.fromJson(responseData['data']);
          } else {
            return Producto.fromJson(responseData);
          }
        } else {
          throw Exception('Formato de respuesta inesperado');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error creando producto con ingredientes: $e');
      throw Exception('No se pudo crear el producto: $e');
    }
  }

  // Actualizar producto
  Future<Producto> updateProducto(Producto producto) async {
    try {
      final headers = await _getHeaders();

      // Convertir el producto a JSON para enviarlo al backend
      final productoJson = producto.toJson();
      print('🔄 Enviando datos de producto al backend: $productoJson');

      final response = await http
          .put(
            Uri.parse('$baseUrl/api/productos/${producto.id}'),
            headers: headers,
            body: json.encode(productoJson),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Producto actualizado exitosamente');
        return Producto.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error actualizando producto: $e');
      throw Exception('No se pudo actualizar el producto: $e');
    }
  }

  // Eliminar producto
  Future<void> deleteProducto(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/api/productos/$id'), headers: headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Producto eliminado exitosamente');
        return;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error eliminando producto: $e');
      throw Exception('No se pudo eliminar el producto: $e');
    }
  }

  // Crear categoría
  Future<Categoria> addCategoria(Categoria categoria) async {
    try {
      final headers = await _getHeaders();

      // Verificar si la imagen es una URL de datos (base64)
      if (categoria.imagenUrl != null &&
          categoria.imagenUrl!.startsWith('data:')) {
        print('Detectada imagen base64 en creación de categoría');
        // Similar al método updateCategoria, aquí podrías:
        // 1. Subir la imagen al servidor y obtener una URL
        // 2. O bien almacenarla directamente como base64 en la BD
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/categorias'),
            headers: headers,
            body: json.encode(categoria.toJson()),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 201) {
        print('✅ Categoría creada exitosamente');
        return Categoria.fromJson(json.decode(response.body));
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        print('❌ Respuesta: ${response.body}');
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error creando categoría: $e');
      throw Exception('No se pudo crear la categoría: $e');
    }
  }

  // Actualizar categoría
  Future<Categoria> updateCategoria(Categoria categoria) async {
    try {
      final headers = await _getHeaders();

      // Verificar si la imagen es una URL de datos (base64)
      if (categoria.imagenUrl != null &&
          categoria.imagenUrl!.startsWith('data:')) {
        print('Detectada imagen base64 en actualización de categoría');
        // Aquí podrías:
        // 1. O bien subir la imagen al servidor y obtener una URL
        // 2. O bien almacenarla directamente como base64 en la BD

        // Por ahora, mantendremos el base64 tal cual, pero en un sistema
        // de producción sería mejor subirla a un servidor de archivos
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/api/categorias/${categoria.id}'),
            headers: headers,
            body: json.encode(categoria.toJson()),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Categoría actualizada exitosamente');
        return Categoria.fromJson(json.decode(response.body));
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        print('❌ Respuesta: ${response.body}');
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error actualizando categoría: $e');
      throw Exception('No se pudo actualizar la categoría: $e');
    }
  }

  // Eliminar categoría
  Future<void> deleteCategoria(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/api/categorias/$id'), headers: headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Categoría eliminada exitosamente');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error eliminando categoría: $e');
      throw Exception('No se pudo eliminar la categoría: $e');
    }
  }

  // Buscar productos
  Future<List<Producto>> searchProductos(
    String query, {
    String? categoriaId,
  }) async {
    try {
      final headers = await _getHeaders();
      Map<String, String> queryParams = {};
      if (query.isNotEmpty) queryParams['q'] = query;
      if (categoriaId != null) queryParams['categoriaId'] = categoriaId;

      final uri = Uri.parse(
        '$baseUrl/api/productos/buscar',
      ).replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        print('✅ Productos encontrados: ${jsonList.length}');
        return jsonList.map((json) => Producto.fromJson(json)).toList();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error buscando productos: $e');
      throw Exception('No se pudieron buscar los productos: $e');
    }
  }

  // Obtener productos por categoría
  Future<List<Producto>> getProductosByCategoria(String categoriaId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/productos?categoriaId=$categoriaId'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        print('✅ Productos por categoría cargados: ${jsonList.length}');
        return jsonList.map((json) => Producto.fromJson(json)).toList();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error obteniendo productos por categoría: $e');
      throw Exception('No se pudieron obtener los productos por categoría: $e');
    }
  }

  // Subir imagen
  Future<String> uploadProductImage(XFile image) async {
    try {
      final headers = await _getHeaders();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/productos/upload-image'),
      );

      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send().timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        print('✅ Imagen subida exitosamente');
        return jsonData['imageUrl'];
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error subiendo imagen: $e');
      throw Exception('No se pudo subir la imagen: $e');
    }
  }

  // Método para seleccionar imagen
  Future<String?> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // En Flutter Web, necesitamos crear una URL de datos para la imagen
        if (kIsWeb) {
          try {
            // Leer el archivo como bytes
            final bytes = await image.readAsBytes();

            // Codificar a base64
            final base64Image = base64Encode(bytes);

            // Crear una URL de datos para la imagen
            // Detectar el tipo de imagen
            String mimeType = 'image/jpeg';
            if (image.name.toLowerCase().endsWith('.png')) {
              mimeType = 'image/png';
            } else if (image.name.toLowerCase().endsWith('.gif')) {
              mimeType = 'image/gif';
            }

            // En Flutter Web, las URL de datos funcionan directamente en los widgets Image
            final dataUrl = 'data:$mimeType;base64,$base64Image';
            print('Generada URL de datos: longitud=${dataUrl.length}');

            // Intentar subir la imagen al servidor
            // Este método es opcional y depende de si tu backend soporta subida de imágenes
            try {
              // Podrías implementar una subida de imagen aquí
              // final uploadedUrl = await _uploadImageToServer(bytes, mimeType);
              // if (uploadedUrl != null) return uploadedUrl;
            } catch (uploadError) {
              print(
                'Error al intentar subir la imagen: $uploadError. Usando URL de datos local.',
              );
            }

            return dataUrl;
          } catch (webError) {
            print('Error procesando imagen en Web: $webError');
            return null;
          }
        } else {
          // En dispositivos móviles, devolvemos la ruta del archivo
          return image.path;
        }
      }
      return null;
    } catch (e) {
      print('Error al seleccionar imagen: $e');
      return null;
    }
  }

  // Obtener solo el nombre de un producto por ID
  Future<String?> getProductoNombre(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/productos/$id/nombre'), headers: headers)
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          // Si la respuesta está envuelta en una estructura data
          if (responseData.containsKey('nombre')) {
            return responseData['nombre'];
          } else if (responseData.containsKey('data') &&
              responseData['data'] is Map<String, dynamic> &&
              responseData['data'].containsKey('nombre')) {
            return responseData['data']['nombre'];
          }
        }
        return 'Producto #$id';
      } else if (response.statusCode == 404) {
        return 'Producto #$id';
      }
      return 'Producto #$id';
    } catch (e) {
      print('❌ Error obteniendo nombre del producto $id: $e');
      return 'Producto #$id';
    }
  }

  // Obtener un producto por ID con nombres de ingredientes resueltos (OPTIMIZADO)
  Future<Producto?> getProducto(String? id) async {
    // Validar que el ID no sea nulo o vacío
    if (id == null || id.trim().isEmpty) {
      print('❌ Error: ID de producto nulo o vacío');
      return null;
    }

    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/productos/$id/con-nombres-ingredientes'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          // Si la respuesta está envuelta en una estructura data
          if (responseData.containsKey('data')) {
            return Producto.fromJson(responseData['data']);
          }
          // Si la respuesta es directamente el producto
          return Producto.fromJson(responseData);
        }
      } else if (response.statusCode == 404) {
        print(
          '❌ Endpoint optimizado no encontrado para producto $id, usando básico...',
        );
        // Fallback al endpoint original
        return await _getProductoBasico(id);
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } catch (e) {
      print(
        '❌ Error con endpoint optimizado para producto $id, usando básico: $e',
      );
      // Fallback al endpoint original
      return await _getProductoBasico(id);
    }
  }

  // Obtener un producto por ID (endpoint básico como fallback)
  Future<Producto?> _getProductoBasico(String? id) async {
    // Validar que el ID no sea nulo o vacío
    if (id == null || id.trim().isEmpty) {
      print('❌ Error: ID de producto nulo o vacío en _getProductoBasico');
      return null;
    }

    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/productos/$id'), headers: headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          // Si la respuesta está envuelta en una estructura data
          if (responseData.containsKey('data')) {
            return Producto.fromJson(responseData['data']);
          }
          // Si la respuesta es directamente el producto
          return Producto.fromJson(responseData);
        }
      } else if (response.statusCode == 404) {
        return null;
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } catch (e) {
      print('❌ Error cargando producto $id: $e');
      return null;
    }
  }

  // Método auxiliar para parsear respuestas de lista de productos
  List<Producto> _parseListResponse(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      // Buscar posibles propiedades que contengan la lista de productos
      if (responseData.containsKey('productos')) {
        return responseData['productos']
            .map<Producto>((json) => Producto.fromJson(json))
            .toList();
      } else if (responseData.containsKey('data')) {
        return responseData['data']
            .map<Producto>((json) => Producto.fromJson(json))
            .toList();
      } else if (responseData.containsKey('results')) {
        return responseData['results']
            .map<Producto>((json) => Producto.fromJson(json))
            .toList();
      }
      throw Exception('No se encontró una lista de productos en la respuesta');
    } else if (responseData is List) {
      return responseData
          .map<Producto>((json) => Producto.fromJson(json))
          .toList();
    }
    throw Exception('Formato de respuesta no válido');
  }

  // ========== MÉTODOS PARA PRODUCTOS COMBO ==========

  /// Obtiene los ingredientes requeridos disponibles para un producto combo
  Future<List<IngredienteProducto>> getIngredientesRequeridosCombo(
    String productoId,
  ) async {
    try {
      final headers = await _getHeaders();
      // USAR ENDPOINT OPTIMIZADO que ya trae nombres resueltos
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/api/productos/$productoId/con-nombres-ingredientes',
            ),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      print(
        '🥘 Obteniendo producto completo CON NOMBRES para ingredientes requeridos: $productoId',
      );
      print('🥘 Response status: ${response.statusCode}');
      print('🥘 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        Map<String, dynamic> productoJson;

        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            productoJson = responseData['data'];
          } else {
            productoJson = responseData;
          }
        } else {
          throw Exception('Formato de respuesta inesperado');
        }

        // Extraer ingredientes requeridos del producto
        List<dynamic> ingredientesJson = [];
        if (productoJson.containsKey('ingredientesRequeridos') &&
            productoJson['ingredientesRequeridos'] != null) {
          ingredientesJson = productoJson['ingredientesRequeridos'];
        }

        print(
          '🔍 TOTAL ingredientes requeridos encontrados: ${ingredientesJson.length}',
        );
        for (int i = 0; i < ingredientesJson.length; i++) {
          print('🔍 Ingrediente requerido $i RAW: ${ingredientesJson[i]}');
        }

        List<IngredienteProducto> ingredientesBasicos = ingredientesJson.map((
          json,
        ) {
          print('🔍 INGREDIENTE REQUERIDO RAW JSON: $json');
          final ingrediente = IngredienteProducto.fromJson(json);
          print(
            '🔍 INGREDIENTE REQUERIDO PROCESADO: nombre="${ingrediente.ingredienteNombre}", id="${ingrediente.ingredienteId}", precio=${ingrediente.precioAdicional}',
          );
          return ingrediente;
        }).toList();

        // Con el nuevo endpoint, los nombres ya deberían venir resueltos, pero mantenemos el fallback
        if (ingredientesBasicos.any(
          (ing) =>
              ing.ingredienteNombre.isEmpty ||
              ing.ingredienteNombre == ing.ingredienteId,
        )) {
          print(
            '⚠️ Algunos ingredientes aún necesitan enriquecimiento, aplicando fallback...',
          );
          return await _enriquecerIngredientesConNombres(ingredientesBasicos);
        }

        return ingredientesBasicos;
      } else if (response.statusCode == 404) {
        print('❌ Endpoint optimizado no disponible, usando básico...');
        return await _getIngredientesRequeridosComboBasico(productoId);
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } catch (e) {
      print('❌ Error con endpoint optimizado, usando básico: $e');
      return await _getIngredientesRequeridosComboBasico(productoId);
    }
  }

  /// Método fallback para ingredientes requeridos (endpoint básico)
  Future<List<IngredienteProducto>> _getIngredientesRequeridosComboBasico(
    String productoId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/productos/$productoId'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      print(
        '🥘 Obteniendo producto completo para ingredientes requeridos (BÁSICO): $productoId',
      );
      print('🥘 Response status: ${response.statusCode}');
      print('🥘 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        Map<String, dynamic> productoJson;

        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            productoJson = responseData['data'];
          } else {
            productoJson = responseData;
          }
        } else {
          throw Exception('Formato de respuesta inesperado');
        }

        // Extraer ingredientes requeridos del producto
        List<dynamic> ingredientesJson = [];
        if (productoJson.containsKey('ingredientesRequeridos') &&
            productoJson['ingredientesRequeridos'] != null) {
          ingredientesJson = productoJson['ingredientesRequeridos'];
        }

        print(
          '🔍 TOTAL ingredientes requeridos encontrados: ${ingredientesJson.length}',
        );
        for (int i = 0; i < ingredientesJson.length; i++) {
          print('🔍 Ingrediente requerido $i RAW: ${ingredientesJson[i]}');
        }

        List<IngredienteProducto> ingredientesBasicos = ingredientesJson.map((
          json,
        ) {
          print('🔍 INGREDIENTE REQUERIDO RAW JSON: $json');
          final ingrediente = IngredienteProducto.fromJson(json);
          print(
            '🔍 INGREDIENTE REQUERIDO PROCESADO: nombre="${ingrediente.ingredienteNombre}", id="${ingrediente.ingredienteId}", precio=${ingrediente.precioAdicional}',
          );
          return ingrediente;
        }).toList();

        // Enriquecer con nombres de ingredientes si están vacíos
        return await _enriquecerIngredientesConNombres(ingredientesBasicos);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error obteniendo ingredientes requeridos del combo: $e');
      throw Exception('No se pudieron cargar los ingredientes requeridos: $e');
    }
  }

  /// Obtiene los ingredientes opcionales disponibles para un producto combo
  Future<List<IngredienteProducto>> getIngredientesOpcionalesCombo(
    String productoId,
  ) async {
    try {
      final headers = await _getHeaders();
      // USAR ENDPOINT OPTIMIZADO que ya trae nombres resueltos
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/api/productos/$productoId/con-nombres-ingredientes',
            ),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      print(
        '🥘 Obteniendo producto completo CON NOMBRES para ingredientes opcionales: $productoId',
      );
      print('🥘 Response status: ${response.statusCode}');
      print('🥘 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        Map<String, dynamic> productoJson;

        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            productoJson = responseData['data'];
          } else {
            productoJson = responseData;
          }
        } else {
          throw Exception('Formato de respuesta inesperado');
        }

        // Extraer ingredientes opcionales del producto
        List<dynamic> ingredientesJson = [];
        if (productoJson.containsKey('ingredientesOpcionales') &&
            productoJson['ingredientesOpcionales'] != null) {
          ingredientesJson = productoJson['ingredientesOpcionales'];
        }

        print(
          '🔍 TOTAL ingredientes opcionales encontrados: ${ingredientesJson.length}',
        );
        for (int i = 0; i < ingredientesJson.length; i++) {
          print('🔍 Ingrediente $i RAW: ${ingredientesJson[i]}');
        }

        List<IngredienteProducto> ingredientesBasicos = ingredientesJson.map((
          json,
        ) {
          print('🔍 INGREDIENTE OPCIONAL RAW JSON: $json');
          final ingrediente = IngredienteProducto.fromJson(json);
          print(
            '🔍 INGREDIENTE OPCIONAL PROCESADO: nombre="${ingrediente.ingredienteNombre}", id="${ingrediente.ingredienteId}", precio=${ingrediente.precioAdicional}',
          );
          return ingrediente;
        }).toList();

        // Con el nuevo endpoint, los nombres ya deberían venir resueltos, pero mantenemos el fallback
        if (ingredientesBasicos.any(
          (ing) =>
              ing.ingredienteNombre.isEmpty ||
              ing.ingredienteNombre == ing.ingredienteId,
        )) {
          print(
            '⚠️ Algunos ingredientes aún necesitan enriquecimiento, aplicando fallback...',
          );
          return await _enriquecerIngredientesConNombres(ingredientesBasicos);
        }

        return ingredientesBasicos;
      } else if (response.statusCode == 404) {
        print('❌ Endpoint optimizado no disponible, usando básico...');
        return await _getIngredientesOpcionalesComboBasico(productoId);
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } catch (e) {
      print('❌ Error con endpoint optimizado, usando básico: $e');
      return await _getIngredientesOpcionalesComboBasico(productoId);
    }
  }

  /// Método fallback para ingredientes opcionales (endpoint básico)
  Future<List<IngredienteProducto>> _getIngredientesOpcionalesComboBasico(
    String productoId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/productos/$productoId'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      print(
        '🥘 Obteniendo producto completo para ingredientes opcionales (BÁSICO): $productoId',
      );
      print('🥘 Response status: ${response.statusCode}');
      print('🥘 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        Map<String, dynamic> productoJson;

        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            productoJson = responseData['data'];
          } else {
            productoJson = responseData;
          }
        } else {
          throw Exception('Formato de respuesta inesperado');
        }

        // Extraer ingredientes opcionales del producto
        List<dynamic> ingredientesJson = [];
        if (productoJson.containsKey('ingredientesOpcionales') &&
            productoJson['ingredientesOpcionales'] != null) {
          ingredientesJson = productoJson['ingredientesOpcionales'];
        }

        print(
          '🔍 TOTAL ingredientes opcionales encontrados: ${ingredientesJson.length}',
        );
        for (int i = 0; i < ingredientesJson.length; i++) {
          print('🔍 Ingrediente $i RAW: ${ingredientesJson[i]}');
        }

        List<IngredienteProducto> ingredientesBasicos = ingredientesJson.map((
          json,
        ) {
          print('🔍 INGREDIENTE OPCIONAL RAW JSON: $json');
          final ingrediente = IngredienteProducto.fromJson(json);
          print(
            '🔍 INGREDIENTE OPCIONAL PROCESADO: nombre="${ingrediente.ingredienteNombre}", id="${ingrediente.ingredienteId}", precio=${ingrediente.precioAdicional}',
          );
          return ingrediente;
        }).toList();

        // Enriquecer con nombres de ingredientes si están vacíos
        return await _enriquecerIngredientesConNombres(ingredientesBasicos);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error obteniendo ingredientes opcionales del combo: $e');
      throw Exception('No se pudieron cargar los ingredientes opcionales: $e');
    }
  }

  /// Verifica si un producto es tipo combo
  Future<bool> verificarSiEsCombo(String productoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/productos/$productoId/es-combo'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      print('🔍 Verificando si producto $productoId es combo');
      print('🔍 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData is Map<String, dynamic>) {
          return responseData['data'] ?? false;
        }
        return false;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error verificando tipo de producto: $e');
      return false; // En caso de error, asumir que no es combo
    }
  }

  /// Carga los ingredientes requeridos y opcionales de un producto y actualiza el objeto Producto
  Future<Producto> cargarIngredientesOpcionalesParaProducto(
    Producto producto,
  ) async {
    try {
      // Solo cargar ingredientes si el producto puede seleccionarlos
      if (producto.puedeSeleccionarIngredientes) {
        print('🔄 Cargando ingredientes para producto: ${producto.nombre}');

        List<IngredienteProducto> ingredientesRequeridos = [];
        List<IngredienteProducto> ingredientesOpcionales = [];

        // Cargar ingredientes requeridos
        try {
          ingredientesRequeridos = await getIngredientesRequeridosCombo(
            producto.id,
          );
          print(
            '✅ Ingredientes requeridos cargados: ${ingredientesRequeridos.length}',
          );
        } catch (e) {
          print('⚠️ Error cargando ingredientes requeridos: $e');
        }

        // Cargar ingredientes opcionales
        try {
          ingredientesOpcionales = await getIngredientesOpcionalesCombo(
            producto.id,
          );
          print(
            '✅ Ingredientes opcionales cargados: ${ingredientesOpcionales.length}',
          );
        } catch (e) {
          print('⚠️ Error cargando ingredientes opcionales: $e');
        }

        // Crear una nueva instancia del producto con los ingredientes cargados
        return producto.copyWith(
          ingredientesRequeridos: ingredientesRequeridos,
          ingredientesOpcionales: ingredientesOpcionales,
        );
      }

      // Si no es combo, devolver el producto sin modificar
      return producto;
    } catch (e) {
      print(
        '❌ Error cargando ingredientes para producto ${producto.nombre}: $e',
      );
      // En caso de error, devolver el producto original
      return producto;
    }
  }

  /// Enriquece los ingredientes con sus nombres completos cargándolos desde el backend
  Future<List<IngredienteProducto>> _enriquecerIngredientesConNombres(
    List<IngredienteProducto> ingredientes,
  ) async {
    List<IngredienteProducto> ingredientesEnriquecidos = [];

    for (var ingrediente in ingredientes) {
      print(
        '🔍 Procesando ingrediente: ID="${ingrediente.ingredienteId}", Nombre="${ingrediente.ingredienteNombre}"',
      );

      // Si el ingrediente ya tiene nombre válido (no es un ID), no necesita enriquecimiento
      if (ingrediente.ingredienteNombre.isNotEmpty &&
          !ingrediente.ingredienteNombre.startsWith('689') &&
          ingrediente.ingredienteNombre != ingrediente.ingredienteId) {
        print(
          '✅ Ingrediente ya tiene nombre válido: ${ingrediente.ingredienteNombre}',
        );
        ingredientesEnriquecidos.add(ingrediente);
        continue;
      }

      print(
        '🔄 Ingrediente necesita enriquecimiento. Nombre actual: "${ingrediente.ingredienteNombre}"',
      );

      // Si solo tenemos el ID, cargar los datos completos del ingrediente
      if (ingrediente.ingredienteId.isNotEmpty) {
        try {
          print(
            '🔄 Cargando nombre para ingrediente ID: ${ingrediente.ingredienteId}',
          );

          final headers = await _getHeaders();
          final response = await http
              .get(
                Uri.parse(
                  '$baseUrl/api/ingredientes/${ingrediente.ingredienteId}',
                ),
                headers: headers,
              )
              .timeout(Duration(seconds: 5));

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            print(
              '📦 Respuesta raw del backend para ingrediente ${ingrediente.ingredienteId}: $responseData',
            );

            Map<String, dynamic> ingredienteJson;

            if (responseData is Map<String, dynamic>) {
              if (responseData.containsKey('data')) {
                ingredienteJson = responseData['data'];
                print('📦 Usando campo "data": $ingredienteJson');
              } else {
                ingredienteJson = responseData;
                print('📦 Usando respuesta directa: $ingredienteJson');
              }
            } else {
              throw Exception('Formato de respuesta inesperado');
            }

            String nombreIngrediente =
                ingredienteJson['nombre']?.toString() ??
                'Ingrediente ${ingrediente.ingredienteId}';

            print(
              '✅ Nombre extraído: "$nombreIngrediente" para ID: ${ingrediente.ingredienteId}',
            );

            // Crear un nuevo ingrediente con el nombre correcto
            final ingredienteEnriquecido = IngredienteProducto(
              ingredienteId: ingrediente.ingredienteId,
              ingredienteNombre: nombreIngrediente,
              cantidadNecesaria: ingrediente.cantidadNecesaria,
              esOpcional: ingrediente.esOpcional,
              precioAdicional: ingrediente.precioAdicional,
            );

            ingredientesEnriquecidos.add(ingredienteEnriquecido);
          } else {
            print(
              '⚠️ No se pudo cargar ingrediente ${ingrediente.ingredienteId}, usando ID como nombre',
            );
            ingredientesEnriquecidos.add(ingrediente);
          }
        } catch (e) {
          print(
            '⚠️ Error cargando ingrediente ${ingrediente.ingredienteId}: $e',
          );
          // En caso de error, usar el ingrediente original
          ingredientesEnriquecidos.add(ingrediente);
        }
      } else {
        // Si no tenemos ID, agregar el ingrediente tal como está
        ingredientesEnriquecidos.add(ingrediente);
      }
    }

    return ingredientesEnriquecidos;
  }

  // Método auxiliar para parsear respuestas de lista de categorías
  List<Categoria> _parseCategoriaListResponse(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      // Buscar posibles propiedades que contengan la lista de categorías
      if (responseData.containsKey('categorias')) {
        return responseData['categorias']
            .map<Categoria>((json) => Categoria.fromJson(json))
            .toList();
      } else if (responseData.containsKey('data')) {
        return responseData['data']
            .map<Categoria>((json) => Categoria.fromJson(json))
            .toList();
      } else if (responseData.containsKey('results')) {
        return responseData['results']
            .map<Categoria>((json) => Categoria.fromJson(json))
            .toList();
      }
      throw Exception('No se encontró una lista de categorías en la respuesta');
    } else if (responseData is List) {
      return responseData
          .map<Categoria>((json) => Categoria.fromJson(json))
          .toList();
    }
    throw Exception('Formato de respuesta no válido');
  }
}
