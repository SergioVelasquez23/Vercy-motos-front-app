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

  // Variables para paginación
  int _paginaActual = 0;
  int _itemsPorPagina = 10;
  List<Ingrediente> _ingredientesPaginados = [];

  // Variable para controlar el timeout del botón guardar ingrediente
  bool _guardandoIngrediente = false;

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

  // Carga directa de ingredientes sin caché
  Future<void> _cargarIngredientes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      print('📝 IngredientesScreen: Cargando datos directamente...');

      // Cargar datos en paralelo desde servicios
      final futures = await Future.wait([
        _ingredienteService.getAllIngredientes(),
        _productoService.getCategorias(),
      ]);

      final ingredientes = futures[0] as List<Ingrediente>;
      final categorias = futures[1] as List<Categoria>;

      if (mounted) {
        setState(() {
          _ingredientes = ingredientes;
          _ingredientesFiltrados = ingredientes;
          _categorias = categorias;
          _paginaActual =
              0; // Reiniciar a primera página al cargar nuevos datos
          _error = '';
          _actualizarPaginacion(); // Actualizar la lista paginada
          _isLoading = false;
        });
        print(
          '✅ IngredientesScreen: ${ingredientes.length} ingredientes y ${categorias.length} categorías cargados',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar ingredientes: $e';
          _isLoading = false;
        });
      }
      print('❌ Error al cargar ingredientes: $e');
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

      // Actualizar la lista paginada
      _actualizarPaginacion();
    });
  }

  /// Actualiza la lista paginada de ingredientes basada en los filtros actuales
  void _actualizarPaginacion() {
    int startIndex = _paginaActual * _itemsPorPagina;
    int endIndex = startIndex + _itemsPorPagina;

    // Asegurar que los índices estén dentro de los límites
    if (startIndex >= _ingredientesFiltrados.length) {
      _paginaActual = 0;
      startIndex = 0;
      endIndex = _itemsPorPagina;
    }

    if (endIndex > _ingredientesFiltrados.length) {
      endIndex = _ingredientesFiltrados.length;
    }

    // Obtener solo los ingredientes para la página actual
    _ingredientesPaginados = _ingredientesFiltrados.sublist(
      startIndex,
      endIndex,
    );
  }

  /// Construye los controles de paginación
  Widget _buildPaginationControls() {
    // Calcular el número total de páginas
    int totalPaginas = (_ingredientesFiltrados.length / _itemsPorPagina).ceil();

    // Si solo hay una página o ninguna, no mostrar controles
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
          // Botón de página anterior
          IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 18),
            color: _paginaActual > 0 ? AppTheme.primary : AppTheme.textMuted,
            onPressed: _paginaActual > 0
                ? () => setState(() {
                    _paginaActual--;
                    _actualizarPaginacion();
                  })
                : null,
          ),

          // Información de página actual
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

          // Botón de siguiente página
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, size: 18),
            color: _paginaActual < totalPaginas - 1
                ? AppTheme.primary
                : AppTheme.textMuted,
            onPressed: _paginaActual < totalPaginas - 1
                ? () => setState(() {
                    _paginaActual++;
                    _actualizarPaginacion();
                  })
                : null,
          ),

          // Selector de items por página
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
                    _paginaActual = 0; // Reset a primera página
                    _actualizarPaginacion();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
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

        // Recargar datos directamente
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

    bool esDescontable = ingrediente?.descontable ?? false;
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
                            esDescontable = value ?? false;
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
              onPressed: _guardandoIngrediente
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        // 🚀 TIMEOUT: Activar estado de guardando para evitar múltiples envíos
                        setState(() {
                          _guardandoIngrediente = true;
                        });

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
                          print(
                            '   - ingrediente == null: ${ingrediente == null}',
                          );
                          print(
                            '   - Operación: ${ingrediente == null ? 'CREATE' : 'UPDATE'}',
                          );
                          print(
                            '   - ID original: ${ingrediente?.id ?? 'No ID'}',
                          );
                          print(
                            '   - ID nuevo ingrediente: ${nuevoIngrediente.id}',
                          );

                          if (ingrediente == null) {
                            // Nuevo ingrediente
                            await _ingredienteService.createIngrediente(
                              nuevoIngrediente,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Ingrediente agregado correctamente',
                                ),
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
                        } finally {
                          // 🚀 TIMEOUT: Resetear estado después de la operación
                          if (mounted) {
                            setState(() {
                              _guardandoIngrediente = false;
                            });
                          }
                        }
                      }
                    },
              style: AppTheme.primaryButtonStyle,
              child: Text(_guardandoIngrediente ? 'Guardando...' : 'Guardar'),
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
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          itemCount: _ingredientesPaginados.length,
                          itemBuilder: (context, index) {
                            final item = _ingredientesPaginados[index];
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
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
                                      icon: Icon(
                                        Icons.edit,
                                        color: AppTheme.primary,
                                      ),
                                      onPressed: () =>
                                          _mostrarDialogoNuevoIngrediente(item),
                                      tooltip: 'Editar ingrediente',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
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

                      // Controles de paginación
                      _buildPaginationControls(),
                    ],
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
