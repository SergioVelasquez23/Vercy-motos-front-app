import 'package:flutter/material.dart';
import '../models/gasto.dart';
import '../services/gasto_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vercy_sidebar_layout.dart';
import '../utils/format_utils.dart';

class GastosListScreen extends StatefulWidget {
  const GastosListScreen({super.key});

  @override
  _GastosListScreenState createState() => _GastosListScreenState();
}

class _GastosListScreenState extends State<GastosListScreen> {
  final GastoService _gastoService = GastoService();

  // Controladores de filtros
  final _filtroNumeroController = TextEditingController();
  final _filtroProveedorController = TextEditingController();

  // Fechas
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  // Otros filtros
  bool _soloCuentasPorPagar = false;
  bool _verPagosParciales = false;
  String _categoriaSeleccionada = 'TODAS';

  List<Gasto> _gastos = [];
  List<Gasto> _gastosFiltrados = [];
  List<String> _categorias = ['TODAS'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _filtroNumeroController.dispose();
    _filtroProveedorController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final gastos = await _gastoService.getAllGastos();

      // Extraer categorías únicas
      final categoriasSet = <String>{'TODAS'};
      for (var gasto in gastos) {
        if (gasto.tipoGastoNombre.isNotEmpty) {
          categoriasSet.add(gasto.tipoGastoNombre);
        }
      }

      setState(() {
        _gastos = gastos;
        _categorias = categoriasSet.toList()..sort();
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
      _gastosFiltrados = _gastos.where((gasto) {
        // Filtro por número
        final matchNumero =
            _filtroNumeroController.text.isEmpty ||
            (gasto.id?.toLowerCase().contains(
                  _filtroNumeroController.text.toLowerCase(),
                ) ??
                false) ||
            (gasto.numeroFactura?.toLowerCase().contains(
                  _filtroNumeroController.text.toLowerCase(),
                ) ??
                false);

        // Filtro por proveedor
        final matchProveedor =
            _filtroProveedorController.text.isEmpty ||
            (gasto.proveedor?.toLowerCase().contains(
                  _filtroProveedorController.text.toLowerCase(),
                ) ??
                false);

        // Filtro por fecha inicio
        final matchFechaInicio =
            _fechaInicio == null ||
            gasto.fechaGasto.isAfter(_fechaInicio!) ||
            gasto.fechaGasto.isAtSameMomentAs(_fechaInicio!);

        // Filtro por fecha fin
        final matchFechaFin =
            _fechaFin == null ||
            gasto.fechaGasto.isBefore(_fechaFin!.add(Duration(days: 1)));

        // Filtro cuentas por pagar
        final matchCuentasPorPagar =
            !_soloCuentasPorPagar || !gasto.pagadoDesdeCaja;

        // Filtro categoría
        final matchCategoria =
            _categoriaSeleccionada == 'TODAS' ||
            gasto.tipoGastoNombre == _categoriaSeleccionada;

        return matchNumero &&
            matchProveedor &&
            matchFechaInicio &&
            matchFechaFin &&
            matchCuentasPorPagar &&
            matchCategoria;
      }).toList();

      // Ordenar por fecha más reciente
      _gastosFiltrados.sort((a, b) => b.fechaGasto.compareTo(a.fechaGasto));
    });
  }

  @override
  Widget build(BuildContext context) {
    return VercySidebarLayout(
      title: 'Gastos',
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              'Lista de Gastos',
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

            // Tabla de gastos
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
          // Buscar Número
          Expanded(
            child: _buildCampoFiltro(
              controller: _filtroNumeroController,
              hint: 'Buscar Número',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 12),

          // Proveedor
          Expanded(
            flex: 2,
            child: _buildCampoFiltro(
              controller: _filtroProveedorController,
              hint: 'Proveedor',
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

          Spacer(),

          // Botón Crear Gasto
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/gastos'),
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              'Crear Gasto',
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

          // Checkbox Ver pagos parciales
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
                  value: _verPagosParciales,
                  onChanged: (value) {
                    setState(() => _verPagosParciales = value ?? false);
                    _aplicarFiltros();
                  },
                  activeColor: AppTheme.primary,
                  side: BorderSide(color: Colors.grey.shade500),
                ),
                Text(
                  'Ver pagos\nparciales',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),

          // Dropdown Categoría
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _categoriaSeleccionada,
                dropdownColor: AppTheme.cardBg,
                style: TextStyle(color: Colors.white, fontSize: 14),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                items: _categorias.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat == 'TODAS' ? 'Categoría' : cat),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _categoriaSeleccionada = value ?? 'TODAS');
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
                _buildEncabezadoColumna('Número', flex: 1),
                _buildEncabezadoColumna('Proveedor', flex: 2),
                _buildEncabezadoColumna('Expedición', flex: 2),
                _buildEncabezadoColumna('Pago', flex: 2),
                _buildEncabezadoColumna('Cuenta', flex: 2),
                _buildEncabezadoColumna(
                  'Total',
                  flex: 2,
                  align: TextAlign.right,
                ),
                _buildEncabezadoColumna(
                  'Pagado',
                  flex: 2,
                  align: TextAlign.right,
                ),
                _buildEncabezadoColumna(
                  'Por Pagar',
                  flex: 2,
                  align: TextAlign.right,
                ),
                _buildEncabezadoColumna('Categoría', flex: 2),
                _buildEncabezadoColumna('', flex: 1), // Acciones
              ],
            ),
          ),

          // Filas de la tabla
          Expanded(
            child: _gastosFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.money_off,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay gastos registrados',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _gastosFiltrados.length,
                    itemBuilder: (context, index) {
                      final gasto = _gastosFiltrados[index];
                      return _buildFilaTabla(gasto, index);
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

  Widget _buildFilaTabla(Gasto gasto, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? AppTheme.cardBg : AppTheme.surfaceDark;

    // Calcular valores
    final pagado = gasto.pagadoDesdeCaja ? gasto.monto : 0.0;
    final porPagar = gasto.monto - pagado;

    // Número para mostrar
    String numeroGasto = 'G${(index + 1).toString().padLeft(3, '0')}';
    if (gasto.id != null && gasto.id!.length >= 4) {
      numeroGasto =
          'G${gasto.id!.substring(gasto.id!.length - 3).toUpperCase()}';
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
          // Número
          Expanded(
            flex: 1,
            child: Text(
              numeroGasto,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          // Proveedor
          Expanded(
            flex: 2,
            child: Text(
              gasto.proveedor ?? 'N/A',
              style: TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Expedición
          Expanded(
            flex: 2,
            child: Text(
              '${gasto.fechaGasto.year}-${gasto.fechaGasto.month.toString().padLeft(2, '0')}-${gasto.fechaGasto.day.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          // Pago (concepto)
          Expanded(
            flex: 2,
            child: Text(
              gasto.concepto,
              style: TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Cuenta
          Expanded(
            flex: 2,
            child: Text(
              gasto.formaPago ?? 'PRINCIPAL-CAJA',
              style: TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Total
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${formatNumberWithDots(gasto.monto)}',
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

          // Categoría
          Expanded(
            flex: 2,
            child: Text(
              gasto.tipoGastoNombre,
              style: TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Acciones
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Ver detalles
                Container(
                  width: 32,
                  height: 32,
                  margin: EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.list_alt, color: Colors.white, size: 16),
                    onPressed: () => _mostrarDetalleGasto(gasto),
                    tooltip: 'Ver detalles',
                  ),
                ),
                // PDF
                Container(
                  width: 32,
                  height: 32,
                  margin: EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 16,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Generar PDF - Próximamente')),
                      );
                    },
                    tooltip: 'Generar PDF',
                  ),
                ),
                // Eliminar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.close, color: Colors.white, size: 16),
                    onPressed: () => _confirmarEliminar(gasto),
                    tooltip: 'Eliminar',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleGasto(Gasto gasto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: AppTheme.primary),
            SizedBox(width: 12),
            Text('Detalle del Gasto', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetalleItem('Concepto', gasto.concepto),
              _buildDetalleItem('Proveedor', gasto.proveedor ?? 'N/A'),
              _buildDetalleItem('Categoría', gasto.tipoGastoNombre),
              _buildDetalleItem(
                'Monto',
                '\$ ${formatNumberWithDots(gasto.monto)}',
              ),
              _buildDetalleItem('Forma de Pago', gasto.formaPago ?? 'N/A'),
              _buildDetalleItem('Responsable', gasto.responsable),
              _buildDetalleItem(
                'Fecha',
                '${gasto.fechaGasto.year}-${gasto.fechaGasto.month.toString().padLeft(2, '0')}-${gasto.fechaGasto.day.toString().padLeft(2, '0')}',
              ),
              _buildDetalleItem(
                'Estado',
                gasto.pagadoDesdeCaja ? 'Pagado' : 'Pendiente',
              ),
              if (gasto.numeroFactura != null)
                _buildDetalleItem('No. Factura', gasto.numeroFactura!),
              if (gasto.numeroRecibo != null)
                _buildDetalleItem('No. Recibo', gasto.numeroRecibo!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(Gasto gasto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('¿Eliminar Gasto?', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Está seguro que desea eliminar este gasto?\n\nConcepto: ${gasto.concepto}\nMonto: \$ ${formatNumberWithDots(gasto.monto)}',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _eliminarGasto(gasto);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarGasto(Gasto gasto) async {
    try {
      if (gasto.id != null) {
        await _gastoService.deleteGasto(gasto.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gasto eliminado correctamente'),
            backgroundColor: AppTheme.success,
          ),
        );
        _cargarDatos();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
