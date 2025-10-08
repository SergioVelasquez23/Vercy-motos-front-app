import 'package:flutter/material.dart';
import '../services/ingrediente_service.dart';
import '../services/producto_service.dart';
import '../models/ingrediente.dart';
import '../models/categoria.dart';
import '../widgets/loading_indicator.dart';
import '../theme/app_theme.dart';

class IngredientesScreen extends StatefulWidget {
  const IngredientesScreen({super.key});

  @override
  _IngredientesScreenState createState() => _IngredientesScreenState();
}

class _IngredientesScreenState extends State<IngredientesScreen> {
  final IngredienteService _ingredienteService = IngredienteService();
  final ProductoService _productoService = ProductoService();
  List<Ingrediente> _ingredientes = [];
  List<Ingrediente> _ingredientesFiltrados = [];
  List<Categoria> _categorias = [];
  bool _isLoading = true;
  String _error = '';
  final TextEditingController _searchController = TextEditingController();
  String _categoriaSeleccionada = 'Todas';

  @override
  void initState() {
    super.initState();
    _cargarIngredientes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarIngredientes() async {
    setState(() => _isLoading = true);

    try {
      final ingredientes = await _ingredienteService.getAllIngredientes();
      final categorias = await _productoService.getCategorias();

      setState(() {
        _ingredientes = ingredientes;
        _ingredientesFiltrados = ingredientes;
        _categorias = categorias;
        _error = '';
      });
    } catch (e) {
      setState(() => _error = 'Error al cargar ingredientes: $e');
      print('❌ Error al cargar ingredientes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filtrarIngredientes() {
    setState(() {
      _ingredientesFiltrados = _ingredientes.where((item) {
        // Filtrar por búsqueda
        bool matchBusqueda = item.nombre.toLowerCase().contains(
          _searchController.text.toLowerCase(),
        );

        // Filtrar por categoría
        bool matchCategoria =
            _categoriaSeleccionada == 'Todas' ||
            item.categoria == _categoriaSeleccionada;

        return matchBusqueda && matchCategoria;
      }).toList();
    });
  }

  // Obtener lista de categorías
  List<String> get _categoriasDisponibles {
    Set<String> categorias = {'Todas'};
    for (var item in _ingredientes) {
      if (item.categoria.isNotEmpty) {
        categorias.add(item.categoria);
      }
    }
    return categorias.toList()..sort();
  }

  Future<void> _confirmarEliminarIngrediente(Ingrediente ingrediente) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('¿Eliminar ingrediente?', style: AppTheme.headlineMedium),
        content: Text(
          '¿Está seguro que desea eliminar el ingrediente "${ingrediente.nombre}"? Esta acción no se puede deshacer.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppTheme.secondaryButtonStyle,
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      try {
        await _ingredienteService.deleteIngrediente(ingrediente.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ingrediente eliminado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        _cargarIngredientes();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar ingrediente: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        print('❌ Error al eliminar ingrediente: $e');
      }
    }
  }

  String _obtenerNombreCategoria(String categoriaId) {
    try {
      final categoria = _categorias.firstWhere((cat) => cat.id == categoriaId);
      return categoria.nombre;
    } catch (e) {
      return categoriaId; // Si no encuentra la categoría, devuelve el ID
    }
  }

  void _mostrarDialogoNuevoIngrediente([Ingrediente? ingrediente]) {
    print('🔍 _mostrarDialogoNuevoIngrediente llamado con:');
    print('   - Ingrediente: ${ingrediente?.nombre ?? 'null'}');
    print('   - ID: ${ingrediente?.id ?? 'null'}');
    print('   - Es nulo: ${ingrediente == null}');

    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(
      text: ingrediente?.nombre ?? '',
    );
    final unidadController = TextEditingController(
      text: ingrediente?.unidad ?? '',
    );
    final costoController = TextEditingController(
      text: ingrediente?.costo.toString() ?? '',
    );
    final cantidadController = TextEditingController(
      text: (ingrediente?.stockActual ?? ingrediente?.cantidad ?? 0).toString(),
    );

    bool esDescontable = ingrediente?.descontable ?? true;
    String? categoriaSeleccionada = ingrediente?.categoria;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(
            ingrediente == null ? 'Nuevo Ingrediente' : 'Editar Ingrediente',
            style: AppTheme.headlineMedium,
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreController,
                    decoration: InputDecoration(
                      labelText: 'Nombre*',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: AppTheme.bodyMedium,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Campo requerido';
                      if (value!.length < 3) return 'Mínimo 3 caracteres';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: categoriaSeleccionada,
                    decoration: InputDecoration(
                      labelText: 'Categoría*',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: AppTheme.bodyMedium,
                    dropdownColor: AppTheme.cardBg,
                    items: _categorias.map((categoria) {
                      return DropdownMenuItem<String>(
                        value: categoria.id,
                        child: Text(
                          categoria.nombre,
                          style: AppTheme.bodyMedium,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        categoriaSeleccionada = value;
                      });
                    },
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Campo requerido' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: unidadController,
                    decoration: InputDecoration(
                      labelText: 'Unidad*',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      helperText: 'Ejemplo: kg, g, l, ml, unidad',
                    ),
                    style: AppTheme.bodyMedium,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Campo requerido' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: costoController,
                    decoration: InputDecoration(
                      labelText: 'Costo*',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: AppTheme.bodyMedium,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Campo requerido';
                      final costo = double.tryParse(value!);
                      if (costo == null) return 'Ingrese un número válido';
                      if (costo <= 0) return 'El costo debe ser mayor a 0';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: cantidadController,
                    decoration: InputDecoration(
                      labelText: 'Cantidad*',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: AppTheme.bodyMedium,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Campo requerido';
                      final cantidad = double.tryParse(value!);
                      if (cantidad == null) return 'Ingrese un número válido';
                      if (cantidad < 0) {
                        return 'La cantidad no puede ser negativa';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: esDescontable,
                        onChanged: (value) {
                          setDialogState(() {
                            esDescontable = value ?? true;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Descontable del inventario',
                          style: AppTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Los ingredientes descontables reducen el stock automáticamente al usarse en pedidos.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: AppTheme.secondaryButtonStyle,
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  try {
                    final costo = double.parse(costoController.text);
                    print('💰 Costo parseado del controlador: $costo');

                    final nuevoIngrediente = Ingrediente(
                      id: ingrediente?.id ?? '',
                      nombre: nombreController.text,
                      categoria: categoriaSeleccionada ?? '',
                      unidad: unidadController.text,
                      costo: costo,
                      cantidad: double.parse(cantidadController.text),
                      stockActual: double.parse(
                        cantidadController.text,
                      ), // Usar stockActual para el stock manual
                      stockMinimo: ingrediente?.stockMinimo ?? 0.0,
                      estado: ingrediente?.estado ?? 'Activo',
                      descontable: esDescontable,
                    );

                    print(
                      '🏗️ Ingrediente construido - Costo: ${nuevoIngrediente.costo}',
                    );

                    print('🔎 Verificando operación:');
                    print('   - ingrediente == null: ${ingrediente == null}');
                    print(
                      '   - Operación: ${ingrediente == null ? 'CREATE' : 'UPDATE'}',
                    );
                    print('   - ID original: ${ingrediente?.id ?? 'No ID'}');
                    print('   - ID nuevo ingrediente: ${nuevoIngrediente.id}');

                    if (ingrediente == null) {
                      // Nuevo ingrediente
                      await _ingredienteService.createIngrediente(
                        nuevoIngrediente,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ingrediente agregado correctamente'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    } else {
                      // Editar ingrediente
                      await _ingredienteService.updateIngrediente(
                        nuevoIngrediente,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ingrediente actualizado correctamente',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }

                    Navigator.pop(context);
                    _cargarIngredientes();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al guardar ingrediente: $e'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 4),
                      ),
                    );
                    print('❌ Error al guardar ingrediente: $e');
                  }
                }
              },
              style: AppTheme.primaryButtonStyle,
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: Text('Ingredientes', style: AppTheme.headlineSmall),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarIngredientes,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _filtrarIngredientes(),
                    decoration: InputDecoration(
                      hintText: 'Buscar ingrediente...',
                      prefixIcon: Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    style: AppTheme.bodyMedium,
                  ),
                ),
                SizedBox(width: 8.0),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _categoriaSeleccionada,
                      items: _categoriasDisponibles.map((categoria) {
                        return DropdownMenuItem(
                          value: categoria,
                          child: Text(
                            categoria,
                            style: TextStyle(
                              color: categoria == 'Todas'
                                  ? Colors.grey
                                  : AppTheme.textDark,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _categoriaSeleccionada = value!;
                          _filtrarIngredientes();
                        });
                      },
                      dropdownColor: AppTheme.cardBg,
                      style: AppTheme.bodyMedium,
                      underline: Container(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de ingredientes
          Expanded(
            child: _isLoading
                ? LoadingIndicator()
                : _error.isNotEmpty
                ? Center(
                    child: Text(_error, style: TextStyle(color: Colors.red)),
                  )
                : _ingredientesFiltrados.isEmpty
                ? Center(
                    child: Text(
                      'No hay ingredientes registrados',
                      style: AppTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: _ingredientesFiltrados.length,
                    itemBuilder: (context, index) {
                      final item = _ingredientesFiltrados[index];
                      bool esStockBajo =
                          item.stock <= item.stockMin ||
                          item.stock <= 10; // Umbral para ingredientes

                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: AppTheme.cardBg,
                        child: ListTile(
                          title: Text(
                            item.nombre,
                            style: AppTheme.headlineSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Categoría: ${_obtenerNombreCategoria(item.categoria)} | Unidad: ${item.unidad.isNotEmpty ? item.unidad : "-"}',
                                style: AppTheme.bodySmall,
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    item.descontable
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 16,
                                    color: item.descontable
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    item.descontable
                                        ? 'Descontable'
                                        : 'No descontable',
                                    style: TextStyle(
                                      color: item.descontable
                                          ? Colors.green
                                          : Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Stock: ${item.stock} ${item.unidad.isNotEmpty ? item.unidad : "-"}',
                                    style: TextStyle(
                                      color: esStockBajo
                                          ? Colors.red
                                          : AppTheme.textDark,
                                      fontWeight: esStockBajo
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    'Costo: \$${item.costo.toStringAsFixed(2)}',
                                    style: AppTheme.bodySmall,
                                  ),
                                ],
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.edit, color: AppTheme.primary),
                                onPressed: () =>
                                    _mostrarDialogoNuevoIngrediente(item),
                                tooltip: 'Editar ingrediente',
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    _confirmarEliminarIngrediente(item),
                                tooltip: 'Eliminar ingrediente',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => _mostrarDialogoNuevoIngrediente(),
        child: Icon(Icons.add),
      ),
    );
  }
}
