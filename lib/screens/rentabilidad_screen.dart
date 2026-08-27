import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/libro_contable_service.dart';
import '../services/pdf_service.dart';
import '../providers/user_provider.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';
import '../widgets/reportes/rango_fechas_dialog.dart';

/// Rentabilidad por Producto y Cliente: responde "¿qué productos son más
/// rentables?", "¿cuáles tienen mucha venta pero poco margen?" y "¿qué
/// clientes generan mayor utilidad?" usando el costo real (o estimado)
/// capturado en cada venta.
class RentabilidadScreen extends StatefulWidget {
  const RentabilidadScreen({super.key});

  @override
  State<RentabilidadScreen> createState() => _RentabilidadScreenState();
}

class _RentabilidadScreenState extends State<RentabilidadScreen> {
  final LibroContableService _libroContableService = LibroContableService();
  final PDFService _pdfService = PDFService();

  DateTimeRange? _rangoSeleccionado;
  bool _mostrandoProductos = true;
  bool _isLoading = false;
  bool _isExportando = false;
  Map<String, dynamic>? _resultadoProductos;
  Map<String, dynamic>? _resultadoClientes;
  bool _excluirManoDeObra = false;

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
          if (_resultadoProductos != null && _resultadoClientes != null) ..._buildResultado(),
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
                Icon(Icons.leaderboard, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Rentabilidad por Producto y Cliente',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Compara qué tan rentable es cada producto (utilidad real, no solo '
              'ventas) y qué clientes te dejan más utilidad, usando el costo '
              'capturado en cada venta.',
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
            const Text('Período', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _excluirManoDeObra,
              onChanged: (valor) => setState(() => _excluirManoDeObra = valor),
              title: const Text('Excluir mano de obra', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Solo repuestos/productos en el ranking, sin servicios de reparación',
                style: TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _rangoSeleccionado == null) ? null : _calcular,
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
                label: Text(_isLoading ? 'Calculando...' : 'Calcular'),
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
    return [
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: _buildModoBoton(
                  label: 'Productos',
                  seleccionado: _mostrandoProductos,
                  onTap: () => setState(() => _mostrandoProductos = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModoBoton(
                  label: 'Clientes',
                  seleccionado: !_mostrandoProductos,
                  onTap: () => setState(() => _mostrandoProductos = false),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (_mostrandoProductos) ..._buildSeccionProductos() else ..._buildSeccionClientes(),
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

  Widget _buildModoBoton({required String label, required bool seleccionado, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
            fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
            color: seleccionado ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSeccionProductos() {
    final porUtilidad = (_resultadoProductos!['porUtilidad'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final porCantidad = (_resultadoProductos!['porCantidadVendida'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final margenPromedio = _resultadoProductos!['margenPromedioPorcentaje'];

    return [
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTituloSeccion('Productos más rentables', Icons.emoji_events, Colors.teal),
              const SizedBox(height: 4),
              Text(
                'Margen promedio del período: ${_formatearPorcentaje(margenPromedio)} · '
                '${_resultadoProductos!['cantidadProductosAnalizados']} productos analizados',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              if (porUtilidad.isEmpty)
                Text('Sin ventas en este período', style: TextStyle(color: Colors.grey.shade600))
              else
                ..._buildRanking(
                  porUtilidad,
                  nombreKey: 'productoNombre',
                  valorKey: 'utilidad',
                  color: Colors.teal,
                  subtitulo: (item) =>
                      'Ventas \$${_formatearMonto(item['ventas'])} · Margen ${_formatearPorcentaje(item['margenPorcentaje'])}',
                ),
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
              _buildTituloSeccion('Productos más vendidos', Icons.shopping_bag, Colors.indigo),
              const SizedBox(height: 4),
              Text(
                'Ordenado por unidades vendidas — revisa el margen: naranja/rojo '
                'indica mucha venta con poca rentabilidad.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              if (porCantidad.isEmpty)
                Text('Sin ventas en este período', style: TextStyle(color: Colors.grey.shade600))
              else
                ..._buildRanking(
                  porCantidad,
                  nombreKey: 'productoNombre',
                  valorKey: 'cantidadVendida',
                  color: Colors.indigo,
                  subtitulo: (item) => '${_formatearMonto(item['cantidadVendida'])} unidades vendidas',
                  margenKey: 'margenPorcentaje',
                ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSeccionClientes() {
    final porUtilidad = (_resultadoClientes!['porUtilidad'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final margenPromedio = _resultadoClientes!['margenPromedioPorcentaje'];

    return [
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTituloSeccion('Clientes que más utilidad generan', Icons.people, Colors.deepPurple),
              const SizedBox(height: 4),
              Text(
                'Margen promedio del período: ${_formatearPorcentaje(margenPromedio)} · '
                '${_resultadoClientes!['cantidadClientesAnalizados']} clientes analizados',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              if (porUtilidad.isEmpty)
                Text('Sin ventas en este período', style: TextStyle(color: Colors.grey.shade600))
              else
                ..._buildRanking(
                  porUtilidad,
                  nombreKey: 'cliente',
                  valorKey: 'utilidad',
                  color: Colors.deepPurple,
                  subtitulo: (item) =>
                      'Ventas \$${_formatearMonto(item['ventas'])} · ${item['numeroPedidos']} pedidos · '
                      'Margen ${_formatearPorcentaje(item['margenPorcentaje'])}',
                ),
            ],
          ),
        ),
      ),
    ];
  }

  /// Ranking con barra proporcional al valor máximo del set — sin librería de
  /// charts, consistente con el estilo minimalista del resto de la app.
  List<Widget> _buildRanking(
    List<Map<String, dynamic>> items, {
    required String nombreKey,
    required String valorKey,
    required Color color,
    required String Function(Map<String, dynamic>) subtitulo,
    String? margenKey,
  }) {
    final maxValor = items
        .map((e) => (e[valorKey] as num?)?.toDouble() ?? 0.0)
        .fold<double>(0.0, (a, b) => b > a ? b : a);

    return items.map((item) {
      final valor = (item[valorKey] as num?)?.toDouble() ?? 0.0;
      final factor = maxValor > 0 ? (valor / maxValor).clamp(0.03, 1.0) : 0.03;
      final margen = margenKey != null ? (item[margenKey] as num?)?.toDouble() : null;
      final colorBarra = margen != null && margen < 5
          ? Colors.red
          : (margen != null && margen < 15 ? Colors.orange : color);

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (item[nombreKey] ?? '-').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item['tieneCostoEstimado'] == true)
                  Tooltip(
                    message: 'Costo estimado (venta anterior a la captura de costo real)',
                    child: Icon(Icons.info_outline, size: 14, color: Colors.amber.shade700),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: factor,
                  child: Container(height: 8, color: colorBarra),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitulo(item), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildTituloSeccion(String texto, IconData icono, Color color) {
    return Row(
      children: [
        Icon(icono, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
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
      _resultadoProductos = null;
      _resultadoClientes = null;
    });
  }

  Future<void> _calcular() async {
    if (_rangoSeleccionado == null) return;

    setState(() {
      _isLoading = true;
      _resultadoProductos = null;
      _resultadoClientes = null;
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
      final resultados = await Future.wait([
        _libroContableService.getRentabilidadProductos(
          _rangoSeleccionado!.start,
          hastaFinDia,
          filtroTipoItem: _excluirManoDeObra ? 'producto' : null,
        ),
        _libroContableService.getRentabilidadClientes(_rangoSeleccionado!.start, hastaFinDia),
      ]);
      if (!mounted) return;
      setState(() {
        _resultadoProductos = resultados[0];
        _resultadoClientes = resultados[1];
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
      'productos': _resultadoProductos,
      'clientes': _resultadoClientes,
      'nombreNegocio': 'VERCY MOTOS',
      'fecha': formatearFechaCorta(ahora),
      'hora': DateFormat('HH:mm').format(ahora),
      'fechaDesde': formatearFechaCorta(_rangoSeleccionado!.start),
      'fechaHasta': formatearFechaCorta(_rangoSeleccionado!.end),
      'generadoPor': userProvider.userName ?? 'Sistema',
    };
  }

  Future<void> _mostrarVistaPrevia() async {
    if (_resultadoProductos == null || _resultadoClientes == null) return;
    try {
      await _pdfService.mostrarVistaPreviewInformeRentabilidad(_armarResumenPDF());
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, errorMessage(e));
      }
    }
  }

  Future<void> _exportarPDF() async {
    if (_resultadoProductos == null || _resultadoClientes == null) return;
    setState(() {
      _isExportando = true;
    });
    try {
      final pdfBytes = await _pdfService.generarInformeRentabilidadPDF(resumen: _armarResumenPDF());
      final nombreArchivo = 'Rentabilidad_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
