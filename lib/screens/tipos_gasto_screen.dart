import 'package:flutter/material.dart';
import '../models/tipo_gasto.dart';
import '../services/gasto_service.dart';

class TiposGastoScreen extends StatefulWidget {
  const TiposGastoScreen({super.key});

  @override
  _TiposGastoScreenState createState() => _TiposGastoScreenState();
}

class _TiposGastoScreenState extends State<TiposGastoScreen> {
  final Color primary = Color(0xFFFF6B00); // Naranja fuego
  final Color bgDark = Color(0xFF1E1E1E); // Fondo oscuro
  final Color cardBg = Color(0xFF252525); // Tarjetas
  final Color textDark = Color(0xFFE0E0E0); // Texto claro
  final Color textLight = Color(0xFFA0A0A0); // Texto suave

  // Services
  final GastoService _gastoService = GastoService();

  // Controllers
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  // Estado
  List<TipoGasto> _tiposGasto = [];
  bool _isLoading = false;
  bool _showForm = false;
  TipoGasto? _tipoEditando;

  @override
  void initState() {
    super.initState();
    _loadTiposGasto();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _loadTiposGasto() async {
    setState(() => _isLoading = true);
    try {
      final tipos = await _gastoService.getAllTiposGasto();
      setState(() => _tiposGasto = tipos);

      // Si no hay tipos de gasto, crear algunos predeterminados
      if (tipos.isEmpty) {
        await _crearTiposPredeterminados();
      }
    } catch (e) {
      _showError(
        'Error al cargar tipos de gasto: ${e.toString().split(':').first}',
      );
      print('Error detallado: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _crearTiposPredeterminados() async {
    final tiposPredeterminados = [
      {'nombre': 'Nómina', 'descripcion': 'Pagos de salarios y prestaciones'},
      {
        'nombre': 'Servicios Públicos',
        'descripcion': 'Agua, luz, gas, internet',
      },
      {
        'nombre': 'Insumos de Cocina',
        'descripcion': 'Ingredientes y materias primas',
      },
      {
        'nombre': 'Mantenimiento',
        'descripcion': 'Reparaciones y mantenimiento de equipos',
      },
      {'nombre': 'Limpieza', 'descripcion': 'Productos de aseo e higiene'},
      {
        'nombre': 'Transporte',
        'descripcion': 'Combustible y transporte de mercancías',
      },
    ];

    try {
      for (final tipo in tiposPredeterminados) {
        await _gastoService.createTipoGasto(
          nombre: tipo['nombre']!,
          descripcion: tipo['descripcion']!,
          activo: true,
        );
      }

      // Recargar la lista
      final tipos = await _gastoService.getAllTiposGasto();
      setState(() => _tiposGasto = tipos);

      _showSuccess('Tipos de gasto predeterminados creados exitosamente');
    } catch (e) {
      print('Error creando tipos predeterminados: $e');
    }
  }

  void _showFormDialog({TipoGasto? tipo}) {
    setState(() {
      _tipoEditando = tipo;
      _showForm = true;
    });

    if (tipo != null) {
      // Editar tipo existente
      _nombreController.text = tipo.nombre;
      _descripcionController.text = tipo.descripcion ?? '';
    } else {
      // Nuevo tipo
      _clearForm();
    }
  }

  void _clearForm() {
    _nombreController.clear();
    _descripcionController.clear();
  }

  Future<void> _saveTipoGasto() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);
    try {
      if (_tipoEditando != null) {
        // Actualizar tipo existente
        await _gastoService.updateTipoGasto(
          _tipoEditando!.id!,
          nombre: _nombreController.text,
          descripcion: _descripcionController.text.isEmpty
              ? null
              : _descripcionController.text,
        );
        _showSuccess('Tipo de gasto actualizado exitosamente');
      } else {
        // Crear nuevo tipo
        await _gastoService.createTipoGasto(
          nombre: _nombreController.text,
          descripcion: _descripcionController.text.isEmpty
              ? null
              : _descripcionController.text,
          activo: true,
        );
        _showSuccess('Tipo de gasto creado exitosamente');
      }

      setState(() => _showForm = false);
      await _loadTiposGasto();
    } catch (e) {
      _showError('Error al guardar tipo de gasto: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      _showError('El nombre es requerido');
      return false;
    }

    // Validar longitud del nombre (para prevenir nombres excesivamente largos)
    if (nombre.length > 50) {
      _showError('El nombre no puede superar los 50 caracteres');
      return false;
    }

    // Validar si ya existe un tipo con el mismo nombre
    if (_tipoEditando == null &&
        _tiposGasto.any(
          (tipo) => tipo.nombre.toLowerCase() == nombre.toLowerCase(),
        )) {
      _showError('Ya existe un tipo de gasto con este nombre');
      return false;
    }

    return true;
  }

  Future<void> _deleteTipoGasto(TipoGasto tipo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('Confirmar eliminación', style: TextStyle(color: textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Está seguro de eliminar este tipo de gasto?',
              style: TextStyle(color: textLight),
            ),
            SizedBox(height: 12),
            Text(
              'Nombre: ${tipo.nombre}',
              style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
            ),
            if (tipo.descripcion != null && tipo.descripcion!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Descripción: ${tipo.descripcion}',
                  style: TextStyle(color: textLight, fontSize: 14),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: TextStyle(color: textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);

        if (tipo.id == null) {
          throw Exception('ID del tipo de gasto no válido');
        }

        final success = await _gastoService.deleteTipoGasto(tipo.id!);
        if (success) {
          _showSuccess('Tipo de gasto "${tipo.nombre}" eliminado exitosamente');
          await _loadTiposGasto();
        } else {
          _showError('No se pudo eliminar el tipo de gasto');
        }
      } catch (e) {
        // Verificar si hay error por referencia (gastos asociados)
        if (e.toString().contains('referencias') ||
            e.toString().contains('constraint') ||
            e.toString().contains('reference')) {
          _showError(
            'No se puede eliminar este tipo porque existen gastos asociados. ' +
                'Considere desactivarlo en su lugar.',
          );
        } else {
          _showError('Error al eliminar: ${e.toString().split(':').first}');
          print('Error detallado: $e');
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleActivo(TipoGasto tipo) async {
    try {
      setState(() => _isLoading = true);

      await _gastoService.updateTipoGasto(tipo.id!, activo: !tipo.activo);

      _showSuccess('Estado actualizado exitosamente');
      await _loadTiposGasto();
    } catch (e) {
      _showError('Error al actualizar estado: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: primary,
        title: Text('Tipos de Gasto', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (!_showForm && !_isLoading)
            IconButton(
              icon: Icon(Icons.refresh),
              tooltip: 'Actualizar lista',
              onPressed: _loadTiposGasto,
            ),
        ],
      ),
      floatingActionButton: !_showForm
          ? FloatingActionButton(
              onPressed: () => _showFormDialog(),
              backgroundColor: primary,
              tooltip: 'Crear nuevo tipo de gasto',
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primary))
            : _showForm
            ? _buildForm()
            : _buildTiposList(),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Card(
        color: cardBg,
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.category, color: primary),
                  SizedBox(width: 8),
                  Text(
                    _tipoEditando != null
                        ? 'Editar Tipo de Gasto'
                        : 'Nuevo Tipo de Gasto',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: textDark,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Tipo de Gasto',
                  labelStyle: TextStyle(color: textLight),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: textDark),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  labelStyle: TextStyle(color: textLight),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: textDark),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => setState(() => _showForm = false),
                      child: Text('Cancelar'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saveTipoGasto,
                      child: Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTiposList() {
    return _tiposGasto.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category, size: 64, color: textLight),
                SizedBox(height: 16),
                Text(
                  'No hay tipos de gasto registrados',
                  style: TextStyle(color: textLight, fontSize: 16),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showFormDialog(),
                      icon: Icon(Icons.add),
                      label: Text('Crear Tipo Manual'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _crearTiposPredeterminados(),
                      icon: Icon(Icons.auto_awesome),
                      label: Text('Crear Tipos Básicos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _tiposGasto.length,
            itemBuilder: (context, index) {
              final tipo = _tiposGasto[index];
              return Card(
                color: cardBg,
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    tipo.nombre,
                    style: TextStyle(
                      color: tipo.activo ? textDark : textLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle:
                      tipo.descripcion != null && tipo.descripcion!.isNotEmpty
                      ? Text(
                          tipo.descripcion!,
                          style: TextStyle(color: textLight),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tipo.activo ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tipo.activo ? 'Activo' : 'Inactivo',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      SizedBox(width: 8),
                      PopupMenuButton(
                        color: cardBg,
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(
                              'Editar',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              tipo.activo ? 'Desactivar' : 'Activar',
                              style: TextStyle(color: primary),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showFormDialog(tipo: tipo);
                          } else if (value == 'toggle') {
                            _toggleActivo(tipo);
                          } else if (value == 'delete') {
                            _deleteTipoGasto(tipo);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
