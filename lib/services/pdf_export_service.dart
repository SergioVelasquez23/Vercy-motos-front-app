import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/resumen_cierre_completo.dart';
import 'package:universal_html/html.dart' as html;

class PdfExportService {
  /// Exporta el resumen de caja a PDF
  Future<void> exportarResumenCaja({
    required ResumenCierreCompleto resumen,
    required String nombreCuadre,
  }) async {
    // Inicializar el locale español
    await initializeDateFormatting('es_ES', null);

    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es_ES');
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
    );

    // Crear el documento PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Encabezado
          _buildHeader(nombreCuadre, resumen, dateFormat),
          pw.SizedBox(height: 20),

          // Resumen Final
          _buildSeccion(
            'RESUMEN FINAL',
            _buildResumenFinal(resumen, currencyFormat),
          ),
          pw.SizedBox(height: 20),

          // Ventas por Método de Pago
          _buildSeccion(
            'VENTAS POR MÉTODO DE PAGO',
            _buildVentasPorMetodo(resumen, currencyFormat),
          ),
          pw.SizedBox(height: 20),

          // Movimientos de Efectivo
          _buildSeccion(
            'MOVIMIENTOS DE EFECTIVO',
            _buildMovimientosEfectivo(resumen, currencyFormat),
          ),
          pw.SizedBox(height: 20),

          // Resumen de Ventas
          _buildSeccion(
            'RESUMEN DE VENTAS',
            _buildResumenVentas(resumen, currencyFormat),
          ),
          pw.SizedBox(height: 20),

          // Resumen de Gastos
          _buildSeccion(
            'RESUMEN DE GASTOS',
            _buildResumenGastos(resumen, currencyFormat),
          ),
          pw.SizedBox(height: 20),

          // Gastos Detallados
          if (resumen.resumenGastos.detallesGastos.isNotEmpty) ...[
            _buildSeccion(
              'GASTOS DETALLADOS',
              _buildGastos(resumen, currencyFormat, dateFormat),
            ),
            pw.SizedBox(height: 20),
          ],

          // Compras Detalladas
          if (resumen.resumenCompras.detallesComprasDesdeCaja.isNotEmpty) ...[
            _buildSeccion(
              'COMPRAS DETALLADAS',
              _buildCompras(resumen, currencyFormat, dateFormat),
            ),
            pw.SizedBox(height: 20),
          ],

          // Resumen Final Consolidado
          _buildSeccion(
            'RESUMEN FINAL CONSOLIDADO',
            _buildBalanceFinal(resumen, currencyFormat),
          ),
        ],
        footer: (context) => _buildFooter(context),
      ),
    );

    // Guardar o descargar el PDF
    final fileName = 'resumen_caja_${nombreCuadre.replaceAll(' ', '_')}.pdf';

    if (kIsWeb) {
      // En Web: descargar directamente
      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // En móvil: usar el diálogo de impresión/compartir
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: fileName,
      );
    }
  }

  /// Construye el encabezado del PDF
  pw.Widget _buildHeader(
    String nombreCuadre,
    ResumenCierreCompleto resumen,
    DateFormat dateFormat,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RESUMEN DE CAJA',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          nombreCuadre,
          style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Fecha apertura: ${resumen.cuadreInfo.fechaApertura}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
            if (resumen.cuadreInfo.fechaCierre != null)
              pw.Text(
                'Fecha cierre: ${resumen.cuadreInfo.fechaCierre}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
          ],
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Construye una sección con título y contenido
  pw.Widget _buildSeccion(String titulo, pw.Widget contenido) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titulo,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 10),
        contenido,
      ],
    );
  }

  /// Construye el resumen final
  pw.Widget _buildResumenFinal(
    ResumenCierreCompleto resumen,
    NumberFormat currencyFormat,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildRow(
                      'Fondo Inicial',
                      currencyFormat.format(resumen.cuadreInfo.fondoInicial),
                    ),
                    _buildRow(
                      'Efectivo Esperado',
                      currencyFormat.format(
                        resumen.movimientosEfectivo.efectivoEsperado,
                      ),
                    ),
                    _buildRow(
                      'Total Ventas',
                      currencyFormat.format(resumen.resumenVentas.totalVentas),
                    ),
                    _buildRow(
                      'Ventas Efectivo',
                      currencyFormat.format(
                        resumen.movimientosEfectivo.ventasEfectivo,
                      ),
                    ),
                    _buildRow(
                      'Total Gastos',
                      currencyFormat.format(resumen.resumenGastos.totalGastos),
                    ),
                    _buildRow(
                      'Gastos Efectivo',
                      currencyFormat.format(
                        resumen.movimientosEfectivo.gastosEfectivo,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildRow(
                      'Total Compras',
                      currencyFormat.format(
                        resumen.resumenCompras.totalComprasDesdeCaja,
                      ),
                    ),
                    _buildRow(
                      'Compras Efectivo',
                      currencyFormat.format(
                        resumen.movimientosEfectivo.comprasEfectivo,
                      ),
                    ),
                    _buildRow(
                      'Gastos Directos',
                      currencyFormat.format(resumen.gastosDirectos),
                    ),
                    _buildRow(
                      'Fact. desde Caja',
                      currencyFormat.format(resumen.facturasPagadasDesdeCaja),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.Divider(height: 20),
          _buildRow(
            'Utilidad Bruta',
            currencyFormat.format(resumen.utilidadBruta),
            bold: true,
            color: resumen.utilidadBruta >= 0 ? PdfColors.green : PdfColors.red,
          ),
        ],
      ),
    );
  }

  /// Construye las ventas por método de pago
  pw.Widget _buildVentasPorMetodo(
    ResumenCierreCompleto resumen,
    NumberFormat currencyFormat,
  ) {
    final ventas = resumen.resumenVentas.ventasPorFormaPago;

    return pw.Column(
      children: [
        ...ventas.entries.map(
          (entry) => _buildRow(
            entry.key.toUpperCase(),
            currencyFormat.format(entry.value),
          ),
        ),
        pw.Divider(),
        _buildRow(
          'TOTAL',
          currencyFormat.format(resumen.resumenVentas.totalVentas),
          bold: true,
        ),
      ],
    );
  }

  /// Construye los movimientos de efectivo
  pw.Widget _buildMovimientosEfectivo(
    ResumenCierreCompleto resumen,
    NumberFormat currencyFormat,
  ) {
    return pw.Column(
      children: [
        _buildRow(
          'Ventas Efectivo',
          currencyFormat.format(resumen.movimientosEfectivo.ventasEfectivo),
        ),
        _buildRow(
          'Ingresos Adicionales',
          currencyFormat.format(resumen.movimientosEfectivo.ingresosEfectivo),
        ),
        _buildRow(
          'Gastos',
          currencyFormat.format(resumen.resumenGastos.totalGastos),
        ),
        _buildRow(
          'Compras',
          currencyFormat.format(resumen.resumenCompras.totalComprasDesdeCaja),
        ),
      ],
    );
  }

  /// Construye la tabla de gastos
  pw.Widget _buildGastos(
    ResumenCierreCompleto resumen,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      children: [
        // Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('Descripción', bold: true),
            _buildTableCell('Monto', bold: true),
            _buildTableCell('Fecha', bold: true),
          ],
        ),
        // Filas de datos
        ...resumen.resumenGastos.detallesGastos.map(
          (gasto) => pw.TableRow(
            children: [
              _buildTableCell(
                gasto.concepto.isNotEmpty ? gasto.concepto : 'Sin descripción',
              ),
              _buildTableCell(currencyFormat.format(gasto.monto)),
              _buildTableCell(dateFormat.format(DateTime.parse(gasto.fecha))),
            ],
          ),
        ),
        // Total
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('TOTAL', bold: true),
            _buildTableCell(
              currencyFormat.format(resumen.resumenGastos.totalGastos),
              bold: true,
            ),
            _buildTableCell(''),
          ],
        ),
      ],
    );
  }

  /// Construye la tabla de compras
  pw.Widget _buildCompras(
    ResumenCierreCompleto resumen,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      children: [
        // Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('Descripción', bold: true),
            _buildTableCell('Monto', bold: true),
            _buildTableCell('Fecha', bold: true),
          ],
        ),
        // Filas de datos
        ...resumen.resumenCompras.detallesComprasDesdeCaja.map(
          (compra) => pw.TableRow(
            children: [
              _buildTableCell(
                compra.observaciones.isNotEmpty
                    ? compra.observaciones
                    : 'Factura ${compra.numero}',
              ),
              _buildTableCell(currencyFormat.format(compra.total)),
              _buildTableCell(dateFormat.format(DateTime.parse(compra.fecha))),
            ],
          ),
        ),
        // Total
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('TOTAL', bold: true),
            _buildTableCell(
              currencyFormat.format(
                resumen.resumenCompras.totalComprasDesdeCaja,
              ),
              bold: true,
            ),
            _buildTableCell(''),
          ],
        ),
      ],
    );
  }

  /// Construye el resumen de ventas
  pw.Widget _buildResumenVentas(
    ResumenCierreCompleto resumen,
    NumberFormat currencyFormat,
  ) {
    final ventas = resumen.resumenVentas;

    return pw.Column(
      children: [
        _buildRow('Total Pedidos', '${ventas.totalPedidos}'),
        _buildRow('Total Ventas', currencyFormat.format(ventas.totalVentas)),
        pw.SizedBox(height: 10),
        pw.Text(
          'Ventas por Forma de Pago:',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        ...ventas.ventasPorFormaPago.entries.map(
          (entry) =>
              _buildRow('  ${entry.key}', currencyFormat.format(entry.value)),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Cantidad por Forma de Pago:',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        ...ventas.cantidadPorFormaPago.entries.map(
          (entry) => _buildRow('  ${entry.key}', '${entry.value}'),
        ),
      ],
    );
  }

  /// Construye el resumen de gastos
  pw.Widget _buildResumenGastos(
    ResumenCierreCompleto resumen,
    NumberFormat currencyFormat,
  ) {
    final gastos = resumen.resumenGastos;

    return pw.Column(
      children: [
        _buildRow('Total Gastos', currencyFormat.format(gastos.totalGastos)),
        _buildRow('Total Registros', '${gastos.totalRegistros}'),
        _buildRow(
          'Gastos Desde Caja',
          currencyFormat.format(gastos.totalGastosDesdeCaja),
        ),
        _buildRow(
          'Fact. desde Caja',
          currencyFormat.format(gastos.facturasPagadasDesdeCaja),
        ),
        _buildRow(
          'Total (con facturas)',
          currencyFormat.format(gastos.totalGastosIncluyendoFacturas),
        ),
        if (gastos.gastosPorFormaPago.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text(
            'Gastos por Forma de Pago:',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          ...gastos.gastosPorFormaPago.entries.map(
            (entry) =>
                _buildRow('  ${entry.key}', currencyFormat.format(entry.value)),
          ),
        ],
      ],
    );
  }

  /// Construye el balance final consolidado
  pw.Widget _buildBalanceFinal(
    ResumenCierreCompleto resumen,
    NumberFormat currencyFormat,
  ) {
    final balanceFinal =
        resumen.cuadreInfo.fondoInicial +
        resumen.resumenVentas.totalVentas -
        resumen.resumenGastos.totalGastos -
        resumen.resumenCompras.totalComprasDesdeCaja;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          _buildRow(
            'BALANCE FINAL',
            currencyFormat.format(balanceFinal),
            bold: true,
            color: balanceFinal >= 0 ? PdfColors.green : PdfColors.red,
          ),
          pw.Divider(height: 20),
          pw.Text(
            'INGRESOS:',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green,
            ),
          ),
          pw.SizedBox(height: 10),
          _buildRow(
            'Fondo Inicial',
            currencyFormat.format(resumen.cuadreInfo.fondoInicial),
          ),
          _buildRow(
            '+ Total Ventas',
            currencyFormat.format(resumen.resumenVentas.totalVentas),
          ),
          _buildRow(
            '  • Efectivo',
            currencyFormat.format(resumen.movimientosEfectivo.ventasEfectivo),
          ),
          _buildRow(
            '  • Transferencia',
            currencyFormat.format(
              resumen.movimientosEfectivo.ventasTransferencia,
            ),
          ),
          _buildRow(
            '+ Ingresos de Caja',
            currencyFormat.format(resumen.movimientosEfectivo.ingresosEfectivo),
          ),
          pw.Divider(),
          _buildRow(
            '= Subtotal Ingresos',
            currencyFormat.format(
              resumen.cuadreInfo.fondoInicial +
                  resumen.resumenVentas.totalVentas +
                  resumen.movimientosEfectivo.ingresosEfectivo,
            ),
            bold: true,
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'EGRESOS:',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red,
            ),
          ),
          pw.SizedBox(height: 10),
          _buildRow(
            '- Total Gastos',
            currencyFormat.format(resumen.resumenGastos.totalGastos),
          ),
          _buildRow(
            '- Total Compras',
            currencyFormat.format(resumen.resumenCompras.totalComprasDesdeCaja),
          ),
          pw.Divider(),
          _buildRow(
            '= Subtotal Egresos',
            currencyFormat.format(
              resumen.resumenGastos.totalGastos +
                  resumen.resumenCompras.totalComprasDesdeCaja,
            ),
            bold: true,
          ),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 2),
          _buildRow(
            'Efectivo Esperado en Caja',
            currencyFormat.format(resumen.movimientosEfectivo.efectivoEsperado),
            bold: true,
          ),
          _buildRow(
            'Utilidad Bruta',
            currencyFormat.format(resumen.utilidadBruta),
            bold: true,
            color: resumen.utilidadBruta >= 0 ? PdfColors.green : PdfColors.red,
          ),
        ],
      ),
    );
  }

  /// Construye una fila de clave-valor
  pw.Widget _buildRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye una celda de tabla
  pw.Widget _buildTableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Construye el pie de página
  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }
}
