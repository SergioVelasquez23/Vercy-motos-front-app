import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../services/cliente_service.dart';
import '../services/producto_service.dart';
import '../services/reportes_service.dart';
import '../theme/app_theme.dart';
import '../services/cuadre_caja_service.dart';

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
  final _cuadreCajaService = CuadreCajaService();
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
  bool _filtrarPorCaja = true;

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
      lastDate: DateTime(2100),
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
      String? cuadreId;
      if (_filtrarPorCaja) {
        final cajaActiva = await _cuadreCajaService.getCajaActiva();
        cuadreId = cajaActiva?.id;
        if (cuadreId == null) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No hay caja activa.')),
            );
          }
          return;
        }
      }
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
          cuadreId: _filtrarPorCaja ? cuadreId : null,
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
          cuadreId: _filtrarPorCaja ? cuadreId : null,
        );
      }
      // Filtrar en frontend por cuadreId o por rango de apertura/cierre de la caja activa
      if (_filtrarPorCaja && cuadreId != null) {
        if (datos.isNotEmpty && datos.first.containsKey('cuadreId')) {
          datos = datos.where((item) => item['cuadreId'] == cuadreId).toList();
        } else {
          // Si no existe el campo cuadreId, filtrar por rango de fechas de la caja activa
          final cajaActiva = await _cuadreCajaService.getCajaActiva();
          if (cajaActiva != null) {
            // Rango: desde el día de apertura a las 6 AM hasta el día siguiente a las 4 AM
            final apertura = DateTime(
              cajaActiva.fechaApertura.year,
              cajaActiva.fechaApertura.month,
              cajaActiva.fechaApertura.day,
              6,
              0,
              0,
            );
            final cierre = DateTime(
              cajaActiva.fechaApertura.add(const Duration(days: 1)).year,
              cajaActiva.fechaApertura.add(const Duration(days: 1)).month,
              cajaActiva.fechaApertura.add(const Duration(days: 1)).day,
              4,
              0,
              0,
            );
            datos = datos.where((item) {
              final fechaStr = item['fecha'] ?? '';
              DateTime? fechaPedido;
              try {
                fechaPedido = DateTime.parse(
                  fechaStr.replaceAll('/', '-').replaceAll(' ', 'T'),
                );
              } catch (_) {
                // Intentar parsear como 'yyyy-MM-dd HH:mm'
                try {
                  fechaPedido = DateFormat('yyyy-MM-dd HH:mm').parse(fechaStr);
                } catch (_) {
                  return false;
                }
              }
              return fechaPedido != null &&
                  !fechaPedido.isBefore(apertura) &&
                  !fechaPedido.isAfter(cierre);
            }).toList();
          }
        }
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Informes de Productos',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.warning,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/dashboard');
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECCIÓN DE FILTROS
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.metal.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Generar informe productos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Filtrar por caja activa',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Switch(
                              value: _filtrarPorCaja,
                              onChanged: (v) {
                                setState(() {
                                  _filtrarPorCaja = v;
                                });
                              },
                              activeColor: AppTheme.success,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Fila 1: Fechas
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            'Desde',
                            _fechaDesde,
                            () => _selectDate(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateField(
                            'Hasta',
                            _fechaHasta,
                            () => _selectDate(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Fila 2: Cliente y Vendedor
                    Row(
                      children: [
                        Expanded(
                          child: _buildClienteAutocomplete()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            'Vendedor',
                            _vendedorController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Fila 3: Código y Producto
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Código',
                            _codigoController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildProductoAutocomplete(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppTheme.success
                                  .withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.description),
                            label: const Text(
                              'Generar informe detallado',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _generarInforme('agrupado'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppTheme.success
                                  .withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.summarize),
                            label: const Text(
                              'Generar informe agrupado',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // TABLA DE RESULTADOS
              if (_tipoInformeActual != null)
                _buildTablaResultados(),
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.metal.withOpacity(0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
              color: AppTheme.cardBg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dateFormat.format(fecha),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
                Icon(
                  Icons.calendar_today,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.5),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: AppTheme.metal.withOpacity(0.2),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: AppTheme.metal.withOpacity(0.2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppTheme.warning, width: 1.5),
            ),
            filled: true,
            fillColor: AppTheme.cardBg,
          ),
        ),
      ],
    );
  }

  Widget _buildClienteAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cliente',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
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
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              onChanged: (value) {
                _clienteController.text = value;
              },
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.5),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          controller.clear();
                          _clienteController.clear();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppTheme.metal.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppTheme.metal.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppTheme.warning, width: 1.5),
                ),
                filled: true,
                fillColor: AppTheme.cardBg,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                    maxWidth: 400,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final cliente = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          cliente.nombreCompleto,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          cliente.numeroIdentificacion,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => onSelected(cliente),
                        hoverColor: AppTheme.warning.withOpacity(0.1),
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

  Widget _buildProductoAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nombre Producto',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
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
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              onChanged: (value) {
                _productoController.text = value;
              },
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.5),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          controller.clear();
                          _productoController.clear();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppTheme.metal.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppTheme.metal.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppTheme.warning, width: 1.5),
                ),
                filled: true,
                fillColor: AppTheme.cardBg,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                    maxWidth: 400,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final producto = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          producto.nombre,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          producto.codigo ?? '',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => onSelected(producto),
                        hoverColor: AppTheme.warning.withOpacity(0.1),
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

  Widget _buildTablaResultados() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: AppTheme.warning),
      );
    }

    if (_resultados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Text(
          'No hay datos para mostrar',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resumen
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.metal.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildResumenCard(
                'Cantidad',
                _totalCantidad.toDouble(),
                isInt: true,
              ),
              _buildResumenCard('Subtotal', _totalSubtotal),
              _buildResumenCard('Descuento', _totalDescuento),
              _buildResumenCard('Impuesto', _totalImpuesto),
              _buildResumenCard('Total Ventas', _totalVentas),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Tabla
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTheme.metal.withOpacity(0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.cardBg,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppTheme.backgroundDark.withOpacity(0.3),
              ),
              dataRowColor: WidgetStateProperty.all(AppTheme.cardBg),
              columns: [
                DataColumn(label: _buildColumnHeader('TIPO')),
                DataColumn(label: _buildColumnHeader('FECHA')),
                DataColumn(label: _buildColumnHeader('# FACTURA')),
                DataColumn(label: _buildColumnHeader('CLIENTE')),
                DataColumn(label: _buildColumnHeader('PRODUCTO')),
                DataColumn(label: _buildColumnHeader('CÓDIGO')),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('CANT'),
                ),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('P. UNIT'),
                ),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('SUBTOTAL'),
                ),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('DESC.'),
                ),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('IMP.'),
                ),
                DataColumn(
                  numeric: true,
                  label: _buildColumnHeader('TOTAL'),
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
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        item['fecha'] ?? '-',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        item['numeroFactura'] ?? '-',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        item['cliente'] ?? '-',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        item['nombreProducto'] ?? '-',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        item['codigoProducto'] ?? '-',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        (item['cantidad'] ?? 0).toString(),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(precioUnitario),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(subtotal),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(descuento),
                        style: TextStyle(
                          color: descuento > 0
                              ? AppTheme.warning
                              : AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(impuesto),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(total),
                        style: TextStyle(
                          color: AppTheme.success,
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
        const SizedBox(height: 24),
        // Fila de totales
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.metal.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTotalItem('REGISTROS', _resultados.length.toString()),
                const SizedBox(width: 30),
                _buildTotalItem('CANTIDAD', _totalCantidad.toString()),
                const SizedBox(width: 30),
                _buildTotalItem('SUBTOTAL', _formatCurrency(_totalSubtotal)),
                const SizedBox(width: 30),
                _buildTotalItem(
                  'DESCUENTO',
                  _formatCurrency(_totalDescuento),
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 30),
                _buildTotalItem('IMPUESTO', _formatCurrency(_totalImpuesto)),
                const SizedBox(width: 30),
                _buildTotalItem(
                  'TOTAL VENTAS',
                  _formatCurrency(_totalVentas),
                  color: AppTheme.success,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  Widget _buildResumenCard(String label, double valor, {bool isInt = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isInt ? valor.toInt().toString() : _formatCurrency(valor),
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
