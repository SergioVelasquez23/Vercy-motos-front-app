import 'dart:async';
import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/ingrediente.dart';
import '../services/producto_service.dart';

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
  final int _pollingIntervalMinutes = 3; // Polling cada 3 minutos

  // Servicios
  final ProductoService _productoService = ProductoService();

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
    print('🚀 Inicializando DatosCacheProvider...');
    // Las categorías se cargarán bajo demanda cuando se necesiten
    // await _cargarCategorias(force: false, silent: false);
    _startPolling(); // ✅ Iniciar polling automático
  }

  // 🔥 WARMUP: Precargar productos en background SIN IMÁGENES
  void warmupProductos() {
    print('🔥 WARMUP: Carga ULTRA RÁPIDA de productos (SIN imágenes)...');
    print('⚡ Endpoint: GET /api/productos/ligero?page=0&size=40');
    print('⏳ Tiempo estimado: 5-15 segundos');
    print(
      '📝 Las imágenes se cargarán individualmente al mostrarse (lazy loading)',
    );
    // Cargar productos en background sin esperar - USAR ENDPOINT LIGERO
    _cargarProductos(
      force: true,
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
    print(
      '📊 Cargando datos ${force ? 'forzados' : 'en caché'}${silent ? ' (silencioso)' : ''}...',
    );

    try {
      await Future.wait([
        _cargarProductos(force: force, silent: silent),
        _cargarCategorias(force: force, silent: silent),
      ]);

      print(
        '✅ Todos los datos cargados exitosamente${silent ? ' (silencioso)' : ''}',
      );
      print('   - Productos: ${_productos?.length ?? 0}');
      print('   - Categorías: ${_categorias?.length ?? 0}');
    } catch (e) {
      print('❌ Error cargando datos: $e');
    }
  }

  // ✅ NUEVO: Polling automático para sincronización
  void _startPolling() {
    if (!_enablePolling) return;

    _pollingTimer?.cancel();

    print(
      '🔄 Iniciando polling automático cada $_pollingIntervalMinutes minutos',
    );

    _pollingTimer = Timer.periodic(Duration(minutes: _pollingIntervalMinutes), (
      timer,
    ) async {
      print('🔄 Ejecutando polling automático...');

      // Solo recargar productos si expiraron (SILENCIOSO para no interrumpir UI)
      if (productosExpired) {
        await _cargarProductos(silent: true);
      }
      // Categorías deshabilitadas - no se usan en esta app
      // if (categoriasExpired) {
      //   await _cargarCategorias(silent: true);
      // }
    });
  }

  // ✅ NUEVO: Métodos públicos para control de caché
  Future<void> forceRefresh() async {
    print('🔄 Forzando actualización completa de datos...');
    await _cargarTodosLosDatos(force: true);
  }

  Future<void> forceRefreshProductos() async {
    print('🔄 Forzando actualización de productos...');
    await _cargarProductos(force: true);
  }

  void enableAutoRefresh() {
    _enablePolling = true;
    _startPolling();
    print('✅ Auto-refresh habilitado');
  }

  void disableAutoRefresh() {
    _enablePolling = false;
    _pollingTimer?.cancel();
    print('⏸️ Auto-refresh deshabilitado');
  }

  // Cargar productos (con cache inteligente)
  Future<void> _cargarProductos({
    bool force = false,
    bool silent = false,
    bool useProgressive =
        false, // ⚡ OPTIMIZADO: Por defecto NO usar progresiva (más lento)
    bool useLigero =
        true, // ⚡ NUEVO: Por defecto usar endpoint ligero (más rápido)
  }) async {
    // ✅ NUEVO: Verificar si necesita actualización
    if (!force && !productosExpired && _productos != null) {
      print('📦 Productos en caché válidos, usando caché local');
      return;
    }

    if (_isLoadingProductos) return;

    _isLoadingProductos = true;
    // ✅ MEJORADO: Solo notificar si no es silencioso
    if (!silent) notifyListeners();

    try {
      if (useProgressive) {
        print('🚀 Usando carga progresiva de productos...');
      } else {
        print('⚡ Usando endpoint LIGERO para carga rápida...');
      }
      
      final productos = await _productoService.getProductos(
        useProgressive: useProgressive,
        useLigero: useLigero,
      );
      _productos = productos;
      _ultimaCargaProductos = DateTime.now();

      if (productos.isEmpty) {
        print('⚠️ ALERTA: Se cargaron 0 productos desde el servidor');
        print('🔍 Verificar conectividad y endpoints del backend');
      } else {
        print(
          '📦 Productos cargados: ${productos.length} (${force ? 'forzado' : 'caché expirado'}) ${silent ? '(silencioso)' : ''}',
        );
      }
    } catch (e) {
      print('❌ Error cargando productos con método progresivo: $e');
      print('🔄 Intentando método tradicional como respaldo...');

      try {
        // Respaldo: intentar método tradicional
        final productos = await _productoService.getProductos(
          useProgressive: false,
        );
        _productos = productos;
        _ultimaCargaProductos = DateTime.now();

        print(
          '✅ Productos cargados con método tradicional: ${productos.length}',
        );
      } catch (backupError) {
        print('❌ Error también en método tradicional: $backupError');
        // Mantener productos existentes en caso de error total
        print(
          '🔄 Manteniendo productos existentes en caché: ${_productos?.length ?? 0}',
        );
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
      print('🏷️ Categorías en caché válidas, usando caché local');
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
      print(
        '🏷️ Categorías cargadas: ${categorias.length} (${force ? 'forzado' : 'caché expirado'}) ${silent ? '(silencioso)' : ''}',
      );
    } catch (e) {
      print('❌ Error cargando categorías: $e');
    } finally {
      _isLoadingCategorias = false;
      // ✅ MEJORADO: Solo notificar si no es silencioso
      if (!silent) notifyListeners();
    }
  }

  // Recargar datos manualmente
  Future<void> recargarDatos() async {
    print('🔄 Recarga manual solicitada...');
    await _cargarTodosLosDatos(
      force: true,
    ); // ✅ MEJORADO: Siempre forzar en recarga manual
  }

  // Limpiar caché
  void limpiarCache() {
    print('🗑️ Limpiando caché...');
    _productos = null;
    _categorias = null;
    _ultimaCargaProductos = null;
    _ultimaCargaCategorias = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
