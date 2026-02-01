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

/// Flag para habilitar/deshabilitar logs detallados de productos
/// En producción web esto debe ser false para evitar spam en consola
const bool _enableProductLogs = kDebugMode;

/// Helper para imprimir solo en modo debug
void _logProducto(String message) {
  if (_enableProductLogs) {
    print(message);
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

    if (_enableProductLogs) print('🔧 Headers para request: $headers');
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
        print(
          '✅ Devolviendo ${_paginationState.productos.length} productos ya cargados progresivamente',
        );
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

    print('🔍 Cargando TODOS los productos desde /api/productos (findAll)');
    print('🔄 Usando estrategia de reintentos inteligente...');

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
          print('🔄 Reintentando carga de productos (intento $attempt)...');
          print('⏳ Esperando ${delay.inSeconds}s antes del siguiente intento');
        },
      );

      print('📦 Response status: ${response.statusCode}');
      print('📏 Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('🔍 Response structure keys: ${responseData.keys.toList()}');
        print('🔍 Success field: ${responseData['success']}');

        if (responseData['success'] == true) {
          final data = responseData['data'];
          print('📊 Data type: ${data.runtimeType}');
          print('📊 Data is List: ${data is List}');

          if (data is List) {
            print('📊 Data length: ${data.length}');
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
          print(
            '❌ Respuesta del servidor con success=false: ${responseData['message']}',
          );
          print('🔄 Intentando con endpoint de paginación como respaldo...');

          // Respaldo: intentar con endpoint paginado
          return await _getProductosConPaginacionRespaldo();
        }
      } else {
        print('❌ Error HTTP ${response.statusCode}: ${response.reasonPhrase}');
        print('🔄 Intentando con endpoint de paginación como respaldo...');

        // Respaldo: intentar con endpoint paginado
        return await _getProductosConPaginacionRespaldo();
      }
    } catch (e) {
      print('❌ Error cargando productos: $e');
      print('🔄 Intentando con endpoint de paginación como respaldo...');

      try {
        return await _getProductosConPaginacionRespaldo();
      } catch (backupError) {
        print('❌ Error también en endpoint de respaldo: $backupError');
        rethrow;
      }
    }
  }

  // Método de respaldo usando endpoint paginado
  Future<List<Producto>> _getProductosConPaginacionRespaldo() async {

    final headers = await _getHeaders();
    final url =
        '$baseUrl/api/productos?page=0&size=1000'; // Cargar muchos de una vez

    print('🔗 URL de respaldo: $url');

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

    print('📦 Respaldo - Response status: ${response.statusCode}');

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

        print('✅ RESPALDO exitoso: ${productos.length} productos cargados');
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
    print('🚀 Iniciando carga progresiva con tamaño de página: $pageSize');

    // Resetear estado de paginación
    _paginationState.reset();
    _paginationState.pageSize = pageSize;

    return await cargarSiguientePaginaProductos();
  }

  /// Carga la siguiente página de productos
  Future<Map<String, dynamic>> cargarSiguientePaginaProductos() async {
    if (_paginationState.isLoading) {
      print('⏳ Ya hay una carga en proceso, esperando...');
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
      print('✋ No hay más productos para cargar');
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
      print('❌ Error cargando página ${_paginationState.currentPage}: $e');
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
    print('🔄 Iniciando carga automática completa de productos...');

    // Intentar iniciar la carga progresiva con reintentos
    int retries = 0;
    while (retries < maxRetries) {
      try {
        await iniciarCargaProgresiva(pageSize: pageSize);
        break;
      } catch (e) {
        retries++;
        print(
          '❌ Error iniciando carga progresiva (intento $retries/$maxRetries): $e',
        );
        if (retries >= maxRetries) {
          print('💥 Falló inicialización después de $maxRetries intentos');
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
          print(
            '❌ Error cargando página ${_paginationState.currentPage + 1} (intento $retries/$maxRetries): $e',
          );
          if (retries >= maxRetries) {
            print(
              '💥 Falló página después de $maxRetries intentos, continuando con siguientes páginas...',
            );
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
        print('⚠️ Terminando carga progresiva por errores repetidos');
        break;
      }
    }

    print(
      '✅ Carga automática completa: ${_paginationState.productos.length} productos cargados',
    );
    return productosActualmenteCargados;
  }

  /// Reinicia la carga progresiva (útil para refrescar datos)
  void reiniciarCargaProgresiva() {
    _paginationState.reset();
    _productosCache.clear();
    print('🔄 Estado de carga progresiva reiniciado');
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

    print('🚀 Cargando página $page con tamaño $size');

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

          print('✅ Página ${data['page'] + 1}/${data['totalPages']} cargada');
          print(
            '📦 Productos: ${productos.length} de ${data['totalElements']} totales',
          );

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
      print('💥 Error en paginación: $e');
      rethrow;
    }
  }

  // NUEVO: Endpoint paginado ultra-optimizado con cache del backend
  Future<List<Producto>> _getProductosPaginados() async {
    final headers = await _getHeaders();
    final url = '$baseUrl/api/productos/paginados?page=0&size=1000';

    print('🚀 ENDPOINT PAGINADO ULTRA-OPTIMIZADO');
    print('🔗 URL: $url');
    print('🔧 Headers: $headers');
    int startTime = DateTime.now().millisecondsSinceEpoch;

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(
            Duration(seconds: 300),
          ); // Timeout generoso para carga inicial

      print('📊 Response status: ${response.statusCode}');
      print('📏 Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        print('✅ Response exitoso, parseando JSON...');
        final responseData = json.decode(response.body);

        print('🔍 Response structure: ${responseData.keys.toList()}');

        if (responseData['success'] == true) {
          final data = responseData['data'];
          print('📦 Data structure: ${data.keys.toList()}');
          print('📊 Content length: ${(data['content'] as List).length}');

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
          print('❌ Response success = false: ${responseData['message']}');
          throw Exception(
            'Error en respuesta del servidor: ${responseData['message']}',
          );
        }
      } else {
        print('❌ HTTP Error ${response.statusCode}: ${response.body}');
        throw Exception(
          'Error HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('💥 Excepción en _getProductosPaginados: $e');
      rethrow;
    }
  }

  // ⚡ NUEVO: Endpoint ligero optimizado como primera opción
  Future<List<Producto>> _getProductosLigero() async {
    final headers = await _getHeaders();
    // ⚡ OPTIMIZADO: Cargar TODOS los productos de una vez (sin paginación)
    final url = '$baseUrl/api/productos/ligero?page=0&size=10000';

    try {
      final response = await _retryStrategy.execute(
        operation: () => http.get(Uri.parse(url), headers: headers),
        timeoutPerAttempt: _getFastTimeoutForEnvironment(),
        shouldRetry: (error) {
          return true;
        },
      );

      print('📦 Response status (ligero): ${response.statusCode}');

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
      print('❌ Error con endpoint ligero: $e');
      print('🔄 Fallback a método básico...');
      return await _getProductosBasico();
    }
  }

  // Endpoint básico como fallback - ULTRA LIGERO (solo campos esenciales)
  Future<List<Producto>> _getProductosBasico() async {
    final headers = await _getHeaders();
    // ⚡ OPTIMIZADO: Cargar TODOS los productos sin paginación
    final url = '$baseUrl/api/productos/ligero?page=0&size=10000';

    print('📦 Intentando endpoint /ligero ultra-optimizado (TODOS): $url');

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(Duration(seconds: 30)); // Endpoint ligero debería ser rápido

    print('📦 Response status (/search): ${response.statusCode}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      print('📦 Response data type: ${responseData.runtimeType}');

      // ⚡ Usar fromJsonLigero para NO cargar imágenes
      final productos = _parseListResponseLigero(responseData);

      // Guardar en caché
      for (var producto in productos) {
        _productosCache[producto.id] = producto;
      }

      print('✅ Productos cargados con endpoint básico: ${productos.length}');
      return productos;
    } else {
      // Intenta analizar el mensaje de error
      String errorMessage = 'Error del servidor: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        if (errorData['message'] != null) {
          errorMessage = errorData['message'];
        }
        print('📦 Error response body: ${response.body}');
      } catch (e) {
        print('📦 No se pudo parsear error response: $e');
      }

      throw Exception(errorMessage);
    }
  }

  // Endpoint optimizado con nombres de ingredientes resueltos
  Future<List<Producto>> _getProductosConNombresIngredientes() async {
    final headers = await _getHeaders();
    final url = '$baseUrl/api/productos/con-nombres-ingredientes';

    print('🚀 Intentando endpoint optimizado: $url');

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(Duration(seconds: 300));

    print('🚀 Response status (optimizado): ${response.statusCode}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      print('🚀 Response data type: ${responseData.runtimeType}');

      final productos = _parseListResponse(responseData);

      // Guardar en caché
      for (var producto in productos) {
        _productosCache[producto.id] = producto;
      }

      print(
        '✅ Productos cargados con endpoint optimizado: ${productos.length}',
      );
      return productos;
    } else {
      // Intenta analizar el mensaje de error
      String errorMessage = 'Error del servidor: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        if (errorData['message'] != null) {
          errorMessage = errorData['message'];
        }
        print('🚀 Error response body: ${response.body}');
      } catch (e) {
        print('🚀 No se pudo parsear error response: $e');
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Render

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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

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

  // 🆕 Buscar UN producto por código de barras (endpoint específico)
  Future<Producto?> getProductoPorCodigoBarras(String codigoBarras) async {
    try {
      print('🔍 Buscando producto por código de barras: "$codigoBarras"');
      final headers = await _getHeaders();

      final url = '$baseUrl/api/productos/codigo-barras/$codigoBarras';
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);

        // Manejar formato ApiResponse
        if (jsonBody is Map<String, dynamic>) {
          if (jsonBody.containsKey('success') && jsonBody['success'] == true) {
            final data = jsonBody['data'];
            if (data != null) {
              print('✅ Producto encontrado por código de barras');
              return Producto.fromJson(data);
            }
          }
          // Si no tiene success, intentar parsear directamente
          else if (jsonBody.containsKey('nombre')) {
            return Producto.fromJson(jsonBody);
          }
        }

        print('⚠️ Formato de respuesta inesperado');
        return null;
      } else if (response.statusCode == 404) {
        print('⚠️ Producto no encontrado con código: "$codigoBarras"');
        return null;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error buscando por código de barras: $e');
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
          .timeout(Duration(seconds: 300));

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
    if (_productoByIdCache.containsKey(id)) {
      final cached = _productoByIdCache[id];
      print(
        '💾 [CACHE] HIT para ID "$id" - ${cached != null ? "PRODUCTO" : "NULL"}',
      );
      return cached;
    }

    // Si ya hay una petición en curso para este id, reutilizarla
    if (_inFlightGetProductoById.containsKey(id)) {
      print('⏳ [IN-FLIGHT] Esperando petición existente para ID "$id"');
      return await _inFlightGetProductoById[id];
    }

    print('🔄 [REQUEST] Nueva petición para ID "$id"');
    final future = _doGetProducto(id);
    _inFlightGetProductoById[id] = future;
    try {
      final res = await future;
      // Cachear el resultado (puede ser null si 404)
      _productoByIdCache[id] = res;
      print(
        '💾 [CACHE] SET para ID "$id" - ${res != null ? "PRODUCTO" : "NULL"}',
      );
      return res;
    } finally {
      _inFlightGetProductoById.remove(id);
    }
  }

  // Implementación real de la carga de producto por id
  Future<Producto?> _doGetProducto(String id) async {
    // �️ VALIDACIÓN: Detectar y corregir IDs malformados (seguridad)
    if (id.contains('_') && id.length > 24) {
      print('🚨 [ERROR] ID malformado detectado: "$id"');
      // Intentar extraer el ID original (antes del primer _)
      final partes = id.split('_');
      if (partes.isNotEmpty && partes[0].length == 24) {
        final idOriginal = partes[0];
        print('🔧 [FIX] Usando ID original: "$idOriginal"');
        return _doGetProducto(idOriginal); // Recursión con ID limpio
      }
    }

    try {
      final headers = await _getHeaders();

      // Intentar con endpoint optimizado primero
      final url = '$baseUrl/api/productos/$id/con-nombres-ingredientes';
      print('🌐 [HTTP] GET $url');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 300));

      print('📡 [HTTP] Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ [HTTP] Respuesta exitosa, parseando...');
        final responseData = json.decode(response.body);
        print('📦 [DATA] Tipo: ${responseData.runtimeType}');
        if (responseData is Map<String, dynamic>) {
          print('📦 [DATA] Keys: ${responseData.keys.toList()}');
          if (responseData.containsKey('data')) {
            print('📦 [DATA] Usando responseData["data"]');
            return Producto.fromJson(responseData['data']);
          }
          print('📦 [DATA] Usando responseData directamente');
          return Producto.fromJson(responseData);
        }
      } else if (response.statusCode == 404) {
        print(
          '⚠️ Endpoint optimizado no encontrado para producto $id, usando endpoint básico',
        );
        return await _getProductoBasico(id);
      }

      throw Exception('Error del servidor: ${response.statusCode}');
    } catch (e) {
      print('❌ Error con endpoint optimizado para producto $id: $e');
      // Fallback al endpoint básico
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
      final url = '$baseUrl/api/productos/$id';
      print('🌐 [HTTP-BASIC] GET $url');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 300));

      print('📡 [HTTP-BASIC] Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ [HTTP-BASIC] Respuesta exitosa, parseando...');
        final responseData = json.decode(response.body);
        print('📦 [DATA-BASIC] Tipo: ${responseData.runtimeType}');
        if (responseData is Map<String, dynamic>) {
          print('📦 [DATA-BASIC] Keys: ${responseData.keys.toList()}');
          // Si la respuesta está envuelta en una estructura data
          if (responseData.containsKey('data')) {
            print('📦 [DATA-BASIC] Usando responseData["data"]');
            return Producto.fromJson(responseData['data']);
          }
          // Si la respuesta es directamente el producto
          print('📦 [DATA-BASIC] Usando responseData directamente');
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
    print('📦 Parseando respuesta - Tipo: ${responseData.runtimeType}');

    if (responseData is Map<String, dynamic>) {
      print('📦 Respuesta es Map - Keys: ${responseData.keys.toList()}');

      // Buscar posibles propiedades que contengan la lista de productos
      if (responseData.containsKey('productos')) {
        final productos = responseData['productos'];
        print(
          '📦 Encontrados productos en key "productos": ${productos is List ? productos.length : 'No es lista'}',
        );
        if (productos is List) {
          return productos
              .map<Producto>((json) => Producto.fromJson(json))
              .toList();
        }
      }

      if (responseData.containsKey('data')) {
        final data = responseData['data'];
        print(
          '📦 Encontrados datos en key "data": ${data is List ? data.length : 'No es lista'}',
        );
        if (data is List) {
          return data.map<Producto>((json) => Producto.fromJson(json)).toList();
        }
        
        // ⚡ NUEVO: Si data es un Map, buscar lista dentro (paginación)
        if (data is Map<String, dynamic>) {
          // Buscar en "content" (formato paginado)
          if (data.containsKey('content') && data['content'] is List) {
            print(
              '📦 Encontrada lista en data.content: ${(data['content'] as List).length} productos',
            );
            return (data['content'] as List)
                .map<Producto>((json) => Producto.fromJson(json))
                .toList();
          }
          // Buscar en "productos"
          if (data.containsKey('productos') && data['productos'] is List) {
            print(
              '📦 Encontrada lista en data.productos: ${(data['productos'] as List).length} productos',
            );
            return (data['productos'] as List)
                .map<Producto>((json) => Producto.fromJson(json))
                .toList();
          }
          // Buscar en "items"
          if (data.containsKey('items') && data['items'] is List) {
            print(
              '📦 Encontrada lista en data.items: ${(data['items'] as List).length} productos',
            );
            return (data['items'] as List)
                .map<Producto>((json) => Producto.fromJson(json))
                .toList();
          }
          print(
            '⚠️ data es Map pero no contiene lista reconocible. Keys: ${data.keys.toList()}',
          );
        }
      }

      if (responseData.containsKey('results')) {
        final results = responseData['results'];
        print(
          '📦 Encontrados resultados en key "results": ${results is List ? results.length : 'No es lista'}',
        );
        if (results is List) {
          return results
              .map<Producto>((json) => Producto.fromJson(json))
              .toList();
        }
      }

      print('❌ No se encontró una lista de productos en la respuesta');
      print('📦 Keys disponibles: ${responseData.keys.toList()}');
      throw Exception('No se encontró una lista de productos en la respuesta');
    } else if (responseData is List) {
      print(
        '📦 Respuesta es List directamente con ${responseData.length} elementos',
      );
      return responseData
          .map<Producto>((json) => Producto.fromJson(json))
          .toList();
    }

    print('❌ Formato de respuesta no válido: ${responseData.runtimeType}');
    throw Exception(
      'Formato de respuesta no válido: esperado Map o List, recibido ${responseData.runtimeType}',
    );
  }

  // ⚡ NUEVO: Método auxiliar para parsear productos LIGEROS (sin imágenes)
  List<Producto> _parseListResponseLigero(dynamic responseData) {
    print('📦 Parseando respuesta LIGERA - Tipo: ${responseData.runtimeType}');

    if (responseData is Map<String, dynamic>) {
      print('📦 Respuesta es Map - Keys: ${responseData.keys.toList()}');

      // Buscar posibles propiedades que contengan la lista de productos
      if (responseData.containsKey('productos')) {
        final productos = responseData['productos'];
        if (productos is List) {
          print(
            '📦 Encontrados ${productos.length} productos en key "productos" (SIN IMÁGENES)',
          );
          // 🔍 LOG TEMPORAL: Ver campos del primer producto
          if (productos.isNotEmpty) {
            print(
              '🔍 PRIMER PRODUCTO JSON KEYS: ${(productos[0] as Map).keys.toList()}',
            );
            print('🔍 PRIMER PRODUCTO JSON: ${productos[0]}');
          }
          return productos
              .map<Producto>((json) => Producto.fromJsonLigero(json))
              .toList();
        }
      }

      if (responseData.containsKey('data')) {
        final data = responseData['data'];
        if (data is List) {
          print(
            '📦 Encontrados ${data.length} productos en data (SIN IMÁGENES)',
          );
          // 🔍 LOG TEMPORAL: Ver campos del primer producto
          if (data.isNotEmpty) {
            print(
              '🔍 PRIMER PRODUCTO JSON KEYS: ${(data[0] as Map).keys.toList()}',
            );
            print('🔍 PRIMER PRODUCTO JSON: ${data[0]}');
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
            print(
              '📦 Encontrados ${content.length} productos en data.content (SIN IMÁGENES)',
            );
            return content
                .map<Producto>((json) => Producto.fromJsonLigero(json))
                .toList();
          }
          // Buscar en "productos"
          if (data.containsKey('productos') && data['productos'] is List) {
            final productos = data['productos'] as List;
            print(
              '📦 Encontrados ${productos.length} productos en data.productos (SIN IMÁGENES)',
            );
            return productos
                .map<Producto>((json) => Producto.fromJsonLigero(json))
                .toList();
          }
          // Buscar en "items"
          if (data.containsKey('items') && data['items'] is List) {
            final items = data['items'] as List;
            print(
              '📦 Encontrados ${items.length} productos en data.items (SIN IMÁGENES)',
            );
            return items
                .map<Producto>((json) => Producto.fromJsonLigero(json))
                .toList();
          }
        }
      }

      if (responseData.containsKey('results')) {
        final results = responseData['results'];
        if (results is List) {
          print(
            '📦 Encontrados ${results.length} productos en results (SIN IMÁGENES)',
          );
          return results
              .map<Producto>((json) => Producto.fromJsonLigero(json))
              .toList();
        }
      }

      print('❌ No se encontró una lista de productos en la respuesta');
      throw Exception('No se encontró una lista de productos en la respuesta');
    } else if (responseData is List) {
      print(
        '📦 Respuesta es List con ${responseData.length} productos (SIN IMÁGENES)',
      );
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
    print('⚠️ Endpoint batch deprecado - usar lazy loading individual');
    return {};
    
    // CÓDIGO COMENTADO: Endpoint POST /api/productos/imagenes tiene problemas
    // if (productosIds.isEmpty) {
    //   print('⚠️ Lista de IDs vacía, no se cargan imágenes');
    //   return {};
    // }
    //
    // final idsLimitados = productosIds.take(20).toList();
    // print('🖼️ Cargando imágenes de ${idsLimitados.length} productos...');
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
    //       print('✅ ${imagenes.length} imágenes cargadas exitosamente');
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
    //   print('❌ Error ${response.statusCode} cargando imágenes');
    //   return {};
    // } catch (e) {
    //   print('❌ Error cargando imágenes: $e');
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
      print('❌ Error cargando imagen: $e');
      return null;
    }
  }

  // Eliminar caché (útil para wake-up / recarga completa)
  void clearCache() {
    _productosCache.clear();
    _productoByIdCache.clear();
    _inFlightGetProductoById.clear();
    _inFlightGetProductos = null;
    print('🧹 ProductoService: Caché completo limpiado');
  }

  // Método de diagnóstico para verificar el estado del servicio
  void diagnosticar() {
    print('🔍 DIAGNÓSTICO ProductoService:');
    print('   - Base URL: $baseUrl');
    print('   - Productos en caché: ${_productosCache.length}');
    print('   - Productos por ID en caché: ${_productoByIdCache.length}');
    print('   - Petición en curso: ${_inFlightGetProductos != null}');
    print(
      '   - Peticiones por ID en curso: ${_inFlightGetProductoById.length}',
    );
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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

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
          .timeout(Duration(seconds: 300)); // Timeout aumentado para Railway

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
              .timeout(
                Duration(seconds: 300),
              ); // Timeout aumentado para Railway

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
