import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/ingrediente.dart';
import '../services/producto_service.dart';
import '../services/ingrediente_service.dart';

class DatosProvider with ChangeNotifier {
  final ProductoService _productoService = ProductoService();
  final IngredienteService _ingredienteService = IngredienteService();

  // Estados de carga
  bool _isLoadingProductos = false;
  bool _isLoadingCategorias = false;
  bool _isLoadingIngredientes = false;
  bool _datosInicializados = false;

  // Datos cacheados
  List<Producto> _productos = [];
  List<Categoria> _categorias = [];
  List<Ingrediente> _ingredientes = [];
  List<Ingrediente> _ingredientesCarnes = [];

  // Timestamps para controlar actualizaciones
  DateTime? _ultimaActualizacionProductos;
  DateTime? _ultimaActualizacionCategorias;
  DateTime? _ultimaActualizacionIngredientes;

  // Duración del cache (30 minutos)
  static const Duration _duracionCache = Duration(minutes: 30);

  // Getters
  bool get isLoadingProductos => _isLoadingProductos;
  bool get isLoadingCategorias => _isLoadingCategorias;
  bool get isLoadingIngredientes => _isLoadingIngredientes;
  bool get datosInicializados => _datosInicializados;
  bool get isLoading =>
      _isLoadingProductos || _isLoadingCategorias || _isLoadingIngredientes;

  List<Producto> get productos => List.unmodifiable(_productos);
  List<Categoria> get categorias => List.unmodifiable(_categorias);
  List<Ingrediente> get ingredientes => List.unmodifiable(_ingredientes);
  List<Ingrediente> get ingredientesCarnes =>
      List.unmodifiable(_ingredientesCarnes);

  // Verificar si el cache es válido
  bool _esCacheValido(DateTime? ultimaActualizacion) {
    if (ultimaActualizacion == null) return false;
    return DateTime.now().difference(ultimaActualizacion) < _duracionCache;
  }

  // Inicializar todos los datos desde el dashboard
  Future<void> inicializarDatos({bool forzarActualizacion = false}) async {
    print('🚀 DatosProvider: Iniciando carga global de datos...');

    try {
      // Cargar datos en paralelo para mayor velocidad
      await Future.wait([
        cargarProductos(forzarActualizacion: forzarActualizacion),
        cargarCategorias(forzarActualizacion: forzarActualizacion),
        cargarIngredientes(forzarActualizacion: forzarActualizacion),
      ]);

      _datosInicializados = true;
      print('✅ DatosProvider: Todos los datos cargados exitosamente');
      notifyListeners();
    } catch (e) {
      print('❌ DatosProvider: Error al inicializar datos: $e');
      rethrow;
    }
  }

  // Cargar productos
  Future<void> cargarProductos({bool forzarActualizacion = false}) async {
    if (!forzarActualizacion && _esCacheValido(_ultimaActualizacionProductos)) {
      print('📦 DatosProvider: Productos en cache válido, saltando carga');
      return;
    }

    _isLoadingProductos = true;
    notifyListeners();

    try {
      print('📦 DatosProvider: Cargando productos...');
      final productosData = await _productoService.getProductos();

      _productos = productosData;
      _ultimaActualizacionProductos = DateTime.now();

      print('✅ DatosProvider: ${_productos.length} productos cargados');
    } catch (e) {
      print('❌ DatosProvider: Error al cargar productos: $e');
      rethrow;
    } finally {
      _isLoadingProductos = false;
      notifyListeners();
    }
  }

  // Cargar categorías
  Future<void> cargarCategorias({bool forzarActualizacion = false}) async {
    if (!forzarActualizacion &&
        _esCacheValido(_ultimaActualizacionCategorias)) {
      print('🏷️ DatosProvider: Categorías en cache válido, saltando carga');
      return;
    }

    _isLoadingCategorias = true;
    notifyListeners();

    try {
      print('🏷️ DatosProvider: Cargando categorías...');
      final categoriasData = await _productoService.getCategorias();

      _categorias = categoriasData;
      _ultimaActualizacionCategorias = DateTime.now();

      print('✅ DatosProvider: ${_categorias.length} categorías cargadas');
    } catch (e) {
      print('❌ DatosProvider: Error al cargar categorías: $e');
      rethrow;
    } finally {
      _isLoadingCategorias = false;
      notifyListeners();
    }
  }

  // Cargar ingredientes
  Future<void> cargarIngredientes({bool forzarActualizacion = false}) async {
    if (!forzarActualizacion &&
        _esCacheValido(_ultimaActualizacionIngredientes)) {
      print('🥘 DatosProvider: Ingredientes en cache válido, saltando carga');
      return;
    }

    _isLoadingIngredientes = true;
    notifyListeners();

    try {
      print('🥘 DatosProvider: Cargando ingredientes...');
      final futures = await Future.wait([
        _ingredienteService.getAllIngredientes(),
        _ingredienteService.getIngredientesCarnes(),
      ]);

      _ingredientes = futures[0] as List<Ingrediente>;
      _ingredientesCarnes = futures[1] as List<Ingrediente>;
      _ultimaActualizacionIngredientes = DateTime.now();

      print(
        '✅ DatosProvider: ${_ingredientes.length} ingredientes y ${_ingredientesCarnes.length} carnes cargados',
      );
    } catch (e) {
      print('❌ DatosProvider: Error al cargar ingredientes: $e');
      rethrow;
    } finally {
      _isLoadingIngredientes = false;
      notifyListeners();
    }
  }

  // Actualizar un producto específico (cuando se edita)
  void actualizarProducto(Producto productoActualizado) {
    final index = _productos.indexWhere((p) => p.id == productoActualizado.id);
    if (index != -1) {
      _productos[index] = productoActualizado;
      print(
        '🔄 DatosProvider: Producto ${productoActualizado.nombre} actualizado en cache',
      );
      notifyListeners();
    }
  }

  // Agregar un nuevo producto (cuando se crea)
  void agregarProducto(Producto nuevoProducto) {
    _productos.add(nuevoProducto);
    print(
      '➕ DatosProvider: Producto ${nuevoProducto.nombre} agregado al cache',
    );
    notifyListeners();
  }

  // Eliminar un producto (cuando se borra)
  void eliminarProducto(String productoId) {
    _productos.removeWhere((p) => p.id == productoId);
    print('🗑️ DatosProvider: Producto eliminado del cache');
    notifyListeners();
  }

  // Buscar productos con filtro local
  List<Producto> buscarProductos(String query, {String? categoriaId}) {
    if (query.isEmpty && categoriaId == null) {
      return _productos;
    }

    return _productos.where((producto) {
      // Filtro por texto
      bool matchTexto = true;
      if (query.isNotEmpty) {
        final palabrasClave = query
            .toLowerCase()
            .split(' ')
            .where((palabra) => palabra.trim().isNotEmpty)
            .toList();

        final nombreLower = producto.nombre.toLowerCase();
        final descripcionLower = producto.descripcion?.toLowerCase() ?? '';
        final categoriaLower = producto.categoria?.nombre.toLowerCase() ?? '';

        matchTexto = palabrasClave.every(
          (palabra) =>
              nombreLower.contains(palabra) ||
              descripcionLower.contains(palabra) ||
              categoriaLower.contains(palabra),
        );
      }

      // Filtro por categoría
      bool matchCategoria =
          categoriaId == null || producto.categoria?.id == categoriaId;

      return matchTexto && matchCategoria;
    }).toList();
  }

  // Limpiar cache manualmente
  void limpiarCache() {
    _productos.clear();
    _categorias.clear();
    _ingredientes.clear();
    _ingredientesCarnes.clear();
    _ultimaActualizacionProductos = null;
    _ultimaActualizacionCategorias = null;
    _ultimaActualizacionIngredientes = null;
    _datosInicializados = false;

    print('🧹 DatosProvider: Cache limpiado');
    notifyListeners();
  }

  // Obtener estadísticas del cache
  Map<String, dynamic> getEstadisticasCache() {
    return {
      'productos': _productos.length,
      'categorias': _categorias.length,
      'ingredientes': _ingredientes.length,
      'ingredientesCarnes': _ingredientesCarnes.length,
      'datosInicializados': _datosInicializados,
      'ultimaActualizacionProductos': _ultimaActualizacionProductos?.toString(),
      'ultimaActualizacionCategorias': _ultimaActualizacionCategorias
          ?.toString(),
      'ultimaActualizacionIngredientes': _ultimaActualizacionIngredientes
          ?.toString(),
    };
  }
}
