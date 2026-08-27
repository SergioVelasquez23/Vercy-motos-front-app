import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/libro_contable_service.dart';
import '../services/pdf_service.dart';
import '../providers/user_provider.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';
import '../widgets/reportes/rango_fechas_dialog.dart';

/// Costeo de Inventario y Utilidad Real: responde con datos del sistema a las
/// 3 preguntas clásicas para reconstruir la utilidad sin depender de un
/// programa contable aparte (inventario inicial/final, compras con o sin
/// IVA), usando la fórmula contable clásica Inventario inicial + Compras −
/// Inventario final = Costo de mercancía vendida, y la compara contra el
/// costo real capturado en cada venta.
class CosteoInventarioScreen extends StatefulWidget {
  const CosteoInventarioScreen({super.key});

  @override
  State<CosteoInventarioScreen> createState() => _CosteoInventarioScreenState();
}

class _CosteoInventarioScreenState extends State<CosteoInventarioScreen> {
  final LibroContableService _libroContableService = LibroContableService();
  final PDFService _pdfService = PDFService();
  final TextEditingController _inventarioInicialController = TextEditingController();

  DateTimeRange? _rangoSeleccionado;
  bool _isLoading = false;
  bool _isExportando = false;
  Map<String, dynamic>? _resultado;

  @override
  void dispose() {
    _inventarioInicialController.dispose();
    super.dispose();
  }

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
                Icon(Icons.calculate, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Costeo de Inventario y Utilidad Real',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Calcula el costo de mercancía vendida por dos métodos: por venta '
              '(usando el costo real de cada producto vendido) y por inventario '
              '(fórmula contable: Inventario inicial + Compras − Inventario '
              'final), para que puedas comparar y validar la utilidad real del '
              'período.',
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
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Inventario inicial (valor a costo, aprox.)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message:
                      'El sistema no guarda un histórico de inventario por '
                      'fecha, así que este valor se pide manualmente. Es lo '
                      'que valía a costo la mercancía en existencia al '
                      'INICIO del período elegido.',
                  child: Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inventarioInicialController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Ej: 30000000',
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                helperText: 'Opcional: sin este dato solo se calcula el costo por venta.',
              ),
            ),
            const SizedBox(height: 16),
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
    final metodoPorVenta = _resultado!['metodoPorVenta'] as Map<String, dynamic>? ?? {};
    final metodoPorInventario = _resultado!['metodoPorInventario'] as Map<String, dynamic>? ?? {};
    final tieneInventarioInicial = metodoPorInventario['inventarioInicial'] != null;
    final huboEstimacion = metodoPorVenta['huboEstimacion'] == true;

    return [
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTituloSeccion('Ventas del período', Icons.point_of_sale, Colors.green),
              const SizedBox(height: 8),
              _buildFila('Ventas', _resultado!['ventasPeriodo'], Colors.green),
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
              _buildTituloSeccion('Método 1: Costo por venta', Icons.receipt_long, Colors.teal),
              const SizedBox(height: 4),
              Text(
                'Suma cantidad × costo de cada producto vendido en el período.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              _buildFilaConInfo(
                'Costo de Mercancía Vendida',
                metodoPorVenta['costoMercanciaVendida'],
                Colors.brown,
                'Suma de (cantidad × costo) de cada producto vendido en el período. '
                'Usa el costo guardado al momento de la venta, o el costo actual '
                'del producto como estimación si esa venta es anterior a que el '
                'sistema empezara a guardarlo.',
              ),
              _buildFilaConInfo(
                'Utilidad Bruta Real',
                metodoPorVenta['utilidadBruta'],
                Colors.teal,
                'Ventas menos Costo de Mercancía Vendida. Es la ganancia real '
                'antes de gastos operativos.',
              ),
              _buildFilaConInfo(
                'Margen Bruto',
                null,
                Colors.teal,
                'Utilidad Bruta Real dividida entre Ventas.',
                valorTexto: _formatearPorcentaje(metodoPorVenta['margenBrutoPorcentaje']),
              ),
              if (huboEstimacion)
                Container(
                  margin: const EdgeInsets.only(top: 8),
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
                          '${metodoPorVenta['cantidadItemsEstimados']} de '
                          '${metodoPorVenta['cantidadItemsTotal']} productos vendidos '
                          'en este período tienen su costo estimado (no capturado al '
                          'momento de la venta).',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
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
              _buildTituloSeccion('Método 2: Costo por inventario', Icons.inventory_2, Colors.indigo),
              const SizedBox(height: 4),
              Text(
                'Fórmula contable clásica: Inventario inicial + Compras − Inventario final.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              _buildFilaConInfo(
                'Inventario Inicial',
                null,
                Colors.indigo,
                'Valor a costo que ingresaste manualmente para el inicio del período.',
                valorTexto: tieneInventarioInicial
                    ? '\$${_formatearMonto(metodoPorInventario['inventarioInicial'])}'
                    : 'No informado',
              ),
              _buildFilaConInfo(
                'Compras (sin IVA)',
                metodoPorInventario['comprasSinIva'],
                Colors.purple,
                'Total de compras a proveedores del período, sin IVA (usado en la fórmula).',
              ),
              _buildFilaConInfo(
                'Compras (con IVA)',
                metodoPorInventario['comprasConIva'],
                Colors.purple,
                'Total de compras a proveedores del período, con IVA (lo que se pagó realmente).',
              ),
              _buildFilaConInfo(
                'Inventario Final',
                metodoPorInventario['inventarioFinalCalculado'],
                Colors.indigo,
                'Valor a costo de la mercancía en existencia HOY. Solo es exacto '
                'si el fin del período elegido es hoy.',
              ),
              _buildFilaConInfo(
                'Costo de Mercancía Vendida',
                null,
                Colors.brown,
                'Inventario inicial + Compras (sin IVA) − Inventario final.',
                valorTexto: tieneInventarioInicial
                    ? '\$${_formatearMonto(metodoPorInventario['costoMercanciaVendida'])}'
                    : 'N/D (falta inventario inicial)',
              ),
              _buildFilaConInfo(
                'Utilidad Bruta (por inventario)',
                null,
                Colors.teal,
                'Ventas menos el Costo de Mercancía Vendida de este método. '
                'Compárala con la Utilidad Bruta Real del Método 1.',
                valorTexto: tieneInventarioInicial
                    ? '\$${_formatearMonto(metodoPorInventario['utilidadBruta'])}'
                    : 'N/D (falta inventario inicial)',
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
              _buildTituloSeccion('Resumen final', Icons.summarize, Theme.of(context).primaryColor),
              const SizedBox(height: 8),
              _buildFila('Gastos Operativos', _resultado!['gastosOperativos'], Colors.red),
              const SizedBox(height: 6),
              _buildFila(
                'Utilidad Neta (${_formatearPorcentaje(_resultado!['margenNetoPorcentaje'])})',
                _resultado!['utilidadNeta'],
                Theme.of(context).primaryColor,
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

  Widget _buildTituloSeccion(String texto, IconData icono, Color color) {
    return Row(
      children: [
        Icon(icono, color: color),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFila(String titulo, dynamic monto, Color color) {
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
          Text('\$${_formatearMonto(monto)}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilaConInfo(
    String titulo,
    dynamic monto,
    Color color,
    String explicacion, {
    String? valorTexto,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: explicacion,
                      child: Icon(Icons.info_outline, size: 15, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Text(
                valorTexto ?? '\$${_formatearMonto(monto)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(explicacion, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Future<void> _elegirRango() async {
    final rango = await mostrarSelectorRangoFechas(
      context,
      titulo: 'Período a Costear',
      valorInicial: _rangoSeleccionado,
    );
    if (rango == null) return;
    setState(() {
      _rangoSeleccionado = rango;
      _resultado = null;
    });
  }

  Future<void> _calcular() async {
    if (_rangoSeleccionado == null) return;

    double? inventarioInicial;
    final textoInventario = _inventarioInicialController.text.trim();
    if (textoInventario.isNotEmpty) {
      inventarioInicial = double.tryParse(textoInventario.replaceAll('.', '').replaceAll(',', '.'));
      if (inventarioInicial == null) {
        showErrorDialog(context, 'El inventario inicial debe ser un número válido');
        return;
      }
    }

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
      final resultado = await _libroContableService.getCosteoInventario(
        _rangoSeleccionado!.start,
        hastaFinDia,
        inventarioInicial: inventarioInicial,
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
      await _pdfService.mostrarVistaPreviewInformeCosteo(_armarResumenPDF());
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
      final pdfBytes = await _pdfService.generarInformeCosteoPDF(resumen: _armarResumenPDF());
      final nombreArchivo = 'Costeo_Utilidad_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
