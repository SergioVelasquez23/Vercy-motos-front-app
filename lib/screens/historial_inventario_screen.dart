import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/movimiento_inventario.dart';
import '../services/inventario_service.dart';
import '../widgets/loading_indicator.dart';

class HistorialInventarioScreen extends StatefulWidget {
  @override
  _HistorialInventarioScreenState createState() =>
      _HistorialInventarioScreenState();
}

class _HistorialInventarioScreenState extends State<HistorialInventarioScreen> {
  final InventarioService _inventarioService = InventarioService();

  // Estados de UI
  bool _isLoading = true;
  String _error = '';

  // Filtros y datos
  List<MovimientoInventario> _movimientos = [];
  List<MovimientoInventario> _movimientosFiltrados = [];
  DateTime _fechaDesde = DateTime.now().subtract(Duration(days: 30));
  DateTime _fechaHasta = DateTime.now();
  String _productoSeleccionado = 'Todos los productos';
  String _tipoMovimientoSeleccionado = '-- Tipo --';

  // Controladores
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarMovimientos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarMovimientos() async {
    setState(() => _isLoading = true);

    try {
      final movimientos = await _inventarioService.getMovimientosInventario();

      setState(() {
        _movimientos = movimientos;
        _aplicarFiltros();
        _error = '';
      });
    } catch (e) {
      setState(() => _error = kErrorCargaDatos);
      print('Error cargando movimientos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarFecha(BuildContext context, bool esDesde) async {
    final DateTime initialDate = esDesde ? _fechaDesde : _fechaHasta;
    final DateTime firstDate = DateTime(2020);
    final DateTime lastDate = DateTime.now().add(Duration(days: 1));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Color(kPrimaryColor),
              onPrimary: Colors.white,
              surface: Color(kCardBackgroundDark),
              onSurface: Color(kTextDark),
            ),
            dialogBackgroundColor: Color(kCardBackgroundDark),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (esDesde) {
          _fechaDesde = picked;
          // Si la fecha inicial es mayor que la final, actualizar la final
          if (_fechaDesde.isAfter(_fechaHasta)) {
            _fechaHasta = _fechaDesde;
          }
        } else {
          _fechaHasta = picked;
          // Si la fecha final es menor que la inicial, actualizar la inicial
          if (_fechaHasta.isBefore(_fechaDesde)) {
            _fechaDesde = _fechaHasta;
          }
        }
        _aplicarFiltros();
      });
    }
  }

  void _aplicarFiltros() {
    final String searchQuery = _searchController.text.toLowerCase();

    setState(() {
      _movimientosFiltrados = _movimientos.where((movimiento) {
        // Filtrar por rango de fechas
        final fechaEnRango =
            (movimiento.fecha.isAfter(_fechaDesde) ||
                movimiento.fecha.isAtSameMomentAs(_fechaDesde)) &&
            (movimiento.fecha.isBefore(_fechaHasta.add(Duration(days: 1))) ||
                movimiento.fecha.isAtSameMomentAs(_fechaHasta));

        // Filtrar por búsqueda de texto
        final matchText =
            searchQuery.isEmpty ||
            movimiento.productoNombre.toLowerCase().contains(searchQuery) ||
            (movimiento.proveedor?.toLowerCase().contains(searchQuery) ??
                false);

        // Filtrar por producto
        final matchProducto =
            _productoSeleccionado == 'Todos los productos' ||
            movimiento.productoNombre == _productoSeleccionado;

        // Filtrar por tipo de movimiento
        final matchTipo =
            _tipoMovimientoSeleccionado == '-- Tipo --' ||
            movimiento.tipoMovimiento == _tipoMovimientoSeleccionado;

        return fechaEnRango && matchText && matchProducto && matchTipo;
      }).toList();

      // Ordenar por fecha, más recientes primero
      _movimientosFiltrados.sort((a, b) => b.fecha.compareTo(a.fecha));
    });
  }

  // Obtener lista de productos
  List<String> get _productosDisponibles {
    Set<String> productos = {'Todos los productos'};
    for (var movimiento in _movimientos) {
      if (movimiento.productoNombre.isNotEmpty) {
        productos.add(movimiento.productoNombre);
      }
    }
    return productos.toList()..sort();
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
        title: Text(
          'Historial de Inventario',
          style: TextStyle(color: textDark),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarMovimientos,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros de fecha
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _seleccionarFecha(context, true),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        children: [
                          Text('Desde', style: TextStyle(color: textDark)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat(kDateFormat).format(_fechaDesde),
                              style: TextStyle(color: primary),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Icon(Icons.calendar_today, size: 16, color: primary),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _seleccionarFecha(context, false),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        children: [
                          Text('Hasta', style: TextStyle(color: textDark)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat(kDateFormat).format(_fechaHasta),
                              style: TextStyle(color: primary),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Icon(Icons.calendar_today, size: 16, color: primary),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filtros de producto y tipo
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Filtro por producto
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _productoSeleccionado,
                      items: _productosDisponibles.map((producto) {
                        return DropdownMenuItem(
                          value: producto,
                          child: Text(
                            producto,
                            style: TextStyle(
                              color: producto == 'Todos los productos'
                                  ? Colors.grey
                                  : textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _productoSeleccionado = value!;
                          _aplicarFiltros();
                        });
                      },
                      dropdownColor: cardBg,
                      style: TextStyle(color: textDark),
                      underline: Container(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Filtro por tipo de movimiento
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _tipoMovimientoSeleccionado = value!;
                          _aplicarFiltros();
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

          // Buscador
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _aplicarFiltros(),
              decoration: InputDecoration(
                hintText: 'Buscar...',
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

          // Botón de búsqueda
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                padding: EdgeInsets.symmetric(vertical: 12),
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: _aplicarFiltros,
              child: Text('Buscar', style: TextStyle(fontSize: 16)),
            ),
          ),

          SizedBox(height: 16),

          // Resultados
          Expanded(
            child: _isLoading
                ? LoadingIndicator()
                : _error.isNotEmpty
                ? Center(
                    child: Text(_error, style: TextStyle(color: Colors.red)),
                  )
                : _movimientosFiltrados.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron movimientos',
                      style: TextStyle(color: textDark),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
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
                              'Fecha',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Producto',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Tipo',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Stock Inicial',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Cantidad',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Stock Final',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                        ],
                        rows: _movimientosFiltrados.map((movimiento) {
                          bool esEntrada = movimiento.tipoMovimiento
                              .toLowerCase()
                              .contains('entrada');
                          bool esSalida = movimiento.tipoMovimiento
                              .toLowerCase()
                              .contains('salida');

                          // Calcular stock inicial y final
                          double stockInicial = movimiento.cantidadAnterior;
                          double stockFinal = movimiento.cantidadNueva;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  DateFormat(
                                    '${kDateFormat} HH:mm',
                                  ).format(movimiento.fecha),
                                  style: TextStyle(color: textDark),
                                ),
                              ),
                              DataCell(
                                Text(
                                  movimiento.productoNombre,
                                  style: TextStyle(color: textDark),
                                ),
                              ),
                              DataCell(
                                Text(
                                  movimiento.tipoMovimiento,
                                  style: TextStyle(
                                    color: esEntrada
                                        ? Colors.green
                                        : (esSalida ? Colors.red : textDark),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  stockInicial.toString(),
                                  style: TextStyle(color: textDark),
                                ),
                              ),
                              DataCell(
                                Text(
                                  (esEntrada ? '+' : '-') +
                                      movimiento.cantidadMovimiento
                                          .abs()
                                          .toString(),
                                  style: TextStyle(
                                    color: esEntrada
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  stockFinal.toString(),
                                  style: TextStyle(color: textDark),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
