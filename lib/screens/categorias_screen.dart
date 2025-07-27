import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/categoria.dart';
import '../models/producto.dart';
import '../services/producto_service.dart';

class CategoriasScreen extends StatefulWidget {
  @override
  _CategoriasScreenState createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  final ProductoService _productoService = ProductoService();
  List<Categoria> _categorias = [];
  List<Producto> _productos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categorias = await _productoService.getCategorias();
      final productos = await _productoService.getProductos();

      setState(() {
        _categorias = categorias;
        _productos = productos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Color(0xFFFF6B00);
    final Color bgDark = Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          'Gestión de Categorías',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            )
          : _categorias.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay categorías disponibles',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Toca el botón + para agregar una categoría',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _categorias.length,
                itemBuilder: (context, index) {
                  return _buildCategoriaItem(_categorias[index]);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCategoriaDialog();
        },
        backgroundColor: primary,
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoriaItem(Categoria categoria) {
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

    return Card(
      color: cardBg,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: _buildCategoriaImage(categoria.imagenUrl),
        ),
        title: Text(
          categoria.nombre,
          style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
        ),
        // Conteo de productos en esta categoría
        subtitle: Text(
          '${_getProductosCount(categoria.id)} productos',
          style: TextStyle(color: textLight.withOpacity(0.7)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: textLight),
              onPressed: () {
                _showCategoriaDialog(categoria: categoria);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                _showDeleteConfirmationDialog(categoria);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriaImage(String? imagenUrl) {
    final Color primary = Color(0xFFFF6B00);

    // Si no hay imagen o la URL es inválida
    if (imagenUrl == null || imagenUrl.isEmpty) {
      return Icon(Icons.category, color: primary, size: 24);
    }

    // Si es una URL web o una URL de datos
    if (imagenUrl.startsWith('http') || imagenUrl.startsWith('data:')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imagenUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error cargando imagen: $error, URL: $imagenUrl');
            return Icon(Icons.category, color: primary, size: 24);
          },
        ),
      );
    }

    // Si es un archivo local
    if (imagenUrl.startsWith('/')) {
      // En Flutter Web, intentamos usar Image.network
      if (kIsWeb) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imagenUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.category, color: primary, size: 24),
          ),
        );
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imagenUrl),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.category, color: primary, size: 24),
          ),
        );
      }
    }

    // Si es un asset
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        imagenUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.category, color: primary, size: 24),
      ),
    );
  }

  int _getProductosCount(String categoriaId) {
    return _productos.where((p) => p.categoria?.id == categoriaId).length;
  }

  void _showDeleteConfirmationDialog(Categoria categoria) {
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('¿Eliminar categoría?', style: TextStyle(color: textLight)),
        content: Text(
          '¿Está seguro que desea eliminar la categoría ${categoria.nombre}?\n\n'
          '${_getProductosCount(categoria.id) > 0 ? 'Esta categoría tiene ${_getProductosCount(categoria.id)} productos asociados que se quedarán sin categoría.' : ''}',
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
                await _productoService.deleteCategoria(categoria.id);
                Navigator.of(context).pop();
                await _cargarDatos(); // Recargar datos después de eliminar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Categoría eliminada'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.of(context).pop();
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
      ),
    );
  }

  void _showCategoriaDialog({Categoria? categoria}) {
    final bool isEditing = categoria != null;
    final Color primary = Color(0xFFFF6B00);
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

    // Controlador para el formulario
    final nombreController = TextEditingController(
      text: isEditing ? categoria.nombre : '',
    );

    String? selectedImageUrl = isEditing ? categoria.imagenUrl : null;
    String? tempImagePath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: cardBg,
              title: Text(
                isEditing ? 'Editar Categoría' : 'Nueva Categoría',
                style: TextStyle(color: textLight),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Imagen
                    GestureDetector(
                      onTap: () async {
                        final source = await _showImageSourceDialog();
                        if (source != null) {
                          final path = await _productoService.pickImage(source);
                          if (path != null) {
                            setState(() {
                              tempImagePath = path;
                            });
                          }
                        }
                      },
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: tempImagePath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: kIsWeb
                                    ? Image.network(
                                        tempImagePath!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print(
                                            'Error mostrando imagen: $error, URL: ${tempImagePath!.length > 50 ? tempImagePath!.substring(0, 50) + '...' : tempImagePath}',
                                          );
                                          return Container(
                                            width: double.infinity,
                                            height: double.infinity,
                                            color: primary.withOpacity(0.1),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image_outlined,
                                                  color: primary,
                                                  size: 30,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Error al cargar\nla imagen',
                                                  style: TextStyle(
                                                    color: primary,
                                                    fontSize: 10,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      )
                                    : Image.file(
                                        File(tempImagePath!),
                                        fit: BoxFit.cover,
                                      ),
                              )
                            : (selectedImageUrl != null
                                  ? _buildCategoriaImage(selectedImageUrl)
                                  : Icon(
                                      Icons.add_a_photo,
                                      color: primary,
                                      size: 40,
                                    )),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Nombre
                    TextField(
                      controller: nombreController,
                      style: TextStyle(color: textLight),
                      decoration: InputDecoration(
                        labelText: 'Nombre de la categoría',
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
                    if (nombreController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ingrese un nombre para la categoría'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // Obtener imagen final
                    String? finalImageUrl = selectedImageUrl;
                    if (tempImagePath != null) {
                      // Verificar si es una URL de datos (base64)
                      if (tempImagePath!.startsWith('data:')) {
                        finalImageUrl = tempImagePath;
                        print(
                          'Usando imagen base64, longitud: ${tempImagePath!.length}',
                        );
                      } else {
                        finalImageUrl = tempImagePath;
                        print('Usando ruta de imagen: $tempImagePath');
                      }
                    }

                    try {
                      if (isEditing) {
                        // Actualizar categoría existente
                        final updatedCategoria = Categoria(
                          id: categoria.id,
                          nombre: nombreController.text,
                          imagenUrl: finalImageUrl,
                        );
                        await _productoService.updateCategoria(
                          updatedCategoria,
                        );
                      } else {
                        // Crear nueva categoría
                        final nuevaCategoria = Categoria(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          nombre: nombreController.text,
                          imagenUrl:
                              finalImageUrl ??
                              'assets/placeholder/food_placeholder.png',
                        );
                        await _productoService.addCategoria(nuevaCategoria);
                      }

                      Navigator.of(context).pop();
                      await _cargarDatos(); // Recargar datos después de guardar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing
                                ? 'Categoría actualizada'
                                : 'Categoría agregada',
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

  Future<ImageSource?> _showImageSourceDialog() async {
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);
    final Color primary = Color(0xFFFF6B00);

    return showDialog<ImageSource>(
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
                  'Usar imagen predeterminada',
                  style: TextStyle(color: textLight),
                ),
                onTap: () {
                  // Usar la imagen predeterminada
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
