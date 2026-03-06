import '../widgets/imagen_producto_widget.dart';
import '../widgets/lazy_product_image_widget.dart';
import '../widgets/optimized_loading_widget.dart';
import '../config/performance_config.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'package:http/http.dart' as http;
import '../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'dart:typed_data' show Uint8List;

import '../theme/app_theme.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/ingrediente.dart';
import 'package:provider/provider.dart';
import '../providers/datos_cache_provider.dart';
import '../services/image_service.dart';
import '../services/producto_service.dart';
import '../services/image_loader_service.dart';
import '../utils/format_utils.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  static const String _backendBaseUrl =
      "https://vercy-motos-app-048m.onrender.com";
  final ImageService _imageService = ImageService();
  final ProductoService _productoService = ProductoService();
  final ImageLoaderService _imageLoader = ImageLoaderService();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoriaId;
  int _paginaActual = 0;
  int _itemsPorPagina = 20; // Paginación en memoria (frontend)
  bool _isLoading = true;
  String? _error;
  bool _guardandoProducto = false;
  bool _isRefreshing = false;
  List<Producto> _productosCache = []; // Todos los productos desde cache
  List<Producto> _productosFiltrados = []; // Productos después de filtros
  List<Producto> _productosPaginados = []; // Productos de la página actual
  List<Categoria> _categorias = [];
  List<Ingrediente> _ingredientesCarnes = [];

  @override
  void initState() {
    super.initState();
    // Cargar datos desde cache provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );
      cacheProvider.addListener(_onCacheDataChanged);
      _cargarDatosDesdeCache();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    try {
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );
      cacheProvider.removeListener(_onCacheDataChanged);
    } catch (e) {}
    super.dispose();
  }

  void _onCacheDataChanged() {
    final cacheProvider = Provider.of<DatosCacheProvider>(
      context,
      listen: false,
    );
    if (cacheProvider.hasData && mounted) {
      setState(() {
        // Crear copias de las listas para evitar modificaciones concurrentes
        _categorias = List<Categoria>.from(cacheProvider.categorias ?? []);
        _ingredientesCarnes = List<Ingrediente>.from(
          cacheProvider.ingredientes ?? [],
        );
        _productosCache = List<Producto>.from(cacheProvider.productos ?? []);
        _aplicarFiltrosYPaginacion();
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarDatosDesdeCache() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );
      if (!cacheProvider.hasData) {
        await cacheProvider.initialize();
        // 🔥 WARMUP: Iniciar carga RÁPIDA de productos
        cacheProvider.warmupProductos();
      }
      setState(() {
        // Crear copias de las listas para evitar modificaciones concurrentes
        _categorias = List<Categoria>.from(cacheProvider.categorias ?? []);
        _ingredientesCarnes = List<Ingrediente>.from(
          cacheProvider.ingredientes ?? [],
        );
        _productosCache = List<Producto>.from(cacheProvider.productos ?? []);
        if (_productosCache.isEmpty) {

        }
        _aplicarFiltrosYPaginacion();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
        _isLoading = false;
      });
    }
  }

  // ✅ OPTIMIZADO: Filtros y paginación en memoria (sin backend)
  void _aplicarFiltrosYPaginacion() {
    final query = _searchController.text.toLowerCase();
    
    // Paso 1: Aplicar filtros
    List<Producto> productosFiltrados = _productosCache.where((producto) {
      final matchesQuery =
          query.isEmpty || producto.nombre.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategoriaId == null ||
          producto.categoria?.id == _selectedCategoriaId;
      return matchesQuery && matchesCategory;
    }).toList();

    _productosFiltrados = productosFiltrados;

    // Paso 2: Calcular paginación en memoria
    final totalElementos = _productosFiltrados.length;
    final totalPaginas = (totalElementos / _itemsPorPagina).ceil();

    // Ajustar página actual si está fuera de rango
    if (_paginaActual >= totalPaginas && totalPaginas > 0) {
      _paginaActual = totalPaginas - 1;
    } else if (_paginaActual < 0) {
      _paginaActual = 0;
    }

    // Paso 3: Obtener productos de la página actual
    final start = _paginaActual * _itemsPorPagina;
    final end = (start + _itemsPorPagina).clamp(0, totalElementos);

    if (start < totalElementos) {
      _productosPaginados = _productosFiltrados.sublist(start, end);
    } else {
      _productosPaginados = [];
    }

           
    // 🖼️ NUEVO: Cargar imágenes de los productos visibles (en background, no bloquea)
    if (_productosPaginados.isNotEmpty) {
      _cargarImagenesVisibles();
    }
  }

  // 🖼️ NUEVO: Cargar imágenes solo de productos visibles (sin await para no bloquear)
  void _cargarImagenesVisibles() {
    if (_productosPaginados.isEmpty) return;
    
       
    // ⚠️ DESHABILITADO: Endpoint batch tiene problemas
    // Las imágenes se cargan individualmente con LazyImagenProducto

    // _imageLoader
    //     .cargarImagenesLote(_productosPaginados)
    //     .then((_) {
    //         
    //       if (mounted) {
    //         setState(() {});
    //       }
    //     })
    //     .catchError((error) {
    //         
    //     });
  }

  void _onSearchChanged() {
    setState(() {
      _paginaActual = 0; // Resetear a primera página al buscar
      _aplicarFiltrosYPaginacion();
    });
  }

  // ✅ OPTIMIZADO: Navegación de páginas en memoria (instantánea)
  void _siguientePagina() {
    final totalPaginas = (_productosFiltrados.length / _itemsPorPagina).ceil();
    if (_paginaActual < totalPaginas - 1) {
      setState(() {
        _paginaActual++;
        _aplicarFiltrosYPaginacion();
      });
    }
  }

  void _paginaAnterior() {
    if (_paginaActual > 0) {
      setState(() {
        _paginaActual--;
        _aplicarFiltrosYPaginacion();
      });
    }
  }

  /// Construye los controles de paginación (100% en memoria)
  Widget _buildPaginationControls() {
    final totalElementos = _productosFiltrados.length;
    final totalPaginas = (totalElementos / _itemsPorPagina).ceil();
    
    if (totalPaginas <= 1) {
      return SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          top: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 18),
            color: _paginaActual > 0 ? AppTheme.primary : AppTheme.textMuted,
            onPressed: _paginaActual > 0 ? _paginaAnterior : null,
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Página ${_paginaActual + 1} de $totalPaginas',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$totalElementos productos',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, size: 18),
            color: _paginaActual < totalPaginas - 1
                ? AppTheme.primary
                : AppTheme.textMuted,
            onPressed: _paginaActual < totalPaginas - 1
                ? _siguientePagina
                : null,
          ),
          Container(
            margin: EdgeInsets.only(left: 16),
            padding: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _itemsPorPagina,
                dropdownColor: AppTheme.cardBg,
                icon: Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                style: TextStyle(color: AppTheme.textPrimary),
                items: [5, 10, 20, 50, 100].map<DropdownMenuItem<int>>((
                  int value,
                ) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value por página'),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _itemsPorPagina = newValue!;
                    _paginaActual = 0;
                    _aplicarFiltrosYPaginacion();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir filtros de categorías
  List<Widget> _buildCategoriaCompactRowProductos() {
    List<Widget> widgets = [];

    // Botón "Todas"
    widgets.add(
      GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategoriaId = null;
            _paginaActual = 0;
            _aplicarFiltrosYPaginacion();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _selectedCategoriaId == null
                ? AppTheme.primary
                : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selectedCategoriaId == null
                  ? AppTheme.primary
                  : AppTheme.textMuted.withOpacity(0.3),
            ),
          ),
          child: Text(
            'Todas',
            style: TextStyle(
              color: _selectedCategoriaId == null
                  ? Colors.white
                  : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    widgets.add(SizedBox(width: 8));

    // Botones de categorías
    for (var categoria in _categorias) {
      widgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategoriaId = categoria.id;
              _paginaActual = 0;
              _aplicarFiltrosYPaginacion();
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedCategoriaId == categoria.id
                  ? AppTheme.primary
                  : AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedCategoriaId == categoria.id
                    ? AppTheme.primary
                    : AppTheme.textMuted.withOpacity(0.3),
              ),
            ),
            child: Text(
              categoria.nombre,
              style: TextStyle(
                color: _selectedCategoriaId == categoria.id
                    ? Colors.white
                    : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
      widgets.add(SizedBox(width: 8));
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: Text('Gestión de Productos', style: AppTheme.headlineMedium),
          backgroundColor: AppTheme.primary,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(AppTheme.spacingLarge),
                decoration: AppTheme.cardDecoration,
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: AppTheme.spacingLarge),
              Text('Cargando productos...', style: AppTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: Text('Gestión de Productos', style: AppTheme.headlineMedium),
          backgroundColor: AppTheme.primary,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Container(
            margin: EdgeInsets.all(AppTheme.spacingLarge),
            padding: EdgeInsets.all(AppTheme.spacingXLarge),
            decoration: AppTheme.elevatedCardDecoration.copyWith(
              border: Border.all(
                color: AppTheme.error.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingMedium),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: AppTheme.error,
                    size: 48,
                  ),
                ),
                SizedBox(height: AppTheme.spacingLarge),
                Text(
                  'Error al cargar productos',
                  style: AppTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppTheme.spacingMedium),
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingMedium),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    _error!,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: AppTheme.spacingLarge),
                ElevatedButton(
                  onPressed: () {
                    final cacheProvider = Provider.of<DatosCacheProvider>(
                      context,
                      listen: false,
                    );
                    cacheProvider.recargarDatos();
                  },
                  style: AppTheme.primaryButtonStyle,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: AppTheme.spacingSmall),
                      Text('Reintentar'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/dashboard');
          },
        ),
        title: Text('Gestión de Productos', style: AppTheme.headlineMedium),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_2),
            tooltip: 'Imprimir Códigos de Barras',
            onPressed: () => _mostrarDialogoImprimirCodigoBarras(),
          ),
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.refresh),
            onPressed: _isRefreshing
                ? null
                : () async {
                    setState(() {
                      _isRefreshing = true;
                    });

                    try {
                      final cacheProvider = Provider.of<DatosCacheProvider>(
                        context,
                        listen: false,
                      );
                      await cacheProvider.recargarDatos();
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isRefreshing = false;
                        });
                      }
                    }
                  },
          ),
          IconButton(
            icon: Icon(Icons.category),
            tooltip: 'Gestionar Categorías',
            onPressed: () async {
              await Navigator.pushNamed(context, '/categorias');
              if (mounted) {
                await _cargarDatosDesdeCache();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sección de búsqueda y filtros
          Container(
            padding: EdgeInsets.all(context.responsivePadding),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Barra de búsqueda mejorada
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.textMuted.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Buscar producto...',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                      prefixIcon: Container(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.search,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    // onChanged ya está manejado por _searchController.addListener
                  ),
                ),
                SizedBox(height: 12), // Reducido de 20 a 12
                // Filtros de categorías
                Padding(
                  padding: EdgeInsets.only(
                    left: 4,
                  ), // Muy poco margen izquierdo
                  child: Text(
                    'Categorías',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 8), // Reducido de 12 a 8
                Container(
                  height: 45, // Más compacta aún
                  margin: EdgeInsets.only(
                    left: 0, // Sin margen izquierdo
                    right: 16,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(
                      left: 4, // Padding mínimo a la izquierda
                      right: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: _buildCategoriaCompactRowProductos(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de productos
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }
                if (_error != null) {
                  return Center(
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  );
                }
                if (_productosFiltrados.isEmpty) {
                  return Center(
                    child: Text(
                      'No se encontraron productos',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _productosPaginados.length,
                        itemBuilder: (context, index) {
                          final producto = _productosPaginados[index];
                          return _buildProductoItem(producto);
                        },
                      ),
                    ),
                    _buildPaginationControls(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'upload',
            onPressed: _mostrarDialogoCargaMasiva,
            backgroundColor: Colors.green,
            child: Icon(Icons.upload_file),
            tooltip: 'Carga masiva Excel',
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () {
              _showProductoDialog();
            },
            backgroundColor: AppTheme.primary,
            child: Icon(Icons.add),
            tooltip: 'Agregar producto',
          ),
        ],
      ),
    );
  }

  Widget _buildProductoItem(Producto producto) {
    // Buscar la categoría por ID (solo usando producto.categoria)
    String categoriaNombre = 'Adicional';
    if (producto.categoria != null && producto.categoria!.nombre.isNotEmpty) {
      categoriaNombre = producto.categoria!.nombre;
    } else {
      categoriaNombre = 'Adicional';
    }

    return Card(
      color: AppTheme.cardBg,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: _buildProductImage(producto),
        ),
        title: Text(
          producto.nombre,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  formatCurrency(producto.precio),
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Costo: ${formatCurrency(producto.costo)}',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.category, color: Colors.orange, size: 16),
                SizedBox(width: 4),
                Text(
                  categoriaNombre,
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (producto.descripcion != null &&
                producto.descripcion!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  producto.descripcion!,
                  style: TextStyle(
                    color: AppTheme.textPrimary.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: AppTheme.textPrimary),
              onPressed: () async {
                // 🔄 Cargar datos completos del producto antes de editar
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      Center(child: CircularProgressIndicator()),
                );

                try {
                  final productoCompleto = await _productoService.getProducto(
                    producto.id,
                  );
                  Navigator.pop(context); // Cerrar loading

                  if (productoCompleto != null) {
                    _showProductoDialog(producto: productoCompleto);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: No se pudo cargar el producto'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.pop(context); // Cerrar loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al cargar producto: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                _showDeleteConfirmationDialog(producto);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🖼️ OPTIMIZADO: Usar lazy loading para imágenes
  Widget _buildProductImage(Producto producto) {
    return LazyProductImageWidget(
      key: ValueKey('lazy-img-${producto.id}'), // Key única por producto
      producto: producto,
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      backendBaseUrl: _backendBaseUrl,
    );
  }

  void _showDeleteConfirmationDialog(Producto producto) {
    bool _isDeleting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(
            '¿Eliminar producto?',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Text(
            '¿Está seguro que desea eliminar ${producto.nombre}?',
            style: TextStyle(color: AppTheme.textPrimary.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onPressed: _isDeleting
                  ? null
                  : () {
                      Navigator.of(context).pop();
                    },
            ),
            TextButton(
              child: Text(
                _isDeleting ? 'Eliminando...' : 'Eliminar',
                style: TextStyle(
                  color: _isDeleting ? Colors.grey : Colors.redAccent,
                ),
              ),
              onPressed: _isDeleting
                  ? null
                  : () async {
                      setState(() {
                        _isDeleting = true;
                      });

                      try {
                        // Llamar al servicio para eliminar el producto
                        await _productoService.deleteProducto(producto.id);
                          

                        // ✅ PRIMERO: Cerrar el diálogo
                        if (mounted) {
                          Navigator.of(context).pop();
                        }

                        // ✅ SEGUNDO: Mostrar mensaje de éxito
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Producto eliminado con éxito'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }

                        // ✅ TERCERO: Recargar datos
                        final cacheProvider = Provider.of<DatosCacheProvider>(
                          context,
                          listen: false,
                        );
                        await cacheProvider.recargarDatos();
                      } catch (e) {
                          

                        // Cerrar diálogo en caso de error
                        if (mounted) {
                          Navigator.of(context).pop();
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error al eliminar producto: ${e.toString()}',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showProductoDialog({Producto? producto}) {
    final bool isEditing = producto != null;

    // ✅ LOGS DE DEPURACIÓN
    if (isEditing) {
        
        
        
        
        
        
        
                                   
        
        
        
        

        
      for (var cat in _categorias) {
          
      }
    }

    // Controladores para el formulario - INFORMACIÓN BÁSICA
    final nombreController = TextEditingController(
      text: isEditing ? producto.nombre : '',
    );
    final descripcionController = TextEditingController(
      text: isEditing ? producto.descripcion ?? '' : '',
    );

    // CÓDIGOS E IDENTIFICACIÓN (SEPARADOS)
    final codigoController = TextEditingController(
      text: isEditing ? (producto.codigo ?? '') : '',
    );
    final codigoBarrasController = TextEditingController(
      text: isEditing ? (producto.codigoBarras ?? '') : '',
    );

    // PRECIOS
    final precioController = TextEditingController(
      text: isEditing ? producto.precio.toString() : '',
    );
    final costoController = TextEditingController(
      text: isEditing ? producto.costo.toString() : '',
    );
    final impuestosController = TextEditingController(
      text: isEditing ? producto.impuestos.toString() : '0',
    );
    final utilidadController = TextEditingController(
      text: isEditing ? producto.utilidad.toString() : '',
    );
    final porcentajeImpuestoController = TextEditingController(
      text: isEditing ? (producto.porcentajeImpuesto?.toString() ?? '') : '',
    );

    // PRECIOS OPCIONALES
    final precioVentaOpc1Controller = TextEditingController(
      text: isEditing ? (producto.precioVentaOpc1?.toString() ?? '') : '',
    );
    final precioVentaOpc2Controller = TextEditingController(
      text: isEditing ? (producto.precioVentaOpc2?.toString() ?? '') : '',
    );
    final precioVentaOpc3Controller = TextEditingController(
      text: isEditing ? (producto.precioVentaOpc3?.toString() ?? '') : '',
    );
    final precioVentaOpc4Controller = TextEditingController(
      text: isEditing ? (producto.precioVentaOpc4?.toString() ?? '') : '',
    );
    final precioVentaOpc5Controller = TextEditingController(
      text: isEditing ? (producto.precioVentaOpc5?.toString() ?? '') : '',
    );

    // CLASIFICACIÓN
    final productoOServicioController = TextEditingController(
      text: isEditing ? (producto.productoOServicio ?? '') : '',
    );
    if (isEditing) {
      print('🔍 [INIT] Inicializando productoOServicioController con: "${producto.productoOServicio}"');
    }
    final tipoProductoNombreController = TextEditingController(
      text: isEditing ? (producto.tipoProductoNombre ?? '') : '',
    );
    final lineaProductoNombreController = TextEditingController(
      text: isEditing ? (producto.lineaProductoNombre ?? '') : '',
    );
    final claseProductoNombreController = TextEditingController(
      text: isEditing ? (producto.claseProductoNombre ?? '') : '',
    );
    final marcaController = TextEditingController(
      text: isEditing ? (producto.marca ?? '') : '',
    );

    // INVENTARIO
    final controlInventarioController = TextEditingController(
      text: isEditing ? (producto.controlInventario ?? '') : '',
    );
    final inventarioBajoController = TextEditingController(
      text: isEditing ? (producto.inventarioBajo?.toString() ?? '') : '',
    );
    final inventarioOptimoController = TextEditingController(
      text: isEditing ? (producto.inventarioOptimo?.toString() ?? '') : '',
    );
    final localizacionController = TextEditingController(
      text: isEditing ? (producto.localizacion ?? '') : '',
    );

    // PROVEEDOR
    final nombreProveedorController = TextEditingController(
      text: isEditing ? (producto.nombreProveedor ?? '') : '',
    );
    final nitProveedorController = TextEditingController(
      text: isEditing ? (producto.nitProveedor ?? '') : '',
    );

    // BODEGA Y UBICACIONES
    final almacenController = TextEditingController(
      text: isEditing ? (producto.almacen?.toString() ?? '') : '',
    );
    final bodegaController = TextEditingController(
      text: isEditing ? (producto.bodega?.toString() ?? '') : '',
    );
    final ubicacion1Controller = TextEditingController(
      text: isEditing ? (producto.ubicacion1 ?? '') : '',
    );
    final ubicacion2Controller = TextEditingController(
      text: isEditing ? (producto.ubicacion2 ?? '') : '',
    );
    final ubicacion3Controller = TextEditingController(
      text: isEditing ? (producto.ubicacion3 ?? '') : '',
    );
    final ubicacion4Controller = TextEditingController(
      text: isEditing ? (producto.ubicacion4 ?? '') : '',
    );
    final localizacionUbi1Controller = TextEditingController(
      text: isEditing ? (producto.localizacionUbi1 ?? '') : '',
    );
    final localizacionUbi2Controller = TextEditingController(
      text: isEditing ? (producto.localizacionUbi2 ?? '') : '',
    );
    final localizacionUbi3Controller = TextEditingController(
      text: isEditing ? (producto.localizacionUbi3 ?? '') : '',
    );
    final localizacionUbi4Controller = TextEditingController(
      text: isEditing ? (producto.localizacionUbi4 ?? '') : '',
    );

    // Función para calcular la utilidad automáticamente
    void calcularUtilidad() {
      final precio = double.tryParse(precioController.text) ?? 0.0;
      final costo = double.tryParse(costoController.text) ?? 0.0;
      final utilidad = precio - costo;
      utilidadController.text = utilidad.toStringAsFixed(2);
    }

    // Función para obtener el margen de ganancia
    double obtenerMargenGanancia() {
      final precio = double.tryParse(precioController.text) ?? 0.0;
      final costo = double.tryParse(costoController.text) ?? 0.0;
      if (precio > 0) {
        return ((precio - costo) / precio) * 100;
      }
      return 0.0;
    }

    // Color del margen según el porcentaje
    Color colorMargen(double margen) {
      if (margen >= 30) return Colors.green;
      if (margen >= 15) return Colors.orange;
      return Colors.red;
    }

    // Agregar listeners para cálculo automático
    precioController.addListener(calcularUtilidad);
    costoController.addListener(calcularUtilidad);

    bool tieneVariantes = isEditing ? producto.tieneVariantes : false;
    String estado = isEditing ? producto.estado : 'Activo';
    // If editing, try to get the category ID either from the categoria object or from the API response
    String? selectedCategoriaId;
    if (isEditing) {
      if (producto.categoria != null) {
        final exists = _categorias.any((c) => c.id == producto.categoria!.id);
        if (exists) {
          selectedCategoriaId = producto.categoria!.id;
                     } else {
          selectedCategoriaId = null;
                     }
      } else {
                 }
    }

      
    String? selectedImageUrl = isEditing ? producto.imagenUrl : null;
    // String? tempImagePath; // Ya no se usa
    List<String> ingredientesSeleccionados = isEditing
        ? List<String>.from(producto.ingredientesDisponibles)
        : [];

    // Nuevas variables para ingredientes y tipo de producto
    bool tieneIngredientes = isEditing ? producto.tieneIngredientes : false;
    String tipoProducto = isEditing ? producto.tipoProducto : 'combo';
    List<IngredienteProducto> ingredientesRequeridos = isEditing
        ? List<IngredienteProducto>.from(producto.ingredientesRequeridos)
        : [];
    List<IngredienteProducto> ingredientesOpcionales = isEditing
        ? List<IngredienteProducto>.from(producto.ingredientesOpcionales)
        : [];

    if (isEditing) {
        
        
        
        
        
      for (var i = 0; i < ingredientesRequeridos.length; i++) {
        final ing = ingredientesRequeridos[i];
                 }
        
      for (var i = 0; i < ingredientesOpcionales.length; i++) {
        final ing = ingredientesOpcionales[i];
                 }
        
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: Text(
                isEditing ? 'Editar Producto' : 'Nuevo Producto',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Imagen
                    GestureDetector(
                      onTap: () async {
                        final result = await _showImageSourceDialog();
                        if (result != null) {
                          if (result is ImageSource) {
                            try {
                              // Usar el servicio de imágenes para seleccionar y subir
                              XFile? pickedFile;
                              if (result == ImageSource.camera) {
                                pickedFile = await _imageService
                                    .pickImageFromCamera();
                              } else {
                                pickedFile = await _imageService
                                    .pickImageFromGallery();
                              }

                              if (pickedFile != null) {
                                   
                                // Mostrar indicador de carga
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Subiendo imagen al servidor...',
                                          ),
                                        ],
                                      ),
                                      duration: Duration(seconds: 30),
                                      backgroundColor: AppTheme.primary,
                                    ),
                                  );
                                }

                                try {
                                  // Subir la imagen al servidor y obtener solo el nombre/ruta corta
                                  final filename = await _imageService
                                      .uploadImage(pickedFile);

                                  setState(() {
                                    selectedImageUrl = filename;
                                  });
                                  
                                     
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✓ Imagen guardada exitosamente',
                                        ),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                    
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error al subir imagen: ${e.toString().replaceAll('Exception: ', '')}',
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                                
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error subiendo imagen: ${e.toString()}',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          }
                        }
                      },
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: selectedImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ImagenProductoWidget(
                                  key: ValueKey(
                                    'dialog-img-${isEditing ? producto.id : "new"}-${selectedImageUrl.hashCode}',
                                  ),
                                  urlRemota: _imageService.getImageUrl(
                                    selectedImageUrl!,
                                  ),
                                  nombreProducto: null,
                                  productoId: isEditing ? producto.id : null,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  backendBaseUrl: _backendBaseUrl,
                                ),
                              )
                            : Icon(
                                Icons.add_a_photo,
                                color: AppTheme.primary,
                                size: 40,
                              ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Nombre
                    TextField(
                      controller: nombreController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        labelStyle: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                        ),
                        filled: true,
                        fillColor: AppTheme.cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // ══════════════════════════════════════
                    // SECCIÓN: CÓDIGOS E IDENTIFICACIÓN
                    // ══════════════════════════════════════
                    ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(
                        'Códigos e Identificación',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      iconColor: AppTheme.primary,
                      collapsedIconColor: AppTheme.textPrimary,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              // Código interno
                              TextField(
                                controller: codigoController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Código Interno',
                                  labelStyle: TextStyle(
                                    color: AppTheme.textPrimary.withOpacity(
                                      0.7,
                                    ),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.tag,
                                    color: AppTheme.primary,
                                  ),
                                  helperText: 'Código único del sistema',
                                  helperStyle: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Código de barras
                              TextField(
                                controller: codigoBarrasController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Código de Barras',
                                  labelStyle: TextStyle(
                                    color: AppTheme.textPrimary.withOpacity(
                                      0.7,
                                    ),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.qr_code,
                                    color: AppTheme.primary,
                                  ),
                                  helperText:
                                      'Escanea o ingresa el código manualmente',
                                  helperStyle: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ══════════════════════════════════════
                    // SECCIÓN: CLASIFICACIÓN
                    // ══════════════════════════════════════
                    ExpansionTile(
                      initiallyExpanded: false,
                      title: Text(
                        'Clasificación del Producto',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      iconColor: AppTheme.primary,
                      collapsedIconColor: AppTheme.textPrimary,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              // Producto o Servicio
                              DropdownButtonFormField<String>(
                                value: productoOServicioController.text.isNotEmpty
                                    ? productoOServicioController.text.toUpperCase()
                                    : 'PRODUCTO',
                                dropdownColor: AppTheme.cardBg,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Producto o Servicio',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                items: ['PRODUCTO', 'SERVICIO']
                                    .map((tipo) => DropdownMenuItem(
                                          value: tipo,
                                          child: Text(tipo),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  print('🔍 [DROPDOWN] Cambio detectado: "$value"');
                                  productoOServicioController.text = value ?? 'PRODUCTO';
                                  print('🔍 [DROPDOWN] Controller actualizado: "${productoOServicioController.text}"');
                                },
                              ),
                              SizedBox(height: 16),

                              // Tipo Producto
                              TextField(
                                controller: tipoProductoNombreController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Tipo Producto',
                                  helperText: 'Ej: Repuesto, Aceite, Llanta',
                                  helperStyle: TextStyle(fontSize: 11),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Línea Producto
                              TextField(
                                controller: lineaProductoNombreController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Línea Producto',
                                  helperText: 'Ej: Motos, Accesorios',
                                  helperStyle: TextStyle(fontSize: 11),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Clase Producto
                              TextField(
                                controller: claseProductoNombreController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Clase Producto',
                                  helperText: 'Subcategoría específica',
                                  helperStyle: TextStyle(fontSize: 11),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Marca
                              TextField(
                                controller: marcaController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Marca',
                                  prefixIcon: Icon(Icons.branding_watermark),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Descripción
                    TextField(
                      controller: descripcionController,
                      maxLines: 3,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Descripción (Opcional)',
                        labelStyle: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                        ),
                        filled: true,
                        fillColor: AppTheme.cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Precio
                    TextField(
                      controller: precioController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Precio',
                        labelStyle: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                        ),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: AppTheme.primary),
                        filled: true,
                        fillColor: AppTheme.cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),

                    // Costo
                    TextField(
                      controller: costoController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Costo',
                        labelStyle: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                        ),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: AppTheme.primary),
                        filled: true,
                        fillColor: AppTheme.cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),

                    // Impuestos
                    TextField(
                      controller: impuestosController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Impuestos',
                        labelStyle: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                        ),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: AppTheme.primary),
                        filled: true,
                        fillColor: AppTheme.cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),

                    // Utilidad (calculada automáticamente)
                    TextField(
                      controller: utilidadController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      readOnly:
                          true, // Solo lectura - se calcula automáticamente
                      decoration: InputDecoration(
                        labelText: 'Utilidad (Automática)',
                        labelStyle: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                        ),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: AppTheme.primary),
                        suffixIcon: Icon(
                          Icons.calculate,
                          color: Colors.green,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.green.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.green.withOpacity(0.5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.green.withOpacity(0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 8),

                    // Indicador de margen de ganancia en tiempo real
                    StatefulBuilder(
                      builder: (context, setState) {
                        // Actualizar cuando cambien los campos
                        precioController.removeListener(() {});
                        costoController.removeListener(() {});

                        void updateMargin() {
                          setState(() {}); // Actualizar solo este widget
                        }

                        precioController.addListener(updateMargin);
                        costoController.addListener(updateMargin);

                        final margen = obtenerMargenGanancia();
                        final color = colorMargen(margen);

                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                margen >= 30
                                    ? Icons.trending_up
                                    : margen >= 15
                                    ? Icons.trending_flat
                                    : Icons.trending_down,
                                color: color,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Margen: ${margen.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                margen >= 30
                                    ? '(Excelente)'
                                    : margen >= 15
                                    ? '(Bueno)'
                                    : '(Bajo)',
                                style: TextStyle(
                                  color: color.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 16),

                    // ══════════════════════════════════════
                    // SECCIÓN: INVENTARIO Y CONTROL
                    // ══════════════════════════════════════
                    ExpansionTile(
                      initiallyExpanded: false,
                      title: Text(
                        'Inventario y Control',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      iconColor: AppTheme.primary,
                      collapsedIconColor: AppTheme.textPrimary,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              // Control de inventario
                              TextField(
                                controller: controlInventarioController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Control de Inventario',
                                  helperText: 'Ej: SI, NO',
                                  helperStyle: TextStyle(fontSize: 11),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // % Impuesto
                              TextField(
                                controller: porcentajeImpuestoController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '% Impuesto',
                                  prefixIcon: Icon(Icons.percent),
                                  helperText: 'Porcentaje de impuesto (0-100)',
                                  helperStyle: TextStyle(fontSize: 11),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Inventario bajo
                              TextField(
                                controller: inventarioBajoController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Inventario Bajo',
                                  helperText: 'Cantidad mínima para alerta',
                                  helperStyle: TextStyle(fontSize: 11),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Inventario óptimo
                              TextField(
                                controller: inventarioOptimoController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Inventario Óptimo',
                                  helperText: 'Cantidad ideal en existencia',
                                  helperStyle: TextStyle(fontSize: 11),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Localización
                              TextField(
                                controller: localizacionController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Localización',
                                  prefixIcon: Icon(Icons.location_on),
                                  helperText: 'Ubicación general del producto',
                                  helperStyle: TextStyle(fontSize: 11),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ══════════════════════════════════════
                    // SECCIÓN: PROVEEDOR
                    // ══════════════════════════════════════
                    ExpansionTile(
                      initiallyExpanded: false,
                      title: Text(
                        'Información del Proveedor',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      iconColor: AppTheme.primary,
                      collapsedIconColor: AppTheme.textPrimary,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              // Nombre proveedor
                              TextField(
                                controller: nombreProveedorController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Nombre Proveedor',
                                  prefixIcon: Icon(Icons.business),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // NIT proveedor
                              TextField(
                                controller: nitProveedorController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'NIT Proveedor (sin DV)',
                                  prefixIcon: Icon(Icons.badge),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ══════════════════════════════════════
                    // SECCIÓN: BODEGA Y UBICACIONES
                    // ══════════════════════════════════════
                    ExpansionTile(
                      initiallyExpanded: false,
                      title: Text(
                        'Bodega y Ubicaciones',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      iconColor: AppTheme.primary,
                      collapsedIconColor: AppTheme.textPrimary,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              // Almacén
                              TextField(
                                controller: almacenController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Almacén',
                                  prefixIcon: Icon(Icons.warehouse),
                                  helperText: 'Número de almacén',
                                  helperStyle: TextStyle(fontSize: 11),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Bodega
                              TextField(
                                controller: bodegaController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Bodega',
                                  prefixIcon: Icon(Icons.store),
                                  helperText: 'Número de bodega',
                                  helperStyle: TextStyle(fontSize: 11),
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Ubicación 1
                              TextField(
                                controller: ubicacion1Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Ubicación 1',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Ubicación 2
                              TextField(
                                controller: ubicacion2Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Ubicación 2',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Ubicación 3
                              TextField(
                                controller: ubicacion3Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Ubicación 3',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Ubicación 4
                              TextField(
                                controller: ubicacion4Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Ubicación 4',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              // Localización Ubi 1-4
                              TextField(
                                controller: localizacionUbi1Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Localización Ubicación 1',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              TextField(
                                controller: localizacionUbi2Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Localización Ubicación 2',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              TextField(
                                controller: localizacionUbi3Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Localización Ubicación 3',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              TextField(
                                controller: localizacionUbi4Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Localización Ubicación 4',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ══════════════════════════════════════
                    // SECCIÓN: PRECIOS OPCIONALES
                    // ══════════════════════════════════════
                    ExpansionTile(
                      initiallyExpanded: false,
                      title: Text(
                        'Precios de Venta Opcionales',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      iconColor: AppTheme.primary,
                      collapsedIconColor: AppTheme.textPrimary,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              // Precio Venta Opción 1
                              TextField(
                                controller: precioVentaOpc1Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Precio de Venta Opción 1',
                                  prefixText: '\$ ',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              TextField(
                                controller: precioVentaOpc2Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Precio de Venta Opción 2',
                                  prefixText: '\$ ',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              TextField(
                                controller: precioVentaOpc3Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Precio de Venta Opción 3',
                                  prefixText: '\$ ',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              TextField(
                                controller: precioVentaOpc4Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Precio de Venta Opción 4',
                                  prefixText: '\$ ',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),

                              TextField(
                                controller: precioVentaOpc5Controller,
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Precio de Venta Opción 5',
                                  prefixText: '\$ ',
                                  filled: true,
                                  fillColor: AppTheme.cardBg.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Categoría
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoriaId,
                      style: TextStyle(color: AppTheme.textPrimary),
                      dropdownColor: AppTheme.cardBg,
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        labelStyle: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                        ),
                        filled: true,
                        fillColor: AppTheme.cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      items: List<DropdownMenuItem<String>>.from(
                        _categorias.map((categoria) {
                          return DropdownMenuItem<String>(
                            value: categoria.id,
                            child: Text(
                              categoria.nombre,
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                          );
                        }),
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedCategoriaId = value;
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    // Estado
                    DropdownButtonFormField<String>(
                      value: estado,
                      style: TextStyle(color: AppTheme.textPrimary),
                      dropdownColor: AppTheme.cardBg,
                      decoration: InputDecoration(
                        labelText: 'Estado',
                        labelStyle: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                        ),
                        prefixIcon: Icon(
                          Icons.toggle_on,
                          color: AppTheme.primary,
                        ),
                        filled: true,
                        fillColor: AppTheme.cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'Activo',
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Activo',
                                style: TextStyle(color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Inactivo',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Inactivo',
                                style: TextStyle(color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          estado = value!;
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    // Tiene variantes
                    Row(
                      children: [
                        Text(
                          '¿Tiene variantes?',
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                        Switch(
                          value: tieneVariantes,
                          onChanged: (value) {
                            setState(() {
                              tieneVariantes = value;
                            });
                          },
                          activeThumbColor: AppTheme.primary,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Tipo de producto (siempre visible)
                    DropdownButtonFormField<String>(
                      initialValue: tipoProducto,
                      style: TextStyle(color: AppTheme.textPrimary),
                      dropdownColor: AppTheme.cardBg,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Producto',
                        labelStyle: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                        ),
                        filled: true,
                        fillColor: AppTheme.cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'combo',
                          child: Text(
                            'Combo (Cliente elige ingredientes)',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tipoProducto = value!;
                          // Actualizar tieneIngredientes basado en el tipo
                          tieneIngredientes = true; // Siempre true ahora
                          // Limpiar ingredientes al cambiar tipo
                          ingredientesRequeridos.clear();
                          ingredientesOpcionales.clear();
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    // Información sobre el tipo seleccionado
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tipoProducto == 'combo'
                                ? Icons.restaurant_menu
                                : Icons.fastfood,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tipoProducto == 'combo'
                                  ? 'Los combos permiten al cliente elegir entre ingredientes opcionales (ej: pollo, res, cerdo)'
                                  : 'Los productos individuales permiten al cliente seleccionar cualquier ingrediente disponible al momento del pedido',
                              style: TextStyle(
                                color: AppTheme.textPrimary.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Botón para gestionar ingredientes
                    ElevatedButton.icon(
                      onPressed: () async {
                          
                                                                              
                        final resultado = await _showIngredientesDialog(
                          tipoProducto: tipoProducto,
                          ingredientesRequeridos: ingredientesRequeridos,
                          ingredientesOpcionales: ingredientesOpcionales,
                        );
                        
                        if (resultado != null) {
                            
                                                                                    setState(() {
                            ingredientesRequeridos =
                                resultado['requeridos'] ?? [];
                            ingredientesOpcionales =
                                resultado['opcionales'] ?? [];
                          });
                        } else {
                            
                        }
                      },
                      icon: Icon(Icons.add_circle_outline),
                      label: Text('Gestionar Ingredientes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Resumen de ingredientes agregados
                    if (ingredientesRequeridos.isNotEmpty ||
                        ingredientesOpcionales.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (ingredientesRequeridos.isNotEmpty) ...[
                              Text(
                                'Ingredientes Requeridos (${ingredientesRequeridos.length}):',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ...List<Widget>.from(
                                ingredientesRequeridos.map(
                                  (ing) => Text(
                                    '• ${ing.ingredienteNombre}',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary.withOpacity(
                                        0.8,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                            ],
                            if (ingredientesOpcionales.isNotEmpty) ...[
                              Text(
                                'Ingredientes Opcionales (${ingredientesOpcionales.length}):',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ...List<Widget>.from(
                                ingredientesOpcionales.map(
                                  (ing) => Text(
                                    '• ${ing.ingredienteNombre}',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary.withOpacity(
                                        0.8,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            //),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),

                      // Estado del producto
                      DropdownButtonFormField<String>(
                        initialValue: estado,
                        style: TextStyle(color: AppTheme.textPrimary),
                        dropdownColor: AppTheme.cardBg,
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          labelStyle: TextStyle(
                            color: AppTheme.textPrimary.withOpacity(0.7),
                          ),
                          filled: true,
                          fillColor: AppTheme.cardBg.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.primary),
                          ),
                        ),
                        items: ['Activo', 'Inactivo', 'Agotado'].map((
                          estadoItem,
                        ) {
                          return DropdownMenuItem<String>(
                            value: estadoItem,
                            child: Text(
                              estadoItem,
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            estado = value!;
                          });
                        },
                      ),
                      SizedBox(height: 16),

                      // Descripción
                      TextField(
                        controller: descripcionController,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Descripción',
                          labelStyle: TextStyle(
                            color: AppTheme.textPrimary.withOpacity(0.7),
                          ),
                          filled: true,
                          fillColor: AppTheme.cardBg.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.primary),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Ingredientes disponibles (Carnes):',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.textPrimary.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selecciona los ingredientes que estarán disponibles para este producto:',
                              style: TextStyle(
                                color: AppTheme.textPrimary.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List<Widget>.from(
                                _ingredientesCarnes.map((ingrediente) {
                                  final bool isSelected =
                                      ingredientesSeleccionados.contains(
                                        ingrediente.nombre,
                                      );
                                  return FilterChip(
                                    label: Text(
                                      ingrediente.nombre,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.textPrimary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      try {
                                        setState(() {
                                          if (selected) {
                                            ingredientesSeleccionados.add(
                                              ingrediente.nombre,
                                            );
                                          } else {
                                            ingredientesSeleccionados.remove(
                                              ingrediente.nombre,
                                            );
                                          }
                                        });
                                      } catch (e) {
                                        // Suprimir error de modificación concurrente
                                        // El estado se actualiza correctamente de todos modos
                                      }
                                    },
                                    selectedColor: AppTheme.primary,
                                    backgroundColor: AppTheme.cardBg
                                        .withOpacity(0.5),
                                    checkmarkColor: Colors.white,
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppTheme.primary
                                          : AppTheme.textPrimary.withOpacity(
                                              0.3,
                                            ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            if (ingredientesSeleccionados.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                'Seleccionados: ${ingredientesSeleccionados.join(', ')}',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(
                    _guardandoProducto
                        ? 'Guardando...'
                        : (isEditing ? 'Actualizar' : 'Guardar'),
                    style: TextStyle(
                      color: _guardandoProducto
                          ? Colors.grey
                          : AppTheme.primary,
                    ),
                  ),
                  onPressed: _guardandoProducto
                      ? null
                      : () async {
                          // Validar campos
                          if (nombreController.text.isEmpty ||
                              precioController.text.isEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Complete los campos requeridos',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                            return;
                          }

                          // 🚀 TIMEOUT: Activar estado de guardando para evitar múltiples envíos
                          setState(() {
                            _guardandoProducto = true;
                          });

                          try {
                            // Obtener categoría
                            Categoria? categoriaSeleccionada;
                            if (selectedCategoriaId != null) {
                              try {
                                categoriaSeleccionada = _categorias.firstWhere(
                                  (c) => c.id == selectedCategoriaId,
                                );
                                                                 } catch (e) {
                                                                 }
                            } else {
                                                             }

                            // Obtener imagen final
                            // Si estamos editando y no se cambió la imagen, preservar la original
                            String? finalImageUrl = selectedImageUrl;
                            if (isEditing && finalImageUrl == null) {
                              // Preservar la imagen original si no se seleccionó una nueva
                              finalImageUrl = producto.imagenUrl;
                                                             }

                                                           
                            // Check if we have a category selected
                            if (selectedCategoriaId != null &&
                                categoriaSeleccionada == null) {
                              // Try to find the category in the list
                              try {
                                categoriaSeleccionada = _categorias.firstWhere(
                                  (c) => c.id == selectedCategoriaId,
                                );
                                                                 } catch (e) {
                                                                   // Create a temporary category object with the ID and the name from the dropdown
                                final selectedCategoryName = _categorias
                                    .firstWhere(
                                      (c) => c.id == selectedCategoriaId,
                                      orElse: () => Categoria(
                                        id: selectedCategoriaId!,
                                        nombre: 'Adicionales',
                                      ),
                                    )
                                    .nombre;

                                categoriaSeleccionada = Categoria(
                                  id: selectedCategoriaId!,
                                  nombre: selectedCategoryName,
                                );
                              }
                            }

                            if (isEditing) {
                              // Actualizar producto existente
                                
                                
                                
                                
                                
                                                                                                for (var ing in ingredientesRequeridos) {
                                                                 }
                                                               for (var ing in ingredientesOpcionales) {
                                                                 }
                              
                              final updatedProducto = Producto(
                                id: producto.id,
                                nombre: nombreController.text,
                                precio: double.parse(precioController.text),
                                costo: double.parse(costoController.text),
                                imagenUrl: finalImageUrl,
                                categoria: categoriaSeleccionada,
                                // CÓDIGOS SEPARADOS
                                codigo: codigoController.text.isNotEmpty
                                    ? codigoController.text
                                    : null,
                                codigoBarras:
                                    codigoBarrasController.text.isNotEmpty
                                    ? codigoBarrasController.text
                                    : null,
                                descripcion:
                                    descripcionController.text.isNotEmpty
                                    ? descripcionController.text
                                    : null,
                                impuestos:
                                    double.tryParse(impuestosController.text) ??
                                    0,
                                utilidad:
                                    double.tryParse(utilidadController.text) ??
                                    0,
                                // CLASIFICACIÓN
                                productoOServicio:
                                    productoOServicioController.text.isNotEmpty
                                    ? (() {
                                        print('🔍 [ACTUALIZAR] productoOServicioController.text: "${productoOServicioController.text}"');
                                        final valor = productoOServicioController.text.toLowerCase();
                                        print('🔍 [ACTUALIZAR] productoOServicio (lowercase): "$valor"');
                                        return valor;
                                      })()
                                    : null,
                                tipoProductoNombre:
                                    tipoProductoNombreController.text.isNotEmpty
                                    ? tipoProductoNombreController.text
                                    : null,
                                lineaProductoNombre:
                                    lineaProductoNombreController
                                        .text
                                        .isNotEmpty
                                    ? lineaProductoNombreController.text
                                    : null,
                                claseProductoNombre:
                                    claseProductoNombreController
                                        .text
                                        .isNotEmpty
                                    ? claseProductoNombreController.text
                                    : null,
                                marca: marcaController.text.isNotEmpty
                                    ? marcaController.text
                                    : null,
                                // INVENTARIO
                                controlInventario:
                                    controlInventarioController.text.isNotEmpty
                                    ? controlInventarioController.text
                                    : null,
                                porcentajeImpuesto: double.tryParse(
                                  porcentajeImpuestoController.text,
                                ),
                                inventarioBajo: int.tryParse(
                                  inventarioBajoController.text,
                                ),
                                inventarioOptimo: int.tryParse(
                                  inventarioOptimoController.text,
                                ),
                                localizacion:
                                    localizacionController.text.isNotEmpty
                                    ? localizacionController.text
                                    : null,
                                // PROVEEDOR
                                nombreProveedor:
                                    nombreProveedorController.text.isNotEmpty
                                    ? nombreProveedorController.text
                                    : null,
                                nitProveedor:
                                    nitProveedorController.text.isNotEmpty
                                    ? nitProveedorController.text
                                    : null,
                                // PRECIOS OPCIONALES
                                precioVentaOpc1: double.tryParse(
                                  precioVentaOpc1Controller.text,
                                ),
                                precioVentaOpc2: double.tryParse(
                                  precioVentaOpc2Controller.text,
                                ),
                                precioVentaOpc3: double.tryParse(
                                  precioVentaOpc3Controller.text,
                                ),
                                precioVentaOpc4: double.tryParse(
                                  precioVentaOpc4Controller.text,
                                ),
                                precioVentaOpc5: double.tryParse(
                                  precioVentaOpc5Controller.text,
                                ),
                                // BODEGA Y UBICACIONES
                                almacen: int.tryParse(almacenController.text),
                                bodega: int.tryParse(bodegaController.text),
                                ubicacion1: ubicacion1Controller.text.isNotEmpty
                                    ? ubicacion1Controller.text
                                    : null,
                                ubicacion2: ubicacion2Controller.text.isNotEmpty
                                    ? ubicacion2Controller.text
                                    : null,
                                ubicacion3: ubicacion3Controller.text.isNotEmpty
                                    ? ubicacion3Controller.text
                                    : null,
                                ubicacion4: ubicacion4Controller.text.isNotEmpty
                                    ? ubicacion4Controller.text
                                    : null,
                                localizacionUbi1:
                                    localizacionUbi1Controller.text.isNotEmpty
                                    ? localizacionUbi1Controller.text
                                    : null,
                                localizacionUbi2:
                                    localizacionUbi2Controller.text.isNotEmpty
                                    ? localizacionUbi2Controller.text
                                    : null,
                                localizacionUbi3:
                                    localizacionUbi3Controller.text.isNotEmpty
                                    ? localizacionUbi3Controller.text
                                    : null,
                                localizacionUbi4:
                                    localizacionUbi4Controller.text.isNotEmpty
                                    ? localizacionUbi4Controller.text
                                    : null,
                                // OTROS
                                tieneVariantes: tieneVariantes,
                                estado: estado,
                                ingredientesDisponibles:
                                    ingredientesSeleccionados,
                                tieneIngredientes: tieneIngredientes,
                                tipoProducto: tipoProducto,
                                ingredientesRequeridos: ingredientesRequeridos,
                                ingredientesOpcionales: ingredientesOpcionales,
                              );

                              // Depuración para verificar los datos del producto antes de actualizar
                                                                  
                              // Llamar al servicio para actualizar el producto
                              await _productoService.updateProducto(
                                updatedProducto,
                              );
                                
                              
                              // Invalidar caché de imagen para que se recargue
                              ImageLoaderService().invalidateProductImage(
                                producto.id,
                              );
                                                          } else {
                              // Crear nuevo producto
                              if (selectedCategoriaId == null) {
                                throw Exception(
                                  'Debe seleccionar una categoría',
                                );
                              }

                              // Crear objeto producto completo para enviar al backend
                              final nuevoProducto = Producto(
                                id: '', // El backend asignará el ID
                                nombre: nombreController.text,
                                precio: double.parse(precioController.text),
                                costo: double.parse(costoController.text),
                                imagenUrl: finalImageUrl,
                                categoria: categoriaSeleccionada,
                                // CÓDIGOS SEPARADOS
                                codigo: codigoController.text.isNotEmpty
                                    ? codigoController.text
                                    : null,
                                codigoBarras:
                                    codigoBarrasController.text.isNotEmpty
                                    ? codigoBarrasController.text
                                    : null,
                                descripcion:
                                    descripcionController.text.isNotEmpty
                                    ? descripcionController.text
                                    : null,
                                impuestos:
                                    double.tryParse(impuestosController.text) ??
                                    0,
                                utilidad:
                                    double.tryParse(utilidadController.text) ??
                                    0,
                                // CLASIFICACIÓN
                                productoOServicio:
                                    productoOServicioController.text.isNotEmpty
                                    ? productoOServicioController.text.toLowerCase()
                                    : null,
                                tipoProductoNombre:
                                    tipoProductoNombreController.text.isNotEmpty
                                    ? tipoProductoNombreController.text
                                    : null,
                                lineaProductoNombre:
                                    lineaProductoNombreController
                                        .text
                                        .isNotEmpty
                                    ? lineaProductoNombreController.text
                                    : null,
                                claseProductoNombre:
                                    claseProductoNombreController
                                        .text
                                        .isNotEmpty
                                    ? claseProductoNombreController.text
                                    : null,
                                marca: marcaController.text.isNotEmpty
                                    ? marcaController.text
                                    : null,
                                // INVENTARIO
                                controlInventario:
                                    controlInventarioController.text.isNotEmpty
                                    ? controlInventarioController.text
                                    : null,
                                porcentajeImpuesto: double.tryParse(
                                  porcentajeImpuestoController.text,
                                ),
                                inventarioBajo: int.tryParse(
                                  inventarioBajoController.text,
                                ),
                                inventarioOptimo: int.tryParse(
                                  inventarioOptimoController.text,
                                ),
                                localizacion:
                                    localizacionController.text.isNotEmpty
                                    ? localizacionController.text
                                    : null,
                                // PROVEEDOR
                                nombreProveedor:
                                    nombreProveedorController.text.isNotEmpty
                                    ? nombreProveedorController.text
                                    : null,
                                nitProveedor:
                                    nitProveedorController.text.isNotEmpty
                                    ? nitProveedorController.text
                                    : null,
                                // PRECIOS OPCIONALES
                                precioVentaOpc1: double.tryParse(
                                  precioVentaOpc1Controller.text,
                                ),
                                precioVentaOpc2: double.tryParse(
                                  precioVentaOpc2Controller.text,
                                ),
                                precioVentaOpc3: double.tryParse(
                                  precioVentaOpc3Controller.text,
                                ),
                                precioVentaOpc4: double.tryParse(
                                  precioVentaOpc4Controller.text,
                                ),
                                precioVentaOpc5: double.tryParse(
                                  precioVentaOpc5Controller.text,
                                ),
                                // BODEGA Y UBICACIONES
                                almacen: int.tryParse(almacenController.text),
                                bodega: int.tryParse(bodegaController.text),
                                ubicacion1: ubicacion1Controller.text.isNotEmpty
                                    ? ubicacion1Controller.text
                                    : null,
                                ubicacion2: ubicacion2Controller.text.isNotEmpty
                                    ? ubicacion2Controller.text
                                    : null,
                                ubicacion3: ubicacion3Controller.text.isNotEmpty
                                    ? ubicacion3Controller.text
                                    : null,
                                ubicacion4: ubicacion4Controller.text.isNotEmpty
                                    ? ubicacion4Controller.text
                                    : null,
                                localizacionUbi1:
                                    localizacionUbi1Controller.text.isNotEmpty
                                    ? localizacionUbi1Controller.text
                                    : null,
                                localizacionUbi2:
                                    localizacionUbi2Controller.text.isNotEmpty
                                    ? localizacionUbi2Controller.text
                                    : null,
                                localizacionUbi3:
                                    localizacionUbi3Controller.text.isNotEmpty
                                    ? localizacionUbi3Controller.text
                                    : null,
                                localizacionUbi4:
                                    localizacionUbi4Controller.text.isNotEmpty
                                    ? localizacionUbi4Controller.text
                                    : null,
                                // OTROS
                                tieneVariantes: tieneVariantes,
                                estado: estado,
                                ingredientesDisponibles:
                                    ingredientesSeleccionados,
                                tieneIngredientes: tieneIngredientes,
                                tipoProducto: tipoProducto,
                                ingredientesRequeridos: ingredientesRequeridos,
                                ingredientesOpcionales: ingredientesOpcionales,
                              );

                              // Enviar usando el método básico por ahora
                              // TODO: Crear método en el servicio que acepte producto completo
                              await _productoService
                                  .crearProductoConIngredientes(
                                    nombre: nuevoProducto.nombre,
                                    precio: nuevoProducto.precio,
                                    costo: nuevoProducto.costo,
                                    categoriaId: selectedCategoriaId!,
                                    ingredientesDisponibles:
                                        nuevoProducto.ingredientesDisponibles,
                                    descripcion: nuevoProducto.descripcion,
                                    cantidadAlmacen: nuevoProducto.almacen,
                                    cantidadBodega: nuevoProducto.bodega,
                                  );
                                
                            }

                            Navigator.of(context).pop();

                            // 📡 Notificar a otras pestañas que hay un producto nuevo/editado
                            final channel = html.BroadcastChannel(
                              'productos_actualizados',
                            );
                            channel.postMessage('actualizado');
                            // Cerrar con delay para garantizar que el mensaje se entregue
                            Future.delayed(
                              Duration(milliseconds: 300),
                              () => channel.close(),
                            );

                            // Recargar caché en background para mantener sincronizado
                            final cacheProvider =
                                Provider.of<DatosCacheProvider>(
                                  context,
                                  listen: false,
                                );
                            await cacheProvider.recargarDatos();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'Producto actualizado'
                                        : 'Producto agregado',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          } finally {
                            // 🚀 TIMEOUT: Resetear estado después de 2 segundos para evitar clics accidentales
                            if (mounted) {
                              setState(() {
                                _guardandoProducto = false;
                              });
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<dynamic> _showImageSourceDialog() async {
    return showDialog<dynamic>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(
            'Seleccionar imagen',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppTheme.primary),
                title: Text(
                  'Tomar foto',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.of(context).pop(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppTheme.primary),
                title: Text(
                  'Galería',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.of(context).pop(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 🚀 OPTIMIZACIÓN: Método para cargar ingredientes con cache
  Future<List<Ingrediente>> _cargarIngredientesDisponibles() async {
    try {
      // Verificar si tenemos cache válido
      if (_ingredientesCache != null &&
          _ingredientesCacheTime != null &&
          PerformanceConfig.isCacheValid(
            _ingredientesCacheTime,
            PerformanceConfig.ingredientesCacheDuration,
          )) {
          
        return _ingredientesCache!;
      }

        
      // Aquí deberías obtener los ingredientes desde el cache provider
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );
      final ingredientes = cacheProvider.ingredientes ?? [];

      // Actualizar cache
      _ingredientesCache = ingredientes;
      _ingredientesCacheTime = DateTime.now();

        
      return ingredientes;
    } catch (e) {
        
      // Si hay error y tenemos cache, usar cache aunque haya expirado
      if (_ingredientesCache != null) {
          
        return _ingredientesCache!;
      }
      return [];
    }
  }

  // Cache de ingredientes para evitar recargas
  static List<Ingrediente>? _ingredientesCache;
  static DateTime? _ingredientesCacheTime;

  Future<Map<String, List<IngredienteProducto>>?> _showIngredientesDialog({
    required String tipoProducto,
    required List<IngredienteProducto> ingredientesRequeridos,
    required List<IngredienteProducto> ingredientesOpcionales,
  }) async {
      
      
           for (var i = 0; i < ingredientesRequeridos.length; i++) {
        
    }
           for (var i = 0; i < ingredientesOpcionales.length; i++) {
        
    }
    
    // Copias locales para editar
    List<IngredienteProducto> requeridosEditables = List.from(
      ingredientesRequeridos,
    );
    List<IngredienteProducto> opcionalesEditables = List.from(
      ingredientesOpcionales,
    );

    // Variables para manejar ingredientes disponibles con cache optimizado
    List<Ingrediente> ingredientesDisponibles = [];
    bool isLoading = true;

    return await showDialog<Map<String, List<IngredienteProducto>>>(
      context: context,
      barrierDismissible:
          false, // Evitar cerrar accidentalmente durante la carga
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 🚀 OPTIMIZACIÓN: Cargar ingredientes con mejor UX
            if (isLoading) {
              _cargarIngredientesDisponibles()
                  .then((ingredientes) {
                    if (mounted) {
                      setState(() {
                        ingredientesDisponibles = ingredientes;
                        isLoading = false;
                      });
                    }
                  })
                  .catchError((error) {
                    if (mounted) {
                      setState(() {
                        isLoading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error cargando ingredientes: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  });
            }
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: Row(
                children: [
                  Icon(Icons.restaurant_menu, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gestionar Ingredientes - ${tipoProducto == 'combo' ? 'Combo' : 'Individual'}',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: isLoading
                    ? const IngredientesLoadingWidget()
                    : Column(
                        children: [
                          // Información del tipo
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tipoProducto == 'combo'
                                  ? '• Ingredientes requeridos: Se incluyen automáticamente\n• Ingredientes opcionales: El cliente puede elegir'
                                  : '• Solo ingredientes requeridos: Se descuentan automáticamente del inventario',
                              style: TextStyle(
                                color: AppTheme.textPrimary.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Tabs para ingredientes requeridos y opcionales
                          Expanded(
                            child: DefaultTabController(
                              length: tipoProducto == 'combo' ? 2 : 1,
                              child: Column(
                                children: [
                                  TabBar(
                                    labelColor: AppTheme.primary,
                                    unselectedLabelColor: AppTheme.textPrimary
                                        .withOpacity(0.6),
                                    indicatorColor: AppTheme.primary,
                                    tabs: [
                                      Tab(text: 'Requeridos'),
                                      if (tipoProducto == 'combo')
                                        Tab(text: 'Opcionales'),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        // Tab de ingredientes requeridos
                                        _buildIngredientesTab(
                                          ingredientes: requeridosEditables,
                                          esOpcional: false,
                                          ingredientesDisponibles:
                                              ingredientesDisponibles,
                                          onAdd: () =>
                                              _showSelectIngredienteDialog(
                                                false,
                                                requeridosEditables,
                                                setState,
                                                ingredientesDisponibles,
                                              ),
                                          onRemove: (index) => setState(
                                            () => requeridosEditables.removeAt(
                                              index,
                                            ),
                                          ),
                                          setState: setState,
                                        ),
                                        // Tab de ingredientes opcionales (solo para combos)
                                        if (tipoProducto == 'combo')
                                          _buildIngredientesTab(
                                            ingredientes: opcionalesEditables,
                                            esOpcional: true,
                                            ingredientesDisponibles:
                                                ingredientesDisponibles,
                                            onAdd: () =>
                                                _showSelectIngredienteDialog(
                                                  true,
                                                  opcionalesEditables,
                                                  setState,
                                                  ingredientesDisponibles,
                                                ),
                                            onRemove: (index) => setState(
                                              () => opcionalesEditables
                                                  .removeAt(index),
                                            ),
                                            setState: setState,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'requeridos': requeridosEditables,
                      'opcionales': opcionalesEditables,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildIngredientesTab({
    required List<IngredienteProducto> ingredientes,
    required bool esOpcional,
    required List<Ingrediente> ingredientesDisponibles,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required StateSetter setState,
  }) {
    return Column(
      children: [
        // Botón agregar
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: Icon(Icons.add),
          label: Text('Agregar Ingrediente'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
        SizedBox(height: 8),

        // Lista de ingredientes
        Expanded(
          child: ingredientes.isEmpty
              ? Center(
                  child: Text(
                    'No hay ingredientes ${esOpcional ? 'opcionales' : 'requeridos'} configurados',
                    style: TextStyle(
                      color: AppTheme.textPrimary.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: ingredientes.length,
                  itemBuilder: (context, index) {
                    final ingrediente = ingredientes[index];
                    return Card(
                      color: AppTheme.cardBg.withOpacity(0.5),
                      child: ListTile(
                        title: Text(
                          ingrediente.ingredienteNombre,
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          'Cantidad: ${ingrediente.cantidadNecesaria}',
                          style: TextStyle(
                            color: AppTheme.textPrimary.withOpacity(0.7),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => onRemove(index),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // 🚀 OPTIMIZACIÓN: Método optimizado con cache y paginación
  void _showSelectIngredienteDialog(
    bool esOpcional,
    List<IngredienteProducto> lista,
    StateSetter parentSetState,
    List<Ingrediente> ingredientesDisponibles,
  ) {
    Ingrediente? selectedIngrediente;
    final cantidadController = TextEditingController();
    final searchController = TextEditingController();
    List<Ingrediente> ingredientesFiltrados = List.from(
      ingredientesDisponibles,
    );

    // Variables para paginación optimizada
    int itemsPorPagina = PerformanceConfig.ingredientesDialogoPorPagina;
    int paginaActual = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            // 🚀 OPTIMIZACIÓN: Función de filtrado con paginación
            void filtrarIngredientes(String query) {
              dialogSetState(() {
                List<Ingrediente> todosLosResultados;
                if (query.isEmpty) {
                  todosLosResultados = List.from(ingredientesDisponibles);
                } else {
                  todosLosResultados = ingredientesDisponibles.where((
                    ingrediente,
                  ) {
                    return ingrediente.nombre.toLowerCase().contains(
                          query.toLowerCase(),
                        ) ||
                        ingrediente.categoria.toLowerCase().contains(
                          query.toLowerCase(),
                        );
                  }).toList();
                }

                // Aplicar paginación para mejorar rendimiento
                int startIndex = paginaActual * itemsPorPagina;
                int endIndex = (startIndex + itemsPorPagina).clamp(
                  0,
                  todosLosResultados.length,
                );
                ingredientesFiltrados = todosLosResultados.sublist(
                  startIndex,
                  endIndex,
                );
              });
            }

            return Dialog(
              backgroundColor: AppTheme.cardBg,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      'Seleccionar Ingrediente ${esOpcional ? 'Opcional' : 'Requerido'}',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Barra de búsqueda
                    TextField(
                      controller: searchController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Buscar ingrediente...',
                        labelStyle: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                        ),
                        prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: AppTheme.textPrimary,
                                ),
                                onPressed: () {
                                  searchController.clear();
                                  filtrarIngredientes('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppTheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: filtrarIngredientes,
                    ),
                    SizedBox(height: 16),

                    // Lista de ingredientes
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.textPrimary.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ingredientesFiltrados.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: AppTheme.textPrimary.withOpacity(
                                        0.5,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No se encontraron ingredientes',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary.withOpacity(
                                          0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: ingredientesFiltrados.length,
                                itemBuilder: (context, index) {
                                  final ingrediente =
                                      ingredientesFiltrados[index];
                                  final isSelected =
                                      selectedIngrediente?.id == ingrediente.id;

                                  return ListTile(
                                    title: Text(
                                      ingrediente.nombre,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppTheme.primary
                                            : AppTheme.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${ingrediente.categoria} - ${ingrediente.unidad} - Stock: ${ingrediente.cantidad}',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary.withOpacity(
                                          0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? Icon(
                                            Icons.check_circle,
                                            color: AppTheme.primary,
                                          )
                                        : null,
                                    selected: isSelected,
                                    selectedTileColor: AppTheme.primary
                                        .withOpacity(0.1),
                                    onTap: () {
                                      dialogSetState(() {
                                        selectedIngrediente = ingrediente;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Campos de cantidad y precio
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cantidadController,
                            style: TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Cantidad necesaria',
                              labelStyle: TextStyle(
                                color: AppTheme.textPrimary.withOpacity(0.7),
                              ),
                              filled: true,
                              fillColor: AppTheme.cardBg.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                                
                              dialogSetState(
                                () {},
                              ); // ✅ FIX: Usar dialogSetState para actualizar el botón
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed:
                              _canAddIngrediente(
                                selectedIngrediente,
                                cantidadController.text,
                              )
                              ? () {
                                  final nuevoIngrediente = IngredienteProducto(
                                    ingredienteId: selectedIngrediente!.id,
                                    ingredienteNombre:
                                        selectedIngrediente!.nombre,
                                    cantidadNecesaria:
                                        double.tryParse(
                                          cantidadController.text,
                                        ) ??
                                        1.0,
                                    esOpcional: esOpcional,
                                    precioAdicional:
                                        0.0, // ✅ SIEMPRE 0 - No hay precio adicional
                                  );

                                  parentSetState(() {
                                    lista.add(nuevoIngrediente);
                                  });

                                  Navigator.of(context).pop();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Agregar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ✅ FIX: Método para validar si se puede agregar el ingrediente
  bool _canAddIngrediente(
    Ingrediente? selectedIngrediente,
    String cantidadText,
  ) {
    if (selectedIngrediente == null) return false;
    if (cantidadText.isEmpty) return false;

    final cantidad = double.tryParse(cantidadText);
    if (cantidad == null || cantidad <= 0) return false;

    return true;
  }

  // Método para mostrar el diálogo de carga masiva
  void _mostrarDialogoCargaMasiva() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.upload_file, color: Colors.green),
              SizedBox(width: 12),
              Text('Carga Masiva de Productos'),
            ],
          ),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sube un archivo Excel (.xlsx o .xls) con los productos a cargar.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  'El archivo debe contener las siguientes columnas:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• CODIGO*\n'
                  '• NOMBRE DEL PRODUCTO*\n'
                  '• PRECIO VENTA PRINCIPAL*\n'
                  '• COSTO UNITARIO*\n'
                  '• PRODUCTO O SERVICIO*\n'
                  '• CONTROL DE INVENTARIO\n'
                  '• % IMPUESTO\n'
                  '• INVENTARIO BAJO\n'
                  '• INVENTARIO ÓPTIMO\n'
                  '• Y más...',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _seleccionarYCargarArchivo();
              },
              icon: Icon(Icons.folder_open),
              label: Text('Seleccionar Archivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Método para seleccionar y cargar el archivo Excel
  Future<void> _seleccionarYCargarArchivo() async {
    try {
        
        

      if (kIsWeb) {
        // En web, usar HTML input file directamente
        await _seleccionarArchivoWeb();
      } else {
        // En desktop/mobile, usar file_picker
        await _seleccionarArchivoDesktop();
      }
    } catch (e, stackTrace) {
        
        

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  // Método específico para web usando HTML input
  Future<void> _seleccionarArchivoWeb() async {
      

    // Crear input file
    final html.FileUploadInputElement uploadInput =
        html.FileUploadInputElement();
    uploadInput.accept =
        '.xlsx,.xls,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel';
    uploadInput.click();

    // Esperar a que el usuario seleccione un archivo
    await uploadInput.onChange.first;

    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
        
      return;
    }

    final file = files[0];
      
      

    // Mostrar diálogo de carga
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando productos...'),
                    SizedBox(height: 8),
                    Text(
                      'Por favor espera',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Leer el archivo como bytes
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final bytes = reader.result as Uint8List;
      

    // Enviar el archivo
    await _cargarArchivoExcelBytes(bytes, file.name);

    // Cerrar diálogo de carga
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Método específico para desktop/mobile usando file_picker
  Future<void> _seleccionarArchivoDesktop() async {
      

    FilePickerResult? result;

    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withReadStream: true,
      );
    } catch (pickerError) {
        
      throw Exception('Error al abrir selector de archivos: $pickerError');
    }

    // Verificar si se canceló la selección
    if (result == null) {
        
      return;
    }

    // Verificar si hay archivos seleccionados
    if (result.files.isEmpty) {
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se seleccionó ningún archivo'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    PlatformFile file = result.files.first;
      
      
      

    if (file.path == null || file.path!.isEmpty) {
      throw Exception('No se pudo obtener la ruta del archivo');
    }

    // Mostrar diálogo de carga
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando productos...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

      
    await _cargarArchivoExcel(file.path!);

    // Cerrar diálogo de carga
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Método para cargar el archivo Excel al backend usando bytes (para web)
  Future<void> _cargarArchivoExcelBytes(
    List<int> bytes,
    String fileName,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendBaseUrl/api/productos/carga-masiva'),
      );

      // Agregar el archivo desde bytes
      request.files.add(
        http.MultipartFile.fromBytes('archivo', bytes, filename: fileName),
      );

      // Enviar la petición
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Productos cargados exitosamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Recargar los productos
        await _cargarDatosDesdeCache();
      } else {
        throw Exception(
          'Error al cargar productos: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar productos: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Método para cargar el archivo Excel al backend usando path (para desktop/mobile)
  Future<void> _cargarArchivoExcel(String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendBaseUrl/api/productos/carga-masiva'),
      );

      // Agregar el archivo
      request.files.add(await http.MultipartFile.fromPath('archivo', filePath));

      // Enviar la petición
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Productos cargados exitosamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Recargar los productos
        await _cargarDatosDesdeCache();
      } else {
        throw Exception(
          'Error al cargar productos: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar productos: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ============================================
  // IMPRESIÓN DE CÓDIGOS DE BARRAS
  // ============================================

  void _mostrarDialogoImprimirCodigoBarras() {
    final productoController = TextEditingController();
    Producto? productoSeleccionado;
    String unidadMedida = 'Unics';
    String tipoFecha = '-Fect';
    String mostrarPrecio = 'Si';
    int cantidad = 2;
    String tipoLista = '-Lis.p';
    String tipoPrecio = '-Prec';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: Row(
              children: [
                Icon(Icons.qr_code_2, color: AppTheme.primary),
                SizedBox(width: 12),
                Text(
                  'Imprimir código de barras',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
                ),
              ],
            ),
            content: Container(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campo de búsqueda de producto
                    Text(
                      'Producto',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Autocomplete<Producto>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Producto>.empty();
                        }
                        return _productosCache
                            .where((Producto producto) {
                              return producto.nombre.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  ) ||
                                  producto.id.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  );
                            })
                            .take(10);
                      },
                      displayStringForOption: (Producto producto) =>
                          producto.nombre,
                      onSelected: (Producto producto) {
                        setDialogState(() {
                          productoSeleccionado = producto;
                          productoController.text = producto.nombre;
                        });
                      },
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Buscar producto...',
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: AppTheme.primary,
                                ),
                              ),
                            );
                          },
                    ),
                    SizedBox(height: 20),

                    // Fila de opciones
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        // Unidad de medida
                        _buildDropdownField(
                          'Unidad',
                          unidadMedida,
                          ['Unics', 'Kg', 'Lt', 'Mt', 'Und'],
                          (value) =>
                              setDialogState(() => unidadMedida = value!),
                          120,
                        ),

                        // Tipo de fecha
                        _buildDropdownField(
                          'Fecha',
                          tipoFecha,
                          ['-Fect', '+Fect', 'N/A'],
                          (value) => setDialogState(() => tipoFecha = value!),
                          120,
                        ),

                        // Mostrar precio
                        _buildDropdownField(
                          'Precio',
                          mostrarPrecio,
                          ['Si', 'No'],
                          (value) =>
                              setDialogState(() => mostrarPrecio = value!),
                          100,
                        ),

                        // Cantidad
                        Container(
                          width: 100,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cantidad',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              TextField(
                                controller: TextEditingController(
                                  text: cantidad.toString(),
                                ),
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.surfaceDark,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (value) {
                                  final val = int.tryParse(value);
                                  if (val != null && val > 0) {
                                    setDialogState(() => cantidad = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        // Lista de precios
                        _buildDropdownField(
                          'Lista',
                          tipoLista,
                          ['-Lis.p', '+Lis.p', 'Detal', 'Mayor'],
                          (value) => setDialogState(() => tipoLista = value!),
                          120,
                        ),

                        // Tipo de precio
                        _buildDropdownField(
                          'Tipo',
                          tipoPrecio,
                          ['-Prec', '+Prec', 'Base'],
                          (value) => setDialogState(() => tipoPrecio = value!),
                          120,
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Vista previa
                    if (productoSeleccionado != null)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Vista previa',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildCodigoBarrasPreview(
                              productoSeleccionado!,
                              mostrarPrecio: mostrarPrecio == 'Si',
                              unidadMedida: unidadMedida,
                              tipoFecha: tipoFecha,
                              tipoLista: tipoLista,
                              tipoPrecio: tipoPrecio,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton.icon(
                onPressed:
                    productoSeleccionado == null ||
                        productoSeleccionado!.codigo == null
                    ? null
                    : () {
                        _imprimirCodigoBarras(
                          productoSeleccionado!,
                          cantidad,
                          mostrarPrecio == 'Si',
                        );
                        Navigator.pop(context);
                      },
                icon: Icon(Icons.print),
                label: Text('Imprimir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor: AppTheme.textMuted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
    double width,
  ) {
    return Container(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: value,
            items: items
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: onChanged,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            dropdownColor: AppTheme.surfaceDark,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodigoBarrasPreview(
    Producto producto, {
    required bool mostrarPrecio,
    required String unidadMedida,
    required String tipoFecha,
    required String tipoLista,
    required String tipoPrecio,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Unidad de medida y tipo de fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                unidadMedida,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                tipoFecha,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          // Nombre del producto
          Text(
            producto.nombre,
            style: TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          // Tipo de lista y tipo de precio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tipoLista,
                style: TextStyle(color: Colors.black, fontSize: 9),
              ),
              Text(
                tipoPrecio,
                style: TextStyle(color: Colors.black, fontSize: 9),
              ),
            ],
          ),
          SizedBox(height: 4),
          // Precio (solo si está seleccionado)
          if (mostrarPrecio)
            Text(
              '\$${producto.precio.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (mostrarPrecio) SizedBox(height: 8),
          // Código de barras
          if (producto.codigoBarras != null &&
              producto.codigoBarras!.isNotEmpty)
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: producto.codigoBarras!,
              width: 180,
              height: 60,
              drawText: false,
            )
          else if (producto.codigo != null && producto.codigo!.isNotEmpty)
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: producto.codigo!,
              width: 180,
              height: 60,
              drawText: false,
            )
          else
            Container(
              padding: EdgeInsets.all(20),
              child: Text(
                'Sin código de barras',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          SizedBox(height: 4),
          // Número del código
          Text(
            producto.codigoBarras ?? producto.codigo ?? 'N/A',
            style: TextStyle(color: Colors.black, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _imprimirCodigoBarras(
    Producto producto,
    int cantidad,
    bool mostrarPrecio,
  ) async {
    try {
      final pdf = pw.Document();

      // Crear una página con múltiples etiquetas
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (context) {
            List<pw.Widget> etiquetas = [];

            for (int i = 0; i < cantidad; i++) {
              etiquetas.add(
                pw.Container(
                  width: 250,
                  margin: pw.EdgeInsets.all(8),
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      // Identificador
                      pw.Text(
                        'a',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      // Nombre del producto
                      pw.Text(
                        producto.nombre,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                        maxLines: 2,
                      ),
                      pw.SizedBox(height: 4),
                      // Precio
                      if (mostrarPrecio)
                        pw.Text(
                          '\$${producto.precio.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      pw.SizedBox(height: 8),
                      // Código de barras
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(),
                        data: producto.codigo ?? producto.id,
                        width: 180,
                        height: 60,
                        drawText: false,
                      ),
                      pw.SizedBox(height: 4),
                      // Número del código
                      pw.Text(
                        producto.codigo ?? producto.id,
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Organizar en grid de 2 columnas
            List<pw.Widget> rows = [];
            for (int i = 0; i < etiquetas.length; i += 2) {
              rows.add(
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    etiquetas[i],
                    if (i + 1 < etiquetas.length) etiquetas[i + 1],
                  ],
                ),
              );
            }

            return rows;
          },
        ),
      );

      // Mostrar diálogo de impresión
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Codigo_Barras_${producto.nombre}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código de barras generado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar código de barras: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
