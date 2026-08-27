import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/libro_contable_service.dart';
import '../services/pdf_service.dart';
import '../providers/user_provider.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';
import '../widgets/reportes/rango_fechas_dialog.dart';

/// Alertas y Anomalías: gastos que subieron anormalmente por categoría,
/// caída de ventas, clientes que compran menos, facturas inusualmente
/// altas, proveedores con aumento de precio y meses con pérdida — cada una
/// con una explicación ya redactada por el backend.
class AnomaliasScreen extends StatefulWidget {
  const AnomaliasScreen({super.key});

  @override
  State<AnomaliasScreen> createState() => _AnomaliasScreenState();
}

class _AnomaliasScreenState extends State<AnomaliasScreen> {
  final LibroContableService _libroContableService = LibroContableService();
  final PDFService _pdfService = PDFService();

  DateTimeRange? _rangoSeleccionado;
  bool _isLoading = false;
  bool _isExportando = false;
  Map<String, dynamic>? _resultado;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildFormularioCard(),
          const SizedBox(height: 16),
          if (_resultado != null) ..._buildResultado(),
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
                Icon(Icons.warning_amber, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Alertas y Anomalías',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Compara el período elegido contra tu propio historial para avisarte '
              'de gastos que se dispararon, caídas de ventas, clientes que se '
              'están alejando, facturas atípicas, proveedores que subieron '
              'precios y meses en pérdida.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormularioCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Período a analizar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _elegirRango,
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
                      _rangoSeleccionado == null
                          ? 'Elegir fechas'
                          : '${formatearFechaCorta(_rangoSeleccionado!.start)} - '
                                '${formatearFechaCorta(_rangoSeleccionado!.end)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _rangoSeleccionado == null) ? null : _analizar,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_isLoading ? 'Analizando...' : 'Analizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResultado() {
    final totalAnomalias = (_resultado!['totalAnomalias'] as num?)?.toInt() ?? 0;

    if (totalAnomalias == 0) {
      return [
        Card(
          elevation: 2,
          color: Colors.green.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No se detectaron anomalías en este período. Todo se ve dentro de lo normal.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildBotonesExportar(),
      ];
    }

    final gastosAnormales = (_resultado!['gastosAnormales'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final caidaVentas = _resultado!['caidaVentas'] as Map<String, dynamic>? ?? {};
    final clientesComprandoMenos =
        (_resultado!['clientesComprandoMenos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final facturasInusuales = (_resultado!['facturasInusuales'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final proveedoresConAumentoPrecio =
        (_resultado!['proveedoresConAumentoPrecio'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final mesesConPerdida = (_resultado!['mesesConPerdida'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return [
      Card(
        elevation: 2,
        color: Colors.red.withOpacity(0.06),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Se detectaron $totalAnomalias anomalías en este período.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildSeccionAnomalias('Gastos anormales por categoría', Icons.money_off, gastosAnormales),
      if (caidaVentas['esAnomalia'] == true)
        _buildSeccionAnomalias('Caída de ventas', Icons.trending_down, [caidaVentas]),
      _buildSeccionAnomalias('Clientes que compran menos', Icons.person_off, clientesComprandoMenos),
      _buildSeccionAnomalias('Facturas inusualmente altas', Icons.receipt_long, facturasInusuales),
      _buildSeccionAnomalias('Proveedores con aumento de precio', Icons.local_shipping, proveedoresConAumentoPrecio),
      _buildSeccionAnomalias('Meses con pérdida', Icons.calendar_month, mesesConPerdida),
      const SizedBox(height: 16),
      _buildBotonesExportar(),
    ];
  }

  Widget _buildSeccionAnomalias(String titulo, IconData icono, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$titulo (${items.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (item['mensaje'] ?? '-').toString(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotonesExportar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isExportando ? null : _mostrarVistaPrevia,
            icon: const Icon(Icons.visibility),
            label: const Text('Vista previa PDF'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isExportando ? null : _exportarPDF,
            icon: _isExportando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_isExportando ? 'Generando...' : 'Exportar PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _elegirRango() async {
    final rango = await mostrarSelectorRangoFechas(
      context,
      titulo: 'Período a Analizar',
      valorInicial: _rangoSeleccionado,
    );
    if (rango == null) return;
    setState(() {
      _rangoSeleccionado = rango;
      _resultado = null;
    });
  }

  Future<void> _analizar() async {
    if (_rangoSeleccionado == null) return;

    setState(() {
      _isLoading = true;
      _resultado = null;
    });

    try {
      final hastaFinDia = DateTime(
        _rangoSeleccionado!.end.year,
        _rangoSeleccionado!.end.month,
        _rangoSeleccionado!.end.day,
        23,
        59,
        59,
      );
      final resultado = await _libroContableService.getAnomalias(_rangoSeleccionado!.start, hastaFinDia);
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
      });
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

  Map<String, dynamic> _armarResumenPDF() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final ahora = DateTime.now();
    return {
      ..._resultado!,
      'nombreNegocio': 'VERCY MOTOS',
      'fecha': formatearFechaCorta(ahora),
      'hora': DateFormat('HH:mm').format(ahora),
      'fechaDesde': formatearFechaCorta(_rangoSeleccionado!.start),
      'fechaHasta': formatearFechaCorta(_rangoSeleccionado!.end),
      'generadoPor': userProvider.userName ?? 'Sistema',
    };
  }

  Future<void> _mostrarVistaPrevia() async {
    if (_resultado == null) return;
    try {
      await _pdfService.mostrarVistaPreviewInformeAnomalias(_armarResumenPDF());
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, errorMessage(e));
      }
    }
  }

  Future<void> _exportarPDF() async {
    if (_resultado == null) return;
    setState(() {
      _isExportando = true;
    });
    try {
      final pdfBytes = await _pdfService.generarInformeAnomaliasPDF(resumen: _armarResumenPDF());
      final nombreArchivo = 'Anomalias_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await _pdfService.descargarPDFDirecto(pdfBytes: pdfBytes, nombreArchivo: nombreArchivo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generado exitosamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportando = false;
        });
      }
    }
  }
}
