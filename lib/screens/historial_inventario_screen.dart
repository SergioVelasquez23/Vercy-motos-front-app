import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/movimiento_inventario.dart';
import '../services/inventario_service.dart';
import '../widgets/loading_indicator.dart';

class HistorialInventarioScreen extends StatefulWidget {
  const HistorialInventarioScreen({super.key});

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
        _movimientosFiltrados = movimientos;
        _isLoading = false;
        _error = '';
      });

      _aplicarFiltros();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar movimientos: $e';
        _isLoading = false;
      });
    }
  }

  void _aplicarFiltros() {
    List<MovimientoInventario> filtrados = List.from(_movimientos);

    // Filtro por rango de fechas
    filtrados = filtrados.where((movimiento) {
      final fechaMovimiento = movimiento.fecha;
      return fechaMovimiento.isAfter(_fechaDesde.subtract(Duration(days: 1))) &&
          fechaMovimiento.isBefore(_fechaHasta.add(Duration(days: 1)));
    }).toList();

    // Filtro por producto
    if (_productoSeleccionado != 'Todos los productos') {
      filtrados = filtrados.where((movimiento) {
        return movimiento.productoNombre.toLowerCase().contains(
          _productoSeleccionado.toLowerCase(),
        );
      }).toList();
    }

    // Filtro por tipo de movimiento
    if (_tipoMovimientoSeleccionado != '-- Tipo --') {
      filtrados = filtrados.where((movimiento) {
        return movimiento.tipoMovimiento.toLowerCase().contains(
          _tipoMovimientoSeleccionado.toLowerCase(),
        );
      }).toList();
    }

    // Filtro por texto de búsqueda
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtrados = filtrados.where((movimiento) {
        return movimiento.productoNombre.toLowerCase().contains(searchQuery) ||
            movimiento.tipoMovimiento.toLowerCase().contains(searchQuery);
      }).toList();
    }

    // Ordenar por fecha descendente (más recientes primero)
    filtrados.sort((a, b) => b.fecha.compareTo(a.fecha));

    setState(() {
      _movimientosFiltrados = filtrados;
    });
  }

  Future<void> _seleccionarFecha(BuildContext context, bool esDesde) async {
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: esDesde ? _fechaDesde : _fechaHasta,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (fechaSeleccionada != null) {
      setState(() {
        if (esDesde) {
          _fechaDesde = fechaSeleccionada;
        } else {
          _fechaHasta = fechaSeleccionada;
        }
      });
      _aplicarFiltros();
    }
  }

  // Obtener lista de productos disponibles
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
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textDark),
            onPressed: _cargarMovimientos,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros compactos
          Container(
            padding: EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: cardBg.withOpacity(0.7),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
            ),
            child: Column(
              children: [
                // Primera fila: Fechas
                Row(
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
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Desde:',
                                style: TextStyle(color: textDark, fontSize: 12),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat(kDateFormat).format(_fechaDesde),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.right,
                                ),
                              ),
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
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Hasta:',
                                style: TextStyle(color: textDark, fontSize: 12),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat(kDateFormat).format(_fechaHasta),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Segunda fila: Filtros y búsqueda
                Row(
                  children: [
                    // Filtro por producto
                    Expanded(
                      flex: 2,
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
                                  fontSize: 12,
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
                    // Filtro por tipo
                    Expanded(
                      flex: 1,
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
                                  fontSize: 12,
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
                    SizedBox(width: 8),
                    // Campo de búsqueda
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _aplicarFiltros(),
                        decoration: InputDecoration(
                          hintText: 'Buscar...',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: Colors.white12,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: TextStyle(color: textDark, fontSize: 12),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _aplicarFiltros,
                      child: Icon(Icons.search, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // TABLA QUE OCUPA TODO EL ANCHO Y ALTO DISPONIBLE
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
                      style: TextStyle(color: textDark, fontSize: 16),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        color: cardBg,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: MediaQuery.of(context)
                                .size
                                .width, // Sin ancho mínimo, usar solo el ancho de pantalla
                            child: Column(
                              children: [
                                // ENCABEZADO FIJO GRANDE
                                Container(
                                  height: 80,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.2),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Text(
                                            'FECHA',
                                            style: TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: Text(
                                            'PRODUCTO',
                                            style: TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Text(
                                            'TIPO',
                                            style: TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            'Stock\nInicial',
                                            style: TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            'Cantidad\nMovida',
                                            style: TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            'Stock\nFinal',
                                            style: TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // CONTENIDO QUE OCUPA TODO EL RESTO
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _movimientosFiltrados.length,
                                    itemBuilder: (context, index) {
                                      final movimiento =
                                          _movimientosFiltrados[index];
                                      bool esEntrada = movimiento.tipoMovimiento
                                          .toLowerCase()
                                          .contains('entrada');
                                      bool esSalida = movimiento.tipoMovimiento
                                          .toLowerCase()
                                          .contains('salida');

                                      Color colorCantidad = textDark;
                                      if (esEntrada) {
                                        colorCantidad = Colors.green;
                                      } else if (esSalida) {
                                        colorCantidad = Colors.red;
                                      }

                                      return Container(
                                        height: 80, // Filas MÁS GRANDES
                                        decoration: BoxDecoration(
                                          color: index % 2 == 0
                                              ? Colors.transparent
                                              : Colors.white.withOpacity(0.02),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  DateFormat(
                                                    'dd/MM/yyyy\nHH:mm',
                                                  ).format(movimiento.fecha),
                                                  style: TextStyle(
                                                    color: textDark,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  movimiento.productoNombre,
                                                  style: TextStyle(
                                                    color: textDark,
                                                    fontSize: 11,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 2,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 8,
                                                ),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: esEntrada
                                                        ? Colors.green
                                                              .withOpacity(0.2)
                                                        : esSalida
                                                        ? Colors.red
                                                              .withOpacity(0.2)
                                                        : Colors.grey
                                                              .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    movimiento.tipoMovimiento,
                                                    style: TextStyle(
                                                      color: esEntrada
                                                          ? Colors.green
                                                          : esSalida
                                                          ? Colors.red
                                                          : textDark,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  movimiento.cantidadAnterior
                                                      .toStringAsFixed(0),
                                                  style: TextStyle(
                                                    color: textDark,
                                                    fontSize: 11,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  '${esEntrada
                                                      ? '+'
                                                      : esSalida
                                                      ? '-'
                                                      : ''}${movimiento.cantidadMovimiento.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    color: colorCantidad,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  movimiento.cantidadNueva
                                                      .toStringAsFixed(0),
                                                  style: TextStyle(
                                                    color: textDark,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
