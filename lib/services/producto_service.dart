import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../config/api_config.dart';
import '../utils/retry_strategy.dart';
import 'alertas_service.dart';

/// Flag para habilitar/deshabilitar logs detallados de productos
/// En producción web esto debe ser false para evitar spam en consola
const bool _enableProductLogs = kDebugMode;

/// Helper para imprimir solo en modo debug
void _logProducto(String message) {
  if (_enableProductLogs) {
      
  }
}

/// Clase para manejar el estado de paginación de productos
class ProductosPaginationState {
  int currentPage = 0;
  int pageSize =
      15; // Tamaño por defecto de 15 productos por página (ultra optimizado)
  int totalElements = 0;
  int totalPages = 0;
  bool hasMore = true;
  bool isLoading = false;
  List<Producto> productos = [];

  void reset() {
    currentPage = 0;
    totalElements = 0;
    totalPages = 0;
    hasMore = true;
    isLoading = false;
    productos.clear();
  }

  void updateFromResponse(Map<String, dynamic> data) {
    currentPage = data['page'] ?? currentPage;
    totalElements = data['totalElements'] ?? totalElements;
    totalPages = data['totalPages'] ?? totalPages;
    hasMore = (currentPage + 1) < totalPages;
  }
}

class ProductoService {
  static final ProductoService _instance = ProductoService._internal();
  factory ProductoService() => _instance;
  ProductoService._internal();

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();
  
  // 🔄 Estrategia de reintentos inteligente
  late final RetryStrategy _retryStrategy = RetryStrategyFactory.forEnvironment(
    baseUrl,
  );

  // Estado de paginación para carga progresiva
  final ProductosPaginationState _paginationState = ProductosPaginationState();
  
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
    // Headers simplificados para Flutter Web - evitar User-Agent unsafe headers
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (_enableProductLogs) {
             }
    
    return headers;
  }

  /// Obtiene el timeout apropiado basado en el entorno (Render es más lento)
  Duration _getTimeoutForEnvironment() {
    if (baseUrl.contains('render.com')) {
      // ⚡ OPTIMIZADO: Reducido de 5 min a 45 seg para evitar esperas largas
      return Duration(seconds: 45);
    } else if (baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1')) {
      // Desarrollo local debería ser rápido
      return Duration(seconds: 20);
    } else {
      // Otros servidores en producción
      return Duration(seconds: 40);
    }
  }

  /// Timeout más corto para intentos iniciales rápidos
  Duration _getFastTimeoutForEnvironment() {
    if (baseUrl.contains('render.com')) {
      // ⚡ OPTIMIZADO: Reducido de 90 seg a 15 seg para intentos rápidos
      return Duration(seconds: 15);
    } else if (baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1')) {
      return Duration(seconds: 10);
    } else {
      return Duration(seconds: 20);
    }
  }

  // Obtener todos los productos - Método principal optimizado
  Future<List<Producto>> getProductos({
    bool useProgressive = true,
    bool useLigero = true,
  }) async {
    // Si ya hay una petición en curso, volver la misma Future
    if (_inFlightGetProductos != null) return _inFlightGetProductos!;

    // ⚡ NUEVA OPTIMIZACIÓN: Usar endpoint ligero si está disponible
    if (useLigero && !useProgressive) {
      _inFlightGetProductos = _getProductosLigero();
    } else if (useProgressive) {
      // Si ya tenemos productos cargados progresivamente, devolverlos
      if (_paginationState.productos.isNotEmpty) {
        return productosActualmenteCargados;
      }

      // Cargar de forma progresiva automática
      _inFlightGetProductos = cargarTodosLosProductosProgresivamente(
        pageSize: 40,
      );
    } else {
      // Método tradicional (carga todo de una vez)
      _inFlightGetProductos = _doGetProductos();
    }
    
    try {
      final res = await _inFlightGetProductos!;
      return res;
    } finally {
      // Liberar el marcador para futuras llamadas
      _inFlightGetProductos = null;
    }
  }

  // Implementación simple y directa: usar /api/productos (findAll)
  Future<List<Producto>> _doGetProductos() async {
    final headers = await _getHeaders();
    final url = '$baseUrl/api/productos';

      
      

    try {
      // 🔄 Usar estrategia de reintentos con timeout adaptativo
      final response = await _retryStrategy.execute(
        operation: () => http.get(Uri.parse(url), headers: headers),
        timeoutPerAttempt: _getFastTimeoutForEnvironment(),
        shouldRetry: (error) {
          // Reintentar en timeouts y errores de red
          return error is TimeoutException ||
              error.toString().contains('SocketException') ||
              error.toString().contains('Connection');
        },
        onRetry: (attempt, delay) {
            
            
        },
      );

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
          
          

        if (responseData['success'] == true) {
          final data = responseData['data'];
            
            

          if (data is List) {
              
            final productos = data
                .map((json) => Producto.fromJson(json))
                .toList();

            // Actualizar caché
            for (var producto in productos) {
              _productosCache[producto.id] = producto;
            }
            return productos;
          } else {
            return [];
          }
        } else {
                         

          // Respaldo: intentar con endpoint paginado
          return await _getProductosConPaginacionRespaldo();
        }
      } else {
          
          

        // Respaldo: intentar con endpoint paginado
        return await _getProductosConPaginacionRespaldo();
      }
    } catch (e) {
        
        

      try {
        return await _getProductosConPaginacionRespaldo();
      } catch (backupError) {
          
        rethrow;
      }
    }
  }

  // Método de respaldo usando endpoint paginado
  Future<List<Producto>> _getProductosConPaginacionRespaldo() async {

    final headers = await _getHeaders();
    final url =
        '$baseUrl/api/productos?page=0&size=1000'; // Cargar muchos de una vez

      

    // 🔄 También usar reintentos en el método de respaldo
    final response = await _retryStrategy.execute(
      operation: () => http.get(Uri.parse(url), headers: headers),
      timeoutPerAttempt: _getFastTimeoutForEnvironment(),
      shouldRetry: (error) {
        return error is TimeoutException ||
            error.toString().contains('SocketException') ||
            error.toString().contains('Connection');
      },
    );

      

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);

      if (responseData['success'] == true) {
        final data = responseData['data'];
        final List<Producto> productos = (data['content'] as List)
            .map((json) => Producto.fromJsonLigero(json))
            .toList();

        // Actualizar caché
        for (var producto in productos) {
          _productosCache[producto.id] = producto;
        }

          
        return productos;
      } else {
        throw Exception(
          'Error en endpoint de respaldo: ${responseData['message']}',
        );
      }
    } else {
      throw Exception(
        'Error HTTP en respaldo ${response.statusCode}: ${response.reasonPhrase}',
      );
    }
  }

  // NUEVO: Método optimizado para carga progresiva usando api/productos directamente
  /// Inicia la carga progresiva de productos desde el principio
  /// [pageSize] determina cuántos productos cargar por página (10-15 recomendado para velocidad)
  Future<Map<String, dynamic>> iniciarCargaProgresiva({
    int pageSize =
        10, // ⚡ OPTIMIZADO: Reducido de 15 a 10 para cargas más rápidas
  }) async {
      

    // Resetear estado de paginación
    _paginationState.reset();
    _paginationState.pageSize = pageSize;

    return await cargarSiguientePaginaProductos();
  }

  /// Carga la siguiente página de productos
  Future<Map<String, dynamic>> cargarSiguientePaginaProductos() async {
    if (_paginationState.isLoading) {
        
      return {
        'productos': <Producto>[],
        'hasMore': _paginationState.hasMore,
        'totalCargados': _paginationState.productos.length,
        'totalElementos': _paginationState.totalElements,
        'paginaActual': _paginationState.currentPage,
        'isLoading': true,
      };
    }

    if (!_paginationState.hasMore) {
        
      return {
        'productos': <Producto>[],
        'hasMore': false,
        'totalCargados': _paginationState.productos.length,
        'totalElementos': _paginationState.totalElements,
        'paginaActual': _paginationState.currentPage,
        'isLoading': false,
      };
    }

    _paginationState.isLoading = true;

    try {
      final headers = await _getHeaders();
      // Usar endpoint LIGERO para evitar cargar imágenes y datos pesados
      final url =
          '$baseUrl/api/productos/ligero?page=${_paginationState.currentPage}&size=${_paginationState.pageSize}';

      _logProducto(
        '📄 Cargando página ${_paginationState.currentPage + 1} (${_paginationState.pageSize} productos) [LIGERO]',
      );
      _logProducto('🔗 URL: $url');

      // 🔄 Usar estrategia de reintentos para carga paginada
      final response = await _retryStrategy.execute(
        operation: () => http.get(Uri.parse(url), headers: headers),
        timeoutPerAttempt: _getFastTimeoutForEnvironment(),
        shouldRetry: (error) {
          return error is TimeoutException ||
              error.toString().contains('SocketException') ||
              error.toString().contains('Connection');
        },
        onRetry: (attempt, delay) {
          _logProducto(
            '🔄 Reintentando carga de página ${_paginationState.currentPage + 1}',
          );
        },
      );

      _logProducto('📦 Paginación - Response status: ${response.statusCode}');
      _logProducto(
        '📏 Paginación - Response body length: ${response.body.length}',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _logProducto(
          '🔍 Paginación - Response structure: ${responseData.keys.toList()}',
        );

        if (responseData['success'] == true) {
          final data = responseData['data'];
          _logProducto('📊 Paginación - Data structure: ${data.keys.toList()}');
          _logProducto(
            '📊 Paginación - Content length: ${(data['content'] as List).length}',
          );

          // Usar fromJsonLigero para mejor rendimiento
          final List<Producto> nuevosProductos = (data['content'] as List)
              .map((json) => Producto.fromJsonLigero(json))
              .toList();

          // Actualizar estado
          _paginationState.updateFromResponse(data);
          _paginationState.productos.addAll(nuevosProductos);
          _paginationState.currentPage++;

          // Actualizar caché
          for (var producto in nuevosProductos) {
            _productosCache[producto.id] = producto;
          }

          final progreso =
              '${_paginationState.productos.length}/${_paginationState.totalElements}';
          _logProducto('✅ Página cargada exitosamente. Progreso: $progreso');

          return {
            'productos': nuevosProductos,
            'hasMore': _paginationState.hasMore,
            'totalCargados': _paginationState.productos.length,
            'totalElementos': _paginationState.totalElements,
            'paginaActual': _paginationState.currentPage - 1,
            'isLoading': false,
          };
        } else {
          throw Exception('Error del servidor: ${responseData['message']}');
        }
      } else {
        throw Exception(
          'Error HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
        
      _paginationState.isLoading = false;
      rethrow;
    } finally {
      _paginationState.isLoading = false;
    }
  }

  /// Obtiene todos los productos cargados hasta el momento
  List<Producto> get productosActualmenteCargados =>
      List.from(_paginationState.productos);

  /// Obtiene información del estado actual de paginación
  Map<String, dynamic> get estadoPaginacion => {
    'totalCargados': _paginationState.productos.length,
    'totalElementos': _paginationState.totalElements,
    'paginaActual': _paginationState.currentPage,
    'totalPaginas': _paginationState.totalPages,
    'hasMore': _paginationState.hasMore,
    'isLoading': _paginationState.isLoading,
    'pageSize': _paginationState.pageSize,
  };

  /// Carga automática de todos los productos de forma progresiva
  /// Útil para cargar todos los productos en segundo plano
  Future<List<Producto>> cargarTodosLosProductosProgresivamente({
    int pageSize =
        20, // ⚡ OPTIMIZADO: Aumentado de 15 a 20 para menos peticiones
    Duration delayBetweenPages = const Duration(
      milliseconds: 300,
    ), // ⚡ OPTIMIZADO: Reducido de 800ms a 300ms
    Function(Map<String, dynamic>)? onProgressUpdate,
    int maxRetries = 2, // ⚡ OPTIMIZADO: Reducido de 3 a 2 reintentos
  }) async {
      

    // Intentar iniciar la carga progresiva con reintentos
    int retries = 0;
    while (retries < maxRetries) {
      try {
        await iniciarCargaProgresiva(pageSize: pageSize);
        break;
      } catch (e) {
        retries++;
        if (retries >= maxRetries) {
            
          rethrow;
        }
        // Esperar antes del siguiente intento
        await Future.delayed(Duration(seconds: retries * 2));
      }
    }

    while (_paginationState.hasMore) {
      retries = 0;
      Map<String, dynamic>? result;

      // Intentar cargar la siguiente página con reintentos
      while (retries < maxRetries) {
        try {
          result = await cargarSiguientePaginaProductos();
          break;
        } catch (e) {
          retries++;
          if (retries >= maxRetries) {
            // No hacer rethrow para continuar con otras páginas
            break;
          }
          // Esperar antes del siguiente intento, tiempo creciente
          await Future.delayed(Duration(seconds: retries * 3));
        }
      }

      // Si se obtuvo resultado, notificar progreso
      if (result != null && onProgressUpdate != null) {
        onProgressUpdate({
          ...result,
          'porcentaje':
              (_paginationState.productos.length /
                      _paginationState.totalElements *
                      100)
                  .round(),
        });
      }

      // Delay entre páginas para no sobrecargar el servidor
      if (_paginationState.hasMore && delayBetweenPages.inMilliseconds > 0) {
        await Future.delayed(delayBetweenPages);
      }

      // Si falló completamente esta página, salir del bucle
      if (result == null && retries >= maxRetries) {
          
        break;
      }
    }

    return productosActualmenteCargados;
  }

  /// Reinicia la carga progresiva (útil para refrescar datos)
  void reiniciarCargaProgresiva() {
    _paginationState.reset();
    _productosCache.clear();
      
  }

  /// Busca un producto en los datos ya cargados (cache local)
  Producto? buscarProductoEnCache(String productoId) {
    // Primero buscar en productos cargados progresivamente
    try {
      return _paginationState.productos.firstWhere((p) => p.id == productoId);
    } catch (e) {
      // Si no está en productos cargados, buscar en cache general
      return _productosCache[productoId];
    }
  }

  /// Filtra productos ya cargados localmente
  List<Producto> filtrarProductosCargados({
    String? searchQuery,
    String? categoriaId,
    bool? disponible,
  }) {
    var productos = _paginationState.productos;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      productos = productos
          .where(
            (p) =>
                p.nombre.toLowerCase().contains(query) ||
                (p.descripcion?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    if (categoriaId != null && categoriaId.isNotEmpty) {
      productos = productos
          .where((p) => p.categoria?.id == categoriaId)
          .toList();
    }

    if (disponible != null) {
      // Usar 'estado' para determinar disponibilidad
      final estadoRequerido = disponible ? 'Activo' : 'Inactivo';
      productos = productos.where((p) => p.estado == estadoRequerido).toList();
    }

    return productos;
  }

  // LEGACY: Método público para cargar productos con paginación flexible (mantenido por compatibilidad)
  Future<Map<String, dynamic>> getProductosPaginados({
    int page = 0,
    int size = 20,
  }) async {
    final headers = await _getHeaders();
    final url = '$baseUrl/api/productos?page=$page&size=$size';

      

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 300));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final data = responseData['data'];
          final List<Producto> productos = (data['content'] as List)
              .map((json) => Producto.fromJsonLigero(json))
              .toList();

          // Actualizar caché
          for (var producto in productos) {
            _productosCache[producto.id] = producto;
          }

            
             
          return {
            'productos': productos,
            'page': data['page'],
            'totalPages': data['totalPages'],
            'totalElements': data['totalElements'],
            'hasMore': (data['page'] + 1) < data['totalPages'],
          };
        } else {
          throw Exception('Error del servidor: ${responseData['message']}');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
        
      rethrow;
    }
  }

  // NUEVO: Endpoint paginado ultra-optimizado con cache del backend
  Future<List<Producto>> _getProductosPaginados() async {
    final headers = await _getHeaders();
    final url = '$baseUrl/api/productos/paginados?page=0&size=1000';

      
      
      
    int startTime = DateTime.now().millisecondsSinceEpoch;

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(
            Duration(seconds: 300),
          ); // Timeout generoso para carga inicial

        
        

      if (response.statusCode == 200) {
          
        final responseData = json.decode(response.body);

          

        if (responseData['success'] == true) {
          final data = responseData['data'];
            
            

          final productos = (data['content'] as List)
              .map((json) => Producto.fromJsonLigero(json))
              .toList();

          int endTime = DateTime.now().millisecondsSinceEpoch;

          // Actualizar caché
          for (var producto in productos) {
            _productosCache[producto.id] = producto;
          }

          return productos;
        } else {
            
          throw Exception(
            'Error en respuesta del servidor: ${responseData['message']}',
          );
        }
      } else {
          
        throw Exception(
          'Error HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
        
      rethrow;
    }
  }

  // ⚡ NUEVO: Endpoint ligero optimizado como primera opción
  Future<List<Producto>> _getProductosLigero() async {
    final headers = await _getHeaders();
    // ⚡ OPTIMIZADO: Cargar TODOS los productos con inventario (bodega y almacén)
    final url = '$baseUrl/api/productos?page=0&size=10000';

    try {
      final response = await _retryStrategy.execute(
        operation: () => http.get(Uri.parse(url), headers: headers),
        timeoutPerAttempt: _getFastTimeoutForEnvironment(),
        shouldRetry: (error) {
          return true;
        },
      );

        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // ⚡ Usar fromJsonLigero para NO cargar imágenes
        final productos = _parseListResponseLigero(responseData);

        // Actualizar cache
        for (var producto in productos) {
          _productosCache[producto.id] = producto;
        }

        return productos;
      } else {
        throw Exception('Error ${response.statusCode} en endpoint ligero');
      }
    } catch (e) {
        
        
      return await _getProductosBasico();
    }
  }

  // Endpoint básico como fallback - ULTRA LIGERO (solo campos esenciales)
  Future<List<Producto>> _getProductosBasico() async {
    final headers = await _getHeaders();
    // ⚡ OPTIMIZADO: Cargar TODOS los productos sin paginación
    final url = '$baseUrl/api/productos?page=0&size=10000';

      

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(Duration(seconds: 30)); // Endpoint ligero debería ser rápido

      

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
        

      // ⚡ Usar fromJsonLigero para NO cargar imágenes
      final productos = _parseListResponseLigero(responseData);

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
          
      }

      throw Exception(errorMessage);
    }
  }

  // Endpoint optimizado con nombres de ingredientes resueltos
  Future<List<Producto>> _getProductosConNombresIngredientes() async {
    final headers = await _getHeaders();
    final url = '$baseUrl/api/productos/con-nombres-ingredientes';

      

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(Duration(seconds: 300));

      

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
          
      }

      throw Exception(errorMessage);
    }
  }

  // Obtener todas las categorías
  Future<List<Categoria>> getCategorias() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/categorias'), headers: headers)
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

      // Response status: ${response.statusCode}
      // Response body: ${response.body}

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseCategoriaListResponse(responseData);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

      if (response.statusCode == 201) {
          
        return Producto.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

                 

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
        
      throw Exception('No se pudo crear el producto: $e');
    }
  }

  // Carga masiva de productos desde Excel
  Future<Map<String, dynamic>> cargaMasivaProductos(
    List<int> excelBytes, {
    required String tipo, // 'bodega' o 'almacen'
  }) async {
    try {
      final headers = await _getHeaders();
      // Remover Content-Type: application/json para multipart/form-data
      headers.remove('Content-Type');

      // Determinar el endpoint según el tipo
      final endpoint = tipo == 'bodega'
          ? '/carga-masiva'
          : '/carga-masiva-almacen';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/productos$endpoint'),
      );

      // Agregar headers de autenticación
      request.headers.addAll(headers);

      // Agregar el archivo Excel
      request.files.add(
        http.MultipartFile.fromBytes(
          'archivo', // Cambiar de 'file' a 'archivo' según el backend
          excelBytes,
          filename: 'productos_$tipo.xlsx',
        ),
      );

      print(
        '📤 Enviando archivo Excel al backend para carga masiva ($tipo)...',
      );

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 180),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Respuesta recibida: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Extraer datos según la estructura del backend
        final data = responseData['data'] ?? responseData;

        print('✅ Carga masiva ($tipo) completada');
        print('   Creados: ${data['productosCreados']}');
        print('   Actualizados: ${data['productosActualizados']}');
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
      print('❌ Error en carga masiva: $e');
      throw Exception('No se pudo procesar la carga masiva: $e');
    }
  }

  // Diagnóstico de columnas Excel
  Future<Map<String, dynamic>> diagnosticarExcel(List<int> excelBytes) async {
    try {
      final headers = await _getHeaders();
      headers.remove('Content-Type');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/productos/diagnostico-excel'),
      );

      request.headers.addAll(headers);

      request.files.add(
        http.MultipartFile.fromBytes(
          'archivo',
          excelBytes,
          filename: 'diagnostico.xlsx',
        ),
      );

      print('🔍 Enviando archivo Excel para diagnóstico...');

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final data = responseData['data'] ?? responseData;

        print('✅ Diagnóstico completado');
        print('   Total columnas: ${data['totalColumnas']}');
        print('   Total filas: ${data['totalFilas']}');
        print('   Columnas detectadas: ${data['columnasNormalizadas']}');

        return data;
      } else {
        throw Exception(
          'Error en diagnóstico: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error en diagnóstico: $e');
      throw Exception('No se pudo diagnosticar el archivo: $e');
    }
  }

  // Actualizar producto
  Future<Producto> updateProducto(Producto producto) async {
    try {
      // Verificar si la cantidad en bodega es baja y notificar por Telegram
      const int kStockBajoUmbral =
          10; // O importar desde constants.dart si ya está
      if (producto.bodega != null && producto.bodega! <= kStockBajoUmbral) {
        // Puedes personalizar los datos de contacto aquí
        final alertasService = AlertasService();
        final mensaje =
            '⚠️ Alerta: El producto "${producto.nombre}" tiene stock bajo en bodega (${producto.bodega}).';
        // Notificación por Telegram
        alertasService.sendTelegramMessage(mensaje);
        // Si quieres usar WhatsApp/email, puedes llamar enviarAlertaStock también:
        // alertasService.enviarAlertaStock(
        //   whatsapp: '573001112233',
        //   email: 'alertas@tucorreo.com',
        //   producto: producto.nombre,
        //   stockActual: producto.bodega!,
        //   stockMinimo: kStockBajoUmbral,
        // );
      }
      // ✅ Validar que el producto tenga un ID válido
      if (producto.id.isEmpty) {
        throw Exception('No se puede actualizar un producto sin ID');
      }
      
      final headers = await _getHeaders();

      // Crear un payload minimalista con solo los campos esenciales
      final Map<String, dynamic> productoJson = {
        'nombre': producto.nombre,
        'precio': producto.precio,
        'costo': producto.costo,
        'estado': producto.estado,
        'descripcion': producto.descripcion,
        'codigo': producto.codigo,
        'codigoBarras': producto.codigoBarras,
        'marca': producto.marca,
        'localizacion': producto.localizacion,
        'controlInventario': producto.controlInventario,
        'inventarioBajo': producto.inventarioBajo,
        'inventarioOptimo': producto.inventarioOptimo,
      };
      
      // Agregar campos opcionales solo si no son null
      if (producto.categoria?.id != null) {
        productoJson['categoriaId'] = producto.categoria!.id;
      }
      if (producto.imagenUrl != null) {
        productoJson['imagenUrl'] = producto.imagenUrl;
      }
      if (producto.impuestos != null && producto.impuestos! > 0) {
        productoJson['impuestos'] = producto.impuestos;
      }
      if (producto.porcentajeImpuesto != null) {
        productoJson['porcentajeImpuesto'] = producto.porcentajeImpuesto;
      }
      if (producto.nombreProveedor != null) {
        productoJson['nombreProveedor'] = producto.nombreProveedor;
      }
      if (producto.nitProveedor != null) {
        productoJson['nitProveedor'] = producto.nitProveedor;
      }
      // ✅ ENVIAR CON LOS NOMBRES CORRECTOS QUE EL BACKEND ESPERA
      if (producto.almacen != null) {
        productoJson['cantidadAlmacen'] =
            producto.almacen; // ✅ Correcto: cantidadAlmacen
      }
      if (producto.bodega != null) {
        productoJson['cantidadBodega'] =
            producto.bodega; // ✅ Correcto: cantidadBodega
      }

      // 🔍 LOG: Ver exactamente qué se envía al backend
      print('📤 PUT /api/productos/${producto.id}');
      print('   - cantidadAlmacen enviado: ${productoJson['cantidadAlmacen']}');
      print('   - cantidadBodega enviado: ${productoJson['cantidadBodega']}');

      final response = await http
          .put(
            Uri.parse('$baseUrl/api/productos/${producto.id}'),
            headers: headers,
            body: json.encode(productoJson),
          )
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

      // 🔍 LOG: Ver respuesta del backend
      print('   - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
          
        final responseBody = json.decode(response.body);

        // 🛠️ WORKAROUND: Si el backend devuelve null, usar los valores enviados
        if (responseBody['cantidadAlmacen'] == null &&
            producto.almacen != null) {
          responseBody['cantidadAlmacen'] = producto.almacen;
        }
        if (responseBody['cantidadBodega'] == null && producto.bodega != null) {
          responseBody['cantidadBodega'] = producto.bodega;
        }

        final productoActualizado = Producto.fromJson(responseBody);

        // ✅ CRÍTICO: Actualizar el cache con los valores corregidos
        _productoByIdCache[producto.id] = productoActualizado;

        return productoActualizado;
      } else {
        throw Exception(
          'Error del servidor: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
        
      throw Exception('No se pudo actualizar el producto: $e');
    }
  }

  // 💰 Actualizar solo el costo del producto (último precio de compra)
  Future<void> actualizarCostoProducto(
    String productoId,
    double nuevoCosto,
  ) async {
    // ✅ Validar que el ID no esté vacío
    if (productoId.isEmpty) {
      print('⚠️ No se puede actualizar costo: ID de producto vacío');
      return;
    }
    
    try {
      final headers = await _getHeaders();

      // 📦 Usar PUT normal con solo el campo costo
      // El backend actualizará solo los campos enviados
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/productos/$productoId'),
            headers: headers,
            body: json.encode({'costo': nuevoCosto}),
          )
          .timeout(Duration(seconds: 300));

      if (response.statusCode != 200 && response.statusCode != 204) {
        print('⚠️ Error al actualizar costo: ${response.statusCode}');
      } else {
        print('✅ Costo actualizado para producto $productoId: \$$nuevoCosto');
      }
    } catch (e) {
      // No lanzar excepción para no interrumpir el flujo de la compra
      print('⚠️ No se pudo actualizar costo (no crítico): $e');
    }
  }

  // Eliminar producto
  Future<void> deleteProducto(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/api/productos/$id'), headers: headers)
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

      if (response.statusCode == 200 || response.statusCode == 204) {
          
        return;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

      if (response.statusCode == 201) {
          
        return Categoria.fromJson(json.decode(response.body));
      } else {
          
          
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

      if (response.statusCode == 200) {
          
        return Categoria.fromJson(json.decode(response.body));
      } else {
          
          
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
      throw Exception('No se pudo actualizar la categoría: $e');
    }
  }

  // Eliminar categoría
  Future<void> deleteCategoria(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/api/categorias/$id'), headers: headers)
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

      if (response.statusCode == 200) {
          
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

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
        //   
        return jsonList.map((json) => Producto.fromJson(json)).toList();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
      throw Exception('No se pudieron buscar los productos: $e');
    }
  }

  // 🆕 Buscar UN producto por código de barras (endpoint específico)
  Future<Producto?> getProductoPorCodigoBarras(String codigoBarras) async {
    try {
        
      final headers = await _getHeaders();

      final url = '$baseUrl/api/productos/codigo-barras/$codigoBarras';
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 10));

        

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);

        // Manejar formato ApiResponse
        if (jsonBody is Map<String, dynamic>) {
          if (jsonBody.containsKey('success') && jsonBody['success'] == true) {
            final data = jsonBody['data'];
            if (data != null) {
                
              return Producto.fromJson(data);
            }
          }
          // Si no tiene success, intentar parsear directamente
          else if (jsonBody.containsKey('nombre')) {
            return Producto.fromJson(jsonBody);
          }
        }

          
        return null;
      } else if (response.statusCode == 404) {
          
        return null;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
      return null;
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

      if (response.statusCode == 200) {
        // Extraer los datos del campo 'data' de la respuesta ApiResponse
        final jsonBody = json.decode(response.body);
        if (!jsonBody['success']) {
          throw Exception(
            jsonBody['message'] ?? 'Error en la respuesta del servidor',
          );
        }

        final List<dynamic> jsonList = jsonBody['data'];
          
        return jsonList.map((json) => Producto.fromJson(json)).toList();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
      throw Exception('No se pudieron obtener los productos por categoría: $e');
    }
  }

  // Subir imagen y guardar como base64 en la base de datos
  Future<String> uploadProductImage(XFile image) async {
    try {
        
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
          .timeout(Duration(seconds: 300));

      if (response.statusCode == 200) {
        // Parsear la respuesta para verificar que se guardó correctamente
        final jsonData = json.decode(response.body);
        // Retornar la data URL para uso inmediato
        return dataUrl;
      } else {
          
        // Fallback: retornar data URL directamente
        return dataUrl;
      }
    } catch (e) {
        

      // Fallback: crear data URL local
      try {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        final mimeType = _getMimeTypeFromFileName(image.name);
        final dataUrl = 'data:$mimeType;base64,$base64Image';

          
        return dataUrl;
      } catch (fallbackError) {
          
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
              

            // Intentar subir la imagen al servidor
            // Este método es opcional y depende de si tu backend soporta subida de imágenes
            try {
              // Podrías implementar una subida de imagen aquí
              // final uploadedUrl = await _uploadImageToServer(bytes, mimeType);
              // if (uploadedUrl != null) return uploadedUrl;
            } catch (uploadError) {
                             }

            return dataUrl;
          } catch (webError) {
              
            return null;
          }
        } else {
          // En dispositivos móviles, devolvemos la ruta del archivo
          return image.path;
        }
      }
      return null;
    } catch (e) {
        
      return null;
    }
  }

  // Obtener solo el nombre de un producto por ID
  // Obtener solo el nombre de un producto por ID
  Future<String?> getProductoNombre(String id) async {
    // Primero intentar obtener desde caché
    if (_productoByIdCache.containsKey(id) && _productoByIdCache[id] != null) {
      return _productoByIdCache[id]!.nombre;
    }

    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/productos/$id/nombre'), headers: headers)
          .timeout(Duration(seconds: 300));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('nombre')) {
            return responseData['nombre'];
          } else if (responseData.containsKey('data') &&
              responseData['data'] != null &&
              responseData['data']['nombre'] != null) {
            return responseData['data']['nombre'];
          }
        }
      }

      // Si no se puede obtener el nombre, devolver un valor por defecto
      return 'Producto #$id';
    } catch (e) {
        
      return 'Producto #$id';
    }
  }

  // Obtener un producto por ID con nombres de ingredientes resueltos (OPTIMIZADO)
  Future<Producto?> getProducto(String? id) async {
    // Validar que el ID no sea nulo o vacío
    if (id == null || id.trim().isEmpty) {
        
      return null;
    }

    // Devolver desde cache si ya existe (incluye cache negativo: null)
    if (_productoByIdCache.containsKey(id)) {
      final cached = _productoByIdCache[id];
      return cached;
    }

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
    // �️ VALIDACIÓN: Detectar y corregir IDs malformados (seguridad)
    if (id.contains('_') && id.length > 24) {
        
      // Intentar extraer el ID original (antes del primer _)
      final partes = id.split('_');
      if (partes.isNotEmpty && partes[0].length == 24) {
        final idOriginal = partes[0];
          
        return _doGetProducto(idOriginal); // Recursión con ID limpio
      }
    }

    try {
      final headers = await _getHeaders();

      // Intentar con endpoint optimizado primero
      final url = '$baseUrl/api/productos/$id/con-nombres-ingredientes';
        

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 300));

        
      if (response.statusCode == 200) {
          
        final responseData = json.decode(response.body);
          
        if (responseData is Map<String, dynamic>) {
          Map<String, dynamic> productoData;
            
          if (responseData.containsKey('data')) {
            productoData = responseData['data'];
          } else {
            productoData = responseData;
          }

          // 🛠️ WORKAROUND CRÍTICO: Si cantidadAlmacen/Bodega son null, loggear advertencia
          // MongoDB tiene los valores correctos, pero backend los serializa como null
          if (productoData['cantidadAlmacen'] == null ||
              productoData['cantidadBodega'] == null) {
            // Por ahora, confiar en el cache. Si no hay cache, usar 0
            productoData['cantidadAlmacen'] ??= 0;
            productoData['cantidadBodega'] ??= 0;
          }
            
          return Producto.fromJson(productoData);
        }
      } else if (response.statusCode == 404) {
        return await _getProductoBasico(id);
      }

      throw Exception('Error del servidor: ${response.statusCode}');
    } catch (e) {
        
      // Fallback al endpoint básico
      return await _getProductoBasico(id);
    }
  }

  // Obtener un producto por ID (endpoint básico como fallback)
  Future<Producto?> _getProductoBasico(String? id) async {
    // Validar que el ID no sea nulo o vacío
    if (id == null || id.trim().isEmpty) {
        
      return null;
    }

    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/api/productos/$id';
        

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 300));

        
      if (response.statusCode == 200) {
          
        final responseData = json.decode(response.body);
          
        if (responseData is Map<String, dynamic>) {
          Map<String, dynamic> productoData;
            
          // Si la respuesta está envuelta en una estructura data
          if (responseData.containsKey('data')) {
            productoData = responseData['data'];
          } else {
            // Si la respuesta es directamente el producto
            productoData = responseData;
          }

          // 🛠️ WORKAROUND: Aplicar el mismo fix para cantidadAlmacen/Bodega null
          if (productoData['cantidadAlmacen'] == null ||
              productoData['cantidadBodega'] == null) {
            productoData['cantidadAlmacen'] ??= 0;
            productoData['cantidadBodega'] ??= 0;
          }
            
          return Producto.fromJson(productoData);
        }
      } else if (response.statusCode == 404) {
        return null;
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } catch (e) {
        
      return null;
    }
  }

  // Método auxiliar para parsear respuestas de lista de productos
  List<Producto> _parseListResponse(dynamic responseData) {
      

    if (responseData is Map<String, dynamic>) {
        

      // Buscar posibles propiedades que contengan la lista de productos
      if (responseData.containsKey('productos')) {
        final productos = responseData['productos'];
        if (productos is List) {
          return productos
              .map<Producto>((json) => Producto.fromJson(json))
              .toList();
        }
      }

      if (responseData.containsKey('data')) {
        final data = responseData['data'];
                   if (data is List) {
          return data.map<Producto>((json) => Producto.fromJson(json)).toList();
        }
        
        // ⚡ NUEVO: Si data es un Map, buscar lista dentro (paginación)
        if (data is Map<String, dynamic>) {
          // Buscar en "content" (formato paginado)
          if (data.containsKey('content') && data['content'] is List) {
            return (data['content'] as List)
                .map<Producto>((json) => Producto.fromJson(json))
                .toList();
          }
          // Buscar en "productos"
          if (data.containsKey('productos') && data['productos'] is List) {
            return (data['productos'] as List)
                .map<Producto>((json) => Producto.fromJson(json))
                .toList();
          }
          // Buscar en "items"
          if (data.containsKey('items') && data['items'] is List) {
            return (data['items'] as List)
                .map<Producto>((json) => Producto.fromJson(json))
                .toList();
          }
        }
      }

      if (responseData.containsKey('results')) {
        final results = responseData['results'];
        if (results is List) {
          return results
              .map<Producto>((json) => Producto.fromJson(json))
              .toList();
        }
      }

        
        
      throw Exception('No se encontró una lista de productos en la respuesta');
    } else if (responseData is List) {
      return responseData
          .map<Producto>((json) => Producto.fromJson(json))
          .toList();
    }

      
    throw Exception(
      'Formato de respuesta no válido: esperado Map o List, recibido ${responseData.runtimeType}',
    );
  }

  // ⚡ NUEVO: Método auxiliar para parsear productos LIGEROS (sin imágenes)
  List<Producto> _parseListResponseLigero(dynamic responseData) {
    print('🔍 _parseListResponseLigero: Analizando respuesta...');

    if (responseData is Map<String, dynamic>) {
      print('   - Respuesta es Map con keys: ${responseData.keys.toList()}');

      // Buscar posibles propiedades que contengan la lista de productos
      if (responseData.containsKey('productos')) {
        final productos = responseData['productos'];
        if (productos is List) {
          // 🔍 LOG: Ver campos del primer producto
          if (productos.isNotEmpty) {
            final primerProducto = productos[0] as Map<String, dynamic>;
            print('   - Primer producto keys: ${primerProducto.keys.toList()}');
            print(
              '   - Tiene cantidadAlmacen: ${primerProducto.containsKey('cantidadAlmacen')}',
            );
            print(
              '   - Tiene cantidadBodega: ${primerProducto.containsKey('cantidadBodega')}',
            );
            print(
              '   - cantidadAlmacen value: ${primerProducto['cantidadAlmacen']}',
            );
            print(
              '   - cantidadBodega value: ${primerProducto['cantidadBodega']}',
            );
          }
          return productos
              .map<Producto>((json) => Producto.fromJsonLigero(json))
              .toList();
        }
      }

      if (responseData.containsKey('data')) {
        final data = responseData['data'];
        if (data is List) {
          // 🔍 LOG: Ver campos del primer producto
          if (data.isNotEmpty) {
            final primerProducto = data[0] as Map<String, dynamic>;
            print('   - Primer producto keys: ${primerProducto.keys.toList()}');
            print(
              '   - Tiene cantidadAlmacen: ${primerProducto.containsKey('cantidadAlmacen')}',
            );
            print(
              '   - Tiene cantidadBodega: ${primerProducto.containsKey('cantidadBodega')}',
            );
          }
          return data
              .map<Producto>((json) => Producto.fromJsonLigero(json))
              .toList();
        }

        // Si data es un Map, buscar lista dentro (paginación)
        if (data is Map<String, dynamic>) {
          // Buscar en "content" (formato paginado)
          if (data.containsKey('content') && data['content'] is List) {
            final content = data['content'] as List;
            return content
                .map<Producto>((json) => Producto.fromJsonLigero(json))
                .toList();
          }
          // Buscar en "productos"
          if (data.containsKey('productos') && data['productos'] is List) {
            final productos = data['productos'] as List;
            return productos
                .map<Producto>((json) => Producto.fromJsonLigero(json))
                .toList();
          }
          // Buscar en "items"
          if (data.containsKey('items') && data['items'] is List) {
            final items = data['items'] as List;
            return items
                .map<Producto>((json) => Producto.fromJsonLigero(json))
                .toList();
          }
        }
      }

      if (responseData.containsKey('results')) {
        final results = responseData['results'];
        if (results is List) {
          return results
              .map<Producto>((json) => Producto.fromJsonLigero(json))
              .toList();
        }
      }

        
      throw Exception('No se encontró una lista de productos en la respuesta');
    } else if (responseData is List) {
      return responseData
          .map<Producto>((json) => Producto.fromJsonLigero(json))
          .toList();
    }

    throw Exception('Formato de respuesta no válido');
  }

  // 🖼️ NUEVO: Cargar imágenes de productos específicos (lazy loading)
  /// Carga las imágenes de un lote de productos (máximo 20 por request)
  /// Retorna un Map con productoId -> imagenUrl
  // ⚠️ DEPRECADO: Este endpoint batch tiene problemas de tipos
  // Usar cargarImagenProducto() individual en su lugar
  @Deprecated('Usar cargarImagenProducto() para cada producto individualmente')
  Future<Map<String, String>> cargarImagenesProductos(
    List<String> productosIds,
  ) async {
      
    return {};
    
    // CÓDIGO COMENTADO: Endpoint POST /api/productos/imagenes tiene problemas
    // if (productosIds.isEmpty) {
    //     
    //   return {};
    // }
    //
    // final idsLimitados = productosIds.take(20).toList();
    //   
    //
    // try {
    //   final headers = await _getHeaders();
    //   final url = '$baseUrl/api/productos/imagenes';
    //
    //   final response = await http
    //       .post(
    //         Uri.parse(url),
    //         headers: headers,
    //         body: json.encode(idsLimitados),
    //       )
    //       .timeout(Duration(seconds: 20));
    //
    //   if (response.statusCode == 200) {
    //     final responseData = json.decode(response.body);
    //
    //     if (responseData['success'] == true && responseData['data'] != null) {
    //       final Map<String, String> imagenes = Map<String, String>.from(
    //         responseData['data'] as Map,
    //       );
    //
    //         
    //
    //       imagenes.forEach((id, imagenUrl) {
    //         if (_productosCache.containsKey(id)) {
    //           _productosCache[id] = _productosCache[id]!.copyWith(
    //             imagenUrl: imagenUrl,
    //           );
    //         }
    //       });
    //
    //       return imagenes;
    //     }
    //   }
    //
    //     
    //   return {};
    // } catch (e) {
    //     
    //   return {};
    // }
  }

  // 🖼️ NUEVO: Cargar imagen de un solo producto (lazy loading individual)
  Future<String?> cargarImagenProducto(String productoId) async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/api/productos/$productoId/imagen';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          final tieneImagen = data['tieneImagen'] == true;
          
          if (tieneImagen && data['imagenUrl'] != null) {
            final imagenBase64 = data['imagenUrl'] as String;

            // Actualizar cache
            if (_productosCache.containsKey(productoId)) {
              _productosCache[productoId] = _productosCache[productoId]!
                  .copyWith(imagenUrl: imagenBase64);
            }

            return imagenBase64;
          }
        }
      }

      return null;
    } catch (e) {
        
      return null;
    }
  }

  // Eliminar caché (útil para wake-up / recarga completa)
  void clearCache() {
    _productosCache.clear();
    _productoByIdCache.clear();
    _inFlightGetProductoById.clear();
    _inFlightGetProductos = null;
      
  }

  // Método de diagnóstico para verificar el estado del servicio
  void diagnosticar() {
      
      
      
      
      
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

                 
        

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

        for (int i = 0; i < ingredientesJson.length; i++) {
            
        }

        List<IngredienteProducto> ingredientesBasicos = ingredientesJson.map((
          json,
        ) {
            
          final ingrediente = IngredienteProducto.fromJson(json);
          return ingrediente;
        }).toList();

        // Con el nuevo endpoint, los nombres ya deberían venir resueltos, pero mantenemos el fallback
        if (ingredientesBasicos.any(
          (ing) =>
              ing.ingredienteNombre.isEmpty ||
              ing.ingredienteNombre == ing.ingredienteId,
        )) {
          return await _enriquecerIngredientesConNombres(ingredientesBasicos);
        }

        return ingredientesBasicos;
      } else if (response.statusCode == 404) {
          
        return await _getIngredientesRequeridosComboBasico(productoId);
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } catch (e) {
        
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

                 
        

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

        for (int i = 0; i < ingredientesJson.length; i++) {
            
        }

        List<IngredienteProducto> ingredientesBasicos = ingredientesJson.map((
          json,
        ) {
            
          final ingrediente = IngredienteProducto.fromJson(json);
          return ingrediente;
        }).toList();

        // Enriquecer con nombres de ingredientes si están vacíos
        return await _enriquecerIngredientesConNombres(ingredientesBasicos);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

                 
        

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

        for (int i = 0; i < ingredientesJson.length; i++) {
            
        }

        List<IngredienteProducto> ingredientesBasicos = ingredientesJson.map((
          json,
        ) {
            
          final ingrediente = IngredienteProducto.fromJson(json);
          return ingrediente;
        }).toList();

        // Con el nuevo endpoint, los nombres ya deberían venir resueltos, pero mantenemos el fallback
        if (ingredientesBasicos.any(
          (ing) =>
              ing.ingredienteNombre.isEmpty ||
              ing.ingredienteNombre == ing.ingredienteId,
        )) {
          return await _enriquecerIngredientesConNombres(ingredientesBasicos);
        }

        return ingredientesBasicos;
      } else if (response.statusCode == 404) {
          
        return await _getIngredientesOpcionalesComboBasico(productoId);
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } catch (e) {
        
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

                 
        

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

        for (int i = 0; i < ingredientesJson.length; i++) {
            
        }

        List<IngredienteProducto> ingredientesBasicos = ingredientesJson.map((
          json,
        ) {
            
          final ingrediente = IngredienteProducto.fromJson(json);
          return ingrediente;
        }).toList();

        // Enriquecer con nombres de ingredientes si están vacíos
        return await _enriquecerIngredientesConNombres(ingredientesBasicos);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
        
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

        
        

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
          

        List<IngredienteProducto> ingredientesRequeridos = [];
        List<IngredienteProducto> ingredientesOpcionales = [];

        // Cargar ingredientes requeridos
        try {
          ingredientesRequeridos = await getIngredientesRequeridosCombo(
            producto.id,
          );
        } catch (e) {
            
        }

        // Cargar ingredientes opcionales
        try {
          ingredientesOpcionales = await getIngredientesOpcionalesCombo(
            producto.id,
          );
        } catch (e) {
            
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
         
      // Si el ingrediente ya tiene nombre válido (no es un ID), no necesita enriquecimiento
      if (ingrediente.ingredienteNombre.isNotEmpty &&
          !ingrediente.ingredienteNombre.startsWith('689') &&
          ingrediente.ingredienteNombre != ingrediente.ingredienteId) {
        ingredientesEnriquecidos.add(ingrediente);
        continue;
      }

         
      // Si solo tenemos el ID, cargar los datos completos del ingrediente
      if (ingrediente.ingredienteId.isNotEmpty) {
        try {
             
          final headers = await _getHeaders();
          final response = await http
              .get(
                Uri.parse(
                  '$baseUrl/api/ingredientes/${ingrediente.ingredienteId}',
                ),
                headers: headers,
              )
              .timeout(
                Duration(seconds: 300),
              ); // Timeout aumentado para Railway

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
               
            Map<String, dynamic> ingredienteJson;

            if (responseData is Map<String, dynamic>) {
              if (responseData.containsKey('data')) {
                ingredienteJson = responseData['data'];
                  
              } else {
                ingredienteJson = responseData;
                  
              }
            } else {
              throw Exception('Formato de respuesta inesperado');
            }

            String nombreIngrediente =
                ingredienteJson['nombre']?.toString() ??
                'Ingrediente ${ingrediente.ingredienteId}';

               
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
            ingredientesEnriquecidos.add(ingrediente);
          }
        } catch (e) {
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

  /// ⚡ OPTIMIZADO PARA TRASLADOS: Carga solo productos necesarios sin imágenes
  /// Usado por TrasladosScreen para carga ultra-rápida
  Future<List<Producto>> obtenerProductosParaTraslados() async {
    final headers = await _getHeaders();
    // 🚀 Endpoint ligero sin imágenes - ideal para listas
    final url = '$baseUrl/api/productos/ligero?page=0&size=10000';

    print('🔍 Llamando endpoint: $url');

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 20));

      print('   - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponseLigero(responseData);
      } else {
        return await _getProductosBasico();
      }
    } catch (e) {
      // Fallback a básico
      return await _getProductosBasico();
    }
  }
}
