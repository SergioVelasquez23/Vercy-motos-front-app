import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class PDFService {
  // Cache de fuentes para evitar cargas repetidas
  pw.Font? _fontRegular;
  pw.Font? _fontBold;

  /// Cargar fuentes de manera segura para web y móvil
  Future<pw.Font> _getFontRegular() async {
    if (_fontRegular != null) return _fontRegular!;

    try {
      // Usar fuente predeterminada de PDF que funciona en todas las plataformas
      _fontRegular = pw.Font.helvetica();
      return _fontRegular!;
    } catch (e) {
      print('⚠️ Error cargando fuente regular, usando fallback: $e');
      return pw.Font.helvetica();
    }
  }

  Future<pw.Font> _getFontBold() async {
    if (_fontBold != null) return _fontBold!;

    try {
      _fontBold = pw.Font.helveticaBold();
      return _fontBold!;
    } catch (e) {
      print('⚠️ Error cargando fuente bold, usando fallback: $e');
      return pw.Font.helveticaBold();
    }
  }

  /// Generar PDF de resumen de pedido
  Future<Uint8List> generarResumenPedidoPDF({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) async {
    // Si es factura, usar el formato profesional
    if (esFactura) {
      return generarFacturaPOSPDF(resumen: resumen);
    }

    final pdf = pw.Document();

    // Usar fuentes seguras para web
    final font = await _getFontRegular();
    final fontBold = await _getFontBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Formato de ticket térmico
        margin: const pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado del restaurante
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      resumen['nombreRestaurante'] ?? 'SOPA Y CARBÓN',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      resumen['direccionRestaurante'] ??
                          'Dirección del restaurante',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.Text(
                      'Tel: ${resumen['telefonoRestaurante'] ?? 'Teléfono'}',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),
              pw.Divider(),

              // Información del documento
              pw.Text(
                esFactura ? 'FACTURA OFICIAL' : 'RESUMEN DE PEDIDO',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 8),

              // Detalles del pedido/factura
              _buildInfoSection(resumen, font, esFactura),

              pw.SizedBox(height: 16),
              pw.Divider(),

              // Productos
              pw.Text(
                'PRODUCTOS:',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 8),

              // Lista de productos
              ...(_buildProductosList(resumen, font)),

              pw.SizedBox(height: 16),
              pw.Divider(),

              // Totales
              _buildTotales(resumen, font, fontBold),

              pw.SizedBox(height: 16),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      '¡Gracias por su preferencia!',
                      style: pw.TextStyle(font: fontBold, fontSize: 12),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Fecha: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                      style: pw.TextStyle(font: font, fontSize: 8),
                    ),
                    pw.Text(
                      'Hora: ${DateTime.now().toLocal().toString().split(' ')[1].substring(0, 8)}',
                      style: pw.TextStyle(font: font, fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generar Factura POS profesional (formato carta)
  Future<Uint8List> generarFacturaPOSPDF({
    required Map<String, dynamic> resumen,
  }) async {
    final pdf = pw.Document();

    // Usar fuentes seguras para web
    final font = await _getFontRegular();
    final fontBold = await _getFontBold();

    // Colores
    const primaryColor = PdfColor.fromInt(0xFF2196F3);
    const headerBgColor = PdfColor.fromInt(0xFFF5F5F5);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ========== ENCABEZADO ==========
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo y datos del negocio
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          resumen['nombreNegocio'] ??
                              resumen['nombreRestaurante'] ??
                              'VERCY MOTOS',
                          style: pw.TextStyle(font: fontBold, fontSize: 18),
                        ),
                        if (resumen['nit'] != null &&
                            resumen['nit'].toString().isNotEmpty)
                          pw.Text(
                            'NIT: ${resumen['nit']}',
                            style: pw.TextStyle(font: font, fontSize: 10),
                          ),
                        pw.SizedBox(height: 8),
                        if (resumen['email'] != null &&
                            resumen['email'].toString().isNotEmpty)
                          pw.Text(
                            'CORREO: ${resumen['email']}',
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        pw.Text(
                          'TELÉFONO: ${resumen['telefonoRestaurante'] ?? ''}/ NO RESPONSABLE DE IVA',
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  // Fecha y hora
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      alignment: pw.Alignment.topRight,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Fecha y Hora de',
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                          pw.Text(
                            'Expedición',
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                          pw.Text(
                            '${resumen['fecha'] ?? ''} ${resumen['hora'] ?? ''}',
                            style: pw.TextStyle(font: fontBold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),

              // ========== DATOS DEL CLIENTE Y FACTURA ==========
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.5),
                ),
                child: pw.Row(
                  children: [
                    // Datos del cliente
                    pw.Expanded(
                      flex: 3,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Cliente: ${resumen['cliente'] ?? 'CONSUMIDOR FINAL'}',
                              style: pw.TextStyle(font: fontBold, fontSize: 10),
                            ),
                            pw.Text(
                              'ID: CC ${resumen['clienteNit'] ?? '222222222-2'}',
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                            pw.Text(
                              'Departamento: ${resumen['departamento'] ?? 'CALDAS'}',
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                            pw.Text(
                              'Ciudad: ${resumen['ciudad'] ?? 'MANIZALES'}',
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                            pw.Text(
                              'Teléfono:',
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                            pw.Text(
                              'Dirección:',
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                            pw.Text(
                              'Correo:',
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Datos de la factura
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            left: pw.BorderSide(
                              color: PdfColors.black,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: pw.Column(
                          children: [
                            // Tipo de factura
                            pw.Container(
                              color: headerBgColor,
                              padding: const pw.EdgeInsets.all(4),
                              width: double.infinity,
                              child: pw.Text(
                                'FACTURA POS',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 10,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                resumen['numero'] ?? resumen['pedidoId'] ?? '',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 11,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            // Fechas
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  child: pw.Container(
                                    color: headerBgColor,
                                    padding: const pw.EdgeInsets.all(2),
                                    child: pw.Text(
                                      'FECHA\nFACTURA',
                                      style: pw.TextStyle(
                                        font: font,
                                        fontSize: 7,
                                      ),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Container(
                                    color: headerBgColor,
                                    padding: const pw.EdgeInsets.all(2),
                                    child: pw.Text(
                                      'FECHA\nVENCE',
                                      style: pw.TextStyle(
                                        font: font,
                                        fontSize: 7,
                                      ),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.all(2),
                                    child: pw.Text(
                                      resumen['fecha'] ?? '',
                                      style: pw.TextStyle(
                                        font: font,
                                        fontSize: 8,
                                      ),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.all(2),
                                    child: pw.Text(
                                      resumen['fechaVencimiento'] ??
                                          resumen['fecha'] ??
                                          '',
                                      style: pw.TextStyle(
                                        font: font,
                                        fontSize: 8,
                                      ),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Resolución DIAN
                            pw.Container(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                'RESOLUCIÓN DE AUTORIZACIÓN N. 1234 DEL 2024-12-31 CON PREFIJO POS DESDE 1 HASTA 100000 VIG. DE 60 MESES',
                                style: pw.TextStyle(font: font, fontSize: 6),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ========== TABLA DE PRODUCTOS ==========
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5), // ITEM
                  1: const pw.FlexColumnWidth(1.5), // CÓDIGO
                  2: const pw.FlexColumnWidth(0.5), // CANT
                  3: const pw.FlexColumnWidth(3), // DETALLE
                  4: const pw.FlexColumnWidth(1), // V. UNIT
                  5: const pw.FlexColumnWidth(0.5), // DCTO
                  6: const pw.FlexColumnWidth(1), // V. UNI DCTO
                  7: const pw.FlexColumnWidth(0.5), // IVA
                  8: const pw.FlexColumnWidth(1), // VALOR IVA
                  9: const pw.FlexColumnWidth(1), // TOTAL SIN IVA
                },
                children: [
                  // Encabezado
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBgColor),
                    children: [
                      _buildTableHeader('ITEM', fontBold),
                      _buildTableHeader('CÓDIGO', fontBold),
                      _buildTableHeader('CANT', fontBold),
                      _buildTableHeader('DETALLE', fontBold),
                      _buildTableHeader('V. UNIT', fontBold),
                      _buildTableHeader('DCTO', fontBold),
                      _buildTableHeader('V. UNI DCTO', fontBold),
                      _buildTableHeader('IVA', fontBold),
                      _buildTableHeader('VALOR IVA', fontBold),
                      _buildTableHeader('TOTAL\nSIN IVA', fontBold),
                    ],
                  ),
                  // Productos
                  ..._buildProductosTable(resumen, font),
                ],
              ),

              pw.SizedBox(height: 12),

              // ========== RESUMEN Y TOTALES ==========
              _buildResumenYTotales(resumen, font, fontBold),

              pw.SizedBox(height: 8),

              // ========== VALOR EN LETRAS ==========
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.5),
                ),
                padding: const pw.EdgeInsets.all(4),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'VALOR EN LETRAS: ',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                    ),
                    pw.Text(
                      _numeroALetras((resumen['total'] ?? 0.0).toDouble()),
                      style: pw.TextStyle(font: font, fontSize: 9),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ========== OBSERVACIONES ==========
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.5),
                ),
                padding: const pw.EdgeInsets.all(8),
                width: double.infinity,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'OBSERVACIONES:',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Este documento se asimila en todos sus efectos legales a una letra de cambio (Artículo 774 del Código de Comercio)',
                      style: pw.TextStyle(font: font, fontSize: 8),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ========== PIE DE PÁGINA ==========
              pw.Center(
                child: pw.Text(
                  'Elaborado por: APLICACIONES DE INGENIERÍA INFORMÁTICA S.A.S. NIT: 901.498.756, software Contoda ® www.contoda.com.co',
                  style: pw.TextStyle(font: font, fontSize: 7),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildTableHeader(String text, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: fontBold, fontSize: 7),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  List<pw.TableRow> _buildProductosTable(
    Map<String, dynamic> resumen,
    pw.Font font,
  ) {
    final productos = resumen['productos'] ?? [];
    if (productos is! List) return [];

    List<pw.TableRow> rows = [];
    int itemNum = 1;

    for (var producto in productos) {
      final cantidad = producto['cantidad'] ?? 1;
      final codigo = producto['codigo'] ?? producto['productoId'] ?? '';
      final nombre = producto['nombre'] ?? producto['producto'] ?? 'Producto';
      final precioUnit =
          (producto['precio'] ?? producto['precioUnitario'] ?? 0.0);
      final descuento = producto['descuento'] ?? 0;
      final iva = producto['iva'] ?? 0;
      final valorIva = (precioUnit * cantidad * iva / 100);
      final totalSinIva = (precioUnit * cantidad) - descuento;

      rows.add(
        pw.TableRow(
          children: [
            _buildTableCell('$itemNum', font),
            _buildTableCell(codigo.toString(), font),
            _buildTableCell('$cantidad', font),
            _buildTableCell(nombre, font, align: pw.TextAlign.left),
            _buildTableCell(_formatearNumero(precioUnit), font),
            _buildTableCell('$descuento%', font),
            _buildTableCell('$descuento', font),
            _buildTableCell('$iva%', font),
            _buildTableCell(_formatearNumero(valorIva), font),
            _buildTableCell(_formatearNumero(totalSinIva), font),
          ],
        ),
      );
      itemNum++;
    }

    return rows;
  }

  pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildResumenYTotales(
    Map<String, dynamic> resumen,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final productos = resumen['productos'] ?? [];
    final cantidadArticulos =
        resumen['cantidadArticulos'] ??
        (productos is List
            ? productos.fold(0, (sum, p) => sum + ((p['cantidad'] ?? 1) as int))
            : 0);
    final cantidadProductos =
        resumen['cantidadProductos'] ??
        (productos is List ? productos.length : 0);
    final vendedor = resumen['vendedor'] ?? resumen['mesero'] ?? 'Sin Vendedor';
    final subtotal = resumen['subtotal'] ?? resumen['totalSinIva'] ?? 0.0;
    final descuento = resumen['descuento'] ?? 0.0;
    final total = resumen['total'] ?? resumen['totalFactura'] ?? 0.0;
    final formaPago = resumen['formaPago'] ?? 'Efectivo';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Info de artículos y detalle de IVA
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'NO. ARTÍCULOS: $cantidadArticulos PRODUCTOS: $cantidadProductos VENDEDOR: $vendedor TIPO: CONTADO TOTAL: ${_formatearNumero(total)}',
                style: pw.TextStyle(font: fontBold, fontSize: 8),
              ),
              pw.SizedBox(height: 4),
              // Tabla de IVA
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF5F5F5),
                    ),
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'DETALLE DE IVA',
                          style: pw.TextStyle(font: fontBold, fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(),
                      pw.Container(),
                      pw.Container(),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF5F5F5),
                    ),
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'TIPO',
                          style: pw.TextStyle(font: fontBold, fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          '%IVA',
                          style: pw.TextStyle(font: fontBold, fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'BASE/IMP',
                          style: pw.TextStyle(font: fontBold, fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'IVA',
                          style: pw.TextStyle(font: fontBold, fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'TOTAL',
                          style: pw.TextStyle(font: fontBold, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          '0',
                          style: pw.TextStyle(font: font, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          '0',
                          style: pw.TextStyle(font: font, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          '0',
                          style: pw.TextStyle(font: font, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        // Forma de pago
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: pw.Column(
              children: [
                pw.Container(
                  color: const PdfColor.fromInt(0xFFF5F5F5),
                  padding: const pw.EdgeInsets.all(2),
                  width: double.infinity,
                  child: pw.Text(
                    'FORMA DE PAGO',
                    style: pw.TextStyle(font: fontBold, fontSize: 7),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text(
                    formaPago,
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text(
                    _formatearNumero(total),
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ),
                pw.Container(
                  color: const PdfColor.fromInt(0xFFF5F5F5),
                  padding: const pw.EdgeInsets.all(2),
                  width: double.infinity,
                  child: pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(font: fontBold, fontSize: 7),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text(
                    _formatearNumero(total),
                    style: pw.TextStyle(font: fontBold, fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        // Totales
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: pw.Column(
              children: [
                _buildTotalRow(
                  'SUBTOTAL',
                  _formatearMoneda(subtotal),
                  font,
                  fontBold,
                ),
                _buildTotalRow(
                  'DCTO. GENERAL',
                  _formatearMoneda(descuento),
                  font,
                  fontBold,
                ),
                pw.Container(
                  color: const PdfColor.fromInt(0xFFF5F5F5),
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL',
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
                      ),
                      pw.Text(
                        _formatearMoneda(total),
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
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

  pw.Widget _buildTotalRow(
    String label,
    String valor,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8)),
          pw.Text(valor, style: pw.TextStyle(font: font, fontSize: 8)),
        ],
      ),
    );
  }

  String _formatearNumero(dynamic numero) {
    if (numero == null) return '0';
    final valor = numero is double
        ? numero
        : (numero is int
              ? numero.toDouble()
              : double.tryParse(numero.toString()) ?? 0.0);
    return valor
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  String _formatearMoneda(dynamic numero) {
    return '\$${_formatearNumero(numero)}';
  }

  String _numeroALetras(double numero) {
    final unidades = [
      '',
      'UN',
      'DOS',
      'TRES',
      'CUATRO',
      'CINCO',
      'SEIS',
      'SIETE',
      'OCHO',
      'NUEVE',
    ];
    final decenas = [
      '',
      'DIEZ',
      'VEINTE',
      'TREINTA',
      'CUARENTA',
      'CINCUENTA',
      'SESENTA',
      'SETENTA',
      'OCHENTA',
      'NOVENTA',
    ];
    final especiales = [
      'DIEZ',
      'ONCE',
      'DOCE',
      'TRECE',
      'CATORCE',
      'QUINCE',
      'DIECISÉIS',
      'DIECISIETE',
      'DIECIOCHO',
      'DIECINUEVE',
    ];
    final centenas = [
      '',
      'CIENTO',
      'DOSCIENTOS',
      'TRESCIENTOS',
      'CUATROCIENTOS',
      'QUINIENTOS',
      'SEISCIENTOS',
      'SETECIENTOS',
      'OCHOCIENTOS',
      'NOVECIENTOS',
    ];

    int n = numero.toInt();
    if (n == 0) return 'CERO PESOS';
    if (n == 100) return 'CIEN PESOS';
    if (n == 1000) return 'MIL PESOS';

    String resultado = '';

    // Miles
    if (n >= 1000) {
      int miles = n ~/ 1000;
      if (miles == 1) {
        resultado += 'MIL ';
      } else if (miles < 10) {
        resultado += '${unidades[miles]} MIL ';
      } else if (miles < 100) {
        int dec = miles ~/ 10;
        int uni = miles % 10;
        if (miles >= 10 && miles <= 19) {
          resultado += '${especiales[miles - 10]} MIL ';
        } else if (uni == 0) {
          resultado += '${decenas[dec]} MIL ';
        } else {
          resultado += '${decenas[dec]} Y ${unidades[uni]} MIL ';
        }
      }
      n = n % 1000;
    }

    // Centenas
    if (n >= 100) {
      int cen = n ~/ 100;
      resultado += '${centenas[cen]} ';
      n = n % 100;
    }

    // Decenas y unidades
    if (n >= 10 && n <= 19) {
      resultado += especiales[n - 10];
    } else if (n >= 10) {
      int dec = n ~/ 10;
      int uni = n % 10;
      if (uni == 0) {
        resultado += decenas[dec];
      } else {
        resultado += '${decenas[dec]} Y ${unidades[uni]}';
      }
    } else if (n > 0) {
      resultado += unidades[n];
    }

    return '${resultado.trim()} PESOS';
  }

  /// Construir sección de información
  pw.Widget _buildInfoSection(
    Map<String, dynamic> resumen,
    pw.Font font,
    bool esFactura,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${esFactura ? 'Factura' : 'Pedido'}: ${resumen['pedidoId'] ?? resumen['numero'] ?? 'N/A'}',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
        if (resumen['fecha'] != null)
          pw.Text(
            'Fecha: ${resumen['fecha']}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        if (resumen['hora'] != null)
          pw.Text(
            'Hora: ${resumen['hora']}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        if (resumen['mesa'] != null)
          pw.Text(
            'Mesa: ${resumen['mesa']}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        if (resumen['mesero'] != null)
          pw.Text(
            'Mesero: ${resumen['mesero']}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        if (resumen['cliente'] != null)
          pw.Text(
            'Cliente: ${resumen['cliente']}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        if (resumen['medioPago'] != null)
          pw.Text(
            'Medio de pago: ${resumen['medioPago']}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
      ],
    );
  }

  /// Construir lista de productos
  List<pw.Widget> _buildProductosList(
    Map<String, dynamic> resumen,
    pw.Font font,
  ) {
    final productos = resumen['productos'] ?? resumen['detalleProductos'] ?? [];

    if (productos is! List) {
      return [
        pw.Text(
          'No hay productos',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
      ];
    }

    return productos.map<pw.Widget>((producto) {
      final cantidad = producto['cantidad'] ?? 1;
      final nombre = producto['nombre'] ?? producto['producto'] ?? 'Producto';
      final precio = producto['precio'] ?? 0.0;
      final subtotal = (precio * cantidad);

      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${cantidad}x $nombre',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                  // Ingredientes si existen
                  if (producto['ingredientesRequeridos'] != null &&
                      (producto['ingredientesRequeridos'] as List).isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, top: 2),
                      child: pw.Text(
                        'Ingredientes: ${(producto['ingredientesRequeridos'] as List).map((i) => i['nombre'] ?? i).join(', ')}',
                        style: pw.TextStyle(font: font, fontSize: 8),
                      ),
                    ),
                  if (producto['observaciones'] != null &&
                      producto['observaciones'].toString().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, top: 2),
                      child: pw.Text(
                        'Obs: ${producto['observaciones']}',
                        style: pw.TextStyle(font: font, fontSize: 8),
                      ),
                    ),
                ],
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Text(
                '\$${subtotal.toStringAsFixed(0)}',
                style: pw.TextStyle(font: font, fontSize: 10),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Construir sección de totales
  pw.Widget _buildTotales(
    Map<String, dynamic> resumen,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final total = resumen['total'] ?? resumen['totalFactura'] ?? 0.0;
    final propina = resumen['propina'] ?? 0.0;
    final impuestos = resumen['impuestos'] ?? resumen['totalImp'] ?? 0.0;
    final base = resumen['base'] ?? (total - impuestos);

    return pw.Column(
      children: [
        if (base > 0 && impuestos > 0) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Base:', style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text(
                '\$${base.toStringAsFixed(0)}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Impuestos:',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.Text(
                '\$${impuestos.toStringAsFixed(0)}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ],
          ),
        ],
        if (propina > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Propina:',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.Text(
                '\$${propina.toStringAsFixed(0)}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ],
          ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'TOTAL:',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '\$${total.toStringAsFixed(0)}',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Mostrar diálogo de impresión nativo
  Future<void> mostrarDialogoImpresion({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) async {
    try {
      final pdfBytes = await generarResumenPedidoPDF(
        resumen: resumen,
        esFactura: esFactura,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name:
            '${esFactura ? 'Factura' : 'Resumen'}_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}',
        format: esFactura ? PdfPageFormat.letter : PdfPageFormat.roll80,
      );
    } catch (e) {
      print('❌ Error en mostrarDialogoImpresion: $e');
      rethrow;
    }
  }

  /// Compartir PDF
  Future<void> compartirPDF({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) async {
    try {
      final pdfBytes = await generarResumenPedidoPDF(
        resumen: resumen,
        esFactura: esFactura,
      );

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            '${esFactura ? 'Factura' : 'Resumen'}_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      print('❌ Error compartiendo PDF: $e');
      rethrow;
    }
  }

  /// Guardar PDF en el dispositivo
  Future<File> guardarPDF({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) async {
    try {
      final pdfBytes = await generarResumenPedidoPDF(
        resumen: resumen,
        esFactura: esFactura,
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${esFactura ? 'Factura' : 'Resumen'}_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfBytes);
      return file;
    } catch (e) {
      print('❌ Error guardando PDF: $e');
      rethrow;
    }
  }

  /// Imprimir directamente (sin mostrar diálogo)
  Future<void> imprimirDirectamente({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
    Printer? impresora,
  }) async {
    try {
      final pdfBytes = await generarResumenPedidoPDF(
        resumen: resumen,
        esFactura: esFactura,
      );

      if (impresora != null) {
        await Printing.directPrintPdf(
          printer: impresora,
          onLayout: (format) async => pdfBytes,
          name:
              '${esFactura ? 'Factura' : 'Resumen'}_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}',
          format: PdfPageFormat.roll80,
        );
      } else {
        // Si no hay impresora específica, mostrar el diálogo de selección
        await mostrarDialogoImpresion(resumen: resumen, esFactura: esFactura);
      }
    } catch (e) {
      print('❌ Error en impresión directa: $e');
      rethrow;
    }
  }

  /// Verificar si hay impresoras disponibles
  Future<List<Printer>> obtenerImpresorasDisponibles() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      print('❌ Error obteniendo impresoras: $e');
      return [];
    }
  }

  /// Vista previa del PDF
  /// Método para imprimir factura directamente
  Future<void> imprimirFactura(Map<String, dynamic> resumen) async {
    try {
      final pdfBytes = await generarFacturaPOSPDF(resumen: resumen);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name:
            'Factura_${resumen['numeroPedido'] ?? DateTime.now().millisecondsSinceEpoch}',
        format: PdfPageFormat.letter,
      );
    } catch (e) {
      print('❌ Error al imprimir factura: $e');
      rethrow;
    }
  }

  Future<void> mostrarVistaPrevia({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) async {
    try {
      final pdfBytes = await generarResumenPedidoPDF(
        resumen: resumen,
        esFactura: esFactura,
      );

      // En web, usar Printing.layoutPdf que abre el diálogo de impresión/PDF
      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name:
              '${esFactura ? 'Factura' : 'Resumen'}_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}',
          format: PdfPageFormat.letter,
        );
      } else {
        // En móvil/desktop, intentar guardar el archivo
        await _guardarYAbrirPDFWindows(pdfBytes, resumen, esFactura);
      }
    } catch (e) {
      print('❌ Error en vista previa: $e');
      // Si falla, intentar compartir el PDF como alternativa
      try {
        final pdfBytes = await generarResumenPedidoPDF(
          resumen: resumen,
          esFactura: esFactura,
        );
        print('✅ PDF generado correctamente (${pdfBytes.length} bytes)');
        
        // Intentar compartir como última opción
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename:
              '${esFactura ? 'Factura' : 'Resumen'}_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      } catch (e2) {
        print('❌ Error generando/compartiendo PDF: $e2');
        rethrow;
      }
    }
  }

  /// Método alternativo para Windows: guardar archivo y abrir con visor predeterminado
  Future<void> _guardarYAbrirPDFWindows(
    Uint8List pdfBytes,
    Map<String, dynamic> resumen,
    bool esFactura,
  ) async {
    try {
      // Obtener directorio de documentos
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${esFactura ? 'Factura' : 'Resumen'}_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      // Escribir el archivo
      await file.writeAsBytes(pdfBytes);

      print('✅ PDF guardado en: ${file.path}');
      print('INFO: Abrir manualmente el archivo desde: ${file.path}');
    } catch (e) {
      print('❌ Error guardando PDF: $e');
      rethrow;
    }
  }
}
