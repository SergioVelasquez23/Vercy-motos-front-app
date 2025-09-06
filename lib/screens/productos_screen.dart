import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/ingrediente.dart';
import '../services/producto_service.dart';
import '../services/ingrediente_service.dart';
import '../utils/format_utils.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final ProductoService _productoService = ProductoService();
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
    final Color primary = Color(0xFFFF6B00);
    final Color bgDark = Color(0xFF1E1E1E);
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          title: Text(
            'Gestión de Productos',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: primary,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primary),
              SizedBox(height: 16),
              Text('Cargando productos...', style: TextStyle(color: textLight)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          title: Text(
            'Gestión de Productos',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: primary,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 64),
              SizedBox(height: 16),
              Text(
                'Error al cargar productos',
                style: TextStyle(color: textLight, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: textLight.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargarDatos,
                icon: Icon(Icons.refresh),
                label: Text('Reintentar'),
                style: ElevatedButton.styleFrom(backgroundColor: primary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          'Gestión de Productos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.category),
            onPressed: () {
              Navigator.pushNamed(context, '/categorias');
            },
            tooltip: 'Gestionar Categorías',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: textLight),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: primary),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primary),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {}); // Actualizar lista al buscar
                  },
                ),
                SizedBox(height: 10),
                // Filtro de categorías
                SizedBox(
                  height: 50,
                  child: Scrollbar(
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    thumbVisibility: true,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            backgroundColor: _selectedCategoriaId == null
                                ? primary
                                : cardBg,
                            label: Text(
                              'Todas',
                              style: TextStyle(
                                color: _selectedCategoriaId == null
                                    ? Colors.white
                                    : textLight,
                              ),
                            ),
                            onSelected: (bool selected) {
                              setState(() {
                                _selectedCategoriaId = null;
                                // Actualizar future para realizar la nueva búsqueda
                                _productosFuture = _filtrarProductos();
                              });
                            },
                            selected: _selectedCategoriaId == null,
                          ),
                        ),
                        ..._categorias.map((categoria) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              backgroundColor:
                                  _selectedCategoriaId == categoria.id
                                  ? primary
                                  : cardBg,
                              label: Text(
                                categoria.nombre,
                                style: TextStyle(
                                  color: _selectedCategoriaId == categoria.id
                                      ? Colors.white
                                      : textLight,
                                ),
                              ),
                              onSelected: (bool selected) {
                                setState(() {
                                  _selectedCategoriaId = selected
                                      ? categoria.id
                                      : null;
                                  // Actualizar future para realizar la nueva búsqueda con la categoría seleccionada
                                  _productosFuture = _filtrarProductos();
                                });
                              },
                              selected: _selectedCategoriaId == categoria.id,
                            ),
                          );
                        }),
                      ],
                    ),
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
                    child: CircularProgressIndicator(color: primary),
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
                          style: TextStyle(color: textLight),
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
                      style: TextStyle(color: textLight),
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
        backgroundColor: primary,
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductoItem(Producto producto) {
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);
    final Color primary = Color(0xFFFF6B00);

    // Buscar la categoría por ID (solo usando producto.categoria)
    String categoriaNombre = 'Adicional';
    if (producto.categoria != null && producto.categoria!.nombre.isNotEmpty) {
      categoriaNombre = producto.categoria!.nombre;
    } else {
      categoriaNombre = 'Adicional';
    }

    return Card(
      color: cardBg,
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
            color: textLight,
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
                  style: TextStyle(color: primary, fontWeight: FontWeight.bold),
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
                  style: TextStyle(color: textLight.withOpacity(0.7)),
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
              icon: Icon(Icons.edit, color: textLight),
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
    final Color primary = Color(0xFFFF6B00);

    // Si no hay imagen o la URL es inválida
    if (imagenUrl == null || imagenUrl.isEmpty) {
      return Icon(Icons.restaurant, color: primary, size: 32);
    }

    // Si es una URL web
    if (imagenUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imagenUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.restaurant, color: primary, size: 32),
        ),
      );
    }

    // Si es un archivo local
    if (imagenUrl.startsWith('/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imagenUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.restaurant, color: primary, size: 32),
        ),
      );
    }

    // Si es un asset
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        imagenUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.restaurant, color: primary, size: 32),
      ),
    );
  }

  void _showDeleteConfirmationDialog(Producto producto) {
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('¿Eliminar producto?', style: TextStyle(color: textLight)),
        content: Text(
          '¿Está seguro que desea eliminar ${producto.nombre}?',
          style: TextStyle(color: textLight.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            child: Text('Cancelar', style: TextStyle(color: textLight)),
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
    final Color primary = Color(0xFFFF6B00);
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

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
    String? tempImagePath;
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
              backgroundColor: cardBg,
              title: Text(
                isEditing ? 'Editar Producto' : 'Nuevo Producto',
                style: TextStyle(color: textLight),
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
                            final path = await _productoService.pickImage(
                              result,
                            );
                            if (path != null) {
                              setState(() {
                                tempImagePath = path;
                                selectedImageUrl =
                                    null; // Clear any previous URL when selecting new image
                              });
                            }
                          } else if (result == 'placeholder') {
                            setState(() {
                              tempImagePath = null;
                              selectedImageUrl =
                                  'assets/placeholder/food_placeholder.png';
                            });
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
                        child: tempImagePath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(tempImagePath!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : selectedImageUrl != null
                            ? _buildProductImage(selectedImageUrl)
                            : Icon(Icons.add_a_photo, color: primary, size: 40),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Nombre
                    TextField(
                      controller: nombreController,
                      style: TextStyle(color: textLight),
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        labelStyle: TextStyle(
                          color: textLight.withOpacity(0.7),
                        ),
                        filled: true,
                        fillColor: cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Precio
                    TextField(
                      controller: precioController,
                      style: TextStyle(color: textLight),
                      decoration: InputDecoration(
                        labelText: 'Precio',
                        labelStyle: TextStyle(
                          color: textLight.withOpacity(0.7),
                        ),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: primary),
                        filled: true,
                        fillColor: cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),

                    // Costo
                    TextField(
                      controller: costoController,
                      style: TextStyle(color: textLight),
                      decoration: InputDecoration(
                        labelText: 'Costo',
                        labelStyle: TextStyle(
                          color: textLight.withOpacity(0.7),
                        ),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: primary),
                        filled: true,
                        fillColor: cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),

                    // Impuestos
                    TextField(
                      controller: impuestosController,
                      style: TextStyle(color: textLight),
                      decoration: InputDecoration(
                        labelText: 'Impuestos',
                        labelStyle: TextStyle(
                          color: textLight.withOpacity(0.7),
                        ),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: primary),
                        filled: true,
                        fillColor: cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),

                    // Utilidad (calculada automáticamente)
                    TextField(
                      controller: utilidadController,
                      style: TextStyle(color: textLight),
                      readOnly:
                          true, // Solo lectura - se calcula automáticamente
                      decoration: InputDecoration(
                        labelText: 'Utilidad (Automática)',
                        labelStyle: TextStyle(
                          color: textLight.withOpacity(0.7),
                        ),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: primary),
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
                      style: TextStyle(color: textLight),
                      dropdownColor: cardBg,
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        labelStyle: TextStyle(
                          color: textLight.withOpacity(0.7),
                        ),
                        filled: true,
                        fillColor: cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary),
                        ),
                      ),
                      items: _categorias.map((categoria) {
                        return DropdownMenuItem<String>(
                          value: categoria.id,
                          child: Text(
                            categoria.nombre,
                            style: TextStyle(color: textLight),
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
                          style: TextStyle(color: textLight),
                        ),
                        Switch(
                          value: tieneVariantes,
                          onChanged: (value) {
                            setState(() {
                              tieneVariantes = value;
                            });
                          },
                          activeThumbColor: primary,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Tipo de producto (siempre visible)
                    DropdownButtonFormField<String>(
                      initialValue: tipoProducto,
                      style: TextStyle(color: textLight),
                      dropdownColor: cardBg,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Producto',
                        labelStyle: TextStyle(
                          color: textLight.withOpacity(0.7),
                        ),
                        filled: true,
                        fillColor: cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary),
                        ),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'individual',
                          child: Text(
                            'Individual (Selección libre)',
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        DropdownMenuItem<String>(
                          value: 'combo',
                          child: Text(
                            'Combo (Cliente elige ingredientes)',
                            style: TextStyle(color: textLight),
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
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tipoProducto == 'combo'
                                ? Icons.restaurant_menu
                                : Icons.fastfood,
                            color: primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tipoProducto == 'combo'
                                  ? 'Los combos permiten al cliente elegir entre ingredientes opcionales (ej: pollo, res, cerdo)'
                                  : 'Los productos individuales permiten al cliente seleccionar cualquier ingrediente disponible al momento del pedido',
                              style: TextStyle(
                                color: textLight.withOpacity(0.8),
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
                          backgroundColor: primary,
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
                            color: cardBg.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: primary.withOpacity(0.3)),
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
                                      color: textLight.withOpacity(0.8),
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
                                      color: textLight.withOpacity(0.8),
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
                          color: textLight,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Selecciona los ingredientes que estarán disponibles para este producto:',
                        style: TextStyle(
                          color: textLight.withOpacity(0.7),
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
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),

                      // Mostrar ingredientes seleccionados
                      if (ingredientesSeleccionados.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ingredientes seleccionados:',
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${ingredientesSeleccionados.length} ingredientes seleccionados',
                                style: TextStyle(
                                  color: textLight.withOpacity(0.8),
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
                      style: TextStyle(color: textLight),
                      dropdownColor: cardBg,
                      decoration: InputDecoration(
                        labelText: 'Estado',
                        labelStyle: TextStyle(
                          color: textLight.withOpacity(0.7),
                        ),
                        filled: true,
                        fillColor: cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary),
                        ),
                      ),
                      items: ['Activo', 'Inactivo', 'Agotado'].map((
                        estadoItem,
                      ) {
                        return DropdownMenuItem<String>(
                          value: estadoItem,
                          child: Text(
                            estadoItem,
                            style: TextStyle(color: textLight),
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
                      style: TextStyle(color: textLight),
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        labelStyle: TextStyle(
                          color: textLight.withOpacity(0.7),
                        ),
                        filled: true,
                        fillColor: cardBg.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Ingredientes disponibles (Carnes):',
                      style: TextStyle(
                        color: textLight,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: textLight.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selecciona los ingredientes que estarán disponibles para este producto:',
                            style: TextStyle(
                              color: textLight.withOpacity(0.7),
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
                                        : textLight,
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
                                selectedColor: primary,
                                backgroundColor: cardBg.withOpacity(0.5),
                                checkmarkColor: Colors.white,
                                side: BorderSide(
                                  color: isSelected
                                      ? primary
                                      : textLight.withOpacity(0.3),
                                ),
                              );
                            }).toList(),
                          ),
                          if (ingredientesSeleccionados.isNotEmpty) ...[
                            SizedBox(height: 8),
                            Text(
                              'Seleccionados: ${ingredientesSeleccionados.join(', ')}',
                              style: TextStyle(
                                color: primary,
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
                  child: Text('Cancelar', style: TextStyle(color: textLight)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(
                    isEditing ? 'Actualizar' : 'Guardar',
                    style: TextStyle(color: primary),
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
                    if (tempImagePath != null) {
                      finalImageUrl = tempImagePath;
                    }

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
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);
    final Color primary = Color(0xFFFF6B00);

    return showDialog<dynamic>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: Text('Seleccionar imagen', style: TextStyle(color: textLight)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: primary),
                title: Text('Tomar foto', style: TextStyle(color: textLight)),
                onTap: () {
                  Navigator.of(context).pop(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: primary),
                title: Text('Galería', style: TextStyle(color: textLight)),
                onTap: () {
                  Navigator.of(context).pop(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.image, color: primary),
                title: Text(
                  'Usar imagen de placeholder',
                  style: TextStyle(color: textLight),
                ),
                onTap: () {
                  // Devolver un valor específico para usar el placeholder
                  Navigator.of(context).pop('placeholder');
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
    final Color primary = Color(0xFFFF6B00);
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

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
              backgroundColor: cardBg,
              title: Text(
                'Gestionar Ingredientes - ${tipoProducto == 'combo' ? 'Combo' : 'Individual'}',
                style: TextStyle(color: textLight, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: primary),
                            SizedBox(height: 16),
                            Text(
                              'Cargando ingredientes disponibles...',
                              style: TextStyle(color: textLight),
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
                              color: primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tipoProducto == 'combo'
                                  ? '• Ingredientes requeridos: Se incluyen automáticamente\n• Ingredientes opcionales: El cliente puede elegir'
                                  : '• Solo ingredientes requeridos: Se descuentan automáticamente del inventario',
                              style: TextStyle(
                                color: textLight.withOpacity(0.8),
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
                                    labelColor: primary,
                                    unselectedLabelColor: textLight.withOpacity(
                                      0.6,
                                    ),
                                    indicatorColor: primary,
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
                  child: Text('Cancelar', style: TextStyle(color: textLight)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'requeridos': requeridosEditables,
                      'opcionales': opcionalesEditables,
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primary),
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
    final Color primary = Color(0xFFFF6B00);
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

    return Column(
      children: [
        // Botón agregar
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: Icon(Icons.add),
          label: Text('Agregar Ingrediente'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
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
                    style: TextStyle(color: textLight.withOpacity(0.6)),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: ingredientes.length,
                  itemBuilder: (context, index) {
                    final ingrediente = ingredientes[index];
                    return Card(
                      color: cardBg.withOpacity(0.5),
                      child: ListTile(
                        title: Text(
                          ingrediente.ingredienteNombre,
                          style: TextStyle(color: textLight),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cantidad: ${ingrediente.cantidadNecesaria}',
                              style: TextStyle(
                                color: textLight.withOpacity(0.7),
                              ),
                            ),
                            if (ingrediente.precioAdicional > 0)
                              Text(
                                'Precio adicional: \$${ingrediente.precioAdicional}',
                                style: TextStyle(color: primary),
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
    final Color primary = Color(0xFFFF6B00);
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

    Ingrediente? selectedIngrediente;
    final cantidadController = TextEditingController();
    final precioController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: cardBg,
              title: Text(
                'Seleccionar Ingrediente ${esOpcional ? 'Opcional' : 'Requerido'}',
                style: TextStyle(color: textLight),
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
                          style: TextStyle(color: textLight),
                        ),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Seleccionar ingrediente',
                      labelStyle: TextStyle(color: textLight.withOpacity(0.7)),
                      filled: true,
                      fillColor: cardBg.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    dropdownColor: cardBg,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: cantidadController,
                    style: TextStyle(color: textLight),
                    decoration: InputDecoration(
                      labelText: 'Cantidad necesaria',
                      labelStyle: TextStyle(color: textLight.withOpacity(0.7)),
                      filled: true,
                      fillColor: cardBg.withOpacity(0.3),
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
                      style: TextStyle(color: textLight),
                      decoration: InputDecoration(
                        labelText: 'Precio adicional (opcional)',
                        labelStyle: TextStyle(
                          color: textLight.withOpacity(0.7),
                        ),
                        prefixText: '\$ ',
                        filled: true,
                        fillColor: cardBg.withOpacity(0.3),
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
                  child: Text('Cancelar', style: TextStyle(color: textLight)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: primary),
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
    final Color primary = Color(0xFFFF6B00);
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

    List<String> selectedIds = List.from(ingredientesSeleccionados);

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: Text(
            'Seleccionar Ingredientes',
            style: TextStyle(color: textLight),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Text(
                  'Selecciona los ingredientes disponibles para este producto:',
                  style: TextStyle(
                    color: textLight.withOpacity(0.7),
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
                          style: TextStyle(color: textLight),
                        ),
                        subtitle: Text(
                          '${ingrediente.categoria} - ${ingrediente.unidad}',
                          style: TextStyle(
                            color: textLight.withOpacity(0.6),
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
                        activeColor: primary,
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
              child: Text('Cancelar', style: TextStyle(color: textLight)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selectedIds),
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              child: Text('Confirmar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
