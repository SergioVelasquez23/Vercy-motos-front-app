import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/libro_contable_service.dart';
import '../services/pdf_service.dart';
import '../providers/user_provider.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';
import '../widgets/reportes/rango_fechas_dialog.dart';

/// Comparación de Períodos: mes actual vs. mes anterior, o un rango contra el
/// mismo rango del año anterior — usando la utilidad real (ventas, costo de
/// mercancía vendida, utilidad bruta/neta) de CosteoUtilidadService.
class ComparativoPeriodosScreen extends StatefulWidget {
  const ComparativoPeriodosScreen({super.key});

  @override
  State<ComparativoPeriodosScreen> createState() => _ComparativoPeriodosScreenState();
}

enum _ModoComparacion { mesAnterior, anioAnterior }

class _ComparativoPeriodosScreenState extends State<ComparativoPeriodosScreen> {
  final LibroContableService _libroContableService = LibroContableService();
  final PDFService _pdfService = PDFService();

  _ModoComparacion _modo = _ModoComparacion.mesAnterior;
  DateTimeRange? _rangoBase;
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
                Icon(Icons.compare_arrows, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Comparación de Períodos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Compara ventas, costo de mercancía vendida y utilidad real entre '
              'dos períodos, para ver si el negocio está mejorando o empeorando.',
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
            const Text('Tipo de comparación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModoBoton(
                    label: 'Mes vs. mes anterior',
                    seleccionado: _modo == _ModoComparacion.mesAnterior,
                    onTap: () => setState(() {
                      _modo = _ModoComparacion.mesAnterior;
                      _resultado = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModoBoton(
                    label: 'Vs. mismo período año anterior',
                    seleccionado: _modo == _ModoComparacion.anioAnterior,
                    onTap: () => setState(() {
                      _modo = _ModoComparacion.anioAnterior;
                      _resultado = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _modo == _ModoComparacion.mesAnterior
                  ? 'Elige cualquier fecha del mes que quieres analizar; se compara contra el mes calendario anterior.'
                  : 'Elige el rango de fechas base; se compara contra el mismo rango, un año atrás.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _elegirRangoBase,
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
                      _rangoBase == null
                          ? 'Elegir fecha/rango base'
                          : '${formatearFechaCorta(_rangoBase!.start)} - ${formatearFechaCorta(_rangoBase!.end)}',
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
                onPressed: (_isLoading || _rangoBase == null) ? null : _calcular,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.calculate),
                label: Text(_isLoading ? 'Calculando...' : 'Comparar'),
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

  Widget _buildModoBoton({required String label, required bool seleccionado, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: seleccionado ? Theme.of(context).primaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? Theme.of(context).primaryColor : Colors.grey.shade300,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
            color: seleccionado ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResultado() {
    final actual = _resultado!['periodoActual'] as Map<String, dynamic>? ?? {};
    final anterior = _resultado!['periodoAnterior'] as Map<String, dynamic>? ?? {};

    return [
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilaComparativa(
                'Ventas',
                actual['ventasPeriodo'],
                anterior['ventasPeriodo'],
                _resultado!['variacionVentasPorcentaje'],
                mostrarVariacion: true,
              ),
              const Divider(),
              _buildFilaComparativa(
                'Costo de Mercancía Vendida',
                actual['costoMercanciaVendida'],
                anterior['costoMercanciaVendida'],
                null,
              ),
              const Divider(),
              _buildFilaComparativa(
                'Utilidad Bruta',
                actual['utilidadBruta'],
                anterior['utilidadBruta'],
                _resultado!['variacionUtilidadBrutaPorcentaje'],
                mostrarVariacion: true,
              ),
              const Divider(),
              _buildFilaComparativa(
                'Utilidad Neta',
                actual['utilidadNeta'],
                anterior['utilidadNeta'],
                _resultado!['variacionUtilidadNetaPorcentaje'],
                mostrarVariacion: true,
              ),
              const Divider(),
              _buildFilaComparativa(
                'Margen Bruto',
                actual['margenBrutoPorcentaje'],
                anterior['margenBrutoPorcentaje'],
                null,
                esPorcentaje: true,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(
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
      ),
    ];
  }

  Widget _buildFilaComparativa(
    String titulo,
    dynamic valorActual,
    dynamic valorAnterior,
    dynamic variacionPorcentaje, {
    bool esPorcentaje = false,
    bool mostrarVariacion = false,
  }) {
    final variacion = variacionPorcentaje is num ? variacionPorcentaje.toDouble() : null;
    final subio = variacion != null && variacion > 0;
    final bajo = variacion != null && variacion < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildValorPeriodo('Actual', valorActual, esPorcentaje),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildValorPeriodo('Anterior', valorAnterior, esPorcentaje),
              ),
              if (mostrarVariacion)
                SizedBox(
                  width: 80,
                  child: variacion == null
                      ? Text('N/A', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              subio
                                  ? Icons.arrow_upward
                                  : (bajo ? Icons.arrow_downward : Icons.remove),
                              size: 14,
                              color: subio ? Colors.green : (bajo ? Colors.red : Colors.grey),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${variacion.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: subio ? Colors.green : (bajo ? Colors.red : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValorPeriodo(String etiqueta, dynamic valor, bool esPorcentaje) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        Text(
          esPorcentaje ? _formatearPorcentaje(valor) : '\$${_formatearMonto(valor)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Future<void> _elegirRangoBase() async {
    final rango = await mostrarSelectorRangoFechas(
      context,
      titulo: _modo == _ModoComparacion.mesAnterior ? 'Fecha del mes a analizar' : 'Rango base a comparar',
      valorInicial: _rangoBase,
    );
    if (rango == null) return;
    setState(() {
      _rangoBase = rango;
      _resultado = null;
    });
  }

  Future<void> _calcular() async {
    if (_rangoBase == null) return;

    setState(() {
      _isLoading = true;
      _resultado = null;
    });

    try {
      late DateTime desdeActual;
      late DateTime hastaActual;
      late DateTime desdeAnterior;
      late DateTime hastaAnterior;

      if (_modo == _ModoComparacion.mesAnterior) {
        final referencia = _rangoBase!.start;
        desdeActual = DateTime(referencia.year, referencia.month, 1);
        hastaActual = DateTime(referencia.year, referencia.month + 1, 1).subtract(const Duration(seconds: 1));
        final mesAnterior = DateTime(referencia.year, referencia.month - 1, 1);
        desdeAnterior = DateTime(mesAnterior.year, mesAnterior.month, 1);
        hastaAnterior = DateTime(mesAnterior.year, mesAnterior.month + 1, 1).subtract(const Duration(seconds: 1));
      } else {
        desdeActual = _rangoBase!.start;
        hastaActual = DateTime(
          _rangoBase!.end.year,
          _rangoBase!.end.month,
          _rangoBase!.end.day,
          23,
          59,
          59,
        );
        desdeAnterior = DateTime(desdeActual.year - 1, desdeActual.month, desdeActual.day);
        hastaAnterior = DateTime(hastaActual.year - 1, hastaActual.month, hastaActual.day, 23, 59, 59);
      }

      final resultado = await _libroContableService.getComparativoPeriodos(
        desdeActual,
        hastaActual,
        desdeAnterior,
        hastaAnterior,
      );
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
      'tipoComparacion': _modo == _ModoComparacion.mesAnterior
          ? 'Mes actual vs. mes anterior'
          : 'Rango vs. mismo rango del año anterior',
      'nombreNegocio': 'VERCY MOTOS',
      'fecha': formatearFechaCorta(ahora),
      'hora': DateFormat('HH:mm').format(ahora),
      'generadoPor': userProvider.userName ?? 'Sistema',
    };
  }

  Future<void> _mostrarVistaPrevia() async {
    if (_resultado == null) return;
    try {
      await _pdfService.mostrarVistaPreviewInformeComparativo(_armarResumenPDF());
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
      final pdfBytes = await _pdfService.generarInformeComparativoPDF(resumen: _armarResumenPDF());
      final nombreArchivo = 'Comparativo_Periodos_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
