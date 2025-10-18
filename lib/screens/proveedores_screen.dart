import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/proveedor.dart';
import '../services/proveedor_service.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({super.key});

  @override
  _ProveedoresScreenState createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ProveedorService _proveedorService = ProveedorService();

  List<Proveedor> _proveedores = [];
  List<Proveedor> _proveedoresFiltrados = [];
  bool _isLoading = false;

  // Variable para controlar el timeout del botón guardar proveedor
  bool _guardandoProveedor = false;

  @override
  void initState() {
    super.initState();
    _cargarProveedores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarProveedores() async {
    setState(() => _isLoading = true);
    try {
      final proveedores = await _proveedorService.getProveedores();
      setState(() {
        _proveedores = proveedores;
        _proveedoresFiltrados = proveedores;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar proveedores: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filtrarProveedores(String query) {
    if (query.isEmpty) {
      setState(() {
        _proveedoresFiltrados = _proveedores;
      });
    } else {
      setState(() {
        _proveedoresFiltrados = _proveedores
            .where(
              (proveedor) =>
                  proveedor.nombre.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (proveedor.documento != null &&
                      proveedor.documento!.toLowerCase().contains(
                        query.toLowerCase(),
                      )) ||
                  (proveedor.email != null &&
                      proveedor.email!.toLowerCase().contains(
                        query.toLowerCase(),
                      )) ||
                  (proveedor.telefono != null &&
                      proveedor.telefono!.toLowerCase().contains(
                        query.toLowerCase(),
                      )),
            )
            .toList();
      });
    }
  }

  void _mostrarDetalleProveedor(Proveedor proveedor) {
    final Color cardBg = Color(kCardBackgroundDark);
    final Color textDark = Color(kTextDark);
    final Color textLight = Color(kTextLight);
    final Color primary = Color(kPrimaryColor);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(proveedor.nombre, style: TextStyle(color: textDark)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (proveedor.nombreComercial != null)
                _buildInfoRow(
                  'Nombre Comercial:',
                  proveedor.nombreComercial!,
                  textDark,
                  textLight,
                ),
              if (proveedor.documento != null)
                _buildInfoRow(
                  'Documento:',
                  proveedor.documento!,
                  textDark,
                  textLight,
                ),
              if (proveedor.email != null)
                _buildInfoRow('Email:', proveedor.email!, textDark, textLight),
              if (proveedor.telefono != null)
                _buildInfoRow(
                  'Teléfono:',
                  proveedor.telefono!,
                  textDark,
                  textLight,
                ),
              if (proveedor.direccion != null)
                _buildInfoRow(
                  'Dirección:',
                  proveedor.direccion!,
                  textDark,
                  textLight,
                ),
              if (proveedor.paginaWeb != null)
                _buildInfoRow(
                  'Página Web:',
                  proveedor.paginaWeb!,
                  textDark,
                  textLight,
                ),
              if (proveedor.contacto != null)
                _buildInfoRow(
                  'Contacto:',
                  proveedor.contacto!,
                  textDark,
                  textLight,
                ),
              if (proveedor.nota != null)
                _buildInfoRow('Nota:', proveedor.nota!, textDark, textLight),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cerrar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: Text('Editar'),
            onPressed: () {
              Navigator.of(context).pop();
              _mostrarDialogoEditarProveedor(proveedor);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color titleColor,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        Text(
          value.isEmpty ? 'No especificado' : value,
          style: TextStyle(color: valueColor),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  void _mostrarDialogoNuevoProveedor() {
    _mostrarDialogoProveedor();
  }

  void _mostrarDialogoEditarProveedor(Proveedor proveedor) {
    _mostrarDialogoProveedor(proveedor: proveedor);
  }

  void _mostrarDialogoProveedor({Proveedor? proveedor}) {
    final Color cardBg = Color(kCardBackgroundDark);
    final Color textDark = Color(kTextDark);
    final Color textLight = Color(kTextLight);
    final Color primary = Color(kPrimaryColor);

    final bool esEdicion = proveedor != null;

    final nombreController = TextEditingController(
      text: proveedor?.nombre ?? '',
    );
    final nombreComercialController = TextEditingController(
      text: proveedor?.nombreComercial ?? '',
    );
    final documentoController = TextEditingController(
      text: proveedor?.documento ?? '',
    );
    final emailController = TextEditingController(text: proveedor?.email ?? '');
    final telefonoController = TextEditingController(
      text: proveedor?.telefono ?? '',
    );
    final direccionController = TextEditingController(
      text: proveedor?.direccion ?? '',
    );
    final paginaWebController = TextEditingController(
      text: proveedor?.paginaWeb ?? '',
    );
    final contactoController = TextEditingController(
      text: proveedor?.contacto ?? '',
    );
    final notaController = TextEditingController(text: proveedor?.nota ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(
          esEdicion ? 'Editar Proveedor' : 'Nuevo Proveedor',
          style: TextStyle(color: textDark),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                'Nombre *',
                nombreController,
                textDark,
                textLight,
              ),
              _buildTextField(
                'Nombre Comercial',
                nombreComercialController,
                textDark,
                textLight,
              ),
              _buildTextField(
                'Documento',
                documentoController,
                textDark,
                textLight,
              ),
              _buildTextField('Email', emailController, textDark, textLight),
              _buildTextField(
                'Teléfono',
                telefonoController,
                textDark,
                textLight,
              ),
              _buildTextField(
                'Dirección',
                direccionController,
                textDark,
                textLight,
              ),
              _buildTextField(
                'Página Web',
                paginaWebController,
                textDark,
                textLight,
              ),
              _buildTextField(
                'Contacto',
                contactoController,
                textDark,
                textLight,
              ),
              _buildTextField(
                'Nota',
                notaController,
                textDark,
                textLight,
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancelar', style: TextStyle(color: textLight)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: Text(
              _guardandoProveedor
                  ? 'Guardando...'
                  : (esEdicion ? 'Actualizar' : 'Crear'),
            ),
            onPressed: _guardandoProveedor
                ? null
                : () async {
                    if (nombreController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('El nombre es requerido')),
                      );
                      return;
                    }

                    // 🚀 TIMEOUT: Activar estado de guardando para evitar múltiples envíos
                    setState(() {
                      _guardandoProveedor = true;
                    });

                    try {
                      // Mostrar indicador de carga
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) =>
                            Center(child: CircularProgressIndicator()),
                      );

                      final nuevoProveedor = Proveedor(
                        id: proveedor?.id ?? '',
                        nombre: nombreController.text.trim(),
                        nombreComercial:
                            nombreComercialController.text.trim().isEmpty
                            ? null
                            : nombreComercialController.text.trim(),
                        documento: documentoController.text.trim().isEmpty
                            ? null
                            : documentoController.text.trim(),
                        email: emailController.text.trim().isEmpty
                            ? null
                            : emailController.text.trim(),
                        telefono: telefonoController.text.trim().isEmpty
                            ? null
                            : telefonoController.text.trim(),
                        direccion: direccionController.text.trim().isEmpty
                            ? null
                            : direccionController.text.trim(),
                        paginaWeb: paginaWebController.text.trim().isEmpty
                            ? null
                            : paginaWebController.text.trim(),
                        contacto: contactoController.text.trim().isEmpty
                            ? null
                            : contactoController.text.trim(),
                        nota: notaController.text.trim().isEmpty
                            ? null
                            : notaController.text.trim(),
                        fechaCreacion:
                            proveedor?.fechaCreacion ?? DateTime.now(),
                        fechaActualizacion: DateTime.now(),
                      );

                      if (esEdicion) {
                        await _proveedorService.actualizarProveedor(
                          nuevoProveedor,
                        );
                        if (mounted) {
                          // Cerrar indicador de carga
                          Navigator.of(context).pop();
                          // Cerrar formulario de edición
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Proveedor actualizado exitosamente',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          await _cargarProveedores();
                        }
                      } else {
                        await _proveedorService.crearProveedor(nuevoProveedor);
                        if (mounted) {
                          // Cerrar indicador de carga
                          Navigator.of(context).pop();
                          // Cerrar formulario de creación
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Proveedor creado exitosamente'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          await _cargarProveedores();
                        }
                      }
                    } catch (e) {
                      print('Error en operación de proveedor: $e');
                      if (mounted) {
                        // Cerrar indicador de carga si está abierto
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      }
                    } finally {
                      // 🚀 TIMEOUT: Resetear estado después de la operación
                      if (mounted) {
                        setState(() {
                          _guardandoProveedor = false;
                        });
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color textColor,
    Color hintColor, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: hintColor),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: hintColor.withOpacity(0.5)),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(kPrimaryColor)),
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarProveedor(Proveedor proveedor) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(kCardBackgroundDark),
        title: Text(
          'Confirmar desactivación',
          style: TextStyle(color: Color(kTextDark)),
        ),
        content: Text(
          '¿Estás seguro de que deseas desactivar el proveedor "${proveedor.nombre}"?\n\nNota: El proveedor no se eliminará definitivamente, solo se desactivará.',
          style: TextStyle(color: Color(kTextLight)),
        ),
        actions: [
          TextButton(
            child: Text('Cancelar', style: TextStyle(color: Color(kTextLight))),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Desactivar'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // Mostrar indicador de carga
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(child: CircularProgressIndicator()),
        );

        final success = await _proveedorService.eliminarProveedor(proveedor.id);

        // Cerrar indicador de carga
        if (mounted) {
          Navigator.of(context).pop();

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Proveedor desactivado exitosamente'),
                backgroundColor: Colors.orange,
              ),
            );
            await _cargarProveedores();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al desactivar proveedor'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('Error eliminando proveedor: $e');
        // Cerrar indicador de carga si está abierto
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar proveedor: $e'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Color(kPrimaryColor);
    final Color bgDark = Color(kBackgroundDark);
    final Color cardBg = Color(kCardBackgroundDark);
    final Color textDark = Color(kTextDark);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardBg,
        title: Text('Proveedores', style: TextStyle(color: textDark)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primary),
            onPressed: _cargarProveedores,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarProveedores,
              decoration: InputDecoration(
                hintText: 'Buscar proveedor...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              style: TextStyle(color: textDark),
            ),
          ),

          // Lista de proveedores
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  )
                : _proveedoresFiltrados.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron proveedores',
                      style: TextStyle(color: textDark),
                    ),
                  )
                : ListView.builder(
                    itemCount: _proveedoresFiltrados.length,
                    itemBuilder: (context, index) {
                      final proveedor = _proveedoresFiltrados[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: cardBg,
                        child: ListTile(
                          title: Text(
                            proveedor.nombre,
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (proveedor.documento != null)
                                Text(
                                  'Doc: ${proveedor.documento}',
                                  style: TextStyle(color: Color(kTextLight)),
                                ),
                              if (proveedor.telefono != null)
                                Text(
                                  'Tel: ${proveedor.telefono}',
                                  style: TextStyle(color: Color(kTextLight)),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: primary),
                                onPressed: () {
                                  _mostrarDialogoEditarProveedor(proveedor);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _eliminarProveedor(proveedor);
                                },
                              ),
                            ],
                          ),
                          onTap: () => _mostrarDetalleProveedor(proveedor),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        onPressed: _mostrarDialogoNuevoProveedor,
        tooltip: 'Añadir nuevo proveedor',
        child: Icon(Icons.add),
      ),
    );
  }
}
