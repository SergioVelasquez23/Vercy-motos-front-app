import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../config/api_config.dart';
import '../config/debug_config.dart';

class ProductoService {
  static final ProductoService _instance = ProductoService._internal();
  factory ProductoService() => _instance;
  ProductoService._internal();

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();

  // Evitar peticiones duplicadas simultáneas para getProductos
  Future<List<Producto>>? _inFlightGetProductos;

  // Cache y peticiones in-flight para getProducto(id)
  final Map<String, Future<Producto?>> _inFlightGetProductoById = {};
  final Map<String, Producto?> _productoByIdCache = {};

  // Caché de productos para evitar cargar todos los productos repetidamente
  // y para proporcionar una alternativa cuando ocurre OutOfMemoryError
  final Map<String, Producto> _productosCache = {};

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Obtener todos los productos con nombres de ingredientes resueltos (NUEVO ENDPOINT OPTIMIZADO)
  Future<List<Producto>> getProductos() async {
    // Si ya hay una petición en curso, volver la misma Future
    if (_inFlightGetProductos != null) return _inFlightGetProductos!;

    _inFlightGetProductos = _doGetProductos();
    try {
      final res = await _inFlightGetProductos!;
      return res;
    } finally {
      // Liberar el marcador para futuras llamadas
      _inFlightGetProductos = null;
    }
  }

  // Implementación real de la obtención de productos (separada para memoización in-flight)
  Future<List<Producto>> _doGetProductos() async {
    try {
      final headers = await _getHeaders();

      // Asegurar que la URL esté correctamente formada
      final url = '$baseUrl/api/productos/con-nombres-ingredientes';

      // 1. Primero intentar con paginación para evitar OutOfMemoryError
      try {
        print(
          '📦 Obteniendo productos con paginación para prevenir OutOfMemoryError...',
        );
        return await _getProductosPaginados(headers);
      } catch (paginationError) {
        print(
          '⚠️ Error con paginación: $paginationError, intentando endpoint optimizado...',
        );
        if (DebugConfig.enableStackTraceInstrumentation) {
          // Instrumentación: imprimir StackTrace para ayudar a localizar el orígen
          try {
            final st = StackTrace.current;
            print('🧭 StackTrace (paginación error): ${st.toString()}');
          } catch (_) {}
        }

        // 2. Si falla la paginación, intentar con el endpoint optimizado
        final response = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(Duration(seconds: 45)); // Timeout aumentado para Railway

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          return _parseListResponse(responseData);
        } else {
          print(
            '❌ Endpoint optimizado no disponible (${response.statusCode}), usando endpoint básico...',
          );
          // 3. Fallback al endpoint original
          return await _getProductosBasico();
        }
      }
    } catch (e) {
      print('❌ Error con endpoint optimizado: $e');
      if (DebugConfig.enableStackTraceInstrumentation) {
        try {
          final st = StackTrace.current;
          print('🧭 StackTrace (doGetProductos error): ${st.toString()}');
        } catch (_) {}
      }

      // Verificar si es un error de memoria
      if (e.toString().contains('OutOfMemoryError') ||
          e.toString().contains('Java heap space')) {
        print(
          '🚨 Error de memoria detectado, usando cache local si está disponible...',
        );
        // Intentar devolver los productos en caché si existen
        if (_productosCache.isNotEmpty) {
          print(
            '📦 Devolviendo ${_productosCache.length} productos de caché local',
          );
          return _productosCache.values.toList();
        }
      }

      // Fallback al endpoint básico como último recurso
      try {
        return await _getProductosBasico();
      } catch (fallbackError) {
        print('💥 Error fatal al cargar productos: $fallbackError');
        // Devolver lista vacía como último recurso para evitar bloquear la UI
        return [];
      }
    }
  }

  // Nuevo método para obtener productos con paginación
  Future<List<Producto>> _getProductosPaginados(
    Map<String, String> headers,
  ) async {
    List<Producto> allProductos = [];
    int page = 1;
    int pageSize = 50;
    bool hasMorePages = true;

    while (hasMorePages) {
      final url = '$baseUrl/api/productos/paginados?page=$page&size=$pageSize';
      print('📦 Obteniendo página $page de productos...');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 45));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Verificar formato de respuesta (con o sin wrapper)
        final List<dynamic> productosData;
        if (responseData is Map && responseData.containsKey('data')) {
          productosData = responseData['data'] as List<dynamic>;
          // Verificar si hay más páginas
          hasMorePages =
              responseData['hasNextPage'] == true ||
              responseData['hasMore'] == true ||
              (responseData['page'] != null &&
                  responseData['totalPages'] != null &&
                  responseData['page'] < responseData['totalPages']);
        } else if (responseData is List) {
          productosData = responseData;
          // Si devuelve menos items que el tamaño de página, asumimos que no hay más
          hasMorePages = productosData.length >= pageSize;
        } else {
          throw Exception('Formato de respuesta de paginación no reconocido');
        }

        // Parsear productos y agregarlos a la lista
        final pageProductos = productosData
            .map((item) => Producto.fromJson(item))
            .toList();

        allProductos.addAll(pageProductos);

        // Si no hay más páginas o la página actual está vacía, salir
        if (pageProductos.isEmpty) {
          hasMorePages = false;
        }

        page++;
      } else if (response.statusCode == 404) {
        // Si el endpoint de paginación no existe, salir del loop
        print('⚠️ Endpoint de paginación no disponible');
        throw Exception('Endpoint de paginación no disponible');
      } else {
        throw Exception(
          'Error al obtener página $page: ${response.statusCode}',
        );
      }
    }

    // Guardar en caché
    for (var producto in allProductos) {
      _productosCache[producto.id] = producto;
    }

    print('✅ Obtenidos ${allProductos.length} productos con paginación');
    return allProductos;
  }

  // Obtener todos los productos (endpoint básico como fallback)
  Future<List<Producto>> _getProductosBasico() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/productos'), headers: headers)
          .timeout(Duration(seconds: 45)); // Timeout aumentado para Railway

      print('📦 Response status (básico): ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final productos = _parseListResponse(responseData);

        // Guardar en caché
        for (var producto in productos) {
          _productosCache[producto.id] = producto;
        }

        return productos;
      } else {
        // Intenta analizar el mensaje de error
        String errorMessage = 'Error del servidor: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // Error al parsear la respuesta, usar mensaje genérico
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Error cargando productos desde backend: $e');

      // Si hay productos en caché, usarlos como último recurso
      if (_productosCache.isNotEmpty) {
        print('📦 Fallback a caché local: ${_productosCache.length} productos');
        return _productosCache.values.toList();
      }

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

      // Response status: ${response.statusCode}
      // Response body: ${response.body}

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
      // Usar 'nombre' en lugar de 'q' para el nuevo endpoint de filtrado
      if (query.isNotEmpty) queryParams['nombre'] = query;
      if (categoriaId != null) queryParams['categoriaId'] = categoriaId;

      final uri = Uri.parse(
        '$baseUrl/api/productos/filtrar', // Usar nuevo endpoint de filtrado
      ).replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: headers)
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

      if (response.statusCode == 200) {
        // Extraer los datos del campo 'data' de la respuesta ApiResponse
        final jsonBody = json.decode(response.body);
        if (!jsonBody['success']) {
          throw Exception(
            jsonBody['message'] ?? 'Error en la respuesta del servidor',
          );
        }

        final List<dynamic> jsonList = jsonBody['data'];
        // ✅ COMENTADO: Log de productos encontrados removido
        // print('✅ Productos encontrados: ${jsonList.length}');
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
            Uri.parse(
              '$baseUrl/api/productos/filtrar?categoriaId=$categoriaId',
            ),
            headers: headers,
          )
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

      if (response.statusCode == 200) {
        // Extraer los datos del campo 'data' de la respuesta ApiResponse
        final jsonBody = json.decode(response.body);
        if (!jsonBody['success']) {
          throw Exception(
            jsonBody['message'] ?? 'Error en la respuesta del servidor',
          );
        }

        final List<dynamic> jsonList = jsonBody['data'];
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

  // Subir imagen y guardar como base64 en la base de datos
  Future<String> uploadProductImage(XFile image) async {
    try {
      print('📤 Iniciando subida de imagen: ${image.name}');
      final headers = await _getHeaders();

      // Siempre usar base64 para persistencia (tanto web como móvil)
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileName = image.name;

      // Detectar MIME type
      String mimeType = 'image/jpeg';
      if (fileName.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.gif')) {
        mimeType = 'image/gif';
      } else if (fileName.toLowerCase().endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      // Crear data URL para almacenamiento persistente
      final dataUrl = 'data:$mimeType;base64,$base64Image';

      print('📤 Imagen convertida: ${dataUrl.length} caracteres');
      print('📤 Guardando imagen como base64 en BD...');

      // Enviar al backend para guardar en BD como base64
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/images/save-base64'),
            headers: headers,
            body: json.encode({
              'fileName': fileName,
              'imageData': dataUrl,
              'mimeType': mimeType,
              'storage': 'database', // Especificar que se guarde en BD
            }),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Parsear la respuesta para verificar que se guardó correctamente
        final jsonData = json.decode(response.body);
        print(
          '✅ Imagen guardada como base64 en BD exitosamente: ${jsonData['success'] == true ? 'OK' : 'Error'}',
        );
        // Retornar la data URL para uso inmediato
        return dataUrl;
      } else {
        print('⚠️ Backend no soporta base64, usando data URL local');
        // Fallback: retornar data URL directamente
        return dataUrl;
      }
    } catch (e) {
      print('❌ Error procesando imagen: $e');

      // Fallback: crear data URL local
      try {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        final mimeType = _getMimeTypeFromFileName(image.name);
        final dataUrl = 'data:$mimeType;base64,$base64Image';

        print('🔄 Usando imagen base64 local como fallback');
        return dataUrl;
      } catch (fallbackError) {
        print('❌ Error en fallback: $fallbackError');
        throw Exception('No se pudo procesar la imagen: $e');
      }
    }
  }

  // Método auxiliar para obtener MIME type
  String _getMimeTypeFromFileName(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
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
          .timeout(Duration(seconds: 20)); // Timeout aumentado para Railway

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

    // Devolver desde cache si ya existe (incluye cache negativo: null)
    if (_productoByIdCache.containsKey(id)) return _productoByIdCache[id];

    // Si ya hay una petición en curso para este id, reutilizarla
    if (_inFlightGetProductoById.containsKey(id)) {
      return await _inFlightGetProductoById[id];
    }

    final future = _doGetProducto(id);
    _inFlightGetProductoById[id] = future;
    try {
      final res = await future;
      // Cachear el resultado (puede ser null si 404)
      _productoByIdCache[id] = res;
      return res;
    } finally {
      _inFlightGetProductoById.remove(id);
    }
  }

  // Implementación real de la carga de producto por id
  Future<Producto?> _doGetProducto(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/productos/$id/con-nombres-ingredientes'),
            headers: headers,
          )
          .timeout(Duration(seconds: 30));

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
          '❌ Endpoint optimizado no encontrado para producto $id, intentando fallback por id base...',
        );
        if (DebugConfig.enableStackTraceInstrumentation) {
          try {
            final st = StackTrace.current;
            print('🧭 StackTrace (getProducto 404 para $id): ${st.toString()}');
          } catch (_) {}
        }
        // Si el id contiene un sufijo (por ejemplo: originalid_timestamp_idx), intentar la parte antes del primer '_'
        if (id.contains('_')) {
          final baseId = id.split('_').first;
          if (baseId != id) {
            try {
              print('🔁 Intentando cargar producto con baseId: $baseId');
              final fallbackResp = await http
                  .get(
                    Uri.parse(
                      '$baseUrl/api/productos/$baseId/con-nombres-ingredientes',
                    ),
                    headers: headers,
                  )
                  .timeout(Duration(seconds: 30));

              if (fallbackResp.statusCode == 200) {
                final responseData = json.decode(fallbackResp.body);
                if (responseData is Map<String, dynamic>) {
                  if (responseData.containsKey('data')) {
                    return Producto.fromJson(responseData['data']);
                  }
                  return Producto.fromJson(responseData);
                }
              }
            } catch (e) {
              print('⚠️ Fallback por baseId falló para $baseId: $e');
            }
          }
        }
        // Fallback al endpoint original usando el id recibido
        print('🔁 Fallback final: usando endpoint básico para $id');
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
          .timeout(Duration(seconds: 30));

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

  // Eliminar caché (útil para wake-up / recarga completa)
  void clearCache() {
    _productosCache.clear();
    print('🧹 ProductoService: Caché de productos limpiada');
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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 30)); // Timeout aumentado para Railway

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
              .timeout(Duration(seconds: 20)); // Timeout aumentado para Railway

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
