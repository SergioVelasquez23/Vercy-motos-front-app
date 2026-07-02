import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/factura_compra.dart';
import '../models/proveedor.dart';
import '../services/factura_compra_service.dart';
import '../services/proveedor_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/pagination_mixin.dart';
import '../widgets/common/screen_header.dart';
import '../widgets/facturizacion/documento_soporte_dialog.dart';
import 'facturas_compras_screen.dart';

class ComprasListScreen extends StatefulWidget {
  const ComprasListScreen({super.key});

  @override
  _ComprasListScreenState createState() => _ComprasListScreenState();
}

class _ComprasListScreenState extends State<ComprasListScreen>
    with PaginacionMixin<ComprasListScreen> {
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
      });
      _aplicarFiltros();
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

      // Ordenar — usa fechaFactura como clave primaria y fechaCreacion como desempate
      if (_ordenamiento == 'reciente') {
        _comprasFiltradas.sort((a, b) {
          final cmp = b.fechaFactura.compareTo(a.fechaFactura);
          return cmp != 0 ? cmp : b.fechaCreacion.compareTo(a.fechaCreacion);
        });
      } else if (_ordenamiento == 'antiguo') {
        _comprasFiltradas.sort((a, b) {
          final cmp = a.fechaFactura.compareTo(b.fechaFactura);
          return cmp != 0 ? cmp : a.fechaCreacion.compareTo(b.fechaCreacion);
        });
      } else if (_ordenamiento == 'mayor') {
        _comprasFiltradas.sort((a, b) => b.total.compareTo(a.total));
      } else if (_ordenamiento == 'menor') {
        _comprasFiltradas.sort((a, b) => a.total.compareTo(b.total));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          icon: Icons.shopping_cart,
          title: 'Lista Compras',
          badge: '${_comprasFiltradas.length}',
          actions: [
            ScreenHeaderAction.success(
              icon: Icons.picture_as_pdf,
              label: 'Importar PDF',
              mobileLabel: 'PDF',
              onPressed: () => context.push('/facturas-compras/importar-pdf'),
            ),
            ScreenHeaderAction.primary(
              icon: Icons.add,
              label: 'Crear Compra',
              mobileLabel: 'Crear',
              onPressed: () => context.push('/facturas-compras'),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(context.isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPrimeraFilaFiltros(),
                const SizedBox(height: 16),
                _buildSegundaFilaFiltros(),
                const SizedBox(height: 16),
                Expanded(child: _buildTabla()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimeraFilaFiltros() {
    final isMobile = context.isMobile;
    final campoAncho = isMobile ? double.infinity : 200.0;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Número Compra
          SizedBox(
            width: campoAncho,
            child: _buildCampoFiltro(
              controller: _filtroNumeroCompraController,
              hint: 'Número Compra',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          // Número Factura
          SizedBox(
            width: campoAncho,
            child: _buildCampoFiltro(
              controller: _filtroNumeroFacturaController,
              hint: 'Número Factura',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          // Nombre Proveedor
          SizedBox(
            width: isMobile ? double.infinity : 260,
            child: _buildCampoFiltro(
              controller: _filtroProveedorController,
              hint: 'Nombre Proveedor',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),

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
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 12 : 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildSegundaFilaFiltros() {
    final isMobile = context.isMobile;
    final fechaAncho = isMobile ? double.infinity : 200.0;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Fecha Inicio
          SizedBox(
            width: fechaAncho,
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
                          surface: Theme.of(context).colorScheme.surface,
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
          // Fecha Fin
          SizedBox(
            width: fechaAncho,
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
                          surface: Theme.of(context).colorScheme.surface,
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
          // Checkbox Cuentas por Pagar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
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
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
                ),
              ],
            ),
          ),
          // Dropdown Ordenamiento
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _ordenamiento,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
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
          // Dropdown Ubicación
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _ubicacion,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
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
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
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
          color: Theme.of(context).colorScheme.surface,
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

    const double minWidth = 820;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final needScroll = constraints.maxWidth < minWidth;
        final content = SizedBox(
          width: needScroll ? minWidth : constraints.maxWidth,
          child: Column(
            children: [
              // Encabezado
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    _buildEncabezadoColumna('#', flex: 1),
                    _buildEncabezadoColumna('N° Factura', flex: 3),
                    _buildEncabezadoColumna('Proveedor', flex: 4),
                    _buildEncabezadoColumna('Fecha', flex: 2),
                    _buildEncabezadoColumna('Total', flex: 2, align: TextAlign.right),
                    _buildEncabezadoColumna('Por pagar', flex: 2, align: TextAlign.right),
                    _buildEncabezadoColumna('Estado', flex: 2, align: TextAlign.center),
                    _buildEncabezadoColumna('Acciones', flex: 3, align: TextAlign.center),
                  ],
                ),
              ),

              // Filas
              Expanded(
                child: _comprasFiltradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade600),
                            SizedBox(height: 16),
                            Text('No hay compras registradas',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _comprasFiltradas.length,
                        itemBuilder: (context, index) => _buildFilaTabla(_comprasFiltradas[index], index),
                      ),
              ),
            ],
          ),
        );
        return needScroll
            ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: content)
            : content;
      }),
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
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        textAlign: align,
      ),
    );
  }

  Widget _buildFilaTabla(FacturaCompra compra, int index) {
    final cs = Theme.of(context).colorScheme;
    final pagado = compra.pagadoDesdeCaja || compra.estado.toUpperCase() == 'PAGADA'
        ? compra.total
        : 0.0;
    final porPagar = compra.total - pagado;
    final esPagada = porPagar <= 0;

    final numeroCorto = compra.id != null && compra.id!.length >= 4
        ? 'OC${compra.id!.substring(compra.id!.length - 4).toUpperCase()}'
        : 'OC${(index + 1).toString().padLeft(3, '0')}';

    final fecha =
        '${compra.fechaFactura.year}-${compra.fechaFactura.month.toString().padLeft(2, '0')}-${compra.fechaFactura.day.toString().padLeft(2, '0')}';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade800, width: 0.5)),
      ),
      child: Row(
        children: [
          // #
          Expanded(
            flex: 1,
            child: Text(numeroCorto, style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 11)),
          ),

          // N° Factura
          Expanded(
            flex: 3,
            child: Text(
              compra.numeroFactura,
              style: TextStyle(color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Proveedor
          Expanded(
            flex: 4,
            child: Text(
              compra.proveedorNombre,
              style: TextStyle(color: cs.onSurface, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Fecha
          Expanded(
            flex: 2,
            child: Text(fecha, style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 12)),
          ),

          // Total
          Expanded(
            flex: 2,
            child: Text(
              '\$${formatNumberWithDots(compra.total)}',
              style: TextStyle(color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),

          // Por pagar
          Expanded(
            flex: 2,
            child: Text(
              '\$${formatNumberWithDots(porPagar)}',
              style: TextStyle(color: porPagar > 0 ? Colors.orange : AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),

          // Estado
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (esPagada ? AppTheme.success : Colors.orange).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  esPagada ? 'Pagada' : 'Pendiente',
                  style: TextStyle(
                    color: esPagada ? AppTheme.success : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Acciones: Editar | Eliminar | DS
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _accionBtn(
                  icon: Icons.edit,
                  color: AppTheme.success,
                  tooltip: 'Editar compra',
                  onPressed: () => context.push('/facturas-compras', extra: compra).then((_) => _cargarDatos()),
                ),
                SizedBox(width: 4),
                _accionBtn(
                  icon: Icons.delete,
                  color: Colors.red,
                  tooltip: 'Eliminar',
                  onPressed: () => _confirmarEliminarCompra(compra),
                ),
                SizedBox(width: 4),
                _accionBtn(
                  icon: Icons.file_present_rounded,
                  color: AppTheme.primary,
                  tooltip: 'Documento Soporte',
                  onPressed: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => DocumentoSoporteDialog(compra: compra),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accionBtn({required IconData icon, required Color color, required String tooltip, required VoidCallback onPressed}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  // Método para confirmar la eliminación de una compra
  Future<void> _confirmarEliminarCompra(FacturaCompra compra) async {
    final motivoController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Eliminar Compra',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas eliminar la compra ${compra.numeroFactura}?\n\n'
                'Se revertirá el inventario asociado a esta compra.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
              SizedBox(height: 16),
              TextField(
                controller: motivoController,
                maxLines: 3,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Razón de la eliminación (opcional)',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  hintText: 'Ej: Factura duplicada, error de digitación...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(motivoController.text.trim());
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        // Revertir inventario ANTES de eliminar la factura
        await _facturaCompraService.revertirInventarioCompra(compra);

        final resultado = await _facturaCompraService.eliminarFacturaCompra(
          compra.id!,
          motivoEliminacion: result.isNotEmpty ? result : null,
        );

        if (resultado['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Compra eliminada correctamente. Stock revertido.'),
              backgroundColor: Colors.green,
            ),
          );
          await _cargarDatos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${resultado['message'] ?? "No se pudo eliminar la compra"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar compra: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}
