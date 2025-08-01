import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/ingrediente.dart';
import '../services/producto_service.dart';
import '../services/ingrediente_service.dart';

class ProductosScreen extends StatefulWidget {
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
  TextEditingController _searchController = TextEditingController();
  String? _selectedCategoriaId;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
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
                Container(
                  height: 50,
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
                              });
                            },
                            selected: _selectedCategoriaId == categoria.id,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de productos
          Expanded(
            child: FutureBuilder<List<Producto>>(
              future: _filtrarProductos(),
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
            Text(
              '\$${producto.precio.toStringAsFixed(0)}',
              style: TextStyle(color: primary, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            if (producto.categoria != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  producto.categoria!.nombre,
                  style: TextStyle(color: primary, fontSize: 12),
                ),
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

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Producto eliminado'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error al eliminar producto: ${e.toString()}',
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
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
    final descripcionController = TextEditingController(
      text: isEditing ? producto.descripcion ?? '' : '',
    );

    bool tieneVariantes = isEditing ? producto.tieneVariantes : false;
    String estado = isEditing ? producto.estado : 'Activo';
    String? selectedCategoriaId = isEditing ? producto.categoria?.id : null;
    String? selectedImageUrl = isEditing ? producto.imagenUrl : null;
    String? tempImagePath;
    List<String> ingredientesSeleccionados = isEditing
        ? List<String>.from(producto.ingredientesDisponibles)
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

                    // Utilidad
                    TextField(
                      controller: utilidadController,
                      style: TextStyle(color: textLight),
                      decoration: InputDecoration(
                        labelText: 'Utilidad',
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

                    // Categoría
                    DropdownButtonFormField<String>(
                      value: selectedCategoriaId,
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
                          activeColor: primary,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Estado del producto
                    DropdownButtonFormField<String>(
                      value: estado,
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

                    // Sección de ingredientes (carnes)
                    if (_ingredientesCarnes.isNotEmpty) ...[
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Complete los campos requeridos'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // Obtener categoría
                    Categoria? categoriaSeleccionada;
                    if (selectedCategoriaId != null) {
                      categoriaSeleccionada = _categorias.firstWhere(
                        (c) => c.id == selectedCategoriaId,
                      );
                    }

                    // Obtener imagen final
                    String? finalImageUrl = selectedImageUrl;
                    if (tempImagePath != null) {
                      finalImageUrl = tempImagePath;
                    }

                    // Crear o actualizar el producto
                    try {
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
                        );
                        await _productoService.updateProducto(updatedProducto);
                      } else {
                        // Crear nuevo producto con ingredientes
                        if (ingredientesSeleccionados.isNotEmpty) {
                          await _productoService.crearProductoConIngredientes(
                            nombre: nombreController.text,
                            precio: double.parse(precioController.text),
                            costo: double.parse(costoController.text),
                            categoriaId: selectedCategoriaId ?? '',
                            ingredientesDisponibles: ingredientesSeleccionados,
                            descripcion: descripcionController.text.isNotEmpty
                                ? descripcionController.text
                                : null,
                          );
                        } else {
                          final nuevoProducto = Producto(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
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
                            ingredientesDisponibles: [],
                          );
                          await _productoService.addProducto(nuevoProducto);
                        }
                      }

                      Navigator.of(context).pop();

                      // Recargar datos después de crear/actualizar
                      await _cargarDatos();

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
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
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
}
