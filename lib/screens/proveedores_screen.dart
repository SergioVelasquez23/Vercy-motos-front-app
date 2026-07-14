import 'package:flutter/material.dart';
import '../models/proveedor.dart';
import '../services/proveedor_service.dart';
import '../theme/app_theme.dart';
import '../utils/submit_guard.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({super.key});

  @override
  _ProveedoresScreenState createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> with SubmitGuard {
  final TextEditingController _searchController = TextEditingController();
  final ProveedorService _proveedorService = ProveedorService();

  List<Proveedor> _proveedores = [];
  List<Proveedor> _proveedoresFiltrados = [];
  bool _isLoading = false;
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
      if (mounted) {
        showErrorDialog(context, 'Error al cargar proveedores: ${errorMessage(e)}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filtrarProveedores(String query) {
    setState(() {
      if (query.isEmpty) {
        _proveedoresFiltrados = _proveedores;
      } else {
        final q = query.toLowerCase();
        _proveedoresFiltrados = _proveedores.where((p) =>
          p.nombre.toLowerCase().contains(q) ||
          (p.documento?.toLowerCase().contains(q) ?? false) ||
          (p.email?.toLowerCase().contains(q) ?? false) ||
          (p.telefono?.toLowerCase().contains(q) ?? false),
        ).toList();
      }
    });
  }

  void _mostrarDetalleProveedor(Proveedor proveedor) {
    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text(proveedor.nombre, style: TextStyle(color: cs.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (proveedor.nombreComercial != null)
                  _buildInfoRow('Nombre Comercial:', proveedor.nombreComercial!, cs),
                if (proveedor.documento != null)
                  _buildInfoRow('Documento:', proveedor.documento!, cs),
                if (proveedor.email != null)
                  _buildInfoRow('Email:', proveedor.email!, cs),
                if (proveedor.telefono != null)
                  _buildInfoRow('Teléfono:', proveedor.telefono!, cs),
                if (proveedor.direccion != null)
                  _buildInfoRow('Dirección:', proveedor.direccion!, cs),
                if (proveedor.paginaWeb != null)
                  _buildInfoRow('Página Web:', proveedor.paginaWeb!, cs),
                if (proveedor.contacto != null)
                  _buildInfoRow('Contacto:', proveedor.contacto!, cs),
                if (proveedor.nota != null)
                  _buildInfoRow('Nota:', proveedor.nota!, cs),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cerrar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: Text('Editar', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                _mostrarDialogoEditarProveedor(proveedor);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
          Text(
            value.isEmpty ? 'No especificado' : value,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoNuevoProveedor() => _mostrarDialogoProveedor();
  void _mostrarDialogoEditarProveedor(Proveedor proveedor) =>
      _mostrarDialogoProveedor(proveedor: proveedor);

  void _mostrarDialogoProveedor({Proveedor? proveedor}) {
    final esEdicion = proveedor != null;

    final nombreController = TextEditingController(text: proveedor?.nombre ?? '');
    final nombreComercialController = TextEditingController(text: proveedor?.nombreComercial ?? '');
    final documentoController = TextEditingController(text: proveedor?.documento ?? '');
    final emailController = TextEditingController(text: proveedor?.email ?? '');
    final telefonoController = TextEditingController(text: proveedor?.telefono ?? '');
    final direccionController = TextEditingController(text: proveedor?.direccion ?? '');
    final paginaWebController = TextEditingController(text: proveedor?.paginaWeb ?? '');
    final contactoController = TextEditingController(text: proveedor?.contacto ?? '');
    final notaController = TextEditingController(text: proveedor?.nota ?? '');

    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: cs.surface,
            title: Text(
              esEdicion ? 'Editar Proveedor' : 'Nuevo Proveedor',
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField('Nombre *', nombreController, cs),
                  _buildTextField('Nombre Comercial', nombreComercialController, cs),
                  _buildTextField('Documento', documentoController, cs),
                  _buildTextField('Email', emailController, cs, keyboardType: TextInputType.emailAddress),
                  _buildTextField('Teléfono', telefonoController, cs, keyboardType: TextInputType.phone),
                  _buildTextField('Dirección', direccionController, cs),
                  _buildTextField('Página Web', paginaWebController, cs),
                  _buildTextField('Contacto', contactoController, cs),
                  _buildTextField('Nota', notaController, cs, maxLines: 3),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancelar'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _guardandoProveedor
                    ? null
                    : () => runGuarded(() async {
                        if (nombreController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('El nombre es requerido')),
                          );
                          return;
                        }

                        setState(() => _guardandoProveedor = true);

                        // Capturar referencias antes del gap asíncrono
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(this.context);

                        try {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => Center(child: CircularProgressIndicator()),
                          );

                          final nuevoProveedor = Proveedor(
                            id: proveedor?.id ?? '',
                            nombre: nombreController.text.trim(),
                            nombreComercial: nombreComercialController.text.trim().isEmpty
                                ? null : nombreComercialController.text.trim(),
                            documento: documentoController.text.trim().isEmpty
                                ? null : documentoController.text.trim(),
                            email: emailController.text.trim().isEmpty
                                ? null : emailController.text.trim(),
                            telefono: telefonoController.text.trim().isEmpty
                                ? null : telefonoController.text.trim(),
                            direccion: direccionController.text.trim().isEmpty
                                ? null : direccionController.text.trim(),
                            paginaWeb: paginaWebController.text.trim().isEmpty
                                ? null : paginaWebController.text.trim(),
                            contacto: contactoController.text.trim().isEmpty
                                ? null : contactoController.text.trim(),
                            nota: notaController.text.trim().isEmpty
                                ? null : notaController.text.trim(),
                            fechaCreacion: proveedor?.fechaCreacion ?? DateTime.now(),
                            fechaActualizacion: DateTime.now(),
                          );

                          if (esEdicion) {
                            await _proveedorService.actualizarProveedor(nuevoProveedor);
                          } else {
                            await _proveedorService.crearProveedor(nuevoProveedor);
                          }

                          if (mounted) {
                            nav.pop(); // cierra loading
                            nav.pop(); // cierra formulario
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(esEdicion
                                    ? 'Proveedor actualizado exitosamente'
                                    : 'Proveedor creado exitosamente'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await _cargarProveedores();
                          }
                        } catch (e) {
                          if (mounted) {
                            nav.pop();
                            showErrorDialog(this.context, errorMessage(e));
                          }
                        } finally {
                          if (mounted) setState(() => _guardandoProveedor = false);
                        }
                      }),
                child: Text(_guardandoProveedor
                    ? 'Guardando...'
                    : (esEdicion ? 'Actualizar' : 'Crear')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    ColorScheme cs, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Future<void> _eliminarProveedor(Proveedor proveedor) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Confirmar desactivación', style: TextStyle(color: cs.onSurface)),
          content: Text(
            '¿Estás seguro de que deseas desactivar el proveedor "${proveedor.nombre}"?\n\nNota: El proveedor no se eliminará definitivamente, solo se desactivará.',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: Text('Desactivar'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(child: CircularProgressIndicator()),
        );

        final success = await _proveedorService.eliminarProveedor(proveedor.id);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? 'Proveedor desactivado exitosamente'
                  : 'Error al desactivar proveedor'),
              backgroundColor: success ? Colors.orange : Colors.red,
            ),
          );
          if (success) await _cargarProveedores();
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          showErrorDialog(context, 'Error al eliminar proveedor: ${errorMessage(e)}');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text('Proveedores', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _cargarProveedores,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarProveedores,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar proveedor...',
                hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search, color: cs.onSurface.withValues(alpha: 0.6)),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _proveedoresFiltrados.isEmpty
                    ? Center(child: Text('No se encontraron proveedores', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _proveedoresFiltrados.length,
                        itemBuilder: (context, index) {
                          final p = _proveedoresFiltrados[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: cs.surfaceContainerLow,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                child: Text(
                                  p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
                                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(p.nombre, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (p.documento != null)
                                    Text('Doc: ${p.documento}', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                                  if (p.telefono != null)
                                    Text('Tel: ${p.telefono}', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: AppTheme.primary),
                                    onPressed: () => _mostrarDialogoEditarProveedor(p),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: cs.error),
                                    onPressed: () => _eliminarProveedor(p),
                                  ),
                                ],
                              ),
                              onTap: () => _mostrarDetalleProveedor(p),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        onPressed: _mostrarDialogoNuevoProveedor,
        tooltip: 'Añadir nuevo proveedor',
        icon: Icon(Icons.add),
        label: Text('Nuevo proveedor', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
