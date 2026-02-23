import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../services/cliente_service.dart';
import '../services/producto_service.dart';
import '../services/reportes_service.dart';
import '../theme/app_theme.dart';

class InformesProductosScreen extends StatefulWidget {
  const InformesProductosScreen({super.key});

  @override
  State<InformesProductosScreen> createState() =>
      _InformesProductosScreenState();
}

class _InformesProductosScreenState extends State<InformesProductosScreen> {
  final ReportesService _reportesService = ReportesService();
  final ProductoService _productoService = ProductoService();
  final ClienteService _clienteService = ClienteService();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // Filtros
  DateTime _fechaDesde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaHasta = DateTime.now();
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _vendedorController = TextEditingController();
  final TextEditingController _productoController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();

  // Listas para dropdowns
  List<Cliente> _clientes = [];
  List<Producto> _productos = [];

  // Estados
  bool _isLoading = false;
  String? _tipoInformeActual; // 'detallado' o 'agrupado'
  List<Map<String, dynamic>> _resultados = [];
  double _totalSubtotal = 0;
  double _totalDescuento = 0;
  double _totalImpuesto = 0;
  double _totalVentas = 0;
  int _totalCantidad = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    await Future.wait([_cargarClientes(), _cargarProductos()]);
  }

  Future<void> _cargarClientes() async {
    try {
      final clientes = await _clienteService.obtenerClientes();
      if (mounted) setState(() => _clientes = clientes);
    } catch (e) {
      debugPrint('Error cargando clientes: $e');
    }
  }

  Future<void> _cargarProductos() async {
    try {
      final productos = await _productoService
          .getProductosLigeroParaDesplegables();
      if (mounted) setState(() => _productos = productos);
    } catch (e) {
      debugPrint('Error cargando productos: $e');
    }
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _vendedorController.dispose();
    _productoController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isDesde) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDesde ? _fechaDesde : _fechaHasta,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isDesde) {
          _fechaDesde = picked;
        } else {
          _fechaHasta = picked;
        }
      });
    }
  }

  Future<void> _generarInforme(String tipo) async {
    setState(() {
      _isLoading = true;
      _tipoInformeActual = tipo;
      _resultados = [];
      _totalSubtotal = 0;
      _totalDescuento = 0;
      _totalImpuesto = 0;
      _totalVentas = 0;
      _totalCantidad = 0;
    });

    try {
      List<Map<String, dynamic>> datos;

      if (tipo == 'detallado') {
        datos = await _reportesService.getProductosVentasDetallado(
          desde: _fechaDesde,
          hasta: _fechaHasta,
          cliente: _clienteController.text.isNotEmpty
              ? _clienteController.text
              : null,
          producto: _productoController.text.isNotEmpty
              ? _productoController.text
              : null,
          vendedor: _vendedorController.text.isNotEmpty
              ? _vendedorController.text
              : null,
          codigo: _codigoController.text.isNotEmpty
              ? _codigoController.text
              : null,
        );
      } else {
        datos = await _reportesService.getProductosVentasAgrupado(
          desde: _fechaDesde,
          hasta: _fechaHasta,
          cliente: _clienteController.text.isNotEmpty
              ? _clienteController.text
              : null,
          producto: _productoController.text.isNotEmpty
              ? _productoController.text
              : null,
          vendedor: _vendedorController.text.isNotEmpty
              ? _vendedorController.text
              : null,
          codigo: _codigoController.text.isNotEmpty
              ? _codigoController.text
              : null,
        );
      }

      // Calcular totales
      for (var item in datos) {
        _totalCantidad += ((item['cantidad'] ?? 0) as num).toInt();
        _totalSubtotal += (item['subtotal'] ?? 0).toDouble();
        _totalDescuento += (item['descuento'] ?? 0).toDouble();
        _totalImpuesto += (item['impuesto'] ?? 0).toDouble();
        _totalVentas += (item['total'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _resultados = datos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al generar informe: $e')));
      }
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '\$0';
    final formatter = NumberFormat('#,##0', 'es_CO');
    return '\$${formatter.format(value)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Informes de Productos'),
        centerTitle: true,
        backgroundColor: AppTheme.warning,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECCIÓN DE FILTROS
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generar informe productos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Fila 1: Fechas
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            'Desde',
                            _fechaDesde,
                            () => _selectDate(true),
                            textColor,
                            cardColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDateField(
                            'Hasta',
                            _fechaHasta,
                            () => _selectDate(false),
                            textColor,
                            cardColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Fila 2: Cliente y Vendedor
                    Row(
                      children: [
                        Expanded(
                          child: _buildClienteAutocomplete(
                            textColor,
                            cardColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            'Vendedor',
                            _vendedorController,
                            textColor,
                            cardColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Fila 3: Código y Producto
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Código',
                            _codigoController,
                            textColor,
                            cardColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildProductoAutocomplete(
                            textColor,
                            cardColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _generarInforme('detallado'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.description),
                            label: const Text('Generar informe detallado'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _generarInforme('agrupado'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.summarize),
                            label: const Text('Generar informe agrupado'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // TABLA DE RESULTADOS
              if (_tipoInformeActual != null)
                _buildTablaResultados(textColor, cardColor, subtextColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime fecha,
    VoidCallback onTap,
    Color textColor,
    Color cardColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
              color: cardColor,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dateFormat.format(fecha),
                  style: TextStyle(color: textColor),
                ),
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color textColor,
    Color cardColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFFFF6B00)),
            ),
            filled: true,
            fillColor: cardColor,
          ),
        ),
      ],
    );
  }

  Widget _buildClienteAutocomplete(Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cliente',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Autocomplete<Cliente>(
          displayStringForOption: (c) => c.nombreCompleto,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return _clientes;
            final query = textEditingValue.text.toLowerCase();
            return _clientes.where(
              (c) =>
                  c.nombreCompleto.toLowerCase().contains(query) ||
                  c.numeroIdentificacion.toLowerCase().contains(query),
            );
          },
          onSelected: (Cliente cliente) {
            _clienteController.text = cliente.nombreCompleto;
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(color: textColor),
              onChanged: (value) {
                _clienteController.text = value;
              },
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.grey,
                  size: 20,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.grey,
                          size: 18,
                        ),
                        onPressed: () {
                          controller.clear();
                          _clienteController.clear();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFFF6B00)),
                ),
                filled: true,
                fillColor: cardColor,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                    maxWidth: 400,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final cliente = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          cliente.nombreCompleto,
                          style: TextStyle(color: textColor, fontSize: 13),
                        ),
                        subtitle: Text(
                          cliente.numeroIdentificacion,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => onSelected(cliente),
                        hoverColor: const Color(0xFFFF6B00).withOpacity(0.1),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductoAutocomplete(Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nombre Producto',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Autocomplete<Producto>(
          displayStringForOption: (p) => p.nombre,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return _productos;
            final query = textEditingValue.text.toLowerCase();
            return _productos.where(
              (p) =>
                  p.nombre.toLowerCase().contains(query) ||
                  (p.codigo?.toLowerCase().contains(query) ?? false),
            );
          },
          onSelected: (Producto producto) {
            _productoController.text = producto.nombre;
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(color: textColor),
              onChanged: (value) {
                _productoController.text = value;
              },
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.grey,
                  size: 20,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.grey,
                          size: 18,
                        ),
                        onPressed: () {
                          controller.clear();
                          _productoController.clear();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFFF6B00)),
                ),
                filled: true,
                fillColor: cardColor,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                    maxWidth: 400,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final producto = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          producto.nombre,
                          style: TextStyle(color: textColor, fontSize: 13),
                        ),
                        subtitle: Text(
                          producto.codigo ?? '',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => onSelected(producto),
                        hoverColor: const Color(0xFFFF6B00).withOpacity(0.1),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTablaResultados(
    Color textColor,
    Color cardColor,
    Color? subtextColor,
  ) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_resultados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Text(
          'No hay datos para mostrar',
          style: TextStyle(color: subtextColor, fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resumen
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildResumenCard('Cantidad', _totalCantidad.toDouble(), textColor, isInt: true),
              _buildResumenCard('Subtotal', _totalSubtotal, textColor),
              _buildResumenCard('Descuento', _totalDescuento, textColor),
              _buildResumenCard('Impuesto', _totalImpuesto, textColor),
              _buildResumenCard('Total Ventas', _totalVentas, textColor),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Tabla
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
            color: cardColor,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                Colors.black.withOpacity(0.2),
              ),
              dataRowColor: WidgetStateProperty.all(cardColor.withOpacity(0.7)),
              columns: [
                DataColumn(label: _buildColumnHeader('TIPO', textColor)),
                DataColumn(label: _buildColumnHeader('FECHA', textColor)),
                DataColumn(label: _buildColumnHeader('# FACTURA', textColor)),
                DataColumn(label: _buildColumnHeader('CLIENTE', textColor)),
                DataColumn(label: _buildColumnHeader('PRODUCTO', textColor)),
                DataColumn(label: _buildColumnHeader('CÓDIGO', textColor)),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('CANT', textColor),
                ),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('P. UNIT', textColor),
                ),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('SUBTOTAL', textColor),
                ),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('DESC.', textColor),
                ),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('IMP.', textColor),
                ),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('TOTAL', textColor),
                ),
              ],
              rows: _resultados.map((item) {
                final total = (item['total'] ?? 0).toDouble();
                final subtotal = (item['subtotal'] ?? 0).toDouble();
                final precioUnitario = (item['precioUnitario'] ?? 0).toDouble();
                final descuento = (item['descuento'] ?? 0).toDouble();
                final impuesto = (item['impuesto'] ?? 0).toDouble();

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        item['tipo'] ?? 'POS',
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        item['fecha'] ?? '-',
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        item['numeroFactura'] ?? '-',
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        item['cliente'] ?? '-',
                        style: TextStyle(color: textColor, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        item['nombreProducto'] ?? '-',
                        style: TextStyle(color: textColor, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        item['codigoProducto'] ?? '-',
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        (item['cantidad'] ?? 0).toString(),
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(precioUnitario),
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(subtotal),
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(descuento),
                        style: TextStyle(
                          color: descuento > 0 ? Colors.orange : textColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(impuesto),
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(total),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Fila de totales
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTotalItem('REGISTROS', _resultados.length.toString(), textColor),
                const SizedBox(width: 30),
                _buildTotalItem('CANTIDAD', _totalCantidad.toString(), textColor),
                const SizedBox(width: 30),
                _buildTotalItem('SUBTOTAL', _formatCurrency(_totalSubtotal), textColor),
                const SizedBox(width: 30),
                _buildTotalItem('DESCUENTO', _formatCurrency(_totalDescuento), Colors.orange),
                const SizedBox(width: 30),
                _buildTotalItem('IMPUESTO', _formatCurrency(_totalImpuesto), textColor),
                const SizedBox(width: 30),
                _buildTotalItem('TOTAL VENTAS', _formatCurrency(_totalVentas), Colors.green),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeader(String text, Color textColor) {
    return Text(
      text,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  Widget _buildResumenCard(String label, double valor, Color textColor, {bool isInt = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isInt ? valor.toInt().toString() : _formatCurrency(valor),
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
