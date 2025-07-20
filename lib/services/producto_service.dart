import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/producto.dart';
import '../models/categoria.dart';

class ProductoService {
  static final ProductoService _instance = ProductoService._internal();
  factory ProductoService() => _instance;
  ProductoService._internal();

  final String baseUrl = 'http://127.0.0.1:8081/api';
  final storage = FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();

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
      final response = await http
          .get(Uri.parse('$baseUrl/productos'), headers: headers)
          .timeout(Duration(seconds: 10));

      print('📦 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

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
          .get(Uri.parse('$baseUrl/categorias'), headers: headers)
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
            Uri.parse('$baseUrl/productos'),
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
      final response = await http
          .put(
            Uri.parse('$baseUrl/productos/${producto.id}'),
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
      final response = await http
          .delete(Uri.parse('$baseUrl/productos/$id'), headers: headers)
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
      final response = await http
          .post(
            Uri.parse('$baseUrl/categorias'),
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
      final response = await http
          .put(
            Uri.parse('$baseUrl/categorias/${categoria.id}'),
            headers: headers,
            body: json.encode(categoria.toJson()),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Categoría actualizada exitosamente');
        return Categoria.fromJson(json.decode(response.body));
      } else {
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
          .delete(Uri.parse('$baseUrl/categorias/$id'), headers: headers)
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
        '$baseUrl/productos/buscar',
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
            Uri.parse('$baseUrl/productos?categoriaId=$categoriaId'),
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
        Uri.parse('$baseUrl/productos/upload-image'),
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

  // Método para seleccionar imagen (método faltante)
  Future<String?> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        return image.path;
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
      final response = await http
          .get(Uri.parse('$baseUrl/productos/$id'), headers: headers)
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
