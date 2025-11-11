import 'dart:async';
import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/ingrediente.dart';
import '../services/producto_service.dart';
import '../services/ingrediente_service.dart';

class DatosCacheProvider extends ChangeNotifier {
  static final DatosCacheProvider _instance = DatosCacheProvider._internal();
  factory DatosCacheProvider() => _instance;
  DatosCacheProvider._internal();

  // Datos en caché
  List<Producto>? _productos;
  List<Categoria>? _categorias;
  List<Ingrediente>? _ingredientes;

  // Estados de carga
  bool _isLoadingProductos = false;
  bool _isLoadingCategorias = false;
  bool _isLoadingIngredientes = false;

  // ✅ NUEVA ESTRATEGIA: Cache con timestamp y auto-refresh
  DateTime? _ultimaCargaProductos;
  DateTime? _ultimaCargaCategorias;
  DateTime? _ultimaCargaIngredientes;

  // Configuración de caché (en minutos)
  final int _duracionCacheProductos = 5; // 5 minutos para productos
  final int _duracionCacheCategorias = 15; // 15 minutos para categorías
  final int _duracionCacheIngredientes = 10; // 10 minutos para ingredientes

  // Polling automático
  Timer? _pollingTimer;
  bool _enablePolling = true;
  final int _pollingIntervalMinutes = 3; // Polling cada 3 minutos

  // Servicios
  final ProductoService _productoService = ProductoService();
  final IngredienteService _ingredienteService = IngredienteService();

  // Getters
  List<Producto>? get productos => _productos;
  List<Categoria>? get categorias => _categorias;
  List<Ingrediente>? get ingredientes => _ingredientes;

  bool get isLoadingProductos => _isLoadingProductos;
  bool get isLoadingCategorias => _isLoadingCategorias;
  bool get isLoadingIngredientes => _isLoadingIngredientes;

  bool get hasData =>
      _productos != null && _categorias != null && _ingredientes != null;

  // ✅ NUEVOS GETTERS: Estado del caché
  bool get productosExpired =>
      _ultimaCargaProductos == null ||
      DateTime.now().difference(_ultimaCargaProductos!).inMinutes >
          _duracionCacheProductos;

  bool get categoriasExpired =>
      _ultimaCargaCategorias == null ||
      DateTime.now().difference(_ultimaCargaCategorias!).inMinutes >
          _duracionCacheCategorias;

  bool get ingredientesExpired =>
      _ultimaCargaIngredientes == null ||
      DateTime.now().difference(_ultimaCargaIngredientes!).inMinutes >
          _duracionCacheIngredientes;

  DateTime? get ultimaActualizacion {
    if (_ultimaCargaProductos == null) return null;
    return _ultimaCargaProductos;
  }

  // Inicializar el provider
  Future<void> initialize() async {
    print('🚀 Inicializando DatosCacheProvider...');
    await _cargarTodosLosDatos();
    _startPolling(); // ✅ Iniciar polling automático
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
        _cargarIngredientes(force: force, silent: silent),
      ]);

      print(
        '✅ Todos los datos cargados exitosamente${silent ? ' (silencioso)' : ''}',
      );
      print('   - Productos: ${_productos?.length ?? 0}');
      print('   - Categorías: ${_categorias?.length ?? 0}');
      print('   - Ingredientes: ${_ingredientes?.length ?? 0}');
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

      // Solo recargar datos expirados (SILENCIOSO para no interrumpir UI)
      if (productosExpired) {
        await _cargarProductos(silent: true);
      }
      if (categoriasExpired) {
        await _cargarCategorias(silent: true);
      }
      if (ingredientesExpired) {
        await _cargarIngredientes(silent: true);
      }
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
      final productos = await _productoService.getProductos();
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
      print('❌ Error cargando productos: $e');
      // Mantener productos existentes en caso de error
      print(
        '🔄 Manteniendo productos existentes en caché: ${_productos?.length ?? 0}',
      );
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

  // Cargar ingredientes (con cache inteligente)
  Future<void> _cargarIngredientes({
    bool force = false,
    bool silent = false,
  }) async {
    // ✅ NUEVO: Verificar si necesita actualización
    if (!force && !ingredientesExpired && _ingredientes != null) {
      print('🥬 Ingredientes en caché válidos, usando caché local');
      return;
    }

    if (_isLoadingIngredientes) return;

    _isLoadingIngredientes = true;
    // ✅ MEJORADO: Solo notificar si no es silencioso
    if (!silent) notifyListeners();

    try {
      final ingredientes = await _ingredienteService.getAllIngredientes();
      _ingredientes = ingredientes;
      _ultimaCargaIngredientes =
          DateTime.now(); // ✅ NUEVO: Actualizar timestamp
      print(
        '🥬 Ingredientes cargados: ${ingredientes.length} (${force ? 'forzado' : 'caché expirado'}) ${silent ? '(silencioso)' : ''}',
      );
    } catch (e) {
      print('❌ Error cargando ingredientes: $e');
    } finally {
      _isLoadingIngredientes = false;
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
    _ingredientes = null;
    _ultimaCargaProductos = null;
    _ultimaCargaCategorias = null;
    _ultimaCargaIngredientes = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
