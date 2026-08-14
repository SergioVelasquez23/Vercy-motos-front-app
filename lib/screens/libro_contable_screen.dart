import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import '../services/libro_contable_service.dart';
import '../services/excel_export_service.dart';
import '../providers/user_provider.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

class LibroContableScreen extends StatefulWidget {
  const LibroContableScreen({super.key});

  @override
  State<LibroContableScreen> createState() => _LibroContableScreenState();
}

class _LibroContableScreenState extends State<LibroContableScreen> {
  final LibroContableService _libroContableService = LibroContableService();

  DateTime _fechaSeleccionada = DateTime.now();
  bool _isLoading = false;
  bool _isExporting = false;
  Map<String, dynamic>? _datosPreview;

  bool _isLoadingUtilidad = false;
  DateTimeRange? _rangoUtilidadSeleccionado;
  Map<String, dynamic>? _utilidadBrutaResultado;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libro Contable Mensual'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
              'Seleccionar Mes y Año',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _mostrarSelectorFecha,
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
                      DateFormat('MMMM yyyy', 'es_ES').format(_fechaSeleccionada),
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
                onPressed: _isLoading ? null : _cargarPreview,
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

    // El total de "Mixto" se muestra como una sola fila (igual que antes) pero
    // acá se le agrega, debajo, cuánto de ese monto vino de cada submétodo
    // real (efectivo/transferencia/etc. dentro del mismo pago mixto) — antes
    // solo se veía el total sin saber de qué estaba compuesto.
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
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      selectableDayPredicate: (DateTime date) => date.day == 1,
      helpText: 'Seleccionar mes y año',
      fieldLabelText: 'Mes/Año',
    );

    if (fechaSeleccionada != null) {
      setState(() {
        _fechaSeleccionada = DateTime(fechaSeleccionada.year, fechaSeleccionada.month, 1);
        _datosPreview = null;
      });
    }
  }

  Future<void> _cargarPreview() async {
    setState(() {
      _isLoading = true;
      _datosPreview = null;
    });

    try {
      final datos = await _libroContableService.getLibroContableMensual(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
      );

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
          errorMsg = 'El servidor tardó demasiado. Intenta con un mes con menos datos.';
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
                'Utilidad Bruta',
                _utilidadBrutaResultado!['utilidadBruta'],
                Theme.of(context).primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarRangoYCalcularUtilidad() async {
    final rango = await _seleccionarRangoFechasUtilidad();
    if (rango == null) return;

    setState(() {
      _isLoadingUtilidad = true;
      _rangoUtilidadSeleccionado = rango;
      _utilidadBrutaResultado = null;
    });

    try {
      // 'hasta' incluye el día completo (23:59:59) para no cortar las ventas
      // del último día del rango.
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

  Future<DateTimeRange?> _seleccionarRangoFechasUtilidad() async {
    DateTime desde = _rangoUtilidadSeleccionado?.start ?? DateTime.now().subtract(const Duration(days: 30));
    DateTime hasta = _rangoUtilidadSeleccionado?.end ?? DateTime.now();

    return showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> seleccionar(bool esDesde) async {
              final fecha = await showDatePicker(
                context: dialogContext,
                initialDate: esDesde ? desde : hasta,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (fecha != null) {
                setDialogState(() {
                  if (esDesde) {
                    desde = fecha;
                  } else {
                    hasta = fecha;
                  }
                });
              }
            }

            return AlertDialog(
              title: const Text('Utilidad Bruta por Rango'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona el rango de fechas a calcular:',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Desde'),
                    subtitle: Text(
                      _formatearFechaCorta(desde),
                      style: TextStyle(color: Theme.of(dialogContext).primaryColor, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => seleccionar(true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hasta'),
                    subtitle: Text(
                      _formatearFechaCorta(hasta),
                      style: TextStyle(color: Theme.of(dialogContext).primaryColor, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => seleccionar(false),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (hasta.isBefore(desde)) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('La fecha "Hasta" no puede ser anterior a "Desde"')),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(DateTimeRange(start: desde, end: hasta));
                  },
                  icon: const Icon(Icons.calculate),
                  label: const Text('Calcular'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatearFechaCorta(DateTime fecha) => DateFormat('dd/MM/yyyy').format(fecha);

  String _formatearMonto(dynamic monto) {
    if (monto == null) return '0';
    try {
      final valor = double.parse(monto.toString());
      return NumberFormat('#,##0', 'es_CO').format(valor);
    } catch (e) {
      return monto.toString();
    }
  }
}
