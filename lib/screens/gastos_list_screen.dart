import 'package:flutter/material.dart';
import '../models/gasto.dart';
import '../services/gasto_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/pagination_mixin.dart';
import '../widgets/common/screen_header.dart';
import '../widgets/horizontal_scroll_table.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

class GastosListScreen extends StatefulWidget {
  const GastosListScreen({super.key});

  @override
  _GastosListScreenState createState() => _GastosListScreenState();
}

class _GastosListScreenState extends State<GastosListScreen> with PaginacionMixin<GastosListScreen> {
  final GastoService _gastoService = GastoService();

  // Controladores de filtros
  final _filtroNumeroController = TextEditingController();
  final _filtroProveedorController = TextEditingController();

  // Fechas
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  // Otros filtros
  bool _soloCuentasPorPagar = false;
  String _tipoGastoSeleccionado = 'TODOS';

  List<Gasto> _gastos = [];
  List<Gasto> _gastosFiltrados = [];
  List<String> _tiposGastoFiltro = ['TODOS'];
  bool _isLoading = false;

  // Barra visible para el scroll vertical de toda la pantalla (filtros +
  // tabla + paginación): sin esto, la única forma de scrollear era la rueda
  // del mouse, que avanza mucho por cada "click" y no deja leer la lista con
  // calma — con la barra visible se puede arrastrar despacio en vez de
  // depender solo de la rueda.
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _filtroNumeroController.dispose();
    _filtroProveedorController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final gastos = await _gastoService.getAllGastos();

      // Extraer tipos de gasto únicos
      final tiposGastoSet = <String>{'TODOS'};
      for (var gasto in gastos) {
        if (gasto.tipoGastoNombre.isNotEmpty) {
          tiposGastoSet.add(gasto.tipoGastoNombre);
        }
      }

      setState(() {
        _gastos = gastos;
        _tiposGastoFiltro = tiposGastoSet.toList()..sort();
        _aplicarFiltros();
      });
    } catch (e) {
      showErrorDialog(context, 'Error al cargar datos: ${errorMessage(e)}');
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

        // Filtro tipo de gasto
        final matchTipoGasto =
            _tipoGastoSeleccionado == 'TODOS' ||
            gasto.tipoGastoNombre == _tipoGastoSeleccionado;

        return matchNumero &&
            matchProveedor &&
            matchFechaInicio &&
            matchFechaFin &&
            matchCuentasPorPagar &&
            matchTipoGasto;
      }).toList();

      // Ordenar por fecha más reciente
      _gastosFiltrados.sort((a, b) => b.fechaGasto.compareTo(a.fechaGasto));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          icon: Icons.receipt_long,
          title: 'Lista de Gastos',
          badge: '${_gastosFiltrados.length}',
        ),
        // 📱 Antes los buscadores (número, proveedor, fechas) quedaban fijos
        // arriba y solo la tabla scrolleaba dentro de su propio Expanded —
        // en un celular eso tapaba media pantalla todo el tiempo. Ahora todo
        // (buscadores + tabla + paginación) va en un solo scroll vertical.
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(context.isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPrimeraFilaFiltros(),
                  const SizedBox(height: 16),
                  _buildSegundaFilaFiltros(),
                  const SizedBox(height: 16),
                  _buildTotalFiltrado(),
                  const SizedBox(height: 16),
                  _buildTabla(),
                  if (_gastosFiltrados.isNotEmpty)
                    buildPaginacion(totalItems: _gastosFiltrados.length),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimeraFilaFiltros() {
    final isMobile = context.isMobile;
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
          // Buscar Número
          SizedBox(
            width: isMobile ? double.infinity : 180,
            child: _buildCampoFiltro(
              controller: _filtroNumeroController,
              hint: 'Buscar Número',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          // Proveedor
          SizedBox(
            width: isMobile ? double.infinity : 260,
            child: _buildCampoFiltro(
              controller: _filtroProveedorController,
              hint: 'Proveedor',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          // Botón Buscar
          ElevatedButton.icon(
            onPressed: _aplicarFiltros,
            icon: Icon(Icons.search, color: Colors.white),
            label: Text(
              'Buscar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 12 : 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        spacing: 20,
        runSpacing: 16,
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
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(
                          context,
                        ).colorScheme.copyWith(primary: AppTheme.primary),
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
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(
                          context,
                        ).colorScheme.copyWith(primary: AppTheme.primary),
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
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  'Cuentas por\nPagar',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
                ),
              ],
            ),
          ),
          // Dropdown Tipo de Gasto
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _tipoGastoSeleccionado,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                items: _tiposGastoFiltro.map((tipo) {
                  return DropdownMenuItem(
                    value: tipo,
                    child: Text(tipo == 'TODOS' ? 'Tipo de Gasto' : tipo),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _tipoGastoSeleccionado = value ?? 'TODOS');
                  _aplicarFiltros();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalFiltrado() {
    final total = _gastosFiltrados.fold<double>(0, (suma, g) => suma + g.monto);
    final hayFiltroFecha = _fechaInicio != null || _fechaFin != null;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize, color: AppTheme.primary, size: 20),
          SizedBox(width: 10),
          Text(
            hayFiltroFecha
                ? 'Total del período filtrado (${_gastosFiltrados.length} gastos):'
                : 'Total (${_gastosFiltrados.length} gastos):',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Spacer(),
          Text(
            '\$ ${formatNumberWithDots(total)}',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
                  color: fecha != null
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.grey.shade500,
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

  // Ancho fijo por columna (Número, Proveedor, Expedición, Pago, Cuenta,
  // Total, Pagado, Por Pagar, Tipo de Gasto, Acciones). Con 10 columnas de
  // ancho flexible no cabían en un teléfono — cada encabezado se partía
  // letra por letra al recibir solo ~30px de una columna Expanded. Ahora la
  // tabla completa (encabezado + filas) tiene ancho fijo y se scrollea
  // horizontal en pantallas angostas.
  static const List<double> _anchosColumnas = [70, 140, 110, 130, 120, 110, 110, 110, 130, 80];
  // Espacio entre columnas: sin esto, un encabezado alineado a la derecha
  // (Total/Pagado/Por Pagar) queda pegado contra el texto de la columna
  // siguiente (alineada a la izquierda), ilegible ("Por PagarTipo de Gasto").
  static const double _gapColumnas = 10;
  static double get _anchoTotalTabla =>
      _anchosColumnas.reduce((a, b) => a + b) + _gapColumnas * _anchosColumnas.length;

  Widget _buildTabla() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      // El scroll horizontal envuelve encabezado + filas para que se
      // desplacen juntos hacia las columnas de la derecha. La paginación
      // vive fuera de este widget (ver build()) para no scrollear con la
      // tabla en ese sentido. HorizontalScrollTable agrega una barra visible
      // — antes era un SingleChildScrollView sin barra, así que en desktop
      // no había ninguna pista de que se podía desplazar hacia las columnas
      // de la derecha (Tipo de Gasto / Acciones).
      child: HorizontalScrollTable(
        contentWidth: _anchoTotalTabla,
        child: Column(
            children: [
              // Encabezado de la tabla
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEncabezadoColumna('Número', width: _anchosColumnas[0]),
                    _buildEncabezadoColumna('Proveedor', width: _anchosColumnas[1]),
                    _buildEncabezadoColumna('Expedición', width: _anchosColumnas[2]),
                    _buildEncabezadoColumna('Pago', width: _anchosColumnas[3]),
                    _buildEncabezadoColumna('Cuenta', width: _anchosColumnas[4]),
                    _buildEncabezadoColumna(
                      'Total',
                      width: _anchosColumnas[5],
                      align: TextAlign.right,
                    ),
                    _buildEncabezadoColumna(
                      'Pagado',
                      width: _anchosColumnas[6],
                      align: TextAlign.right,
                    ),
                    _buildEncabezadoColumna(
                      'Por Pagar',
                      width: _anchosColumnas[7],
                      align: TextAlign.right,
                    ),
                    _buildEncabezadoColumna('Tipo de Gasto', width: _anchosColumnas[8]),
                    _buildEncabezadoColumna('', width: _anchosColumnas[9]), // Acciones
                  ],
                ),
              ),

              // Filas de la tabla — shrinkWrap + NeverScrollableScrollPhysics:
              // ya no es esta lista la que scrollea verticalmente (ahora lo
              // hace el SingleChildScrollView exterior que también incluye
              // los buscadores), solo se dimensiona a su contenido.
              _gastosFiltrados.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
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
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paginarLista(_gastosFiltrados).length,
                      itemBuilder: (context, index) {
                        final gasto = paginarLista(_gastosFiltrados)[index];
                        return _buildFilaTabla(gasto, index);
                      },
                    ),
            ],
          ),
      ),
    );
  }

  Widget _buildEncabezadoColumna(
    String texto, {
    required double width,
    TextAlign align = TextAlign.left,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: _gapColumnas),
      child: SizedBox(
        width: width,
        child: Text(
          texto,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          textAlign: align,
        ),
      ),
    );
  }

  Widget _buildFilaTabla(Gasto gasto, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Número
          SizedBox(
            width: _anchosColumnas[0],
            child: Text(
              numeroGasto,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            ),
          ),
          const SizedBox(width: _gapColumnas),

          // Proveedor
          SizedBox(
            width: _anchosColumnas[1],
            child: Text(
              gasto.proveedor ?? 'N/A',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: _gapColumnas),

          // Expedición
          SizedBox(
            width: _anchosColumnas[2],
            child: Text(
              '${gasto.fechaGasto.year}-${gasto.fechaGasto.month.toString().padLeft(2, '0')}-${gasto.fechaGasto.day.toString().padLeft(2, '0')}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            ),
          ),
          const SizedBox(width: _gapColumnas),

          // Pago (concepto)
          SizedBox(
            width: _anchosColumnas[3],
            child: Text(
              gasto.concepto,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: _gapColumnas),

          // Cuenta
          SizedBox(
            width: _anchosColumnas[4],
            child: Text(
              gasto.formaPago ?? 'PRINCIPAL-CAJA',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: _gapColumnas),

          // Total
          SizedBox(
            width: _anchosColumnas[5],
            child: Text(
              '\$ ${formatNumberWithDots(gasto.monto)}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: _gapColumnas),

          // Pagado
          SizedBox(
            width: _anchosColumnas[6],
            child: Text(
              '\$ ${formatNumberWithDots(pagado)}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: _gapColumnas),

          // Por pagar
          SizedBox(
            width: _anchosColumnas[7],
            child: Text(
              '\$ ${formatNumberWithDots(porPagar)}',
              style: TextStyle(
                color: porPagar > 0 ? Colors.orange : Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: _gapColumnas),

          // Tipo de Gasto
          SizedBox(
            width: _anchosColumnas[8],
            child: Text(
              gasto.tipoGastoNombre,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: _gapColumnas),

          // Acciones
          SizedBox(
            width: _anchosColumnas[9],
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
                    // Sin esto, IconButton exige un mínimo de 48x48 (tamaño
                    // táctil de Material) aunque el padding sea cero, y ese
                    // mínimo no cabe en el círculo de 32x32 — se veía
                    // "cortado" contra el borde de la celda de al lado.
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                    icon: Icon(Icons.list_alt, color: Colors.white, size: 16),
                    onPressed: () => _mostrarDetalleGasto(gasto),
                    tooltip: 'Ver detalles',
                  ),
                ),
                // PDF
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
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: AppTheme.primary),
            SizedBox(width: 12),
            Text(
              'Detalle del Gasto',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: Container(
          width: dialogWidth(context, 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetalleItem('Concepto', gasto.concepto),
              _buildDetalleItem('Proveedor', gasto.proveedor ?? 'N/A'),
              _buildDetalleItem('Tipo de Gasto', gasto.tipoGastoNombre),
              _buildDetalleItem(
                'Monto',
                '\$ ${formatNumberWithDots(gasto.monto)}',
              ),
              _buildDetalleItem('Forma de Pago', gasto.formaPago ?? 'N/A'),
              if (gasto.formaPago?.toLowerCase() == 'mixto') ...[
                _buildDetalleItem(
                  '  Efectivo',
                  '\$ ${formatNumberWithDots(gasto.montoEfectivo)}',
                ),
                _buildDetalleItem(
                  '  Transferencia',
                  '\$ ${formatNumberWithDots(gasto.montoTransferencia)}',
                ),
              ],
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
            child: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(Gasto gasto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          '¿Eliminar Gasto?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          '¿Está seguro que desea eliminar este gasto?\n\nConcepto: ${gasto.concepto}\nMonto: \$ ${formatNumberWithDots(gasto.monto)}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
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
        final resultado = await _gastoService.deleteGasto(gasto.id!);
        if (!mounted) return;
        if (resultado['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message'] ?? 'Gasto eliminado correctamente'),
              backgroundColor: AppTheme.success,
            ),
          );
          _cargarDatos();
        } else {
          showErrorDialog(context, resultado['message'] ?? 'No se pudo eliminar el gasto');
        }
      }
    } catch (e) {
      showErrorDialog(context, 'Error al eliminar: ${errorMessage(e)}');
    }
  }
}
