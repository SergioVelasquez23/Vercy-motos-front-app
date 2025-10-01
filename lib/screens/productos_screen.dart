import '../widgets/imagen_producto_widget.dart';
import '../widgets/image_upload_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/ingrediente.dart';
import '../services/producto_service.dart';
import '../services/ingrediente_service.dart';
import '../services/image_service.dart';
import '../utils/format_utils.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  // Cambia esto por tu dominio backend real si es diferente
  static const String _backendBaseUrl = "https://sopa-y-carbon.onrender.com";
  final ProductoService _productoService = ProductoService();
  final ImageService _imageService = ImageService();
  final IngredienteService _ingredienteService = IngredienteService();
  List<Categoria> _categorias = [];
  List<Producto> _productos = [];
  List<Ingrediente> _ingredientesCarnes = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoriaId;
  Future<List<Producto>>? _productosFuture;

  @override
  void initState() {
    super.initState();
    _cargarDatos(); // Cargar datos al iniciar
    // Actualizar la lista de productos cuando cambia el texto de búsqueda
    _searchController.addListener(() {
      setState(() {
        _productosFuture = _filtrarProductos();
      });
    });
  }

  Future<void> _cargarDatos() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      // Cargar datos en paralelo
      final categorias = await _productoService.getCategorias();
      final productos = await _productoService.getProductos();
      final ingredientesCarnes = await _ingredienteService
          .getIngredientesCarnes();

      if (mounted) {
        setState(() {
          _categorias = categorias;
          _productos = productos;
          _ingredientesCarnes = ingredientesCarnes;
          _isLoading = false;
          // Inicializar el future para cargar los productos
          _productosFuture = _filtrarProductos();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Producto>> _filtrarProductos() async {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty && _selectedCategoriaId == null) {
      return _productos;
    }

    try {
      return await _productoService.searchProductos(
        query,
        categoriaId: _selectedCategoriaId,
      );
    } catch (e) {
      // En caso de error, devolver lista local filtrada
      return _productos.where((producto) {
        final matchesQuery =
            query.isEmpty || producto.nombre.toLowerCase().contains(query);
        final matchesCategory =
            _selectedCategoriaId == null ||
            producto.categoria?.id == _selectedCategoriaId;
        return matchesQuery && matchesCategory;
      }).toList();
    }
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
                  onPressed: _cargarDatos,
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
          Container(
            margin: EdgeInsets.only(right: AppTheme.spacingSmall),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(Icons.image, size: 20),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ImageUploadHelper(),
                );
              },
              tooltip: 'Gestionar Imágenes',
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: AppTheme.spacingSmall),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(Icons.category, size: 20),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/categorias');
              },
              tooltip: 'Gestionar Categorías',
            ),
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
                SizedBox(height: 20),
                // Filtros de categorías
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Categorías',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  height: 45,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Chip "Todas"
                      Container(
                        margin: EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategoriaId = null;
                              _productosFuture = _filtrarProductos();
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: _selectedCategoriaId == null
                                  ? LinearGradient(
                                      colors: [
                                        AppTheme.primary,
                                        AppTheme.primaryLight,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: _selectedCategoriaId == null
                                  ? null
                                  : AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: _selectedCategoriaId == null
                                    ? AppTheme.primary
                                    : AppTheme.textMuted.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: _selectedCategoriaId == null
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.apps,
                                  color: _selectedCategoriaId == null
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Todas',
                                  style: TextStyle(
                                    color: _selectedCategoriaId == null
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Chips de categorías
                      ..._categorias.map((categoria) {
                        final isSelected = _selectedCategoriaId == categoria.id;
                        return Container(
                          margin: EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategoriaId = isSelected
                                    ? null
                                    : categoria.id;
                                _productosFuture = _filtrarProductos();
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [
                                          AppTheme.primary,
                                          AppTheme.primaryLight,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isSelected ? null : AppTheme.cardBg,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primary.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                categoria.nombre,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de productos
          Expanded(
            child: FutureBuilder<List<Producto>>(
              future: _productosFuture ??= _filtrarProductos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Error al filtrar productos',
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  );
                }

                final productos = snapshot.data ?? [];

                if (productos.isEmpty) {
                  return Center(
                    child: Text(
                      'No se encontraron productos',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final producto = productos[index];
                    return _buildProductoItem(producto);
                  },
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
                await _productoService.deleteProducto(producto.id);
                Navigator.of(context).pop();

                // Recargar datos después de eliminar
                await _cargarDatos();

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
    String tipoProducto = isEditing ? producto.tipoProducto : 'individual';
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
                                // Subir la imagen usando el servicio de imágenes
                                final filename = await _imageService
                                    .uploadImage(pickedFile);
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
                          value: 'individual',
                          child: Text(
                            'Individual (Selección libre)',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ),
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

                    // Botón para gestionar ingredientes (solo para combos)
                    if (tipoProducto == 'combo') ...[
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
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ],

                    // Ingredientes para productos individuales
                    if (tipoProducto == 'individual') ...[
                      Text(
                        'Ingredientes disponibles:',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Selecciona los ingredientes que estarán disponibles para este producto:',
                        style: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 12),

                      // Botón para cargar y seleccionar ingredientes de la base de datos
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Cargar ingredientes de la base de datos
                          final ingredientesDB =
                              await _cargarIngredientesDisponibles();

                          // Mostrar diálogo de selección
                          final ingredientesSeleccionadosDB =
                              await showDialog<List<String>>(
                                context: context,
                                builder: (context) =>
                                    _buildIngredientesIndividualesDialog(
                                      ingredientesDB,
                                      ingredientesSeleccionados,
                                    ),
                              );

                          if (ingredientesSeleccionadosDB != null) {
                            setState(() {
                              ingredientesSeleccionados =
                                  ingredientesSeleccionadosDB;
                            });
                          }
                        },
                        icon: Icon(Icons.add_circle_outline),
                        label: Text('Seleccionar Ingredientes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),

                      // Mostrar ingredientes seleccionados
                      if (ingredientesSeleccionados.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ingredientes seleccionados:',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${ingredientesSeleccionados.length} ingredientes seleccionados',
                                style: TextStyle(
                                  color: AppTheme.textPrimary.withOpacity(0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ],

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
                              final bool isSelected = ingredientesSeleccionados
                                  .contains(ingrediente.nombre);
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
                    isEditing ? 'Actualizar' : 'Guardar',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                  onPressed: () async {
                    // Validar campos
                    if (nombreController.text.isEmpty ||
                        precioController.text.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Complete los campos requeridos'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      return;
                    }

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
                      print('⚠️ No se ha seleccionado ninguna categoría');
                    }

                    // Obtener imagen final
                    String? finalImageUrl = selectedImageUrl;

                    // Crear o actualizar el producto
                    try {
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
                          descripcion: descripcionController.text.isNotEmpty
                              ? descripcionController.text
                              : null,
                          impuestos:
                              double.tryParse(impuestosController.text) ?? 0,
                          utilidad:
                              double.tryParse(utilidadController.text) ?? 0,
                          tieneVariantes: tieneVariantes,
                          estado: estado,
                          ingredientesDisponibles: ingredientesSeleccionados,
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

                        await _productoService.updateProducto(updatedProducto);
                      } else {
                        // Crear nuevo producto con el sistema actualizado
                        final nuevoProducto = Producto(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          nombre: nombreController.text,
                          precio: double.parse(precioController.text),
                          costo: double.parse(costoController.text),
                          imagenUrl: finalImageUrl,
                          categoria: categoriaSeleccionada,
                          descripcion: descripcionController.text.isNotEmpty
                              ? descripcionController.text
                              : null,
                          impuestos:
                              double.tryParse(impuestosController.text) ?? 0,
                          utilidad:
                              double.tryParse(utilidadController.text) ?? 0,
                          tieneVariantes: tieneVariantes,
                          estado: estado,
                          ingredientesDisponibles: ingredientesSeleccionados,
                          tieneIngredientes: tieneIngredientes,
                          tipoProducto: tipoProducto,
                          ingredientesRequeridos: ingredientesRequeridos,
                          ingredientesOpcionales: ingredientesOpcionales,
                        );
                        await _productoService.addProducto(nuevoProducto);
                      }

                      Navigator.of(context).pop();

                      // Recargar datos después de crear/actualizar
                      await _cargarDatos();

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

  // Método para cargar ingredientes disponibles de la base de datos
  Future<List<Ingrediente>> _cargarIngredientesDisponibles() async {
    try {
      final ingredienteService = IngredienteService();
      return await ingredienteService.getAllIngredientes();
    } catch (e) {
      print('Error cargando ingredientes: $e');
      return [];
    }
  }

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

    // Variables para manejar ingredientes disponibles
    List<Ingrediente> ingredientesDisponibles = [];
    bool isLoading = true;

    return await showDialog<Map<String, List<IngredienteProducto>>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Cargar ingredientes disponibles al mostrar el diálogo
            if (isLoading) {
              _cargarIngredientesDisponibles().then((ingredientes) {
                setState(() {
                  ingredientesDisponibles = ingredientes;
                  isLoading = false;
                });
              });
            }
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: Text(
                'Gestionar Ingredientes - ${tipoProducto == 'combo' ? 'Combo' : 'Individual'}',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppTheme.primary),
                            SizedBox(height: 16),
                            Text(
                              'Cargando ingredientes disponibles...',
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      )
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

  void _showSelectIngredienteDialog(
    bool esOpcional,
    List<IngredienteProducto> lista,
    StateSetter parentSetState,
    List<Ingrediente> ingredientesDisponibles,
  ) {
    Ingrediente? selectedIngrediente;
    final cantidadController = TextEditingController();
    final precioController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: Text(
                'Seleccionar Ingrediente ${esOpcional ? 'Opcional' : 'Requerido'}',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Ingrediente>(
                    initialValue: selectedIngrediente,
                    onChanged: (Ingrediente? value) {
                      dialogSetState(() {
                        selectedIngrediente = value;
                      });
                    },
                    items: ingredientesDisponibles.map((ingrediente) {
                      return DropdownMenuItem<Ingrediente>(
                        value: ingrediente,
                        child: Text(
                          '${ingrediente.nombre} (${ingrediente.unidad})',
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Seleccionar ingrediente',
                      labelStyle: TextStyle(
                        color: AppTheme.textPrimary.withOpacity(0.7),
                      ),
                      filled: true,
                      fillColor: AppTheme.cardBg.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    dropdownColor: AppTheme.cardBg,
                  ),
                  SizedBox(height: 16),
                  TextField(
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
                  ),
                  SizedBox(height: 16),
                  if (esOpcional) ...[
                    TextField(
                      controller: precioController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Precio adicional (opcional)',
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
                    ),
                  ],
                ],
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
                    if (selectedIngrediente != null &&
                        cantidadController.text.isNotEmpty) {
                      final nuevoIngrediente = IngredienteProducto(
                        ingredienteId: selectedIngrediente!.id,
                        ingredienteNombre: selectedIngrediente!.nombre,
                        cantidadNecesaria:
                            double.tryParse(cantidadController.text) ?? 1.0,
                        esOpcional: esOpcional,
                        precioAdicional:
                            double.tryParse(precioController.text) ?? 0.0,
                      );

                      parentSetState(() {
                        lista.add(nuevoIngrediente);
                      });

                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: Text('Agregar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildIngredientesIndividualesDialog(
    List<Ingrediente> ingredientesDisponibles,
    List<String> ingredientesSeleccionados,
  ) {
    List<String> selectedIds = List.from(ingredientesSeleccionados);

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(
            'Seleccionar Ingredientes',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Text(
                  'Selecciona los ingredientes disponibles para este producto:',
                  style: TextStyle(
                    color: AppTheme.textPrimary.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: ingredientesDisponibles.length,
                    itemBuilder: (context, index) {
                      final ingrediente = ingredientesDisponibles[index];
                      final isSelected = selectedIds.contains(ingrediente.id);

                      return CheckboxListTile(
                        title: Text(
                          ingrediente.nombre,
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          '${ingrediente.categoria} - ${ingrediente.unidad}',
                          style: TextStyle(
                            color: AppTheme.textPrimary.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedIds.add(ingrediente.id);
                            } else {
                              selectedIds.remove(ingrediente.id);
                            }
                          });
                        },
                        activeColor: AppTheme.primary,
                        checkColor: Colors.white,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selectedIds),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              child: Text('Confirmar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
