import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/ingrediente_service.dart';
import '../services/producto_service.dart';
import '../models/ingrediente.dart';
import '../models/categoria.dart';
import '../widgets/loading_indicator.dart';

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
      setState(() => _error = kErrorCargaDatos);
      print('Error cargando datos: $e');
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
        backgroundColor: Color(kCardBackgroundDark),
        title: Text(
          '¿Eliminar ingrediente?',
          style: TextStyle(color: Color(kTextDark)),
        ),
        content: Text(
          '¿Está seguro que desea eliminar el ingrediente "${ingrediente.nombre}"? Esta acción no se puede deshacer.',
          style: TextStyle(color: Color(kTextLight)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      try {
        await _ingredienteService.deleteIngrediente(ingrediente.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ingrediente eliminado correctamente')),
        );
        _cargarIngredientes();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar el ingrediente'),
            backgroundColor: Colors.red,
          ),
        );
        print('Error eliminando ingrediente: $e');
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
          title: Text(
            ingrediente == null ? 'Nuevo Ingrediente' : 'Editar Ingrediente',
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
                    style: TextStyle(color: Color(kTextDark)),
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
                    style: TextStyle(color: Color(kTextDark)),
                    dropdownColor: Colors.grey[800],
                    items: _categorias.map((categoria) {
                      return DropdownMenuItem<String>(
                        value: categoria.id,
                        child: Text(
                          categoria.nombre,
                          style: const TextStyle(color: Colors.white),
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
                    style: TextStyle(color: Color(kTextDark)),
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
                    style: TextStyle(color: Color(kTextDark)),
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
                    style: TextStyle(color: Color(kTextDark)),
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
                          style: TextStyle(color: Color(kTextDark)),
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
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  try {
                    final nuevoIngrediente = Ingrediente(
                      id: ingrediente?.id ?? '',
                      nombre: nombreController.text,
                      categoria: categoriaSeleccionada ?? '',
                      unidad: unidadController.text,
                      costo: double.parse(costoController.text),
                      cantidad: double.parse(cantidadController.text),
                      estado: ingrediente?.estado ?? 'Activo',
                      descontable: esDescontable,
                    );

                    if (ingrediente == null) {
                      // Nuevo ingrediente
                      await _ingredienteService.createIngrediente(
                        nuevoIngrediente,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ingrediente agregado')),
                      );
                    } else {
                      // Editar ingrediente
                      await _ingredienteService.updateIngrediente(
                        nuevoIngrediente,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ingrediente actualizado')),
                      );
                    }

                    Navigator.pop(context);
                    _cargarIngredientes();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al guardar ingrediente')),
                    );
                    print('Error al guardar ingrediente: $e');
                  }
                }
              },
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    );
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
        title: Text('Ingredientes', style: TextStyle(color: textDark)),
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
                    style: TextStyle(color: textDark),
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
                                  : textDark,
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
                      dropdownColor: cardBg,
                      style: TextStyle(color: textDark),
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
                      style: TextStyle(color: textDark),
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
                        color: cardBg,
                        child: ListTile(
                          title: Text(
                            item.nombre,
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Categoría: ${_obtenerNombreCategoria(item.categoria)} | Unidad: ${item.unidad}',
                                style: TextStyle(color: Color(kTextLight)),
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
                                    'Stock: ${item.stock} ${item.unidad}',
                                    style: TextStyle(
                                      color: esStockBajo
                                          ? Colors.red
                                          : textDark,
                                      fontWeight: esStockBajo
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    'Costo: \$${item.costo.toStringAsFixed(2)}',
                                    style: TextStyle(color: Color(kTextLight)),
                                  ),
                                ],
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.edit, color: primary),
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
        backgroundColor: primary,
        onPressed: () => _mostrarDialogoNuevoIngrediente(),
        child: Icon(Icons.add),
      ),
    );
  }
}
