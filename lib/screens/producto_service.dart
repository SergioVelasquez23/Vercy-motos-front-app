import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart'; // Para hash de contraseñas
import '../models/producto.dart';
import '../models/categoria.dart';
import '../config/api_config.dart';

class ProductoService {
  static final ProductoService _instance = ProductoService._internal();
  factory ProductoService() => _instance;
  ProductoService._internal() {
    _initSecureClient();
  }

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();
  late http.Client _client;

  // Inicializar un cliente HTTP seguro
  void _initSecureClient() {
    // Por ahora usamos un cliente HTTP básico
    _client = http.Client();

    // Verificar que estamos usando HTTPS
    if (!baseUrl.startsWith('https') &&
        !baseUrl.contains('localhost') &&
        !baseUrl.contains('127.0.0.1')) {
      print(
        '⚠️ ADVERTENCIA: No estás usando HTTPS. Las comunicaciones no son seguras.',
      );
    }

    // En producción, deberías implementar SSL Pinning
    // Ejemplo:
    /*
    // Para implementar SSL Pinning en producción, descomentar este código:
    if (!kIsWeb) {  // SSL Pinning solo funciona en dispositivos móviles
      try {
        // Configurar SSL Pinning
        final sslPinningManager = SSLPinningManager();
        
        // Define los hashes SHA-256 de los certificados que confías
        // Estos hashes deben ser obtenidos de tus certificados reales
        final trustedCertificateHashes = [
          'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // Reemplazar con hash real
        ];
        
        // Crea un cliente HTTP con SSL Pinning
        final secureHttpClient = HttpClient()
          ..badCertificateCallback = (cert, host, port) {
            // Verificar si el certificado coincide con alguno de nuestros hashes confiables
            final certBytes = cert.der;
            final sha256Hash = sha256.convert(certBytes);
            final hash64 = base64.encode(sha256Hash.bytes);
            final pinnedHash = 'sha256/$hash64';
            
            return trustedCertificateHashes.contains(pinnedHash);
          };
        
        // Reemplazar el cliente HTTP estándar con el seguro
        _client = IOClient(secureHttpClient);
        print('✅ SSL Pinning configurado correctamente');
      } catch (e) {
        print('❌ Error configurando SSL Pinning: $e');
        // Fallback a cliente HTTP normal
        _client = http.Client();
      }
    }
    */
  }

  // Genera un hash SHA-256 para contraseñas
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Cierre de sesión seguro (limpia todas las claves y datos sensibles)
  Future<void> logoutSecurely() async {
    try {
      // Eliminar el token JWT
      await storage.delete(key: 'jwt_token');

      // En producción podrías hacer una llamada al servidor para invalidar el token
      if (!ApiConfig.instance.isDevelopment) {
        try {
          await _client
              .post(
                Uri.parse('$baseUrl/api/auth/logout'),
                headers: await _getHeaders(),
              )
              .timeout(Duration(seconds: 5));
        } catch (e) {
          print('Error al invalidar el token en el servidor: $e');
          // No bloqueamos el proceso de cierre de sesión por este error
        }
      }

      print('✅ Sesión cerrada correctamente y datos sensibles eliminados');
    } catch (e) {
      print('❌ Error durante el cierre de sesión: $e');
      throw Exception('Error durante el cierre de sesión: $e');
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Obtener todos los productos
  Future<List<Producto>> getProductos() async {
    try {
      final headers = await _getHeaders();
      final response = await _client
          .get(
            Uri.parse(ApiConfig.instance.endpoints.products.all),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      print('📦 Response status: ${response.statusCode}');
      // No logueamos el body completo para evitar filtrar información potencialmente sensible
      print('📦 Response recibida correctamente');

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
      // Para categorías necesitaríamos añadir un endpoint en la configuración
      // Por ahora mantenemos la URL original
      final response = await _client
          .get(Uri.parse('$baseUrl/api/categorias'), headers: headers)
          .timeout(Duration(seconds: 10));

      print('📂 Response status: ${response.statusCode}');
      // Evitar loguear información sensible
      print('📂 Categorías recibidas correctamente');

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
      final response = await _client
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

  // Actualizar producto
  Future<Producto> updateProducto(Producto producto) async {
    try {
      final headers = await _getHeaders();
      final response = await _client
          .put(
            Uri.parse('$baseUrl/api/productos/${producto.id}'),
            headers: headers,
            body: json.encode(producto.toJson()),
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
      final response = await _client
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

      final response = await _client
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
      final response = await _client
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
      final response = await _client
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
      final response = await _client
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

          // Devolver la URL de datos
          return 'data:$mimeType;base64,$base64Image';
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

  // Obtener un producto por ID
  Future<Producto?> getProducto(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client
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
