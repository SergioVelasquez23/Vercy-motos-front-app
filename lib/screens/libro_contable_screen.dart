import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import '../services/libro_contable_service.dart';
import '../services/excel_export_service.dart';
import '../providers/user_provider.dart';
import '../providers/libro_contable_resumen_draft_provider.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';
import '../widgets/reportes/rango_fechas_dialog.dart';
import 'costeo_inventario_screen.dart';
import 'rentabilidad_screen.dart';
import 'comparativo_periodos_screen.dart';
import 'anomalias_screen.dart';

/// Pantalla única que fusiona los 5 reportes contables que antes vivían
/// separados en el submenú (Libro Contable, Costeo y Utilidad Real,
/// Rentabilidad Producto/Cliente, Comparación de Períodos, Alertas y
/// Anomalías) en una sola pantalla con tabs. [initialTabIndex] permite que
/// las rutas antiguas (/costeo-inventario, /rentabilidad, etc.) sigan
/// funcionando como deep-links, abriendo directamente el tab que corresponde.
class LibroContableScreen extends StatefulWidget {
  final int initialTabIndex;

  const LibroContableScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LibroContableScreen> createState() => _LibroContableScreenState();
}

class _LibroContableScreenState extends State<LibroContableScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<Tab> _tabs = [
    Tab(icon: Icon(Icons.summarize), text: 'Resumen'),
    Tab(icon: Icon(Icons.menu_book), text: 'Ventas y Gastos'),
    Tab(icon: Icon(Icons.calculate), text: 'Costeo y Utilidad'),
    Tab(icon: Icon(Icons.leaderboard), text: 'Rentabilidad'),
    Tab(icon: Icon(Icons.compare_arrows), text: 'Comparación'),
    Tab(icon: Icon(Icons.warning_amber), text: 'Anomalías'),
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libro Contable'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ResumenTab(),
          _VentasYGastosTab(),
          CosteoInventarioScreen(),
          RentabilidadScreen(),
          ComparativoPeriodosScreen(),
          AnomaliasScreen(),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB "RESUMEN" — narrativa texto + datos, con desglose expandible por cifra.
// ============================================================================

class _ResumenTab extends StatefulWidget {
  const _ResumenTab();

  @override
  State<_ResumenTab> createState() => _ResumenTabState();
}

class _ResumenTabState extends State<_ResumenTab> {
  final LibroContableService _service = LibroContableService();

  DateTimeRange? _rango;
  bool _isLoading = false;

  Map<String, dynamic>? _libroContable;
  Map<String, dynamic>? _rentabilidadProductos;
  List<dynamic>? _recomendaciones;
  bool _isExporting = false;
  bool _draftRestaurado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Restaura el último resumen generado (guardado en un provider que vive
    // en la raíz de la app) para que sobreviva a salir de esta pantalla y
    // volver — se comporta como un borrador hasta que se genere uno nuevo.
    if (_draftRestaurado) return;
    _draftRestaurado = true;
    final draft = context.read<LibroContableResumenDraftProvider>();
    if (draft.hasDraft) {
      _rango = draft.rango;
      _libroContable = draft.libroContable;
      _rentabilidadProductos = draft.rentabilidadProductos;
      _recomendaciones = draft.recomendaciones;
    }
  }

  Future<void> _elegirRangoYCargar() async {
    final rango = await mostrarSelectorRangoFechas(
      context,
      titulo: 'Resumen del Período',
      valorInicial: _rango,
    );
    if (rango == null) return;

    setState(() {
      _rango = rango;
    });
    await _cargar();
  }

  Future<void> _exportarAExcel() async {
    if (_libroContable == null) return;
    setState(() {
      _isExporting = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final filePath = await ExcelExportService.exportarLibroContable(
        datosLibroContable: _libroContable!,
        nombreUsuario: userProvider.userName,
        rentabilidadProductosSinManoDeObra: _rentabilidadProductos,
        recomendaciones: _recomendaciones,
      );

      if (!mounted) return;
      if (filePath != null) {
        final isWeb = filePath.startsWith('web_download:');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isWeb
                  ? '¡Archivo descargado exitosamente! Verifica tu carpeta de descargas.'
                  : 'Excel generado en: $filePath',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: (!isWeb)
                ? SnackBarAction(
                    label: 'Compartir',
                    textColor: Colors.white,
                    onPressed: () => ExcelExportService.compartirExcel(filePath),
                  )
                : null,
          ),
        );
      } else {
        showErrorDialog(context, 'Error al generar el archivo Excel');
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _cargar() async {
    if (_rango == null) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final desde = _rango!.start;
      final hasta = DateTime(
        _rango!.end.year,
        _rango!.end.month,
        _rango!.end.day,
        23,
        59,
        59,
      );

      final resultados = await Future.wait([
        _service.getLibroContablePorRango(desde, hasta),
        _service.getRentabilidadProductos(
          desde,
          hasta,
          limite: 9999,
          filtroTipoItem: 'producto',
        ),
        _service.getRecomendaciones(desde, hasta),
      ]);

      if (!mounted) return;
      final libroContable = resultados[0] as Map<String, dynamic>;
      final rentabilidadProductos = resultados[1] as Map<String, dynamic>;
      final recomendaciones = resultados[2] as List<dynamic>;
      setState(() {
        _libroContable = libroContable;
        _rentabilidadProductos = rentabilidadProductos;
        _recomendaciones = recomendaciones;
      });
      context.read<LibroContableResumenDraftProvider>().guardar(
            rango: _rango!,
            libroContable: libroContable,
            rentabilidadProductos: rentabilidadProductos,
            recomendaciones: recomendaciones,
          );
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(context),
          const SizedBox(height: 16),
          _buildSelectorCard(context),
          if (_libroContable != null) ...[
            const SizedBox(height: 16),
            _buildVentasSection(),
            const SizedBox(height: 12),
            _buildProductosSection(),
            const SizedBox(height: 12),
            _buildGastosSection(),
            const SizedBox(height: 12),
            _buildComprasSection(),
            const SizedBox(height: 12),
            _buildUtilidadSection(),
            const SizedBox(height: 12),
            _buildRecomendacionesSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Resumen del período',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Un solo reporte que explica en texto y cifras cuánto vendiste, qué '
              'vendiste (sin mezclar mano de obra), cuánto gastaste (fijo vs. '
              'variable), cuánto compraste a proveedores y tu utilidad real. Cada '
              'cifra se puede expandir para ver de dónde sale.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Período a analizar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _elegirRangoYCargar,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.date_range),
                label: Text(
                  _rango == null
                      ? 'Elegir período y generar resumen'
                      : '${formatearFechaCorta(_rango!.start)} - ${formatearFechaCorta(_rango!.end)}',
                ),
              ),
            ),
            if (_libroContable != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportarAExcel,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isExporting ? 'Generando Excel...' : 'Exportar resumen a Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVentasSection() {
    final feyPos = _libroContable!['ventasElectronicasFEyPOS'] as Map<String, dynamic>? ?? {};
    final locales = _libroContable!['ventasLocales'] as Map<String, dynamic>? ?? {};
    final totalVentas = _libroContable!['totalVentasPeriodo'];
    final detalle = <dynamic>[
      ...(feyPos['detalle'] as List<dynamic>? ?? []),
      ...(locales['detalle'] as List<dynamic>? ?? []),
    ];

    return _seccionNarrativa(
      icono: Icons.point_of_sale,
      color: Colors.green,
      titulo: 'Cuánto vendiste',
      narrativa: 'En este período vendiste un total de \$${_formatearMonto(totalVentas)}, '
          'sumando \$${_formatearMonto(feyPos['total'])} en facturación electrónica/POS '
          'y \$${_formatearMonto(locales['total'])} en facturas locales, repartidos en '
          '${detalle.length} transacciones.',
      expandible: _buildListaExpandible(
        titulo: 'Ver las ${detalle.length} transacciones',
        items: detalle,
        constructorFila: (item) {
          final mapa = item as Map<String, dynamic>;
          final numero = mapa['numero'] ?? mapa['id'] ?? mapa['_id'] ?? '-';
          final cliente = mapa['clienteNombre'] ?? mapa['cliente'] ?? 'Consumidor Final';
          final total = mapa['totalPagado'] ?? mapa['total'] ?? 0;
          return _filaDetalle('$numero — $cliente', '\$${_formatearMonto(total)}');
        },
      ),
    );
  }

  Widget _buildProductosSection() {
    final porCantidad = _rentabilidadProductos?['porCantidadVendida'] as List<dynamic>? ?? [];
    final cantidadAnalizados = _rentabilidadProductos?['cantidadProductosAnalizados'] ?? 0;
    final totalUnidades = porCantidad.fold<double>(
      0,
      (acc, p) => acc + (((p as Map)['cantidadVendida'] as num?)?.toDouble() ?? 0),
    );

    return _seccionNarrativa(
      icono: Icons.inventory_2,
      color: Colors.blue,
      titulo: 'Qué vendiste (sin mano de obra)',
      narrativa: 'Vendiste $cantidadAnalizados repuestos/productos distintos, por un total de '
          '${totalUnidades.toStringAsFixed(0)} unidades. Esto excluye la mano de obra de '
          'reparación — solo cuenta lo que sale de tu inventario.',
      expandible: _buildListaExpandible(
        titulo: 'Ver los $cantidadAnalizados productos vendidos',
        items: porCantidad,
        constructorFila: (item) {
          final mapa = item as Map<String, dynamic>;
          final nombre = mapa['productoNombre'] ?? 'Sin nombre';
          final cantidad = mapa['cantidadVendida'] ?? 0;
          final ventas = mapa['ventas'] ?? 0;
          return _filaDetalle('$nombre (x$cantidad)', '\$${_formatearMonto(ventas)}');
        },
      ),
    );
  }

  Widget _buildGastosSection() {
    final gastos = _libroContable!['gastos'] as Map<String, dynamic>? ?? {};
    final porNaturaleza = gastos['porNaturaleza'] as Map<String, dynamic>? ?? {};
    final detalle = gastos['detalle'] as List<dynamic>? ?? [];

    double montoDe(String clave) =>
        ((porNaturaleza[clave] as Map?)?['monto'] as num?)?.toDouble() ?? 0;

    final fijo = montoDe('FIJO');
    final variable = montoDe('VARIABLE');
    final mixto = montoDe('MIXTO');

    return _seccionNarrativa(
      icono: Icons.money_off,
      color: Colors.red,
      titulo: 'Cuánto gastaste (fijo vs. variable)',
      narrativa: 'Gastaste \$${_formatearMonto(gastos['total'])} en total: '
          '\$${_formatearMonto(fijo)} en gastos fijos (arriendo, salarios, seguros — '
          'siguen ahí vendas o no), \$${_formatearMonto(variable)} en variables '
          '(combustible, impuestos — suben y bajan con tus ventas), y '
          '\$${_formatearMonto(mixto)} en gastos mixtos (servicios, mantenimiento).',
      expandible: _buildListaExpandible(
        titulo: 'Ver los ${detalle.length} gastos registrados',
        items: detalle,
        constructorFila: (item) {
          final mapa = item as Map<String, dynamic>;
          final concepto = mapa['concepto'] ?? mapa['tipoGastoNombre'] ?? 'Gasto';
          final monto = mapa['monto'] ?? 0;
          return _filaDetalle(concepto.toString(), '\$${_formatearMonto(monto)}');
        },
      ),
    );
  }

  Widget _buildComprasSection() {
    final compras = _libroContable!['compras'] as Map<String, dynamic>? ?? {};
    final detalle = compras['detalle'] as List<dynamic>? ?? [];
    final porcentaje = _libroContable!['comprasComoPorcentajeVentas'];

    return _seccionNarrativa(
      icono: Icons.local_shipping,
      color: Colors.purple,
      titulo: 'Cuánto compraste a proveedores',
      narrativa: 'Compraste \$${_formatearMonto(compras['total'])} a proveedores en este '
          'período, equivalente al ${_formatearPorcentaje(porcentaje)} de tus ventas — '
          'es lo que repones de inventario para poder seguir vendiendo.',
      expandible: _buildListaExpandible(
        titulo: 'Ver las ${detalle.length} compras',
        items: detalle,
        constructorFila: (item) {
          final mapa = item as Map<String, dynamic>;
          final proveedor = mapa['proveedorNombre'] ?? 'Sin proveedor';
          final total = mapa['total'] ?? 0;
          return _filaDetalle(proveedor.toString(), '\$${_formatearMonto(total)}');
        },
      ),
    );
  }

  Widget _buildUtilidadSection() {
    final costo = _libroContable!['costoMercanciaVendida'];
    final utilidadReal = _libroContable!['utilidadBrutaReal'];
    final margen = _libroContable!['margenBrutoPorcentaje'];
    final utilidadNeta = _libroContable!['utilidadNeta'];
    final margenNeto = _libroContable!['margenNetoPorcentaje'];
    final ventas = _libroContable!['totalVentasPeriodo'];
    final huboEstimacion = _libroContable!['huboEstimacion'] == true;

    return _seccionNarrativa(
      icono: Icons.trending_up,
      color: Colors.teal,
      titulo: 'Tu utilidad real',
      narrativa: 'A tus \$${_formatearMonto(ventas)} en ventas se le resta el costo real '
          'de cada producto vendido (\$${_formatearMonto(costo)}, tomado del costo '
          'registrado en el inventario al momento de cada venta) — eso da una utilidad '
          'bruta real de \$${_formatearMonto(utilidadReal)} (${_formatearPorcentaje(margen)}). '
          'Después de restar también los gastos operativos, la utilidad neta del período '
          'es \$${_formatearMonto(utilidadNeta)} (${_formatearPorcentaje(margenNeto)}).'
          '${huboEstimacion ? " Algunos costos son estimados con el costo actual del producto porque la venta fue anterior a que el sistema guardara el costo real." : ""}',
      expandible: null,
    );
  }

  Widget _buildRecomendacionesSection() {
    final recomendaciones = _recomendaciones ?? [];
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('Recomendaciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (recomendaciones.isEmpty)
              const Text(
                'No hay recomendaciones puntuales para este período — no se detectaron '
                'señales fuera de lo esperado.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...recomendaciones.map((r) {
                final mapa = r as Map<String, dynamic>;
                final severidad = mapa['severidad'] as String? ?? 'info';
                final color = severidad == 'alerta'
                    ? Colors.red
                    : severidad == 'positivo'
                        ? Colors.green
                        : Colors.blueGrey;
                final icono = severidad == 'alerta'
                    ? Icons.warning_amber
                    : severidad == 'positivo'
                        ? Icons.check_circle
                        : Icons.info;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icono, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mapa['mensaje'] as String? ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// Card estándar de este tab: ícono + título + narrativa en texto + un
  /// ExpansionTile opcional con el detalle línea por línea de esa cifra.
  Widget _seccionNarrativa({
    required IconData icono,
    required Color color,
    required String titulo,
    required String narrativa,
    required Widget? expandible,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(narrativa, style: const TextStyle(fontSize: 14, height: 1.4)),
            if (expandible != null) ...[
              const SizedBox(height: 8),
              expandible,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListaExpandible({
    required String titulo,
    required List<dynamic> items,
    required Widget Function(dynamic item) constructorFila,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(titulo, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        children: items.map(constructorFila).toList(),
      ),
    );
  }

  Widget _filaDetalle(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(etiqueta, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatearMonto(dynamic monto) {
    if (monto == null) return '0';
    try {
      final valor = double.parse(monto.toString());
      return NumberFormat('#,##0', 'es_CO').format(valor);
    } catch (e) {
      return monto.toString();
    }
  }

  String _formatearPorcentaje(dynamic porcentaje) {
    if (porcentaje == null) return '0%';
    try {
      final valor = double.parse(porcentaje.toString());
      return '${valor.toStringAsFixed(1)}%';
    } catch (e) {
      return '0%';
    }
  }
}

// ============================================================================
// TAB "VENTAS Y GASTOS" — contenido original de Libro Contable (vista previa
// por medio de pago/proveedor/concepto + utilidad bruta por rango).
// ============================================================================

class _VentasYGastosTab extends StatefulWidget {
  const _VentasYGastosTab();

  @override
  State<_VentasYGastosTab> createState() => _VentasYGastosTabState();
}

class _VentasYGastosTabState extends State<_VentasYGastosTab> {
  final LibroContableService _libroContableService = LibroContableService();

  DateTime _fechaSeleccionada = DateTime.now();
  bool _isLoading = false;
  bool _isExporting = false;
  Map<String, dynamic>? _datosPreview;

  bool _modoRango = false;
  DateTimeRange? _rangoPreviewSeleccionado;

  bool _isLoadingUtilidad = false;
  DateTimeRange? _rangoUtilidadSeleccionado;
  Map<String, dynamic>? _utilidadBrutaResultado;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildSelectorFecha(),
          const SizedBox(height: 16),
          _buildBotonesAccion(),
          const SizedBox(height: 16),
          _buildUtilidadBrutaCard(),
          const SizedBox(height: 16),
          if (_datosPreview != null) _buildPreviewCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Libro Contable Mensual',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Separa las ventas de Facturación Electrónica y POS de las Facturas '
              'Locales, y desglosa cada grupo por medio de pago (Nequi, DaviPlata, '
              'Bancolombia, Bold, Sistecredito, Addi, Credilondon, Efectivo). '
              'Incluye Compras y Gastos del mes.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorFecha() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Período a Consultar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModoPeriodoBoton(
                    label: 'Mes completo',
                    seleccionado: !_modoRango,
                    onTap: () => _cambiarModoPeriodo(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModoPeriodoBoton(
                    label: 'Rango personalizado',
                    seleccionado: _modoRango,
                    onTap: () => _cambiarModoPeriodo(true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _modoRango ? _elegirRangoPreview : _mostrarSelectorFecha,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text(
                      _modoRango
                          ? (_rangoPreviewSeleccionado == null
                              ? 'Elegir fechas'
                              : '${_formatearFechaCorta(_rangoPreviewSeleccionado!.start)} - '
                                    '${_formatearFechaCorta(_rangoPreviewSeleccionado!.end)}')
                          : DateFormat('MMMM yyyy', 'es_ES').format(_fechaSeleccionada),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModoPeriodoBoton({
    required String label,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado
              ? Theme.of(context).primaryColor.withOpacity(0.15)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado
                ? Theme.of(context).primaryColor
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
            color: seleccionado
                ? Theme.of(context).primaryColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _cambiarModoPeriodo(bool aRango) {
    if (_modoRango == aRango) return;
    setState(() {
      _modoRango = aRango;
      _datosPreview = null;
    });
    if (!aRango || _rangoPreviewSeleccionado != null) {
      _cargarPreview();
    }
  }

  Future<void> _elegirRangoPreview() async {
    final rango = await mostrarSelectorRangoFechas(
      context,
      titulo: 'Rango de Fechas a Consultar',
      valorInicial: _rangoPreviewSeleccionado,
    );
    if (rango == null) return;

    setState(() {
      _rangoPreviewSeleccionado = rango;
      _datosPreview = null;
    });
    _cargarPreview();
  }

  Widget _buildBotonesAccion() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || (_modoRango && _rangoPreviewSeleccionado == null))
                    ? null
                    : _cargarPreview,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.preview),
                label: Text(_isLoading ? 'Cargando datos del servidor...' : 'Cargar Vista Previa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                  disabledForegroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (_isExporting ||
                        !ExcelExportService.hayDatosLibroContableParaExportar(_datosPreview))
                    ? null
                    : _exportarAExcel,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_isExporting ? 'Generando Excel...' : 'Exportar a Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final ventasFEyPOS =
        _datosPreview!['ventasElectronicasFEyPOS'] as Map<String, dynamic>? ?? {};
    final ventasLocales = _datosPreview!['ventasLocales'] as Map<String, dynamic>? ?? {};
    final compras = _datosPreview!['compras'] as Map<String, dynamic>? ?? {};
    final gastos = _datosPreview!['gastos'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Ventas Facturación Electrónica y POS',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTotalRow('Total', ventasFEyPOS['total'], Colors.green),
                const SizedBox(height: 8),
                ..._buildDesglose(ventasFEyPOS, 'porMedioPago', 'Sin ventas en este período'),
                const SizedBox(height: 12),
                Text(
                  'Por caja',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                ..._buildDesglose(ventasFEyPOS, 'porCaja', 'Sin ventas en este período'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.store, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'Ventas Facturas Locales',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTotalRow('Total', ventasLocales['total'], Colors.orange),
                const SizedBox(height: 8),
                ..._buildDesglose(ventasLocales, 'porMedioPago', 'Sin ventas en este período'),
                const SizedBox(height: 12),
                Text(
                  'Por caja',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                ..._buildDesglose(ventasLocales, 'porCaja', 'Sin ventas en este período'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Text(
                      'Compras',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTotalRow('Total', compras['total'], Colors.purple),
                const SizedBox(height: 8),
                Text(
                  'Por medio de pago',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                ..._buildDesglose(compras, 'porMedioPago', 'Sin compras en este período'),
                const SizedBox(height: 12),
                Text(
                  'Por proveedor',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                ..._buildDesglose(compras, 'porProveedor', 'Sin compras en este período'),
                const SizedBox(height: 12),
                Text(
                  'Por caja',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                ..._buildDesglose(compras, 'porCaja', 'Sin compras en este período'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.money_off, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Gastos',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTotalRow('Total', gastos['total'], Colors.red),
                const SizedBox(height: 8),
                Text(
                  'Por naturaleza (fijo / variable / mixto)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                ..._buildDesglose(gastos, 'porNaturaleza', 'Sin gastos en este período'),
                const SizedBox(height: 12),
                Text(
                  'Por medio de pago',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                ..._buildDesglose(gastos, 'porMedioPago', 'Sin gastos en este período'),
                const SizedBox(height: 12),
                Text(
                  'Por concepto (incluye Salarios/Prestaciones para nómina)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                ..._buildDesglose(gastos, 'porConcepto', 'Sin gastos en este período'),
                const SizedBox(height: 12),
                Text(
                  'Por caja',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                ..._buildDesglose(gastos, 'porCaja', 'Sin gastos en este período'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String titulo, dynamic monto, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$titulo:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '\$${_formatearMonto(monto)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDesglose(Map<String, dynamic> seccion, String key, String mensajeVacio) {
    final datos = seccion[key] as Map<String, dynamic>? ?? {};
    if (datos.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(mensajeVacio, style: const TextStyle(color: Colors.grey)),
        ),
      ];
    }

    final entradas = datos.entries.toList()
      ..sort((a, b) {
        final montoA = double.tryParse((a.value as Map)['monto']?.toString() ?? '0') ?? 0;
        final montoB = double.tryParse((b.value as Map)['monto']?.toString() ?? '0') ?? 0;
        return montoB.compareTo(montoA);
      });

    final desgloseMixto = key == 'porMedioPago'
        ? (seccion['desgloseMixto'] as Map<String, dynamic>? ?? {})
        : <String, dynamic>{};

    return entradas.expand((entry) {
      final detalle = entry.value as Map<String, dynamic>;
      final filaPrincipal = Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '\$${_formatearMonto(detalle['monto'])} (${detalle['cantidad'] ?? 0})',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      );

      if (entry.key != 'Mixto' || desgloseMixto.isEmpty) {
        return [filaPrincipal];
      }

      final subEntradas = desgloseMixto.entries.toList()
        ..sort((a, b) {
          final montoA = double.tryParse((a.value as Map)['monto']?.toString() ?? '0') ?? 0;
          final montoB = double.tryParse((b.value as Map)['monto']?.toString() ?? '0') ?? 0;
          return montoB.compareTo(montoA);
        });

      return [
        filaPrincipal,
        ...subEntradas.map((sub) {
          final subDetalle = sub.value as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(left: 20, top: 1, bottom: 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '↳ ${sub.key}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                Text(
                  '\$${_formatearMonto(subDetalle['monto'])} (${subDetalle['cantidad'] ?? 0})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }),
      ];
    }).toList();
  }

  void _mostrarSelectorFecha() async {
    final DateTime? fechaSeleccionada = await _seleccionarMesAnio();

    if (fechaSeleccionada != null) {
      setState(() {
        _fechaSeleccionada = fechaSeleccionada;
        _datosPreview = null;
      });
      _cargarPreview();
    }
  }

  Future<DateTime?> _seleccionarMesAnio() async {
    int anio = _fechaSeleccionada.year;
    const mesesAbrev = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final cs = Theme.of(dialogContext).colorScheme;
            return AlertDialog(
              title: const Text('Seleccionar Mes y Año'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setDialogState(() => anio--),
                        ),
                        Text(
                          '$anio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setDialogState(() => anio++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(12, (index) {
                        final mes = index + 1;
                        final esSeleccionado = anio == _fechaSeleccionada.year &&
                            mes == _fechaSeleccionada.month;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              Navigator.of(dialogContext).pop(DateTime(anio, mes, 1)),
                          child: Container(
                            decoration: BoxDecoration(
                              color: esSeleccionado
                                  ? Theme.of(dialogContext).primaryColor
                                  : cs.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: esSeleccionado
                                    ? Theme.of(dialogContext).primaryColor
                                    : cs.onSurface.withOpacity(0.2),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              mesesAbrev[index],
                              style: TextStyle(
                                color: esSeleccionado ? Colors.white : cs.onSurface,
                                fontWeight:
                                    esSeleccionado ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cargarPreview() async {
    if (_modoRango && _rangoPreviewSeleccionado == null) return;

    setState(() {
      _isLoading = true;
      _datosPreview = null;
    });

    try {
      final Map<String, dynamic> datos;
      if (_modoRango) {
        final rango = _rangoPreviewSeleccionado!;
        final hastaFinDia =
            DateTime(rango.end.year, rango.end.month, rango.end.day, 23, 59, 59);
        datos = await _libroContableService.getLibroContablePorRango(rango.start, hastaFinDia);
      } else {
        datos = await _libroContableService.getLibroContableMensual(
          _fechaSeleccionada.year,
          _fechaSeleccionada.month,
        );
      }

      setState(() {
        _datosPreview = datos;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Vista previa cargada exitosamente')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Error al cargar el libro contable';
        if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
          errorMsg = 'El servidor tardó demasiado. Intenta con un período con menos datos.';
        } else if (e.toString().contains('No autorizado') || e.toString().contains('401')) {
          errorMsg = 'Sesión expirada. Vuelve a iniciar sesión.';
        } else if (e.toString().contains('Sin conexión') || e.toString().contains('SocketException')) {
          errorMsg = 'Sin conexión a internet. Verifica tu red.';
        } else {
          errorMsg = errorMessage(e);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: _cargarPreview,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportarAExcel() async {
    if (!ExcelExportService.hayDatosLibroContableParaExportar(_datosPreview)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay datos para exportar. Carga la vista previa primero.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      String? nombreUsuario = userProvider.userName;

      String? filePath = await ExcelExportService.exportarLibroContable(
        datosLibroContable: _datosPreview!,
        nombreUsuario: nombreUsuario,
      );

      if (filePath != null) {
        final isWeb = filePath.startsWith('web_download:');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isWeb
                    ? '¡Archivo descargado exitosamente! Verifica tu carpeta de descargas.'
                    : 'Excel generado en: $filePath',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: (!isWeb)
                  ? SnackBarAction(
                      label: 'Compartir',
                      textColor: Colors.white,
                      onPressed: () => ExcelExportService.compartirExcel(filePath),
                    )
                  : null,
            ),
          );
        }
      } else {
        if (mounted) {
          showErrorDialog(context, 'Error al generar el archivo Excel');
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Widget _buildUtilidadBrutaCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Utilidad Bruta por Rango de Fechas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ventas − Compras − Gastos del período elegido (mismo criterio que '
              'el balance de cierre de caja, pero para el rango que quieras).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoadingUtilidad ? null : _seleccionarRangoYCalcularUtilidad,
                icon: _isLoadingUtilidad
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.date_range),
                label: Text(
                  _rangoUtilidadSeleccionado == null
                      ? 'Elegir rango y calcular'
                      : '${_formatearFechaCorta(_rangoUtilidadSeleccionado!.start)} - '
                            '${_formatearFechaCorta(_rangoUtilidadSeleccionado!.end)}',
                ),
              ),
            ),
            if (_utilidadBrutaResultado != null) ...[
              const SizedBox(height: 12),
              _buildTotalRow('Ventas', _utilidadBrutaResultado!['totalVentasPeriodo'], Colors.green),
              const SizedBox(height: 6),
              _buildTotalRow('Compras', _utilidadBrutaResultado!['compras']?['total'], Colors.purple),
              const SizedBox(height: 6),
              _buildTotalRow('Gastos', _utilidadBrutaResultado!['gastos']?['total'], Colors.red),
              const SizedBox(height: 6),
              _buildTotalRow(
                'Utilidad Bruta (de caja)',
                _utilidadBrutaResultado!['utilidadBruta'],
                Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Utilidad Real (con costo de mercancía vendida)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 6),
              _buildTotalRow(
                'Costo de Mercancía Vendida',
                _utilidadBrutaResultado!['costoMercanciaVendida'],
                Colors.brown,
              ),
              const SizedBox(height: 6),
              _buildTotalRow(
                'Utilidad Bruta Real (${_formatearPorcentaje(_utilidadBrutaResultado!['margenBrutoPorcentaje'])})',
                _utilidadBrutaResultado!['utilidadBrutaReal'],
                Colors.teal,
              ),
              const SizedBox(height: 6),
              _buildTotalRow(
                'Utilidad Neta (${_formatearPorcentaje(_utilidadBrutaResultado!['margenNetoPorcentaje'])})',
                _utilidadBrutaResultado!['utilidadNeta'],
                Colors.indigo,
              ),
              if (_utilidadBrutaResultado!['huboEstimacion'] == true) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Algunos costos son estimados (productos vendidos antes de '
                          'esta actualización no tenían su costo guardado; se usó el '
                          'costo actual del producto como aproximación).',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarRangoYCalcularUtilidad() async {
    final rango = await mostrarSelectorRangoFechas(
      context,
      titulo: 'Utilidad Bruta por Rango',
      valorInicial: _rangoUtilidadSeleccionado,
    );
    if (rango == null) return;

    setState(() {
      _isLoadingUtilidad = true;
      _rangoUtilidadSeleccionado = rango;
      _utilidadBrutaResultado = null;
    });

    try {
      final hastaFinDia = DateTime(rango.end.year, rango.end.month, rango.end.day, 23, 59, 59);
      final resultado = await _libroContableService.getLibroContablePorRango(rango.start, hastaFinDia);
      if (!mounted) return;
      setState(() {
        _utilidadBrutaResultado = resultado;
      });
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUtilidad = false;
        });
      }
    }
  }

  String _formatearFechaCorta(DateTime fecha) => formatearFechaCorta(fecha);

  String _formatearMonto(dynamic monto) {
    if (monto == null) return '0';
    try {
      final valor = double.parse(monto.toString());
      return NumberFormat('#,##0', 'es_CO').format(valor);
    } catch (e) {
      return monto.toString();
    }
  }

  String _formatearPorcentaje(dynamic porcentaje) {
    if (porcentaje == null) return '0%';
    try {
      final valor = double.parse(porcentaje.toString());
      return '${valor.toStringAsFixed(1)}%';
    } catch (e) {
      return '0%';
    }
  }
}
