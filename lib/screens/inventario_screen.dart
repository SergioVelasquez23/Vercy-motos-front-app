import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/inventario.dart';
import '../models/movimiento_inventario.dart';
import '../services/inventario_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/movimiento_inventario_dialog.dart';
import '../config/constants.dart';

class InventarioScreen extends StatefulWidget {
  @override
  _InventarioScreenState createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InventarioService _inventarioService = InventarioService();

  // Lista de inventario
  List<Inventario> _inventarioItems = [];
  List<Inventario> _inventarioItemsFiltrados = [];

  // Lista de movimientos
  List<MovimientoInventario> _movimientos = [];
  List<MovimientoInventario> _movimientosFiltrados = [];

  // Estados de UI
  bool _isLoadingInventario = true;
  bool _isLoadingMovimientos = true;
  String _errorInventario = '';
  String _errorMovimientos = '';

  // Controladores para filtros
  final TextEditingController _searchInventarioController =
      TextEditingController();
  final TextEditingController _searchMovimientosController =
      TextEditingController();

  // Filtros seleccionados
  String _categoriaSeleccionada = 'Todas';
  String _tipoMovimientoSeleccionado = '-- Tipo --';
  String _proveedorSeleccionado = '-- Proveedor --';

  // Suscripción a cambios en inventario
  late StreamSubscription<bool> _inventarioSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();

    // Suscribirse a cambios en el inventario
    _inventarioSubscription = _inventarioService.onInventarioActualizado.listen(
      (_) {
        _cargarDatos();
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchInventarioController.dispose();
    _searchMovimientosController.dispose();
    _inventarioSubscription.cancel();
    super.dispose();
  }

  // Cargar datos de inventario y movimientos
  Future<void> _cargarDatos() async {
    _cargarInventario();
    _cargarMovimientos();
  }

  // Cargar inventario
  Future<void> _cargarInventario() async {
    setState(() => _isLoadingInventario = true);

    try {
      final inventario = await _inventarioService.getInventario();
      print('Inventario cargado: ${inventario.length} items');
      setState(() {
        _inventarioItems = inventario;
        _inventarioItemsFiltrados = inventario;
        _errorInventario = '';
      });
    } catch (e) {
      setState(() => _errorInventario = kErrorCargaDatos);
      print('Error cargando inventario: $e');
    } finally {
      setState(() => _isLoadingInventario = false);
    }
  }

  // Cargar movimientos
  Future<void> _cargarMovimientos() async {
    setState(() => _isLoadingMovimientos = true);

    try {
      final movimientos = await _inventarioService.getMovimientosInventario();
      setState(() {
        _movimientos = movimientos;
        _movimientosFiltrados = movimientos;
        _errorMovimientos = '';
      });
    } catch (e) {
      setState(() => _errorMovimientos = kErrorCargaDatos);
      print('Error cargando movimientos: $e');
    } finally {
      setState(() => _isLoadingMovimientos = false);
    }
  }

  // Filtrar inventario
  void _filtrarInventario() {
    setState(() {
      _inventarioItemsFiltrados = _inventarioItems.where((item) {
        // Filtrar por búsqueda
        bool matchBusqueda = item.nombre.toLowerCase().contains(
          _searchInventarioController.text.toLowerCase(),
        );

        // Filtrar por categoría
        bool matchCategoria =
            _categoriaSeleccionada == 'Todas' ||
            item.categoria == _categoriaSeleccionada;

        return matchBusqueda && matchCategoria;
      }).toList();
    });
  }

  // Filtrar movimientos
  void _filtrarMovimientos() {
    setState(() {
      _movimientosFiltrados = _movimientos.where((movimiento) {
        // Filtrar por búsqueda
        bool matchBusqueda = movimiento.productoNombre.toLowerCase().contains(
          _searchMovimientosController.text.toLowerCase(),
        );

        // Filtrar por tipo de movimiento
        bool matchTipo =
            _tipoMovimientoSeleccionado == '-- Tipo --' ||
            movimiento.tipoMovimiento.contains(_tipoMovimientoSeleccionado);

        // Filtrar por proveedor
        bool matchProveedor =
            _proveedorSeleccionado == '-- Proveedor --' ||
            (movimiento.proveedor != null &&
                movimiento.proveedor == _proveedorSeleccionado);

        return matchBusqueda && matchTipo && matchProveedor;
      }).toList();
    });
  }

  // Mostrar diálogo para crear movimiento
  void _mostrarDialogoNuevoMovimiento() async {
    // Verificar si hay elementos en el inventario
    if (_inventarioItems.isEmpty) {
      // Si está vacío, intentar cargar nuevamente
      try {
        final inventario = await _inventarioService.getInventario();
        setState(() {
          _inventarioItems = inventario;
          _inventarioItemsFiltrados = inventario;
        });
        print('Cargados ${_inventarioItems.length} productos de inventario');
      } catch (e) {
        print('Error recargando inventario: $e');
        // Mostrar mensaje al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No hay productos disponibles. Intente recargar la página.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return; // No mostrar el diálogo si no hay productos
      }
    }

    await showDialog(
      context: context,
      builder: (context) =>
          MovimientoInventarioDialog(inventarioItems: _inventarioItems),
    );
  }

  // Obtener lista de categorías
  List<String> get _categoriasDisponibles {
    Set<String> categorias = {'Todas'};
    for (var item in _inventarioItems) {
      if (item.categoria.isNotEmpty) {
        categorias.add(item.categoria);
      }
    }
    return categorias.toList()..sort();
  }

  // Obtener lista de tipos de movimiento
  List<String> get _tiposMovimientoDisponibles {
    Set<String> tipos = {'-- Tipo --'};
    for (var movimiento in _movimientos) {
      if (movimiento.tipoMovimiento.isNotEmpty) {
        tipos.add(movimiento.tipoMovimiento);
      }
    }
    return tipos.toList()..sort();
  }

  // Obtener lista de proveedores
  List<String> get _proveedoresDisponibles {
    Set<String> proveedores = {'-- Proveedor --'};
    for (var movimiento in _movimientos) {
      if (movimiento.proveedor != null && movimiento.proveedor!.isNotEmpty) {
        proveedores.add(movimiento.proveedor!);
      }
    }
    return proveedores.toList()..sort();
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
        title: Text('Inventario', style: TextStyle(color: textDark)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          tabs: [
            Tab(text: 'INVENTARIO', icon: Icon(Icons.inventory)),
            Tab(
              text: 'MOVIMIENTOS INVENTARIO',
              icon: Icon(Icons.compare_arrows),
            ),
          ],
        ),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargarDatos),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Inventario
          _buildInventarioTab(cardBg, textDark, primary),

          // Tab 2: Movimientos
          _buildMovimientosTab(cardBg, textDark, primary),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        onPressed: _mostrarDialogoNuevoMovimiento,
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildInventarioTab(Color cardBg, Color textDark, Color primary) {
    return Column(
      children: [
        // Filtros de inventario
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchInventarioController,
                  onChanged: (_) => _filtrarInventario(),
                  decoration: InputDecoration(
                    hintText: 'Nombre',
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
                        _filtrarInventario();
                      });
                    },
                    dropdownColor: cardBg,
                    style: TextStyle(color: textDark),
                    underline: Container(),
                  ),
                ),
              ),
              SizedBox(width: 8.0),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: DropdownButton<String>(
                  value: 'Mostrar:',
                  items: ['Mostrar:'].map((mostrar) {
                    return DropdownMenuItem(
                      value: mostrar,
                      child: Text(mostrar, style: TextStyle(color: textDark)),
                    );
                  }).toList(),
                  onChanged: (_) {},
                  dropdownColor: cardBg,
                  style: TextStyle(color: textDark),
                  underline: Container(),
                ),
              ),
            ],
          ),
        ),

        // Lista de inventario
        Expanded(
          child: _isLoadingInventario
              ? LoadingIndicator()
              : _errorInventario.isNotEmpty
              ? Center(
                  child: Text(
                    _errorInventario,
                    style: TextStyle(color: Colors.red),
                  ),
                )
              : _inventarioItemsFiltrados.isEmpty
              ? Center(
                  child: Text(
                    'No hay productos en el inventario',
                    style: TextStyle(color: textDark),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      cardBg.withOpacity(0.7),
                    ),
                    dataRowColor: MaterialStateProperty.all(
                      cardBg.withOpacity(0.3),
                    ),
                    columns: [
                      DataColumn(
                        label: Text(
                          'Negocio',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Categoría',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Nombre',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Unidad',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Precio de compra',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Costo Promedio',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Cantidad actual',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Stock mínimo',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Total Precio de Compra',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Total Costo Promedio',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                    ],
                    rows: _inventarioItemsFiltrados.map((item) {
                      // Verificar si el stock está por debajo del umbral mínimo configurado o del stock mínimo del producto
                      bool esStockBajo =
                          item.stockActual <= item.stockMinimo ||
                          item.stockActual <= kStockBajoUmbral;

                      // Calcular totales
                      double totalPrecioCompra =
                          item.precioCompra * item.stockActual;

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              'Sopa y Carbon',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.categoria,
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.nombre,
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.unidad,
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              NumberFormat.currency(
                                symbol: '',
                                decimalDigits: 2,
                              ).format(item.precioCompra),
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              NumberFormat.currency(
                                symbol: '',
                                decimalDigits: 2,
                              ).format(
                                item.precioCompra,
                              ), // Using precioCompra since costoPromedio isn't available
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.stockActual.toString(),
                              style: TextStyle(
                                color: esStockBajo ? Colors.red : textDark,
                                fontWeight: esStockBajo
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.stockMinimo.toString(),
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              NumberFormat.currency(
                                symbol: '',
                                decimalDigits: 2,
                              ).format(totalPrecioCompra),
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              NumberFormat.currency(
                                symbol: '',
                                decimalDigits: 2,
                              ).format(
                                totalPrecioCompra,
                              ), // Using totalPrecioCompra since totalCostoPromedio isn't available
                              style: TextStyle(color: textDark),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMovimientosTab(Color cardBg, Color textDark, Color primary) {
    return Column(
      children: [
        // Filtros de movimientos
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchMovimientosController,
                  onChanged: (_) => _filtrarMovimientos(),
                  decoration: InputDecoration(
                    hintText: 'N° Factura',
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
                    value: _tipoMovimientoSeleccionado,
                    items: _tiposMovimientoDisponibles.map((tipo) {
                      return DropdownMenuItem(
                        value: tipo,
                        child: Text(
                          tipo,
                          style: TextStyle(
                            color: tipo == '-- Tipo --'
                                ? Colors.grey
                                : textDark,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _tipoMovimientoSeleccionado = value!;
                        _filtrarMovimientos();
                      });
                    },
                    dropdownColor: cardBg,
                    style: TextStyle(color: textDark),
                    underline: Container(),
                  ),
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
                    value: _proveedorSeleccionado,
                    items: _proveedoresDisponibles.map((proveedor) {
                      return DropdownMenuItem(
                        value: proveedor,
                        child: Text(
                          proveedor,
                          style: TextStyle(
                            color: proveedor == '-- Proveedor --'
                                ? Colors.grey
                                : textDark,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _proveedorSeleccionado = value!;
                        _filtrarMovimientos();
                      });
                    },
                    dropdownColor: cardBg,
                    style: TextStyle(color: textDark),
                    underline: Container(),
                  ),
                ),
              ),
              SizedBox(width: 8.0),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: DropdownButton<String>(
                  value: 'Mostrar:',
                  items: ['Mostrar:'].map((mostrar) {
                    return DropdownMenuItem(
                      value: mostrar,
                      child: Text(mostrar, style: TextStyle(color: textDark)),
                    );
                  }).toList(),
                  onChanged: (_) {},
                  dropdownColor: cardBg,
                  style: TextStyle(color: textDark),
                  underline: Container(),
                ),
              ),
            ],
          ),
        ),

        // Lista de movimientos
        Expanded(
          child: _isLoadingMovimientos
              ? LoadingIndicator()
              : _errorMovimientos.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMovimientos,
                    style: TextStyle(color: Colors.red),
                  ),
                )
              : _movimientosFiltrados.isEmpty
              ? Center(
                  child: Text(
                    'No hay movimientos en el inventario',
                    style: TextStyle(color: textDark),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      cardBg.withOpacity(0.7),
                    ),
                    dataRowColor: MaterialStateProperty.all(
                      cardBg.withOpacity(0.3),
                    ),
                    columns: [
                      DataColumn(
                        label: Text(
                          'Fecha Movimiento',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Fecha Creación',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text('Tipo', style: TextStyle(color: textDark)),
                      ),
                      DataColumn(
                        label: Text('Total', style: TextStyle(color: textDark)),
                      ),
                      DataColumn(
                        label: Text(
                          'Proveedor',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Fact. No.',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Acciones',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                    ],
                    rows: _movimientosFiltrados.map((movimiento) {
                      bool esEntrada = movimiento.tipoMovimiento
                          .toLowerCase()
                          .contains('entrada');
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              DateFormat(
                                'yyyy-MM-dd HH:mm:ss',
                              ).format(movimiento.fecha),
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              DateFormat(
                                'yyyy-MM-dd HH:mm:ss',
                              ).format(movimiento.fecha),
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              movimiento.tipoMovimiento,
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              NumberFormat.currency(
                                symbol: '',
                                decimalDigits: 2,
                              ).format(movimiento.valorMovimiento),
                              style: TextStyle(
                                color: esEntrada
                                    ? Colors.green[300]
                                    : Colors.red[300],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              movimiento.proveedor ?? 'N/A',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Text(
                              movimiento.facturaNo ?? 'N/A',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: primary),
                                  onPressed: () {
                                    // Ver detalles o editar movimiento
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    // Eliminar movimiento
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
