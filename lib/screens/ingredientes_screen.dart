import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/inventario_service.dart';
import '../models/inventario.dart';
import '../widgets/loading_indicator.dart';

class IngredientesScreen extends StatefulWidget {
  @override
  _IngredientesScreenState createState() => _IngredientesScreenState();
}

class _IngredientesScreenState extends State<IngredientesScreen> {
  final InventarioService _inventarioService = InventarioService();
  List<Inventario> _ingredientes = [];
  List<Inventario> _ingredientesFiltrados = [];
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
      final ingredientes = await _inventarioService.getInventario();
      setState(() {
        _ingredientes = ingredientes;
        _ingredientesFiltrados = ingredientes;
        _error = '';
      });
    } catch (e) {
      setState(() => _error = kErrorCargaDatos);
      print('Error cargando ingredientes: $e');
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

  Future<void> _confirmarEliminarIngrediente(Inventario ingrediente) async {
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
        await _inventarioService.deleteIngrediente(ingrediente.id);
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

  void _mostrarDialogoNuevoIngrediente([Inventario? ingrediente]) {
    final _formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(
      text: ingrediente?.nombre ?? '',
    );
    final codigoController = TextEditingController(
      text: ingrediente?.codigo ?? '',
    );
    final categoriaController = TextEditingController(
      text: ingrediente?.categoria ?? '',
    );
    final unidadController = TextEditingController(
      text: ingrediente?.unidad ?? '',
    );
    final precioController = TextEditingController(
      text: ingrediente?.precioCompra.toString() ?? '',
    );
    final stockActualController = TextEditingController(
      text: ingrediente?.stockActual.toString() ?? '',
    );
    final stockMinimoController = TextEditingController(
      text: ingrediente?.stockMinimo.toString() ?? '',
    );

    bool esDescontable = ingrediente?.descontable ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            ingrediente == null ? 'Nuevo Ingrediente' : 'Editar Ingrediente',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
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
                  TextFormField(
                    controller: codigoController,
                    decoration: InputDecoration(
                      labelText: 'Código*',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: Color(kTextDark)),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Campo requerido';
                      if (value!.length < 2) return 'Mínimo 2 caracteres';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: categoriaController,
                    decoration: InputDecoration(
                      labelText: 'Categoría*',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: Color(kTextDark)),
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
                    controller: precioController,
                    decoration: InputDecoration(
                      labelText: 'Precio de compra*',
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
                      final precio = double.tryParse(value!);
                      if (precio == null) return 'Ingrese un número válido';
                      if (precio <= 0) return 'El precio debe ser mayor a 0';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: stockActualController,
                    decoration: InputDecoration(
                      labelText: 'Stock actual*',
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
                      final stock = double.tryParse(value!);
                      if (stock == null) return 'Ingrese un número válido';
                      if (stock < 0) return 'El stock no puede ser negativo';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: stockMinimoController,
                    decoration: InputDecoration(
                      labelText: 'Stock mínimo*',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      helperText: 'Nivel mínimo para alertas',
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: Color(kTextDark)),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Campo requerido';
                      final stockMin = double.tryParse(value!);
                      if (stockMin == null) return 'Ingrese un número válido';
                      if (stockMin < 0)
                        return 'El stock mínimo no puede ser negativo';
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
                if (_formKey.currentState?.validate() ?? false) {
                  try {
                    final nuevoIngrediente = Inventario(
                      id: ingrediente?.id ?? '',
                      nombre: nombreController.text,
                      codigo: codigoController.text,
                      categoria: categoriaController.text,
                      unidad: unidadController.text,
                      precioCompra: double.parse(precioController.text),
                      stockActual: double.parse(stockActualController.text),
                      stockMinimo: double.parse(stockMinimoController.text),
                      estado: ingrediente?.estado ?? 'ACTIVO',
                      descontable: esDescontable,
                    );

                    if (ingrediente == null) {
                      // Nuevo ingrediente
                      await _inventarioService.createIngrediente(
                        nuevoIngrediente,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ingrediente agregado')),
                      );
                    } else {
                      // Editar ingrediente
                      await _inventarioService.updateIngrediente(
                        ingrediente.id,
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
                          item.stockActual <= item.stockMinimo ||
                          item.stockActual <= kStockBajoUmbral;

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
                                'Categoría: ${item.categoria} | Unidad: ${item.unidad}',
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
                                    'Stock: ${item.stockActual}',
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
                                    'Precio: \$${item.precioCompra.toStringAsFixed(2)}',
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
