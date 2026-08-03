import 'dart:async';
import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/ingrediente.dart';
import '../services/producto_service.dart';
import '../services/traslado_websocket_service.dart';
import '../config/constants.dart';
import '../utils/logger.dart';

class DatosCacheProvider extends ChangeNotifier {
  static final DatosCacheProvider _instance = DatosCacheProvider._internal();
  factory DatosCacheProvider() => _instance;
  DatosCacheProvider._internal();

  // Datos en caché
  List<Producto>? _productos;
  List<Categoria>? _categorias;

  // Estados de carga
  bool _isLoadingProductos = false;
  bool _isLoadingCategorias = false;

  // ✅ NUEVA ESTRATEGIA: Cache con timestamp y auto-refresh
  DateTime? _ultimaCargaProductos;
  DateTime? _ultimaCargaCategorias;

  // Configuración de caché (en minutos)
  final int _duracionCacheProductos =
      10; // ⚡ OPTIMIZADO: Aumentado a 10 min (menos recargas)
  final int _duracionCacheCategorias =
      30; // ⚡ OPTIMIZADO: Aumentado a 30 min (rara vez cambian)

  // Polling automático
  Timer? _pollingTimer;
  bool _enablePolling = true;
  // Alineado con _duracionCacheProductos (10 min) para no disparar timers en vano
  final int _pollingIntervalMinutes = 12;

  // Servicios
  final ProductoService _productoService = ProductoService();
  final TrasladoWebSocketService _wsService = TrasladoWebSocketService();

  // Getters
  List<Producto>? get productos => _productos;
  List<Categoria>? get categorias => _categorias;
  
  // TODO: Ingredientes - Lista vacía temporal para compatibilidad
  // Eliminar cuando se quite la funcionalidad de ingredientes
  List<Ingrediente> get ingredientes => [];

  bool get isLoadingProductos => _isLoadingProductos;
  bool get isLoadingCategorias => _isLoadingCategorias;

  bool get hasData =>
      _productos != null && _categorias != null;

  // ✅ NUEVOS GETTERS: Estado del caché
  bool get productosExpired =>
      _ultimaCargaProductos == null ||
      DateTime.now().difference(_ultimaCargaProductos!).inMinutes >
          _duracionCacheProductos;

  bool get categoriasExpired =>
      _ultimaCargaCategorias == null ||
      DateTime.now().difference(_ultimaCargaCategorias!).inMinutes >
          _duracionCacheCategorias;

  DateTime? get ultimaActualizacion {
    if (_ultimaCargaProductos == null) return null;
    return _ultimaCargaProductos;
  }

  // Inicializar el provider
  Future<void> initialize() async {
    // Las categorías se cargarán bajo demanda cuando se necesiten
    // await _cargarCategorias(force: false, silent: false);
    _startPolling(); // ✅ Iniciar polling automático
  }

  /// Conecta al WebSocket (canal /rt/traslados, reutilizado — ver
  /// TrasladoWebSocketService/ProductoRealtimeService en el backend) para
  /// enterarse al instante cuando un producto se crea, se edita o le cambia
  /// el stock (compra, venta, traslado), en vez de esperar hasta 10-12 min
  /// al siguiente refresh del caché o depender de que alguien recargue a
  /// mano. El polling periódico sigue activo como respaldo — si el
  /// WebSocket se cae, la reconexión automática lo retoma solo.
  void iniciarEscuchaTiempoReal() {
    _wsService.connect(
      baseUrl: kDynamicBackendUrl,
      onEvent: (data) {
        switch (data['tipo']) {
          case 'PRODUCTOS_ACTUALIZADOS':
            final lista = data['productos'] as List<dynamic>? ?? [];
            for (final json in lista) {
              try {
                _upsertProductoEnCache(
                  Producto.fromJson(json as Map<String, dynamic>),
                );
              } catch (e) {
                appLog('⚠️ Error parseando producto de PRODUCTOS_ACTUALIZADOS: $e');
              }
            }
            break;
          case 'PRODUCTOS_ELIMINADOS':
            final ids = data['productoIds'] as List<dynamic>? ?? [];
            for (final id in ids) {
              eliminarProductoDelCache(id.toString());
            }
            break;
          case 'PRODUCTOS_CAMBIO_MASIVO':
            // Carga masiva (ej. importación de Excel): en vez de parchear
            // cache por cache, se recarga todo una sola vez.
            forceRefreshProductos();
            break;
        }
      },
    );
  }

  void detenerEscuchaTiempoReal() {
    _wsService.disconnect();
  }

  /// Inserta el producto si no estaba en caché, o lo reemplaza si ya
  /// existía — a diferencia de agregarProductoAlCache/actualizarProductoEnCache
  /// por separado, no asume de antemano si es nuevo o no.
  void _upsertProductoEnCache(Producto producto) {
    if (_productos == null || producto.id.isEmpty) return;
    final index = _productos!.indexWhere((p) => p.id == producto.id);
    if (index >= 0) {
      _productos![index] = producto;
    } else {
      _productos!.insert(0, producto);
    }
    notifyListeners();
  }

  // 🔥 WARMUP: Precargar productos en background SIN IMÁGENES
  // No fuerza recarga si el caché es fresco — evita llamadas duplicadas en login
  void warmupProductos() {
    if (!productosExpired && _productos != null) return;
    _cargarProductos(
      force: false,
      silent: false,
      useProgressive: false,
      useLigero: true,
    );
  }

  // Cargar todos los datos en paralelo
  Future<void> _cargarTodosLosDatos({
    bool force = false,
    bool silent = false,
  }) async {
       
    try {
      await Future.wait([
        _cargarProductos(force: force, silent: silent),
        _cargarCategorias(force: force, silent: silent),
      ]);

                 
        
    } catch (e) {
        
    }
  }

  // ✅ NUEVO: Polling automático para sincronización
  void _startPolling() {
    if (!_enablePolling) return;

    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(Duration(minutes: _pollingIntervalMinutes), (
      timer,
    ) async {
      // Si el flag de carga lleva más de un ciclo de polling atascado, es un
      // cuelgue (tab estuvo suspendido y el Future nunca resolvió). Resetear.
      if (_isLoadingProductos) {
        _isLoadingProductos = false;
        notifyListeners();
      }

      if (productosExpired) {
        await _cargarProductos(silent: true);
      }
    });
  }

  // ✅ NUEVO: Métodos públicos para control de caché
  Future<void> forceRefresh() async {
      
    await _cargarTodosLosDatos(force: true);
  }

  Future<void> forceRefreshProductos() async {
      
    await _cargarProductos(force: true);
  }

  void enableAutoRefresh() {
    _enablePolling = true;
    _startPolling();
      
  }

  void disableAutoRefresh() {
    _enablePolling = false;
    _pollingTimer?.cancel();
      
  }

  // Cargar productos (con cache inteligente)
  Future<void> _cargarProductos({
    bool force = false,
    bool silent = false,
    bool useProgressive = false,
    bool useLigero = true,
  }) async {
    if (!force && !productosExpired && _productos != null) {
      return;
    }

    // Guard: si lleva más de 60s cargando, probablemente está colgado — resetear.
    if (_isLoadingProductos) return;

    _isLoadingProductos = true;
    // ✅ MEJORADO: Solo notificar si no es silencioso
    if (!silent) notifyListeners();

    try {
      if (useProgressive) {
      } else {
      }
      
      final productos = await _productoService.getProductos(
        useProgressive: useProgressive,
        useLigero: useLigero,
      );
      _productos = productos;
      _ultimaCargaProductos = DateTime.now();

      if (productos.isEmpty) {
      } else {
  
      }
    } catch (e) {
        
        

      try {
        // Respaldo: intentar método tradicional
        final productos = await _productoService.getProductos(
          useProgressive: false,
        );
        _productos = productos;
        _ultimaCargaProductos = DateTime.now();

      } catch (backupError) {
        // Mantener productos existentes en caso de error total

      }
    } finally {
      _isLoadingProductos = false;
      // ✅ MEJORADO: Solo notificar si no es silencioso
      if (!silent) notifyListeners();
    }
  }

  // Cargar categorías (con cache inteligente)
  Future<void> _cargarCategorias({
    bool force = false,
    bool silent = false,
  }) async {
    // ✅ NUEVO: Verificar si necesita actualización
    if (!force && !categoriasExpired && _categorias != null) {
        
      return;
    }

    if (_isLoadingCategorias) return;

    _isLoadingCategorias = true;
    // ✅ MEJORADO: Solo notificar si no es silencioso
    if (!silent) notifyListeners();

    try {
      final categorias = await _productoService.getCategorias();
      _categorias = categorias;
      _ultimaCargaCategorias = DateTime.now(); // ✅ NUEVO: Actualizar timestamp
    } catch (e) {
        
    } finally {
      _isLoadingCategorias = false;
      // ✅ MEJORADO: Solo notificar si no es silencioso
      if (!silent) notifyListeners();
    }
  }

  // Recargar datos manualmente
  Future<void> recargarDatos() async {
      
    await _cargarTodosLosDatos(
      force: true,
    ); // ✅ MEJORADO: Siempre forzar en recarga manual
  }

  // Limpiar caché
  void limpiarCache() {
      
    _productos = null;
    _categorias = null;
    _ultimaCargaProductos = null;
    _ultimaCargaCategorias = null;
    notifyListeners();
  }

  /// Invalidar solo del caché de productos (para refetch rápido después de crear/editar)
  void limpiarProductos() {
    _productos = null;
    _ultimaCargaProductos = null;
    notifyListeners();
  }

  /// Agregar un nuevo producto al cache existente (sin refetch!)
  void agregarProductoAlCache(Producto nuevoProducto) {
    if (_productos != null) {
      // Agregar al inicio de la lista
      _productos!.insert(0, nuevoProducto);
      notifyListeners();
    }
  }

  /// Actualizar un producto específico en el cache (sin refetch!)
  void actualizarProductoEnCache(Producto productoActualizado) {
    if (_productos != null && productoActualizado.id != null) {
      final index = _productos!.indexWhere(
        (p) => p.id == productoActualizado.id,
      );
      if (index >= 0) {
        _productos![index] = productoActualizado;
        notifyListeners();
        appLog('✅ Producto actualizado en caché: ${productoActualizado.nombre}');
      } else {
        appLog(
          '⚠️ Producto no encontrado en caché para actualizar: ${productoActualizado.id}',
        );
      }
    }
  }

  /// Eliminar un producto específico del cache (sin refetch!)
  void eliminarProductoDelCache(String productoId) {
    if (_productos != null && productoId.isNotEmpty) {
      final index = _productos!.indexWhere((p) => p.id == productoId);
      if (index >= 0) {
        final nombreProducto = _productos![index].nombre;
        _productos!.removeAt(index);
        notifyListeners();
        appLog('✅ Producto eliminado del caché: $nombreProducto');
      } else {
        appLog('⚠️ Producto no encontrado en caché para eliminar: $productoId');
      }
    }
  }

  /// ⚡ ULTRA RÁPIDO: Carga inicial optimizada (solo productos sin imágenes)
  Future<void> initializeRapido() async {
    _isLoadingProductos = true;
    notifyListeners();

    try {
      // Cargar solo productos sin imágenes (10x más rápido)
      final productos = await _productoService.obtenerProductosParaTraslados();
      _productos = productos;
      _ultimaCargaProductos = DateTime.now();

      // Categorías se cargan en background si es necesario
      _cargarCategorias(silent: true);
      _startPolling();
    } catch (e) {
    } finally {
      _isLoadingProductos = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _wsService.disconnect();
    super.dispose();
  }
}
