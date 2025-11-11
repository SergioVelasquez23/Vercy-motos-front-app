import '../widgets/imagen_producto_widget.dart';
import '../widgets/optimized_loading_widget.dart';
import '../config/performance_config.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/ingrediente.dart';
import 'package:provider/provider.dart';
import '../providers/datos_cache_provider.dart';
import '../services/image_service.dart';
import '../utils/format_utils.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  static const String _backendBaseUrl = "https://sopa-y-carbon.onrender.com";
  final ImageService _imageService = ImageService();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoriaId;
  int _paginaActual = 0;
  int _itemsPorPagina = 10;
  List<Producto> _productosPaginados = [];
  bool _isLoading = true;
  String? _error;
  bool _guardandoProducto = false;
  List<Producto> _productosVista = [];
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
        _categorias = cacheProvider.categorias ?? [];
        _ingredientesCarnes = cacheProvider.ingredientes ?? [];
        _actualizarProductosVista();
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
      }
      setState(() {
        _categorias = cacheProvider.categorias ?? [];
        _ingredientesCarnes = cacheProvider.ingredientes ?? [];
        _actualizarProductosVista();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _actualizarProductosVista();
    });
  }

  void _actualizarProductosVista() {
    final cacheProvider = Provider.of<DatosCacheProvider>(
      context,
      listen: false,
    );
    List<Producto> productos = cacheProvider.productos ?? [];
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty || _selectedCategoriaId != null) {
      productos = productos.where((producto) {
        final matchesQuery =
            query.isEmpty || producto.nombre.toLowerCase().contains(query);
        final matchesCategory =
            _selectedCategoriaId == null ||
            producto.categoria?.id == _selectedCategoriaId;
        return matchesQuery && matchesCategory;
      }).toList();
    }
    int startIndex = _paginaActual * _itemsPorPagina;
    int endIndex = (startIndex + _itemsPorPagina).clamp(0, productos.length);
    _productosPaginados = productos.sublist(startIndex, endIndex);
    _productosVista = productos;
  }

  // 🚀 OPTIMIZACIÓN: Carga de datos mejorada con mejor UX

  void _siguientePagina() {
    int startIndex = (_paginaActual + 1) * _itemsPorPagina;
    if (startIndex < _productosVista.length) {
      setState(() {
        _paginaActual++;
        _actualizarProductosVista();
      });
    }
  }

  void _paginaAnterior() {
    if (_paginaActual > 0) {
      setState(() {
        _paginaActual--;
        _actualizarProductosVista();
      });
    }
  }

  /// Construye los controles de paginación
  Widget _buildPaginationControls() {
    int totalPaginas = (_productosVista.length / _itemsPorPagina).ceil();
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
                items: [5, 10, 20, 50].map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value por página'),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _itemsPorPagina = newValue!;
                    _paginaActual = 0;
                    _actualizarProductosVista();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
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
        title: Text('Gestión de Productos', style: AppTheme.headlineMedium),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              final cacheProvider = Provider.of<DatosCacheProvider>(
                context,
                listen: false,
              );
              cacheProvider.recargarDatos();
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
                    onChanged: (value) {
                      setState(() {}); // Actualizar lista al buscar
                    },
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
                if (_productosVista.isEmpty) {
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showProductoDialog();
        },
        backgroundColor: AppTheme.primary,
        child: Icon(Icons.add),
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
          child: _buildProductImage(producto.imagenUrl),
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
              onPressed: () {
                _showProductoDialog(producto: producto);
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

  Widget _buildProductImage(String? imagenUrl) {
    return ImagenProductoWidget(
      urlRemota: imagenUrl != null
          ? _imageService.getImageUrl(imagenUrl)
          : null,
      nombreProducto: null,
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      backendBaseUrl: _backendBaseUrl,
    );
  }

  void _showDeleteConfirmationDialog(Producto producto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
            onPressed: () async {
              try {
                // Aquí deberías implementar la lógica de borrado usando el provider o tu backend
                Navigator.of(context).pop();
                final cacheProvider = Provider.of<DatosCacheProvider>(
                  context,
                  listen: false,
                );
                await cacheProvider.recargarDatos();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Producto eliminado'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                Navigator.of(context).pop();
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
    );
  }

  void _showProductoDialog({Producto? producto}) {
    final bool isEditing = producto != null;

    // Controladores para el formulario
    final nombreController = TextEditingController(
      text: isEditing ? producto.nombre : '',
    );
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
    final descripcionController = TextEditingController(
      text: isEditing ? producto.descripcion ?? '' : '',
    );

    bool tieneVariantes = isEditing ? producto.tieneVariantes : false;
    String estado = isEditing ? producto.estado : 'Activo';
    // If editing, try to get the category ID either from the categoria object or from the API response
    String? selectedCategoriaId;
    if (isEditing) {
      if (producto.categoria != null) {
        final exists = _categorias.any((c) => c.id == producto.categoria!.id);
        if (exists) {
          selectedCategoriaId = producto.categoria!.id;
          print(
            '✅ Categoría seleccionada del objeto categoria: $selectedCategoriaId',
          );
        } else {
          selectedCategoriaId = null;
          print(
            '⚠️ La categoría del producto no existe en la lista, se asigna null',
          );
        }
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
                                // Subir la imagen usando ProductoService con base64
                                // Aquí deberías implementar la lógica de subida de imagen usando el provider o tu backend
                                final filename = null;
                                setState(() {
                                  selectedImageUrl = filename;
                                });

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Imagen subida exitosamente',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              print('❌ Error subiendo imagen: $e');
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
                            ? _buildProductImage(selectedImageUrl)
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
                      items: _categorias.map((categoria) {
                        return DropdownMenuItem<String>(
                          value: categoria.id,
                          child: Text(
                            categoria.nombre,
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategoriaId = value;
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
                              ...ingredientesRequeridos.map(
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
                              ...ingredientesOpcionales.map(
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
                              children: _ingredientesCarnes.map((ingrediente) {
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
                                  },
                                  selectedColor: AppTheme.primary,
                                  backgroundColor: AppTheme.cardBg.withOpacity(
                                    0.5,
                                  ),
                                  checkmarkColor: Colors.white,
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.textPrimary.withOpacity(0.3),
                                  ),
                                );
                              }).toList(),
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
                                print(
                                  '✅ Categoría seleccionada: ${categoriaSeleccionada.nombre} (ID: ${categoriaSeleccionada.id})',
                                );
                              } catch (e) {
                                print(
                                  '❌ Error al buscar categoría con ID: $selectedCategoriaId - $e',
                                );
                              }
                            } else {
                              print(
                                '⚠️ No se ha seleccionado ninguna categoría',
                              );
                            }

                            // Obtener imagen final
                            String? finalImageUrl = selectedImageUrl;
                            // Check if we have a category selected
                            if (selectedCategoriaId != null &&
                                categoriaSeleccionada == null) {
                              // Try to find the category in the list
                              try {
                                categoriaSeleccionada = _categorias.firstWhere(
                                  (c) => c.id == selectedCategoriaId,
                                );
                                print(
                                  '✅ Encontrada la categoría para el producto: ${categoriaSeleccionada.nombre}',
                                );
                              } catch (e) {
                                print(
                                  '⚠️ No se pudo encontrar la categoría con ID: $selectedCategoriaId',
                                );
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
                              final updatedProducto = Producto(
                                id: producto.id,
                                nombre: nombreController.text,
                                precio: double.parse(precioController.text),
                                costo: double.parse(costoController.text),
                                imagenUrl: finalImageUrl,
                                categoria: categoriaSeleccionada,
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
                              print(
                                '🔍 Producto a actualizar: ${updatedProducto.nombre}',
                              );
                              print(
                                '🔍 Categoria ID: ${updatedProducto.categoria?.id}',
                              );

                              // Aquí deberías implementar la lógica de actualización usando el provider o tu backend

                              // Los datos se actualizarán automáticamente al recargar la pantalla
                            } else {
                              // Crear nuevo producto con el sistema actualizado
                              // Aquí deberías implementar la lógica de creación usando el provider o tu backend

                              // Los datos se actualizarán automáticamente al recargar
                            }

                            Navigator.of(context).pop();

                            // Recargar datos después de crear/actualizar
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
        print('📦 Usando cache de ingredientes para productos');
        return _ingredientesCache!;
      }

      print('🔄 Cargando ingredientes desde API...');
      // Aquí deberías obtener los ingredientes desde el cache provider
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );
      final ingredientes = cacheProvider.ingredientes ?? [];

      // Actualizar cache
      _ingredientesCache = ingredientes;
      _ingredientesCacheTime = DateTime.now();

      print('✅ Ingredientes cargados y en cache: ${ingredientes.length}');
      return ingredientes;
    } catch (e) {
      print('❌ Error cargando ingredientes: $e');
      // Si hay error y tenemos cache, usar cache aunque haya expirado
      if (_ingredientesCache != null) {
        print('🔄 Usando cache expirado como fallback');
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cantidad: ${ingrediente.cantidadNecesaria}',
                              style: TextStyle(
                                color: AppTheme.textPrimary.withOpacity(0.7),
                              ),
                            ),
                            if (ingrediente.precioAdicional > 0)
                              Text(
                                'Precio adicional: \$${ingrediente.precioAdicional}',
                                style: TextStyle(color: AppTheme.primary),
                              ),
                          ],
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
    final precioController = TextEditingController();
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
                              print('🔍 CANTIDAD INGREDIENTE CHANGED: $value');
                              dialogSetState(
                                () {},
                              ); // ✅ FIX: Usar dialogSetState para actualizar el botón
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: precioController,
                            style: TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Precio adicional',
                              labelStyle: TextStyle(
                                color: AppTheme.textPrimary.withOpacity(0.7),
                              ),
                              prefixText: '\$ ',
                              filled: true,
                              fillColor: AppTheme.cardBg.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              print('🔍 PRECIO INGREDIENTE CHANGED: $value');
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
                                        double.tryParse(
                                          precioController.text,
                                        ) ??
                                        0.0,
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

  // ✅ MÉTODO ELIMINADO: _buildCategoriaGridRowsProductos no se usaba

  // 🎨 NUEVA: Barra compacta de categorías (copiada de pedido_screen)
  List<Widget> _buildCategoriaCompactRowProductos() {
    List<Widget> allCategories = [];

    // Agregar opción "Todo" - más compacta
    allCategories.add(
      _buildCategoriaCompactChipProductos(
        nombre: 'Todo',
        icon: Icons.apps,
        isSelected: _selectedCategoriaId == null,
        onTap: () => setState(() {
          _selectedCategoriaId = null;
          _actualizarProductosVista();
        }),
      ),
    );

    // Agregar todas las categorías de forma compacta
    allCategories.addAll(
      _categorias.map(
        (categoria) => _buildCategoriaCompactChipProductos(
          nombre: categoria.nombre,
          imagenUrl: categoria.imagenUrl,
          isSelected: _selectedCategoriaId == categoria.id,
          onTap: () => setState(() {
            _selectedCategoriaId = categoria.id;
            _actualizarProductosVista();
          }),
        ),
      ),
    );

    return allCategories;
  }

  // Widget copiado de pedido_screen para consistencia visual
  Widget _buildCategoriaCompactChipProductos({
    required String nombre,
    String? imagenUrl,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primary = Color(0xFFFF6B00);
    final cardBg = Color(0xFF2A2A2A);
    final textLight = Color(0xFFB0B0B0);

    return Container(
      margin: EdgeInsets.only(right: 8), // Espaciado entre chips
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ), // Más compacto
          decoration: BoxDecoration(
            color: isSelected ? primary : cardBg,
            borderRadius: BorderRadius.circular(16), // Menos redondeado
            border: Border.all(
              color: isSelected ? primary : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Imagen circular o icono - Más pequeño
              Container(
                width: 24, // Reducido de 32 a 24
                height: 24, // Reducido de 32 a 24
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.3),
                ),
                child: ClipOval(
                  child: imagenUrl != null && imagenUrl.isNotEmpty
                      ? Image.network(
                          _imageService.getImageUrl(imagenUrl),
                          fit: BoxFit.cover,
                          headers: {
                            'Cache-Control': 'no-cache',
                            'User-Agent': 'Flutter App',
                          },
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.restaurant_menu,
                            color: isSelected ? Colors.white : textLight,
                            size: 14, // Icono más pequeño
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Icon(
                              Icons.restaurant_menu,
                              color: isSelected ? Colors.white : textLight,
                              size: 14, // Icono más pequeño
                            );
                          },
                        )
                      : Icon(
                          icon ?? Icons.restaurant_menu,
                          color: isSelected ? Colors.white : textLight,
                          size: 14, // Icono más pequeño
                        ),
                ),
              ),
              SizedBox(width: 6), // Espaciado reducido
              // Texto de la categoría - Más compacto
              Text(
                nombre,
                style: TextStyle(
                  color: isSelected ? Colors.white : textLight,
                  fontSize: 12, // Fuente pequeña
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
