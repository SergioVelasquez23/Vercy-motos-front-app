import 'package:flutter/material.dart';
import '../models/resumen_cierre_completo.dart';
import '../services/resumen_cierre_completo_service.dart';
import '../utils/format_utils.dart';
import '../utils/payment_calculator.dart';
import '../theme/app_theme.dart';

class ResumenCierreDetalladoScreen extends StatefulWidget {
  final String cuadreId;
  final String nombreCuadre;
  final dynamic datosPrecargados; // ✅ NUEVO: Datos precargados

  const ResumenCierreDetalladoScreen({
    super.key,
    required this.cuadreId,
    required this.nombreCuadre,
    this.datosPrecargados, // Opcional
  });

  @override
  State<ResumenCierreDetalladoScreen> createState() =>
      _ResumenCierreDetalladoScreenState();
}

class _ResumenCierreDetalladoScreenState
    extends State<ResumenCierreDetalladoScreen> {
  // Theme getters
  Color get primary => AppTheme.primary;
  Color get bgDark => AppTheme.backgroundDark;
  Color get cardBg => AppTheme.cardBg;
  Color get textDark => AppTheme.textDark;
  Color get textLight => AppTheme.textLight;
  Color get accent => AppTheme.accent;

  final ResumenCierreCompletoService _service = ResumenCierreCompletoService();
  final ScrollController _scrollController = ScrollController();

  ResumenCierreCompleto? _resumen;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // ✅ OPTIMIZACIÓN: Usar datos precargados si están disponibles
    if (widget.datosPrecargados != null) {
      _resumen = widget.datosPrecargados;
      _isLoading = false;
    } else {
      _loadResumenDetallado();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadResumenDetallado() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resumen = await _service.getResumenCierre(widget.cuadreId);
      setState(() {
        _resumen = resumen;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar el resumen: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: primary,
        title: Text(
          'Resumen Detallado - ${widget.nombreCuadre}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadResumenDetallado,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _scrollToBottom,
        backgroundColor: primary,
        child: Icon(Icons.keyboard_arrow_down, color: Colors.white),
        tooltip: 'Ir al balance final',
      ),
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primary),
            SizedBox(height: 16),
            Text(
              'Cargando resumen detallado...',
              style: TextStyle(color: textLight),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadResumenDetallado,
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_resumen == null) {
      return Center(
        child: Text(
          'No hay datos disponibles',
          style: TextStyle(color: textLight, fontSize: 16),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primera fila: 2 cards por fila
          _buildGridRow([_buildCuadreInfo(), _buildResumenFinal()]),
          SizedBox(height: 24),

          // Segunda fila: 2 cards por fila
          _buildGridRow([_buildMovimientosEfectivo(), _buildIngresosCaja()]),
          SizedBox(height: 24),

          // Tercera fila: 2 cards por fila
          _buildGridRow([_buildResumenVentas(), _buildResumenGastos()]),
          SizedBox(height: 24),

          // Resto de secciones que ocupan todo el ancho (detallados o más complejos)
          _buildDetallesPedidos(),
          SizedBox(height: 24),
          _buildResumenCompras(),
          SizedBox(height: 24),
          _buildResumenFinalConsolidado(),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 8), // Reduced margin
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6), // Reduced padding
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6), // Reduced radius
            ),
            child: Icon(icon, color: primary, size: 16), // Smaller icon
          ),
          SizedBox(width: 8), // Reduced spacing
          Text(
            title,
            style: TextStyle(
              color: textDark,
              fontSize: 15, // Smaller font size
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGridRow(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .map(
            (child) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: child,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6), // Increased vertical padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textLight, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? textDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuadreInfo() {
    final info = _resumen!.cuadreInfo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Información del Cuadre', Icons.info),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primera columna
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Nombre', info.nombre),
                        SizedBox(height: 10),
                        _buildInfoRow('Responsable', info.responsable),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Estado',
                          info.estado,
                          valueColor: info.estado == 'pendiente'
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 28),
                  // Segunda columna
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'Fecha Apertura',
                          _formatDate(info.fechaApertura),
                        ),
                        SizedBox(height: 10),
                        if (info.fechaCierre != null)
                          _buildInfoRow(
                            'Fecha Cierre',
                            _formatDate(info.fechaCierre!),
                          )
                        else
                          _buildInfoRow('Fecha Cierre', '-'),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Fondo Inicial',
                          formatCurrency(info.fondoInicial),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (info.fondoInicialDesglosado.isNotEmpty) ...[
                Divider(height: 16, color: textLight.withOpacity(0.2)),
                Text(
                  'Desglose Fondo Inicial:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 16,
                  runSpacing: 2,
                  children: info.fondoInicialDesglosado.entries
                      .map(
                        (entry) => SizedBox(
                          width: 120, // Fixed width for each entry
                          child: _buildInfoRow(
                            '${entry.key}',
                            formatCurrency(entry.value),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResumenFinal() {
    final resumen = _resumen!.resumenFinal;
    final movimientos =
        _resumen!.movimientosEfectivo; // ✅ Usar movimientos para fondo inicial
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Resumen Final', Icons.assessment),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información principal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primera columna
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'Fondo Inicial',
                          formatCurrency(
                            movimientos.fondoInicial,
                          ), // ✅ CORREGIDO: Usar movimientos
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Efectivo Esperado',
                          formatCurrency(resumen.efectivoEsperado),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Total Ventas',
                          formatCurrency(resumen.totalVentas),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Ventas Efectivo',
                          formatCurrency(resumen.ventasEfectivo),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 28),
                  // Segunda columna
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'Total Gastos',
                          formatCurrency(resumen.totalGastos),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Gastos Efectivo',
                          formatCurrency(resumen.gastosEfectivo),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Total Compras',
                          formatCurrency(resumen.totalCompras),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Compras Efectivo',
                          formatCurrency(resumen.comprasEfectivo),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Divider(height: 16, color: textLight.withOpacity(0.3)),

              // Totales finales
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      'Gastos Directos',
                      formatCurrency(resumen.gastosDirectos),
                    ),
                  ),
                  SizedBox(width: 28),
                  Expanded(
                    child: _buildInfoRow(
                      'Fact. desde Caja',
                      formatCurrency(resumen.facturasPagadasDesdeCaja),
                    ),
                  ),
                ],
              ),

              Divider(height: 16, color: textLight.withOpacity(0.3)),

              // Utilidad bruta con estilo destacado
              _buildInfoRow(
                'Utilidad Bruta',
                formatCurrency(resumen.utilidadBruta),
                valueColor: resumen.utilidadBruta >= 0
                    ? Colors.green
                    : Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMovimientosEfectivo() {
    final movimientos = _resumen!.movimientosEfectivo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Movimientos de Efectivo', Icons.attach_money),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primera fila con información principal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'Fondo Inicial',
                          formatCurrency(movimientos.fondoInicial),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Efectivo Esperado',
                          formatCurrency(movimientos.efectivoEsperado),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'Total Ingresos',
                          formatCurrency(movimientos.totalIngresosCaja),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Transf. Esperada',
                          formatCurrency(movimientos.transferenciaEsperada),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Divider(height: 16, color: textLight.withOpacity(0.2)),

              // Secciones detalladas en una cuadrícula
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primera columna: Ingresos y Ventas
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ingresos:',
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        _buildInfoRow(
                          'Efectivo',
                          formatCurrency(movimientos.ingresosEfectivo),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Transferencia',
                          formatCurrency(movimientos.ingresosTransferencia),
                        ),

                        SizedBox(height: 16),

                        Text(
                          'Ventas:',
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        _buildInfoRow(
                          'Efectivo',
                          formatCurrency(movimientos.ventasEfectivo),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Transferencia',
                          formatCurrency(movimientos.ventasTransferencia),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 28),

                  // Segunda columna: Gastos y Compras
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gastos:',
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        _buildInfoRow(
                          'Efectivo',
                          formatCurrency(movimientos.gastosEfectivo),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Transferencia',
                          formatCurrency(movimientos.gastosTransferencia),
                        ),

                        SizedBox(height: 16),

                        Text(
                          'Compras:',
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        _buildInfoRow(
                          'Efectivo',
                          formatCurrency(movimientos.comprasEfectivo),
                        ),
                        SizedBox(height: 10),
                        _buildInfoRow(
                          'Transferencia',
                          formatCurrency(movimientos.comprasTransferencia),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResumenVentas() {
    final ventas = _resumen!.resumenVentas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Resumen de Ventas', Icons.shopping_cart),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información principal en dos columnas
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      'Total Pedidos',
                      ventas.totalPedidos.toString(),
                    ),
                  ),
                  SizedBox(width: 28),
                  Expanded(
                    child: _buildInfoRow(
                      'Total Ventas',
                      formatCurrency(ventas.totalVentas),
                    ),
                  ),
                ],
              ),

              if (ventas.ventasPorFormaPago.isNotEmpty) ...[
                Divider(height: 16, color: textLight.withOpacity(0.2)),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ventas por Forma de Pago:',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 4),
                          ...ventas.ventasPorFormaPago.entries.map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: _buildInfoRow(
                                entry.key,
                                formatCurrency(entry.value),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ventas.cantidadPorFormaPago.isNotEmpty) ...[
                      SizedBox(width: 28),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cantidad por Forma de Pago:',
                              style: TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            ...ventas.cantidadPorFormaPago.entries.map(
                              (entry) => Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: _buildInfoRow(
                                  entry.key,
                                  entry.value.toString(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResumenCompras() {
    final compras = _resumen!.resumenCompras;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Resumen de Compras', Icons.shopping_bag),
        _buildCard(
          child: Column(
            children: [
              _buildInfoRow(
                'Total Compras Generales',
                formatCurrency(compras.totalComprasGenerales),
              ),
              SizedBox(height: 10),
              _buildInfoRow(
                'Total Facturas Generales',
                compras.totalFacturasGenerales.toString(),
              ),
              SizedBox(height: 16),
              Text(
                'Compras desde Caja:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              _buildInfoRow(
                '  Total',
                formatCurrency(compras.totalComprasDesdeCaja),
              ),
              SizedBox(height: 10),
              _buildInfoRow(
                '  Facturas',
                compras.totalFacturasDesdeCaja.toString(),
              ),
              SizedBox(height: 16),
              Text(
                'Compras NO desde Caja:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              _buildInfoRow(
                '  Total',
                formatCurrency(compras.totalComprasNoDesdeCaja),
              ),
              SizedBox(height: 10),
              _buildInfoRow(
                '  Facturas',
                compras.totalFacturasNoDesdeCaja.toString(),
              ),
              if (compras.comprasPorFormaPago.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Compras por Forma de Pago:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                ...compras.comprasPorFormaPago.entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _buildInfoRow(
                      '  ${entry.key}',
                      formatCurrency(entry.value),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (compras.detallesComprasNoDesdeCaja.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildComprasDetalles(
            'Compras NO pagadas desde Caja',
            compras.detallesComprasNoDesdeCaja,
          ),
        ],
        if (compras.detallesComprasDesdeCaja.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildComprasDetalles(
            'Compras pagadas desde Caja',
            compras.detallesComprasDesdeCaja,
          ),
        ],
      ],
    );
  }

  Widget _buildComprasDetalles(String titulo, List<DetalleCompra> compras) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        ...compras.map(
          (compra) => Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: textLight.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      compra.numero,
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatCurrency(compra.total),
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Proveedor: ${compra.proveedor}',
                  style: TextStyle(color: textLight, fontSize: 12),
                ),
                Text(
                  'Medio de Pago: ${compra.medioPago}',
                  style: TextStyle(color: textLight, fontSize: 12),
                ),
                Text(
                  'Fecha: ${_formatDate(compra.fecha)}',
                  style: TextStyle(color: textLight, fontSize: 12),
                ),
                if (compra.observaciones.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    'Observaciones: ${compra.observaciones}',
                    style: TextStyle(color: textLight, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumenGastos() {
    final gastos = _resumen!.resumenGastos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Resumen de Gastos', Icons.money_off),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primera fila
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      'Total Gastos',
                      formatCurrency(gastos.totalGastos),
                    ),
                  ),
                  SizedBox(width: 28),
                  Expanded(
                    child: _buildInfoRow(
                      'Total Registros',
                      gastos.totalRegistros.toString(),
                    ),
                  ),
                ],
              ),

              Divider(height: 16, color: textLight.withOpacity(0.2)),

              // Segunda fila
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      'Gastos Desde Caja',
                      formatCurrency(gastos.totalGastosDesdeCaja),
                    ),
                  ),
                  SizedBox(width: 28),
                  Expanded(
                    child: _buildInfoRow(
                      'Fact. desde Caja',
                      formatCurrency(gastos.facturasPagadasDesdeCaja),
                    ),
                  ),
                ],
              ),

              // Total incluyendo facturas
              Divider(height: 16, color: textLight.withOpacity(0.2)),
              _buildInfoRow(
                'Total (con facturas)',
                formatCurrency(gastos.totalGastosIncluyendoFacturas),
                valueColor: Colors.red,
              ),
              if (gastos.gastosPorTipo.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Gastos por Tipo:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                ...gastos.gastosPorTipo.entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _buildInfoRow(
                      '  ${entry.key}',
                      formatCurrency(entry.value),
                    ),
                  ),
                ),
              ],
              if (gastos.gastosPorFormaPago.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Gastos por Forma de Pago:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                ...gastos.gastosPorFormaPago.entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _buildInfoRow(
                      '  ${entry.key}',
                      formatCurrency(entry.value),
                    ),
                  ),
                ),
              ],
              if (gastos.cantidadPorTipo.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Cantidad por Tipo:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                ...gastos.cantidadPorTipo.entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _buildInfoRow(
                      '  ${entry.key}',
                      entry.value.toString(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Mostrar detalles de gastos si hay
        if (gastos.detallesGastos.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildGastosDetalles('Detalles de Gastos', gastos.detallesGastos),
        ],
      ],
    );
  }

  Widget _buildGastosDetalles(String titulo, List<DetalleGasto> gastos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        ...gastos.map(
          (gasto) => Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: textLight.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        gasto.concepto,
                        style: TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      formatCurrency(gasto.monto),
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                if (gasto.proveedor != null && gasto.proveedor!.isNotEmpty)
                  Text(
                    'Proveedor: ${gasto.proveedor}',
                    style: TextStyle(color: textLight, fontSize: 12),
                  ),
                if (gasto.formaPago.isNotEmpty)
                  Text(
                    'Forma de Pago: ${gasto.formaPago}',
                    style: TextStyle(color: textLight, fontSize: 12),
                  ),
                Text(
                  'Fecha: ${_formatDate(gasto.fecha)}',
                  style: TextStyle(color: textLight, fontSize: 12),
                ),
                Text(
                  'Pagado desde Caja: ${gasto.pagadoDesdeCaja ? "Sí" : "No"}',
                  style: TextStyle(
                    color: gasto.pagadoDesdeCaja ? Colors.red : textLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngresosCaja() {
    final movimientos = _resumen!.movimientosEfectivo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Ingresos de Caja', Icons.account_balance_wallet),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información principal
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildInfoRow(
                      'Total Ingresos',
                      formatCurrency(movimientos.totalIngresosCaja),
                      valueColor: Colors.green,
                    ),
                  ),
                ],
              ),

              Divider(height: 16, color: textLight.withOpacity(0.2)),

              // Detalle de ingresos
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      'Efectivo',
                      formatCurrency(movimientos.ingresosEfectivo),
                    ),
                  ),
                  SizedBox(width: 28),
                  Expanded(
                    child: _buildInfoRow(
                      'Transferencia',
                      formatCurrency(movimientos.ingresosTransferencia),
                    ),
                  ),
                ],
              ),

              if (movimientos.ingresosPorFormaPago.isNotEmpty) ...[
                Divider(height: 16, color: textLight.withOpacity(0.2)),
                Text(
                  'Ingresos por Forma de Pago:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: movimientos.ingresosPorFormaPago.entries
                      .map(
                        (entry) => SizedBox(
                          width: 120, // Fixed width for each entry
                          child: _buildInfoRow(
                            entry.key,
                            formatCurrency(entry.value),
                            valueColor: Colors.green,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetallesPedidos() {
    final ventas = _resumen!.resumenVentas;
    if (ventas.detallesPedidos.isEmpty) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Detalles de Pedidos', Icons.receipt_long),
        Text(
          'Pedidos (${ventas.detallesPedidos.length})',
          style: TextStyle(
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        ...ventas.detallesPedidos.map(
          (pedido) => Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: textLight.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con mesa y total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.table_restaurant,
                          color: Colors.blue,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Mesa: ${pedido.mesa}',
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (pedido.descuento > 0 || pedido.propina > 0) ...[
                          Text(
                            'Total items: ${formatCurrency(pedido.total)}',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          if (pedido.descuento > 0)
                            Text(
                              'Descuento: -${formatCurrency(pedido.descuento)}',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          if (pedido.propina > 0)
                            Text(
                              'Propina: +${formatCurrency(pedido.propina)}',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                          Divider(height: 8),
                        ],
                        Text(
                          'PAGADO: ${formatCurrency(PaymentCalculator.calcularTotalRealDetalle(pedido.total, pedido.descuento, pedido.propina))}',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Información básica en 2 columnas
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipo: ${pedido.tipo}',
                            style: TextStyle(color: textLight, fontSize: 12),
                          ),
                          Text(
                            'Forma de Pago: ${pedido.formaPago}',
                            style: TextStyle(color: textLight, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha: ${_formatDate(pedido.fecha)}',
                            style: TextStyle(color: textLight, fontSize: 12),
                          ),
                          Text(
                            'ID: ${pedido.id.length > 8 ? pedido.id.substring(pedido.id.length - 8) : pedido.id}',
                            style: TextStyle(color: textLight, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Alerta para pagos mixtos que no muestran desglose
                if (pedido.formaPago.toLowerCase().contains('mixto') ||
                    pedido.formaPago.toLowerCase().contains('multiple'))
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.purple,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pago mixto - Desglose por forma de pago no disponible en el resumen',
                            style: TextStyle(
                              color: Colors.purple,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumenFinalConsolidado() {
    final resumen = _resumen!.resumenFinal;
    final movimientos = _resumen!.movimientosEfectivo;
    final ventas = _resumen!.resumenVentas;

    // ✅ ARREGLADO: Usar el total correcto de ventas desde resumenVentas (que se muestra correctamente arriba)
    final totalVentasCorrectas = ventas.totalVentas;

    // 🐛 DEBUG: Imprimir valores para entender las discrepancias
    print('🔍 DEBUGGING BALANCE FINAL:');
    print('  - resumen.totalVentas: \$${resumen.totalVentas}');
    print('  - ventas.totalVentas (CORRECTO): \$${ventas.totalVentas}');
    print('  - movimientos.ventasEfectivo: \$${movimientos.ventasEfectivo}');
    print(
      '  - movimientos.ventasTransferencia: \$${movimientos.ventasTransferencia}',
    );
    print(
      '  - movimientos.totalIngresosCaja: \$${movimientos.totalIngresosCaja}',
    );

    // Calcular balance final con datos corregidos
    final ingresosTotales =
        movimientos.fondoInicial +
        movimientos.totalIngresosCaja +
        totalVentasCorrectas; // ✅ CORREGIDO: Incluir fondo inicial
    final egresosTotales = resumen.totalGastos + resumen.totalCompras;
    final balanceFinal = ingresosTotales - egresosTotales;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Resumen Final Consolidado', Icons.analytics),
        _buildCard(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'BALANCE FINAL',
                      style: TextStyle(
                        color: primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 28),
                    Text(
                      formatCurrency(balanceFinal),
                      style: TextStyle(
                        color: balanceFinal >= 0 ? Colors.green : Colors.red,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              _buildInfoRow(
                'Fondo Inicial',
                formatCurrency(
                  movimientos.fondoInicial,
                ), // ✅ CORREGIDO: Usar movimientos
              ),
              Divider(color: textLight.withOpacity(0.3)),
              Text(
                'INGRESOS:',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildInfoRow(
                '+ Total Ventas',
                formatCurrency(totalVentasCorrectas),
                valueColor: Colors.green,
              ),
              // ✅ DESGLOSE: Mostrar desglose de ventas (usando datos correctos de resumenVentas)
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: Column(
                  children: [
                    _buildInfoRow(
                      '  • Efectivo',
                      formatCurrency(
                        ventas.ventasPorFormaPago['efectivo'] ?? 0,
                      ),
                      valueColor: Colors.green.withOpacity(0.8),
                    ),
                    _buildInfoRow(
                      '  • Transferencia',
                      formatCurrency(
                        ventas.ventasPorFormaPago['transferencia'] ?? 0,
                      ),
                      valueColor: Colors.green.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
              _buildInfoRow(
                '+ Ingresos de Caja',
                formatCurrency(movimientos.totalIngresosCaja),
                valueColor: Colors.green,
              ),
              _buildInfoRow(
                '= Subtotal Ingresos',
                formatCurrency(ingresosTotales),
                valueColor: Colors.green,
              ),
              Divider(color: textLight.withOpacity(0.3)),
              Text(
                'EGRESOS:',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildInfoRow(
                '- Total Gastos',
                formatCurrency(resumen.totalGastos),
                valueColor: Colors.red,
              ),
              _buildInfoRow(
                '- Total Compras',
                formatCurrency(resumen.totalCompras),
                valueColor: Colors.red,
              ),
              _buildInfoRow(
                '= Subtotal Egresos',
                formatCurrency(egresosTotales),
                valueColor: Colors.red,
              ),
              Divider(color: textLight.withOpacity(0.3)),
              _buildInfoRow(
                'Efectivo Esperado en Caja',
                formatCurrency(resumen.efectivoEsperado),
                valueColor: primary,
              ),
              _buildInfoRow(
                'Utilidad Bruta',
                formatCurrency(resumen.utilidadBruta),
                valueColor: resumen.utilidadBruta >= 0
                    ? Colors.green
                    : Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
