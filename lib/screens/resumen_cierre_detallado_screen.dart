import 'package:flutter/material.dart';
import '../models/resumen_cierre_completo.dart';
import '../services/resumen_cierre_completo_service.dart';
import '../utils/format_utils.dart';
import '../theme/app_theme.dart';

class ResumenCierreDetalladoScreen extends StatefulWidget {
  final String cuadreId;
  final String nombreCuadre;

  const ResumenCierreDetalladoScreen({
    super.key,
    required this.cuadreId,
    required this.nombreCuadre,
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

  ResumenCierreCompleto? _resumen;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadResumenDetallado();
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
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCuadreInfo(),
          SizedBox(height: 20),
          _buildResumenFinal(),
          SizedBox(height: 20),
          _buildMovimientosEfectivo(),
          SizedBox(height: 20),
          _buildIngresosCaja(),
          SizedBox(height: 20),
          _buildResumenVentas(),
          SizedBox(height: 20),
          _buildDetallesPedidos(),
          SizedBox(height: 20),
          _buildResumenCompras(),
          SizedBox(height: 20),
          _buildResumenGastos(),
          SizedBox(height: 20),
          _buildResumenFinalConsolidado(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: textDark,
              fontSize: 18,
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textLight, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? textDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
            children: [
              _buildInfoRow('Nombre', info.nombre),
              _buildInfoRow('Responsable', info.responsable),
              _buildInfoRow(
                'Estado',
                info.estado,
                valueColor: info.estado == 'pendiente'
                    ? Colors.orange
                    : Colors.green,
              ),
              _buildInfoRow('Fecha Apertura', _formatDate(info.fechaApertura)),
              if (info.fechaCierre != null)
                _buildInfoRow('Fecha Cierre', _formatDate(info.fechaCierre!)),
              _buildInfoRow('Fondo Inicial', formatCurrency(info.fondoInicial)),
              if (info.fondoInicialDesglosado.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Desglose Fondo Inicial:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ...info.fondoInicialDesglosado.entries.map(
                  (entry) => _buildInfoRow(
                    '  ${entry.key}',
                    formatCurrency(entry.value),
                  ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Resumen Final', Icons.assessment),
        _buildCard(
          child: Column(
            children: [
              _buildInfoRow(
                'Fondo Inicial',
                formatCurrency(resumen.fondoInicial),
              ),
              _buildInfoRow(
                'Efectivo Esperado',
                formatCurrency(resumen.efectivoEsperado),
              ),
              _buildInfoRow(
                'Total Ventas',
                formatCurrency(resumen.totalVentas),
              ),
              _buildInfoRow(
                'Ventas en Efectivo',
                formatCurrency(resumen.ventasEfectivo),
              ),
              _buildInfoRow(
                'Total Gastos',
                formatCurrency(resumen.totalGastos),
              ),
              _buildInfoRow(
                'Gastos en Efectivo',
                formatCurrency(resumen.gastosEfectivo),
              ),
              _buildInfoRow(
                'Gastos Directos',
                formatCurrency(resumen.gastosDirectos),
              ),
              _buildInfoRow(
                'Total Compras',
                formatCurrency(resumen.totalCompras),
              ),
              _buildInfoRow(
                'Compras en Efectivo',
                formatCurrency(resumen.comprasEfectivo),
              ),
              _buildInfoRow(
                'Facturas Pagadas desde Caja',
                formatCurrency(resumen.facturasPagadasDesdeCaja),
              ),
              Divider(color: textLight.withOpacity(0.3)),
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
            children: [
              _buildInfoRow(
                'Fondo Inicial',
                formatCurrency(movimientos.fondoInicial),
              ),
              _buildInfoRow(
                'Efectivo Esperado',
                formatCurrency(movimientos.efectivoEsperado),
              ),
              _buildInfoRow(
                'Total Ingresos Caja',
                formatCurrency(movimientos.totalIngresosCaja),
              ),
              SizedBox(height: 8),
              Text(
                'Ingresos:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.w500),
              ),
              _buildInfoRow(
                '  Efectivo',
                formatCurrency(movimientos.ingresosEfectivo),
              ),
              _buildInfoRow(
                '  Transferencia',
                formatCurrency(movimientos.ingresosTransferencia),
              ),
              SizedBox(height: 8),
              Text(
                'Ventas:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.w500),
              ),
              _buildInfoRow(
                '  Efectivo',
                formatCurrency(movimientos.ventasEfectivo),
              ),
              _buildInfoRow(
                '  Transferencia',
                formatCurrency(movimientos.ventasTransferencia),
              ),
              SizedBox(height: 8),
              Text(
                'Gastos:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.w500),
              ),
              _buildInfoRow(
                '  Efectivo',
                formatCurrency(movimientos.gastosEfectivo),
              ),
              _buildInfoRow(
                '  Transferencia',
                formatCurrency(movimientos.gastosTransferencia),
              ),
              SizedBox(height: 8),
              Text(
                'Compras:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.w500),
              ),
              _buildInfoRow(
                '  Efectivo',
                formatCurrency(movimientos.comprasEfectivo),
              ),
              _buildInfoRow(
                '  Transferencia',
                formatCurrency(movimientos.comprasTransferencia),
              ),
              Divider(color: textLight.withOpacity(0.3)),
              _buildInfoRow(
                'Transferencia Esperada',
                formatCurrency(movimientos.transferenciaEsperada),
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
            children: [
              _buildInfoRow('Total Pedidos', ventas.totalPedidos.toString()),
              _buildInfoRow('Total Ventas', formatCurrency(ventas.totalVentas)),
              if (ventas.ventasPorFormaPago.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Ventas por Forma de Pago:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ...ventas.ventasPorFormaPago.entries.map(
                  (entry) => _buildInfoRow(
                    '  ${entry.key}',
                    formatCurrency(entry.value),
                  ),
                ),
              ],
              if (ventas.cantidadPorFormaPago.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Cantidad por Forma de Pago:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ...ventas.cantidadPorFormaPago.entries.map(
                  (entry) =>
                      _buildInfoRow('  ${entry.key}', entry.value.toString()),
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
              _buildInfoRow(
                'Total Facturas Generales',
                compras.totalFacturasGenerales.toString(),
              ),
              SizedBox(height: 8),
              Text(
                'Compras desde Caja:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.w500),
              ),
              _buildInfoRow(
                '  Total',
                formatCurrency(compras.totalComprasDesdeCaja),
              ),
              _buildInfoRow(
                '  Facturas',
                compras.totalFacturasDesdeCaja.toString(),
              ),
              SizedBox(height: 8),
              Text(
                'Compras NO desde Caja:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.w500),
              ),
              _buildInfoRow(
                '  Total',
                formatCurrency(compras.totalComprasNoDesdeCaja),
              ),
              _buildInfoRow(
                '  Facturas',
                compras.totalFacturasNoDesdeCaja.toString(),
              ),
              if (compras.comprasPorFormaPago.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Compras por Forma de Pago:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ...compras.comprasPorFormaPago.entries.map(
                  (entry) => _buildInfoRow(
                    '  ${entry.key}',
                    formatCurrency(entry.value),
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
            children: [
              _buildInfoRow('Total Gastos', formatCurrency(gastos.totalGastos)),
              _buildInfoRow(
                'Total Registros',
                gastos.totalRegistros.toString(),
              ),
              _buildInfoRow(
                'Total Gastos (incluyendo facturas)',
                formatCurrency(gastos.totalGastosIncluyendoFacturas),
              ),
              _buildInfoRow(
                'Total Gastos desde Caja',
                formatCurrency(gastos.totalGastosDesdeCaja),
              ),
              _buildInfoRow(
                'Facturas Pagadas desde Caja',
                formatCurrency(gastos.facturasPagadasDesdeCaja),
              ),
              if (gastos.gastosPorTipo.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Gastos por Tipo:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ...gastos.gastosPorTipo.entries.map(
                  (entry) => _buildInfoRow(
                    '  ${entry.key}',
                    formatCurrency(entry.value),
                  ),
                ),
              ],
              if (gastos.gastosPorFormaPago.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Gastos por Forma de Pago:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ...gastos.gastosPorFormaPago.entries.map(
                  (entry) => _buildInfoRow(
                    '  ${entry.key}',
                    formatCurrency(entry.value),
                  ),
                ),
              ],
              if (gastos.cantidadPorTipo.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Cantidad por Tipo:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ...gastos.cantidadPorTipo.entries.map(
                  (entry) =>
                      _buildInfoRow('  ${entry.key}', entry.value.toString()),
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
            children: [
              _buildInfoRow(
                'Total Ingresos',
                formatCurrency(movimientos.totalIngresosCaja),
                valueColor: Colors.green,
              ),
              _buildInfoRow(
                'Ingresos en Efectivo',
                formatCurrency(movimientos.ingresosEfectivo),
              ),
              _buildInfoRow(
                'Ingresos por Transferencia',
                formatCurrency(movimientos.ingresosTransferencia),
              ),
              if (movimientos.ingresosPorFormaPago.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Ingresos por Forma de Pago:',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ...movimientos.ingresosPorFormaPago.entries.map(
                  (entry) => _buildInfoRow(
                    '  ${entry.key}',
                    formatCurrency(entry.value),
                    valueColor: Colors.green,
                  ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mesa: ${pedido.mesa}',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatCurrency(pedido.total),
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Tipo: ${pedido.tipo}',
                  style: TextStyle(color: textLight, fontSize: 12),
                ),
                Text(
                  'Forma de Pago: ${pedido.formaPago}',
                  style: TextStyle(color: textLight, fontSize: 12),
                ),
                Text(
                  'Fecha: ${_formatDate(pedido.fecha)}',
                  style: TextStyle(color: textLight, fontSize: 12),
                ),
                Text(
                  'ID: ${pedido.id}',
                  style: TextStyle(color: textLight, fontSize: 10),
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

    // Calcular balance final
    final ingresosTotales = movimientos.totalIngresosCaja + resumen.totalVentas;
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
                    SizedBox(height: 8),
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
                formatCurrency(resumen.fondoInicial),
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
                formatCurrency(resumen.totalVentas),
                valueColor: Colors.green,
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
