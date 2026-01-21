import 'package:flutter/material.dart';
import '../models/factura_compra.dart';
import '../models/proveedor.dart';
import '../services/factura_compra_service.dart';
import '../services/proveedor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vercy_sidebar_layout.dart';
import '../utils/format_utils.dart';

class ComprasListScreen extends StatefulWidget {
  const ComprasListScreen({super.key});

  @override
  _ComprasListScreenState createState() => _ComprasListScreenState();
}

class _ComprasListScreenState extends State<ComprasListScreen> {
  final FacturaCompraService _facturaCompraService = FacturaCompraService();
  final ProveedorService _proveedorService = ProveedorService();

  // Controladores de filtros
  final _filtroNumeroCompraController = TextEditingController();
  final _filtroNumeroFacturaController = TextEditingController();
  final _filtroProveedorController = TextEditingController();

  // Fechas
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  // Otros filtros
  bool _soloCuentasPorPagar = false;
  String _ordenamiento = 'reciente';
  String _ubicacion = 'TODAS';

  List<FacturaCompra> _compras = [];
  List<FacturaCompra> _comprasFiltradas = [];
  List<Proveedor> _proveedores = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _filtroNumeroCompraController.dispose();
    _filtroNumeroFacturaController.dispose();
    _filtroProveedorController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final compras = await _facturaCompraService.getFacturasCompras();
      final proveedores = await _proveedorService.getProveedores();
      setState(() {
        _compras = compras;
        _proveedores = proveedores;
        _aplicarFiltros();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _comprasFiltradas = _compras.where((compra) {
        // Filtro por número de compra
        final matchNumeroCompra =
            _filtroNumeroCompraController.text.isEmpty ||
            (compra.id?.toLowerCase().contains(
                  _filtroNumeroCompraController.text.toLowerCase(),
                ) ??
                false);

        // Filtro por número de factura
        final matchNumeroFactura =
            _filtroNumeroFacturaController.text.isEmpty ||
            compra.numeroFactura.toLowerCase().contains(
              _filtroNumeroFacturaController.text.toLowerCase(),
            );

        // Filtro por proveedor
        final matchProveedor =
            _filtroProveedorController.text.isEmpty ||
            compra.proveedorNombre.toLowerCase().contains(
              _filtroProveedorController.text.toLowerCase(),
            );

        // Filtro por fecha inicio
        final matchFechaInicio =
            _fechaInicio == null ||
            compra.fechaFactura.isAfter(_fechaInicio!) ||
            compra.fechaFactura.isAtSameMomentAs(_fechaInicio!);

        // Filtro por fecha fin
        final matchFechaFin =
            _fechaFin == null ||
            compra.fechaFactura.isBefore(_fechaFin!.add(Duration(days: 1)));

        // Filtro cuentas por pagar
        final matchCuentasPorPagar =
            !_soloCuentasPorPagar ||
            (compra.estado.toUpperCase() == 'PENDIENTE' &&
                !compra.pagadoDesdeCaja);

        return matchNumeroCompra &&
            matchNumeroFactura &&
            matchProveedor &&
            matchFechaInicio &&
            matchFechaFin &&
            matchCuentasPorPagar;
      }).toList();

      // Ordenar
      if (_ordenamiento == 'reciente') {
        _comprasFiltradas.sort(
          (a, b) => b.fechaCreacion.compareTo(a.fechaCreacion),
        );
      } else if (_ordenamiento == 'antiguo') {
        _comprasFiltradas.sort(
          (a, b) => a.fechaCreacion.compareTo(b.fechaCreacion),
        );
      } else if (_ordenamiento == 'mayor') {
        _comprasFiltradas.sort((a, b) => b.total.compareTo(a.total));
      } else if (_ordenamiento == 'menor') {
        _comprasFiltradas.sort((a, b) => a.total.compareTo(b.total));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return VercySidebarLayout(
      title: 'Compras',
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              'Lista Compras',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),

            // Primera fila de filtros
            _buildPrimeraFilaFiltros(),
            SizedBox(height: 16),

            // Segunda fila de filtros
            _buildSegundaFilaFiltros(),
            SizedBox(height: 16),

            // Tabla de compras
            Expanded(child: _buildTabla()),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimeraFilaFiltros() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          // Número Compra
          Expanded(
            child: _buildCampoFiltro(
              controller: _filtroNumeroCompraController,
              hint: 'Número Compra',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 12),

          // Número Factura
          Expanded(
            child: _buildCampoFiltro(
              controller: _filtroNumeroFacturaController,
              hint: 'Número Factura',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 12),

          // Nombre Proveedor
          Expanded(
            flex: 2,
            child: _buildCampoFiltro(
              controller: _filtroProveedorController,
              hint: 'Nombre Proveedor',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 16),

          // Botón Buscar
          ElevatedButton.icon(
            onPressed: _aplicarFiltros,
            icon: Icon(Icons.search, color: Colors.white),
            label: Text(
              'Buscar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(width: 8),

          // Botón Excel
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exportar Excel - Próximamente')),
                );
              },
              icon: Icon(Icons.file_download, color: Colors.white),
              tooltip: 'Exportar Excel',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegundaFilaFiltros() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          // Fecha Inicio
          Expanded(
            child: _buildCampoFecha(
              label: 'Fecha Inicio',
              fecha: _fechaInicio,
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _fechaInicio ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: AppTheme.primary,
                          surface: AppTheme.cardBg,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (fecha != null) {
                  setState(() => _fechaInicio = fecha);
                  _aplicarFiltros();
                }
              },
              onClear: () {
                setState(() => _fechaInicio = null);
                _aplicarFiltros();
              },
            ),
          ),
          SizedBox(width: 12),

          // Fecha Fin
          Expanded(
            child: _buildCampoFecha(
              label: 'Fecha Fin',
              fecha: _fechaFin,
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _fechaFin ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: AppTheme.primary,
                          surface: AppTheme.cardBg,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (fecha != null) {
                  setState(() => _fechaFin = fecha);
                  _aplicarFiltros();
                }
              },
              onClear: () {
                setState(() => _fechaFin = null);
                _aplicarFiltros();
              },
            ),
          ),
          SizedBox(width: 16),

          // Checkbox Cuentas por Pagar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _soloCuentasPorPagar,
                  onChanged: (value) {
                    setState(() => _soloCuentasPorPagar = value ?? false);
                    _aplicarFiltros();
                  },
                  activeColor: AppTheme.primary,
                  side: BorderSide(color: Colors.grey.shade500),
                ),
                Text(
                  'Cuentas por\nPagar',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),

          // Dropdown Ordenamiento
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _ordenamiento,
                dropdownColor: AppTheme.cardBg,
                style: TextStyle(color: Colors.white, fontSize: 14),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                items: [
                  DropdownMenuItem(
                    value: 'reciente',
                    child: Text('Compra más reciente'),
                  ),
                  DropdownMenuItem(
                    value: 'antiguo',
                    child: Text('Compra más antigua'),
                  ),
                  DropdownMenuItem(value: 'mayor', child: Text('Mayor valor')),
                  DropdownMenuItem(value: 'menor', child: Text('Menor valor')),
                ],
                onChanged: (value) {
                  setState(() => _ordenamiento = value ?? 'reciente');
                  _aplicarFiltros();
                },
              ),
            ),
          ),
          SizedBox(width: 12),

          // Dropdown Ubicación
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _ubicacion,
                dropdownColor: AppTheme.cardBg,
                style: TextStyle(color: Colors.white, fontSize: 14),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                items: [
                  DropdownMenuItem(value: 'TODAS', child: Text('Ubicación')),
                  DropdownMenuItem(value: 'BODEGA', child: Text('BODEGA')),
                  DropdownMenuItem(value: 'TIENDA', child: Text('TIENDA')),
                ],
                onChanged: (value) {
                  setState(() => _ubicacion = value ?? 'TODAS');
                  _aplicarFiltros();
                },
              ),
            ),
          ),

          Spacer(),

          // Botón Crear Compra
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/facturas-compras'),
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              'Crear Compra',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoFiltro({
    required TextEditingController controller,
    required String hint,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: AppTheme.surfaceDark,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildCampoFecha({
    required String label,
    required DateTime? fecha,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade700),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                fecha != null
                    ? '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}'
                    : label,
                style: TextStyle(
                  color: fecha != null ? Colors.white : Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ),
            if (fecha != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, color: Colors.grey, size: 18),
              )
            else
              Icon(Icons.calendar_today, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTabla() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          // Encabezado de la tabla
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                _buildEncabezadoColumna('#', flex: 1),
                _buildEncabezadoColumna('Factura', flex: 2),
                _buildEncabezadoColumna('Proveedor', flex: 2),
                _buildEncabezadoColumna('Expedición', flex: 2),
                _buildEncabezadoColumna('Vencimiento', flex: 2),
                _buildEncabezadoColumna(
                  'Total',
                  flex: 2,
                  align: TextAlign.right,
                ),
                _buildEncabezadoColumna(
                  'Descuento',
                  flex: 1,
                  align: TextAlign.right,
                ),
                _buildEncabezadoColumna(
                  'Pagado',
                  flex: 2,
                  align: TextAlign.right,
                ),
                _buildEncabezadoColumna(
                  'Por pagar',
                  flex: 2,
                  align: TextAlign.right,
                ),
                _buildEncabezadoColumna(
                  'Estado',
                  flex: 2,
                  align: TextAlign.center,
                ),
                _buildEncabezadoColumna('Destino', flex: 2),
              ],
            ),
          ),

          // Filas de la tabla
          Expanded(
            child: _comprasFiltradas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay compras registradas',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _comprasFiltradas.length,
                    itemBuilder: (context, index) {
                      final compra = _comprasFiltradas[index];
                      return _buildFilaTabla(compra, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncabezadoColumna(
    String texto, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        texto,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        textAlign: align,
      ),
    );
  }

  Widget _buildFilaTabla(FacturaCompra compra, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? AppTheme.cardBg : AppTheme.surfaceDark;

    // Calcular valores
    final pagado =
        compra.pagadoDesdeCaja || compra.estado.toUpperCase() == 'PAGADA'
        ? compra.total
        : 0.0;
    final porPagar = compra.total - pagado;
    final estado =
        compra.pagadoDesdeCaja || compra.estado.toUpperCase() == 'PAGADA'
        ? 'Completa'
        : 'Pendiente';

    // ID corto para mostrar
    String numeroCompra = 'OC${(index + 1).toString().padLeft(3, '0')}';
    if (compra.id != null && compra.id!.length >= 4) {
      numeroCompra =
          'OC${compra.id!.substring(compra.id!.length - 4).toUpperCase()}';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // #
          Expanded(
            flex: 1,
            child: Text(
              numeroCompra,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          // Factura (con botón editar)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.edit, color: Colors.white, size: 16),
                    onPressed: () {
                      // TODO: Navegar a editar factura
                    },
                    tooltip: 'Editar',
                  ),
                ),
              ],
            ),
          ),

          // Proveedor
          Expanded(
            flex: 2,
            child: Text(
              compra.proveedorNombre,
              style: TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Expedición
          Expanded(
            flex: 2,
            child: Text(
              '${compra.fechaFactura.year}-${compra.fechaFactura.month.toString().padLeft(2, '0')}-${compra.fechaFactura.day.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          // Vencimiento
          Expanded(
            flex: 2,
            child: Text(
              '${compra.fechaVencimiento.year}-${compra.fechaVencimiento.month.toString().padLeft(2, '0')}-${compra.fechaVencimiento.day.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          // Total
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${formatNumberWithDots(compra.total)}',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Descuento
          Expanded(
            flex: 1,
            child: Text(
              '\$ ${formatNumberWithDots(compra.totalDescuentos)}',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Pagado
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${formatNumberWithDots(pagado)}',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Por pagar
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${formatNumberWithDots(porPagar)}',
              style: TextStyle(
                color: porPagar > 0 ? Colors.orange : Colors.white,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Estado
          Expanded(
            flex: 2,
            child: Text(
              estado,
              style: TextStyle(
                color: estado == 'Completa' ? AppTheme.success : Colors.orange,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Destino
          Expanded(
            flex: 2,
            child: Text(
              'BODEGA',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
