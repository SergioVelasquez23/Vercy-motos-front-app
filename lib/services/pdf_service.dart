import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'pdf_download_helper.dart';
import '../utils/logger.dart';

class PDFService {
  // Cache de fuentes para evitar cargas repetidas
  pw.Font? _fontRegular;
  pw.Font? _fontBold;

  /// Convertir cualquier valor a String de forma segura
  String _toSafeString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    if (value is String) {
      if (value.trim().isEmpty) return defaultValue;
      return _sanitizeText(value);
    }
    if (value is DateTime) {
      return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    }
    if (value is num) return value.toString();
    return _sanitizeText(value.toString());
  }

  /// Sanitizar texto para PDF eliminando caracteres problemáticos
  String _sanitizeText(String? text) {
    if (text == null || text.isEmpty) return '';

    // Reemplazar caracteres especiales que causan problemas
    return text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N')
        .replaceAll('¿', '')
        .replaceAll('¡', '')
        // Eliminar otros caracteres no ASCII
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  /// Cargar fuentes de manera segura para web y móvil
  Future<pw.Font> _getFontRegular() async {
    if (_fontRegular != null) return _fontRegular!;

    try {
      // Usar fuente predeterminada de PDF que funciona en todas las plataformas
      _fontRegular = pw.Font.helvetica();
      return _fontRegular!;
    } catch (e) {
      return pw.Font.helvetica();
    }
  }

  Future<pw.Font> _getFontBold() async {
    if (_fontBold != null) return _fontBold!;

    try {
      _fontBold = pw.Font.helveticaBold();
      return _fontBold!;
    } catch (e) {
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

    // Pre-procesar valores
    final nombreRestaurante = _toSafeString(
      resumen['nombreRestaurante'],
      'SOPA Y CARBON',
    );
    final direccionRestaurante = _toSafeString(
      resumen['direccionRestaurante'],
      'Direccion del restaurante',
    );
    final telefonoRestaurante = _toSafeString(
      resumen['telefonoRestaurante'],
      'Telefono',
    );

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
                      nombreRestaurante,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      direccionRestaurante,
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.Text(
                      'Tel: $telefonoRestaurante',
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

    // Cargar logo con manejo de errores
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/vercylogo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      appLog('✅ Logo cargado exitosamente');
    } catch (e) {
      appLog('⚠️ Error cargando logo: $e');
      logoImage = null;
    }

    // Pre-procesar todos los valores del resumen para evitar errores
    // Obtener datos del negocio (pueden venir directamente o en objeto 'negocio')
    final negocio = resumen['negocio'] as Map<String, dynamic>?;
    final nombreNegocio = _toSafeString(
      resumen['nombreNegocio'] ??
          resumen['nombreRestaurante'] ??
          negocio?['nombre'],
      'VERCY MOTOS',
    );
    final nit = _toSafeString(
      resumen['nit'] ?? negocio?['nit'],
    );
    final email = _toSafeString(
      resumen['email'] ?? negocio?['email'],
    );
    final telefono = _toSafeString(
      resumen['telefonoRestaurante'] ?? negocio?['telefono'],
    );
    final direccion = _toSafeString(
      resumen['direccionRestaurante'] ?? negocio?['direccion'],
    );
    final responsableIva =
        resumen['responsableIva'] ?? negocio?['responsableIva'] ?? true;
    final fecha = _toSafeString(resumen['fecha']);
    final hora = _toSafeString(resumen['hora']);
    final cliente = _toSafeString(resumen['cliente'], 'CONSUMIDOR FINAL');
    final clienteNit = _toSafeString(resumen['clienteNit'], '222222222-2');
    final clienteTipoId = _toSafeString(resumen['clienteTipoId'], 'CC');
    final clienteDireccion = _toSafeString(resumen['clienteDireccion']);
    final clienteTelefono = _toSafeString(resumen['clienteTelefono']);
    final clienteCorreo = _toSafeString(resumen['clienteCorreo']);
    final clienteDepartamento = _toSafeString(resumen['clienteDepartamento']);
    final clienteCiudad = _toSafeString(resumen['clienteCiudad']);

    // Debug: Verificar datos del cliente
    appLog('📋 Datos del cliente en PDF:');
    appLog('  - Nombre: $cliente');
    appLog('  - NIT: $clienteNit');
    appLog('  - Dirección: $clienteDireccion');
    appLog('  - Teléfono: $clienteTelefono');
    appLog('  - Correo: $clienteCorreo');
    appLog('  - Departamento: $clienteDepartamento');
    appLog('  - Ciudad: $clienteCiudad');

    final departamento = _toSafeString(
      resumen['departamento'] ?? negocio?['departamento'],
      'CALDAS',
    );
    final ciudad = _toSafeString(
      resumen['ciudad'] ?? negocio?['ciudad'],
      'MANIZALES',
    );
    final numeroPedido = _toSafeString(
      resumen['numeroCotizacion'] ?? resumen['numeroPedido'] ?? resumen['numero'],
    );
    final tipoDocumento = _toSafeString(resumen['tipoDocumento'], 'ORDEN DE VENTA');
    final metodoPago = _toSafeString(
      resumen['metodoPago'] ?? resumen['formaPago'],
      'EFECTIVO',
    );

    // Colores
    const primaryColor = PdfColor.fromInt(0xFF2196F3);
    const headerBgColor = PdfColor.fromInt(0xFFF5F5F5);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
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
                      if (logoImage != null)
                        pw.Image(
                          logoImage,
                          width: 120,
                          height: 60,
                          fit: pw.BoxFit.contain,
                        )
                      else
                        pw.Text(
                          nombreNegocio,
                          style: pw.TextStyle(font: fontBold, fontSize: 18),
                        ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'REGIMEN SIMPLE TRIBUTACION',
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
                      ),
                      pw.Text(
                        'NIT: $nit',
                        style: pw.TextStyle(font: font, fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Correo: $email',
                        style: pw.TextStyle(font: font, fontSize: 9),
                      ),
                      pw.Text(
                        'Telefono: $telefono',
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
                          'Expedicion',
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                        pw.Text(
                          '$fecha $hora',
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
                            'Cliente: $cliente',
                            style: pw.TextStyle(font: fontBold, fontSize: 10),
                          ),
                          pw.Text(
                            'ID: $clienteNit',
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                          pw.Text(
                            'Departamento: ${clienteDepartamento.isNotEmpty ? clienteDepartamento : departamento}',
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                          pw.Text(
                            'Ciudad: ${clienteCiudad.isNotEmpty ? clienteCiudad : ciudad}',
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                          if (clienteTelefono.isNotEmpty)
                            pw.Text(
                              'Telefono: $clienteTelefono',
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                          if (clienteDireccion.isNotEmpty)
                            pw.Text(
                              'Direccion: $clienteDireccion',
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                          if (clienteCorreo.isNotEmpty)
                            pw.Text(
                              'Correo: $clienteCorreo',
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
                              tipoDocumento,
                              style: pw.TextStyle(font: fontBold, fontSize: 10),
                             textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              numeroPedido,
                              style: pw.TextStyle(font: fontBold, fontSize: 11),
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
                                    fecha,
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
                                    _toSafeString(
                                      resumen['fechaVencimiento'],
                                      fecha,
                                    ),
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
                10: const pw.FlexColumnWidth(1), // TOTAL CON IVA
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
                    _buildTableHeader('TOTAL\nCON IVA', fontBold),
                  ],
                ),
                // Productos - se agregan dinámicamente basado en la cantidad
                ..._buildProductosTable(resumen, font),
              ],
            ),

            pw.SizedBox(height: 12),

            // ========== OBSERVACIONES (debajo de productos) ==========
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.5),
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'OBSERVACIONES:',
                    style: pw.TextStyle(font: fontBold, fontSize: 9),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _toSafeString(
                      resumen['observaciones'],
                      'Este documento se asimila en todos sus efectos legales a una letra de cambio (Articulo 774 del Codigo de Comercio)',
                    ),
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 8),

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
                  pw.Expanded(
                    child: pw.Text(
                      _numeroALetras((resumen['total'] ?? 0.0).toDouble()),
                      style: pw.TextStyle(font: font, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // ========== PIE DE PÁGINA ==========
            pw.Center(
              child: pw.Text(
                'Gracias por su compra - $nombreNegocio',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
            ),
          ];
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
    final productos = resumen['productos'] ?? resumen['items'] ?? [];
    if (productos is! List) return [];

    List<pw.TableRow> rows = [];
    int itemNum = 1;

    for (var producto in productos) {
      final cantidad = producto['cantidad'] ?? 1;
      final codigo = _toSafeString(
        producto['codigo'] ?? producto['productoId'],
      );
      final nombre = _toSafeString(
        producto['productoNombre'] ??
            producto['nombre'] ??
            producto['producto'],
        'Producto',
      );
      final precioUnit =
          (producto['precioUnitario'] ?? producto['precio'] ?? 0.0);
      final porcentajeDescuento =
          producto['porcentajeDescuento'] ?? producto['descuento'] ?? 0;
      final valorDescuento = (producto['valorDescuento'] ?? 0.0);
      final porcentajeImpuesto =
          producto['porcentajeImpuesto'] ?? producto['iva'] ?? 0;
      final valorImpuesto =
          (producto['valorImpuesto'] ?? producto['valorIva'] ?? 0.0);
      final subtotal = (precioUnit * cantidad);
      // "TOTAL SIN IVA" = subtotal de la línea sin impuesto (no debe sumar valorImpuesto)
      final totalItem = subtotal - valorDescuento;
      // "TOTAL CON IVA" = el total anterior más el impuesto de la línea
      final totalItemConIva =
          totalItem + (valorImpuesto is num ? valorImpuesto.toDouble() : 0.0);

      rows.add(
        pw.TableRow(
          children: [
            _buildTableCell('$itemNum', font),
            _buildTableCell(codigo, font),
            _buildTableCell('$cantidad', font),
            _buildTableCell(nombre, font, align: pw.TextAlign.left),
            _buildTableCell(_formatearNumero(precioUnit), font),
            _buildTableCell('$porcentajeDescuento%', font),
            _buildTableCell(_formatearNumero(valorDescuento), font),
            _buildTableCell('$porcentajeImpuesto%', font),
            _buildTableCell(_formatearNumero(valorImpuesto), font),
            _buildTableCell(_formatearNumero(totalItem), font),
            _buildTableCell(_formatearNumero(totalItemConIva), font),
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
        (productos is List ? productos.length : 0);
    final cantidadProductos =
        resumen['cantidadProductos'] ??
        (productos is List ? productos.length : 0);
    final vendedor = _toSafeString(
      resumen['vendedor'] ?? resumen['mesero'],
      'Sin Vendedor',
    );
    final subtotal = resumen['subtotal'] ?? resumen['totalSinIva'] ?? 0.0;
    final descuento = resumen['descuento'] ?? 0.0;
    final iva =
        resumen['iva'] ??
        resumen['totalIva'] ??
        resumen['impuestos'] ??
        resumen['totalImp'] ??
        0.0;
    final total = resumen['total'] ?? resumen['totalFactura'] ?? 0.0;
    final formaPago = _toSafeString(resumen['formaPago'], 'Efectivo');
    final pagosParciales = resumen['pagosParciales'] as List?;

    // Calcular IVA desde productos si no viene directo
    double ivaCalculado = (iva is num ? iva.toDouble() : 0.0);
    double baseIva = 0.0;
    double pctIva = 0.0;
    if (productos is List) {
      double ivaProductos = 0.0;
      for (var p in productos) {
        final valorImpuesto = (p['valorImpuesto'] ?? p['valorIva'] ?? 0.0);
        final pctImp = (p['porcentajeImpuesto'] ?? p['iva'] ?? 0);
        final cant = (p['cantidad'] ?? 1);
        if (valorImpuesto is num && valorImpuesto > 0) {
          ivaProductos +=
              valorImpuesto.toDouble() * (cant is num ? cant.toInt() : 1);
        }
        if (pctImp is num && pctImp > 0) pctIva = pctImp.toDouble();
      }
      if (ivaCalculado == 0 && ivaProductos > 0) ivaCalculado = ivaProductos;
      baseIva = (subtotal is num ? subtotal.toDouble() : 0.0);
    }

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
                'PRODUCTOS: $cantidadProductos VENDEDOR: $vendedor TIPO: CONTADO TOTAL: ${_formatearNumero(total)}',
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
                          'DETALLE DE IMPUESTOS',
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
                          _formatearNumero(baseIva),
                          style: pw.TextStyle(font: font, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          _formatearNumero(ivaCalculado),
                          style: pw.TextStyle(font: font, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          _formatearNumero(baseIva),
                          style: pw.TextStyle(font: font, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          _formatearNumero(ivaCalculado),
                          style: pw.TextStyle(font: font, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if ((resumen['descuento'] ?? 0.0) > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    'DCTO. GENERAL: -${_formatearMoneda(resumen['descuento'] ?? 0.0)}',
                    style: pw.TextStyle(font: fontBold, fontSize: 8),
                  ),
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
                // Desglose de pagos mixtos
                if (pagosParciales != null && pagosParciales.isNotEmpty)
                  ...pagosParciales.map((pago) {
                    final nombre = _toSafeString((pago as Map)['formaPago']);
                    final monto = (pago['monto'] ?? 0.0) is num
                        ? (pago['monto'] as num).toDouble()
                        : 0.0;
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 1,
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            nombre,
                            style: pw.TextStyle(font: font, fontSize: 7),
                          ),
                          pw.Text(
                            _formatearNumero(monto),
                            style: pw.TextStyle(font: font, fontSize: 7),
                          ),
                        ],
                      ),
                    );
                  }),
                if (pagosParciales == null || pagosParciales.isEmpty)
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
                  'IVA',
                  _formatearMoneda(ivaCalculado),
                  font,
                  fontBold,
                ),
                // Retenciones (mostrar solo si > 0)
                if ((resumen['retencion'] ?? 0.0) > 0)
                  _buildTotalRow(
                    'RETENCIÓN (${(resumen['retencionPct'] ?? 0).toStringAsFixed(1)}%)',
                    '-${_formatearMoneda(resumen['retencion'] ?? 0.0)}',
                    font,
                    fontBold,
                  ),
                if ((resumen['reteIVA'] ?? 0.0) > 0)
                  _buildTotalRow(
                    'RETEIVA (${(resumen['reteIVAPct'] ?? 0).toStringAsFixed(1)}%)',
                    '-${_formatearMoneda(resumen['reteIVA'] ?? 0.0)}',
                    font,
                    fontBold,
                  ),
                if ((resumen['reteICA'] ?? 0.0) > 0)
                  _buildTotalRow(
                    'RETEICA (${(resumen['reteICAPct'] ?? 0).toStringAsFixed(1)}%)',
                    '-${_formatearMoneda(resumen['reteICA'] ?? 0.0)}',
                    font,
                    fontBold,
                  ),
                if ((resumen['aiu'] ?? 0.0) > 0)
                  _buildTotalRow(
                    'AIU (${(resumen['aiuPct'] ?? 0).toStringAsFixed(1)}%)',
                    '+${_formatearMoneda(resumen['aiu'] ?? 0.0)}',
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
      'DIECISEIS',
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

    // Convierte un grupo de hasta 999 a letras
    String grupoALetras(int n) {
      String r = '';
      if (n >= 100) {
        int cen = n ~/ 100;
        r += '${centenas[cen]} ';
        n = n % 100;
      }
      if (n >= 10 && n <= 19) {
        r += especiales[n - 10];
      } else if (n >= 10) {
        int dec = n ~/ 10;
        int uni = n % 10;
        r += uni == 0 ? decenas[dec] : '${decenas[dec]} Y ${unidades[uni]}';
      } else if (n > 0) {
        r += unidades[n];
      }
      return r.trim();
    }

    // Redondear igual que el total numérico (_formatearNumero usa
    // toStringAsFixed(0), que redondea) — .toInt() truncaba en vez de
    // redondear, así que en valores con decimales el total en letras podía
    // no coincidir con la cifra mostrada.
    int n = numero.round();
    if (n == 0) return 'CERO PESOS';
    if (n == 100) return 'CIEN PESOS';

    String resultado = '';

    // Millones
    if (n >= 1000000) {
      int millones = n ~/ 1000000;
      if (millones == 1) {
        resultado += 'UN MILLON ';
      } else {
        resultado += '${grupoALetras(millones)} MILLONES ';
      }
      n = n % 1000000;
    }

    // Miles
    if (n >= 1000) {
      int miles = n ~/ 1000;
      if (miles == 1) {
        resultado += 'MIL ';
      } else {
        resultado += '${grupoALetras(miles)} MIL ';
      }
      n = n % 1000;
    }

    // Centenas, decenas y unidades restantes
    if (n > 0) {
      if (n == 100) {
        resultado += 'CIEN ';
      } else {
        resultado += grupoALetras(n);
      }
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
          '${esFactura ? 'Factura' : 'Pedido'}: ${_toSafeString(resumen['pedidoId'] ?? resumen['numero'], 'N/A')}',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
        if (resumen['fecha'] != null)
          pw.Text(
            'Fecha: ${_toSafeString(resumen['fecha'])}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        if (resumen['hora'] != null)
          pw.Text(
            'Hora: ${_toSafeString(resumen['hora'])}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        if (resumen['mesa'] != null)
          pw.Text(
            'Mesa: ${_toSafeString(resumen['mesa'])}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        if (resumen['mesero'] != null)
          pw.Text(
            'Mesero: ${_toSafeString(resumen['mesero'])}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        if (resumen['cliente'] != null)
          pw.Text(
            'Cliente: ${_toSafeString(resumen['cliente'])}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        if (resumen['medioPago'] != null)
          pw.Text(
            'Medio de pago: ${_toSafeString(resumen['medioPago'])}',
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
    final productos =
        resumen['productos'] ??
        resumen['items'] ??
        resumen['detalleProductos'] ??
        [];

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
      final nombre =
          producto['productoNombre'] ??
          producto['nombre'] ??
          producto['producto'] ??
          'Producto';
      final precio = (producto['precioUnitario'] ?? producto['precio'] ?? 0.0);
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
                _formatearMoneda(subtotal),
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
                _formatearMoneda(base),
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
                _formatearMoneda(impuestos),
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
                _formatearMoneda(propina),
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
              _formatearMoneda(total),
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
      rethrow;
    }
  }

  /// Verificar si hay impresoras disponibles
  Future<List<Printer>> obtenerImpresorasDisponibles() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
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
      rethrow;
    }
  }

  /// Descargar PDF que ya ha sido generado (sin regenerar)
  Future<void> descargarPDFDirecto({
    required Uint8List pdfBytes,
    required String nombreArchivo,
  }) async {
    try {
      // En web, descargar el archivo directamente
      if (kIsWeb) {
        descargarPDFWeb(pdfBytes, nombreArchivo);
      } else {
        // En móvil/desktop, guardar el archivo
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$nombreArchivo');
        await file.writeAsBytes(pdfBytes);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Vista previa del PDF de informe de productos
  Future<void> mostrarVistaPreviewInformeProductos(
    Map<String, dynamic> resumen,
  ) async {
    try {
      final pdfBytes = await generarInformeProductosPDF(resumen: resumen);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Informe_Productos_${DateTime.now().millisecondsSinceEpoch}',
        format: PdfPageFormat.letter,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> mostrarVistaPrevia({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
    String? nombreArchivo,
  }) async {
    try {
      final pdfBytes = await generarResumenPedidoPDF(
        resumen: resumen,
        esFactura: esFactura,
      );

      final fileName =
          nombreArchivo ??
          '${esFactura ? 'Factura' : 'Resumen'}_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';

      // En web, descargar el archivo directamente
      if (kIsWeb) {
        descargarPDFWeb(pdfBytes, fileName);
      } else {
        // En móvil/desktop, intentar guardar el archivo
        await _guardarYAbrirPDFWindows(
          pdfBytes,
          resumen,
          esFactura,
          nombreArchivo: fileName,
        );
      }
    } catch (e) {
      // Si falla, intentar compartir el PDF como alternativa
      try {
        final pdfBytes = await generarResumenPedidoPDF(
          resumen: resumen,
          esFactura: esFactura,
        );

        final fileName =
            nombreArchivo ??
            '${esFactura ? 'Factura' : 'Resumen'}_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';

        // Intentar compartir como última opción
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      } catch (e2) {
        rethrow;
      }
    }
  }

  /// Método alternativo para Windows: guardar archivo y abrir con visor predeterminado
  Future<void> _guardarYAbrirPDFWindows(
    Uint8List pdfBytes,
    Map<String, dynamic> resumen,
    bool esFactura, {
    String? nombreArchivo,
  }) async {
    try {
      // Obtener directorio de documentos
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          nombreArchivo ??
          '${esFactura ? 'Factura' : 'Resumen'}_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      // Escribir el archivo
      await file.writeAsBytes(pdfBytes);
    } catch (e) {
      rethrow;
    }
  }

  /// Generar PDF de informe de productos
  Future<Uint8List> generarInformeProductosPDF({
    required Map<String, dynamic> resumen,
  }) async {
    final pdf = pw.Document();

    // Usar fuentes seguras para web
    final font = await _getFontRegular();
    final fontBold = await _getFontBold();

    // Pre-procesar valores
    final nombreNegocio = _toSafeString(
      resumen['nombreNegocio'],
      'VERCY MOTOS',
    );
    final tipoInforme = _toSafeString(resumen['tipoInforme'], 'Informe');
    final fechaDesde = _toSafeString(resumen['fechaDesde']);
    final fechaHasta = _toSafeString(resumen['fechaHasta']);
    final cliente = _toSafeString(resumen['cliente'], 'Todos');
    final producto = _toSafeString(resumen['producto'], 'Todos');
    final vendedor = _toSafeString(resumen['vendedor'], 'Todos');
    final codigo = _toSafeString(resumen['codigo'], 'Todos');
    final fecha = _toSafeString(resumen['fecha']);
    final hora = _toSafeString(resumen['hora']);

    final totalRegistros = resumen['totalRegistros'] ?? 0;
    final totalCantidad = resumen['totalCantidad'] ?? 0;
    final totalSubtotal = (resumen['totalSubtotal'] ?? 0.0).toDouble();
    final totalDescuento = (resumen['totalDescuento'] ?? 0.0).toDouble();
    final totalImpuesto = (resumen['totalImpuesto'] ?? 0.0).toDouble();
    final totalVentas = (resumen['totalVentas'] ?? 0.0).toDouble();

    final productos = resumen['productos'] ?? [];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ========== ENCABEZADO ==========
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      nombreNegocio,
                      style: pw.TextStyle(font: fontBold, fontSize: 18),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      tipoInforme,
                      style: pw.TextStyle(font: fontBold, fontSize: 14),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Fecha: $fecha $hora',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          'Período: $fechaDesde a $fechaHasta',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ========== FILTROS APLICADOS ==========
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                ),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FILTROS APLICADOS',
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            'Cliente: $cliente',
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Producto: $producto',
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            'Vendedor: $vendedor',
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Código: $codigo',
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                      ],
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
                  1: const pw.FlexColumnWidth(1), // FECHA
                  2: const pw.FlexColumnWidth(1), // FACTURA
                  3: const pw.FlexColumnWidth(1.5), // CLIENTE
                  4: const pw.FlexColumnWidth(1.5), // PRODUCTO
                  5: const pw.FlexColumnWidth(0.8), // CÓDIGO
                  6: const pw.FlexColumnWidth(0.6), // CANT
                  7: const pw.FlexColumnWidth(1), // P. UNIT
                  8: const pw.FlexColumnWidth(1), // SUBTOTAL
                  9: const pw.FlexColumnWidth(0.7), // DESC.
                  10: const pw.FlexColumnWidth(0.7), // IMP.
                  11: const pw.FlexColumnWidth(1), // TOTAL
                },
                children: [
                  // Encabezado
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF5F5F5),
                    ),
                    children: [
                      _buildTableHeader('ITEM', fontBold),
                      _buildTableHeader('FECHA', fontBold),
                      _buildTableHeader('FACTURA', fontBold),
                      _buildTableHeader('CLIENTE', fontBold),
                      _buildTableHeader('PRODUCTO', fontBold),
                      _buildTableHeader('CÓDIGO', fontBold),
                      _buildTableHeader('CANT', fontBold),
                      _buildTableHeader('P. UNIT', fontBold),
                      _buildTableHeader('SUBTOTAL', fontBold),
                      _buildTableHeader('DESC.', fontBold),
                      _buildTableHeader('IMP.', fontBold),
                      _buildTableHeader('TOTAL', fontBold),
                    ],
                  ),
                  // Productos
                  ...(_buildProductosInformeTable(productos, font)),
                ],
              ),

              pw.SizedBox(height: 12),

              // ========== RESUMEN DE TOTALES ==========
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.5),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF5F5F5),
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.black,
                            width: 0.5,
                          ),
                        ),
                      ),
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: pw.Text(
                        'RESUMEN TOTAL',
                        style: pw.TextStyle(font: fontBold, fontSize: 11),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        children: [
                          _buildTotalRowInforme(
                            'Total Registros',
                            totalRegistros.toString(),
                            font,
                            fontBold,
                          ),
                          _buildTotalRowInforme(
                            'Cantidad Total',
                            totalCantidad.toString(),
                            font,
                            fontBold,
                          ),
                          _buildTotalRowInforme(
                            'Subtotal',
                            _formatearMoneda(totalSubtotal),
                            font,
                            fontBold,
                          ),
                          _buildTotalRowInforme(
                            'Descuentos',
                            _formatearMoneda(totalDescuento),
                            font,
                            fontBold,
                          ),
                          _buildTotalRowInforme(
                            'Impuestos',
                            _formatearMoneda(totalImpuesto),
                            font,
                            fontBold,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                top: pw.BorderSide(
                                  color: PdfColors.black,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 4,
                            ),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'TOTAL VENTAS',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 11,
                                  ),
                                ),
                                pw.Text(
                                  _formatearMoneda(totalVentas),
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ========== PIE DE PÁGINA ==========
              pw.Center(
                child: pw.Text(
                  'Este es un documento generado automáticamente por el sistema de gestión - $nombreNegocio',
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Construir filas de productos para informe
  List<pw.TableRow> _buildProductosInformeTable(
    List<dynamic> productos,
    pw.Font font,
  ) {
    List<pw.TableRow> rows = [];
    int itemNum = 1;

    for (var producto in productos) {
      if (producto is! Map<String, dynamic>) continue;

      final tipo = _toSafeString(producto['tipo'], 'POS');
      final fecha = _toSafeString(producto['fecha'], '-');
      final numeroFactura = _toSafeString(producto['numeroFactura'], '-');
      final cliente = _toSafeString(producto['cliente'], '-');
      final nombreProducto = _toSafeString(producto['nombreProducto'], '-');
      final codigoProducto = _toSafeString(producto['codigoProducto'], '-');
      final cantidad = producto['cantidad'] ?? 0;
      final precioUnitario = (producto['precioUnitario'] ?? 0.0).toDouble();
      final subtotal = (producto['subtotal'] ?? 0.0).toDouble();
      final descuento = (producto['descuento'] ?? 0.0).toDouble();
      final impuesto = (producto['impuesto'] ?? 0.0).toDouble();
      final total = (producto['total'] ?? 0.0).toDouble();

      rows.add(
        pw.TableRow(
          children: [
            _buildTableCell('$itemNum', font),
            _buildTableCell(fecha, font),
            _buildTableCell(numeroFactura, font),
            _buildTableCell(cliente, font, align: pw.TextAlign.left),
            _buildTableCell(nombreProducto, font, align: pw.TextAlign.left),
            _buildTableCell(codigoProducto, font),
            _buildTableCell('$cantidad', font),
            _buildTableCell(_formatearNumero(precioUnitario), font),
            _buildTableCell(_formatearNumero(subtotal), font),
            _buildTableCell(_formatearNumero(descuento), font),
            _buildTableCell(_formatearNumero(impuesto), font),
            _buildTableCell(_formatearNumero(total), font),
          ],
        ),
      );
      itemNum++;
    }

    return rows;
  }

  /// Construir fila de totales para informe
  pw.Widget _buildTotalRowInforme(
    String label,
    String valor,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9)),
        pw.Text(valor, style: pw.TextStyle(font: font, fontSize: 9)),
      ],
    );
  }

  /// Fila de un informe explicado: título + valor en negrita, con una línea
  /// gris debajo aclarando qué significa la cifra (para que el informe se
  /// pueda leer como una explicación contable, no solo una tabla de números).
  pw.Widget _buildFilaExplicada(
    String label,
    String valor,
    String explicacion,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.Text(valor, style: pw.TextStyle(font: fontBold, fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            explicacion,
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSeccionTitulo(String texto, pw.Font fontBold) {
    return pw.Container(
      width: double.infinity,
      color: const PdfColor.fromInt(0xFFF5F5F5),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const pw.EdgeInsets.only(bottom: 8, top: 4),
      child: pw.Text(texto, style: pw.TextStyle(font: fontBold, fontSize: 11)),
    );
  }

  /// Informe de Costeo de Inventario y Utilidad Real: explica, en formato de
  /// informe contable descargable, cómo se calculó la utilidad real del
  /// período (costo de mercancía vendida por los dos métodos: por venta y
  /// por inventario) además de la utilidad neta tras gastos operativos.
  Future<Uint8List> generarInformeCosteoPDF({
    required Map<String, dynamic> resumen,
  }) async {
    final pdf = pw.Document();
    final font = await _getFontRegular();
    final fontBold = await _getFontBold();

    final nombreNegocio = _toSafeString(resumen['nombreNegocio'], 'VERCY MOTOS');
    final fecha = _toSafeString(resumen['fecha']);
    final hora = _toSafeString(resumen['hora']);
    final fechaDesde = _toSafeString(resumen['fechaDesde']);
    final fechaHasta = _toSafeString(resumen['fechaHasta']);

    final ventasPeriodo = (resumen['ventasPeriodo'] ?? 0.0).toDouble();
    final metodoPorVenta = resumen['metodoPorVenta'] as Map<String, dynamic>? ?? {};
    final metodoPorInventario = resumen['metodoPorInventario'] as Map<String, dynamic>? ?? {};
    final gastosOperativos = (resumen['gastosOperativos'] ?? 0.0).toDouble();
    final utilidadNeta = (resumen['utilidadNeta'] ?? 0.0).toDouble();
    final margenNetoPorcentaje = (resumen['margenNetoPorcentaje'] ?? 0.0).toDouble();
    final huboEstimacion = metodoPorVenta['huboEstimacion'] == true;

    final inventarioInicial = metodoPorInventario['inventarioInicial'];
    final tieneInventarioInicial = inventarioInicial != null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(nombreNegocio, style: pw.TextStyle(font: fontBold, fontSize: 18)),
                pw.SizedBox(height: 4),
                pw.Text('Costeo de Inventario y Utilidad Real', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Generado: $fecha $hora', style: pw.TextStyle(font: font, fontSize: 10)),
                    pw.Text('Periodo: $fechaDesde a $fechaHasta', style: pw.TextStyle(font: font, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          _buildSeccionTitulo('VENTAS DEL PERIODO', fontBold),
          _buildFilaExplicada(
            'Ventas',
            _formatearMoneda(ventasPeriodo),
            'Suma de todas las ventas pagadas/completadas del periodo elegido.',
            font,
            fontBold,
          ),
          _buildSeccionTitulo('METODO 1: COSTO POR VENTA (detalle de costos)', fontBold),
          _buildFilaExplicada(
            'Costo de Mercancia Vendida (COGS)',
            _formatearMoneda(metodoPorVenta['costoMercanciaVendida']),
            'Suma de (cantidad x costo) de cada producto vendido en el periodo. '
            'Usa el costo guardado al momento de cada venta; si una venta es '
            'anterior a que el sistema empezara a guardarlo, se estima con el '
            'costo actual del producto.',
            font,
            fontBold,
          ),
          _buildFilaExplicada(
            'Utilidad Bruta Real',
            _formatearMoneda(metodoPorVenta['utilidadBruta']),
            'Ventas menos Costo de Mercancia Vendida. Es la ganancia real antes '
            'de gastos operativos (arriendo, salarios, servicios, etc.).',
            font,
            fontBold,
          ),
          _buildFilaExplicada(
            'Margen Bruto',
            '${((metodoPorVenta['margenBrutoPorcentaje'] ?? 0.0) as num).toStringAsFixed(1)}%',
            'Utilidad Bruta Real dividida entre Ventas. Indica que porcentaje de '
            'cada venta queda como ganancia antes de gastos operativos.',
            font,
            fontBold,
          ),
          if (huboEstimacion)
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              margin: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFF3CD),
                border: pw.Border.all(color: PdfColors.orange),
              ),
              child: pw.Text(
                'Aviso: ${metodoPorVenta['cantidadItemsEstimados']} de '
                '${metodoPorVenta['cantidadItemsTotal']} productos vendidos en este '
                'periodo no tenian su costo guardado; se uso el costo actual del '
                'producto como aproximacion.',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
            ),
          _buildSeccionTitulo('METODO 2: COSTO POR INVENTARIO (formula contable)', fontBold),
          _buildFilaExplicada(
            'Inventario Inicial',
            tieneInventarioInicial ? _formatearMoneda(inventarioInicial) : 'No informado',
            'Valor a costo de la mercancia que habia en existencia al inicio del '
            'periodo. Se informa manualmente porque el sistema no guarda un '
            'historico de inventario por fecha.',
            font,
            fontBold,
          ),
          _buildFilaExplicada(
            'Compras del Periodo (sin IVA)',
            _formatearMoneda(metodoPorInventario['comprasSinIva']),
            'Total de compras a proveedores en el periodo, sin incluir el IVA '
            '(usado en la formula de costeo).',
            font,
            fontBold,
          ),
          _buildFilaExplicada(
            'Compras del Periodo (con IVA)',
            _formatearMoneda(metodoPorInventario['comprasConIva']),
            'Total de compras a proveedores en el periodo, incluyendo el IVA '
            '(lo que realmente se pago).',
            font,
            fontBold,
          ),
          _buildFilaExplicada(
            'Inventario Final',
            _formatearMoneda(metodoPorInventario['inventarioFinalCalculado']),
            'Valor a costo de la mercancia en existencia hoy (cantidad x costo '
            'de cada producto activo). Solo es exacto si el fin del periodo es hoy.',
            font,
            fontBold,
          ),
          _buildFilaExplicada(
            'Costo de Mercancia Vendida',
            tieneInventarioInicial ? _formatearMoneda(metodoPorInventario['costoMercanciaVendida']) : 'N/D',
            'Formula contable clasica: Inventario Inicial + Compras (sin IVA) − '
            'Inventario Final.',
            font,
            fontBold,
          ),
          _buildFilaExplicada(
            'Utilidad Bruta (por inventario)',
            tieneInventarioInicial ? _formatearMoneda(metodoPorInventario['utilidadBruta']) : 'N/D',
            'Ventas menos el Costo de Mercancia Vendida calculado por este '
            'metodo. Sirve para comparar/validar contra el Metodo 1.',
            font,
            fontBold,
          ),
          _buildSeccionTitulo('RESUMEN FINAL', fontBold),
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              children: [
                _buildTotalRowInforme('Gastos Operativos', _formatearMoneda(gastosOperativos), font, fontBold),
                pw.SizedBox(height: 4),
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.5)),
                  ),
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('UTILIDAD NETA', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                      pw.Text(
                        '${_formatearMoneda(utilidadNeta)}  (${margenNetoPorcentaje.toStringAsFixed(1)}%)',
                        style: pw.TextStyle(font: fontBold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              'Este es un documento generado automaticamente por el sistema de gestion - $nombreNegocio',
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> mostrarVistaPreviewInformeCosteo(Map<String, dynamic> resumen) async {
    try {
      final pdfBytes = await generarInformeCosteoPDF(resumen: resumen);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Informe_Costeo_Utilidad_${DateTime.now().millisecondsSinceEpoch}',
        format: PdfPageFormat.letter,
      );
    } catch (e) {
      rethrow;
    }
  }

  pw.Widget _buildEncabezadoInforme(
    String nombreNegocio,
    String titulo,
    String fecha,
    String hora,
    String fechaDesde,
    String fechaHasta,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(nombreNegocio, style: pw.TextStyle(font: fontBold, fontSize: 18)),
          pw.SizedBox(height: 4),
          pw.Text(titulo, style: pw.TextStyle(font: fontBold, fontSize: 14)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generado: $fecha $hora', style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text('Periodo: $fechaDesde a $fechaHasta', style: pw.TextStyle(font: font, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPiePagina(String nombreNegocio, pw.Font font) {
    return pw.Center(
      child: pw.Text(
        'Este es un documento generado automaticamente por el sistema de gestion - $nombreNegocio',
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    );
  }

  /// Informe de Rentabilidad por Producto y Cliente: productos mas rentables,
  /// productos con mucha venta pero poco margen, y clientes que mas utilidad
  /// generan (no solo mas venden).
  Future<Uint8List> generarInformeRentabilidadPDF({
    required Map<String, dynamic> resumen,
  }) async {
    final pdf = pw.Document();
    final font = await _getFontRegular();
    final fontBold = await _getFontBold();

    final nombreNegocio = _toSafeString(resumen['nombreNegocio'], 'VERCY MOTOS');
    final fecha = _toSafeString(resumen['fecha']);
    final hora = _toSafeString(resumen['hora']);
    final fechaDesde = _toSafeString(resumen['fechaDesde']);
    final fechaHasta = _toSafeString(resumen['fechaHasta']);

    final productos = resumen['productos'] as Map<String, dynamic>? ?? {};
    final clientes = resumen['clientes'] as Map<String, dynamic>? ?? {};
    final porUtilidad = (productos['porUtilidad'] as List?) ?? [];
    final porCantidad = (productos['porCantidadVendida'] as List?) ?? [];
    final clientesPorUtilidad = (clientes['porUtilidad'] as List?) ?? [];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          _buildEncabezadoInforme(nombreNegocio, 'Rentabilidad por Producto y Cliente', fecha, hora, fechaDesde,
              fechaHasta, font, fontBold),
          pw.SizedBox(height: 4),
          _buildSeccionTitulo(
              'PRODUCTOS MAS RENTABLES (margen promedio: '
              '${((productos['margenPromedioPorcentaje'] ?? 0.0) as num).toStringAsFixed(1)}%)',
              fontBold),
          _buildTablaRanking(porUtilidad, 'productoNombre', ['Cantidad', 'Ventas', 'Costo', 'Utilidad', 'Margen %'],
              (item) => [
                    _formatearNumero(item['cantidadVendida']),
                    _formatearMoneda(item['ventas']),
                    _formatearMoneda(item['costo']),
                    _formatearMoneda(item['utilidad']),
                    '${((item['margenPorcentaje'] ?? 0.0) as num).toStringAsFixed(1)}%',
                  ],
              font, fontBold),
          pw.SizedBox(height: 8),
          _buildSeccionTitulo('PRODUCTOS MAS VENDIDOS (revisar margen bajo)', fontBold),
          _buildTablaRanking(porCantidad, 'productoNombre', ['Cantidad', 'Ventas', 'Utilidad', 'Margen %'],
              (item) => [
                    _formatearNumero(item['cantidadVendida']),
                    _formatearMoneda(item['ventas']),
                    _formatearMoneda(item['utilidad']),
                    '${((item['margenPorcentaje'] ?? 0.0) as num).toStringAsFixed(1)}%',
                  ],
              font, fontBold),
          pw.SizedBox(height: 8),
          _buildSeccionTitulo(
              'CLIENTES QUE MAS UTILIDAD GENERAN (margen promedio: '
              '${((clientes['margenPromedioPorcentaje'] ?? 0.0) as num).toStringAsFixed(1)}%)',
              fontBold),
          _buildTablaRanking(clientesPorUtilidad, 'cliente', ['Pedidos', 'Ventas', 'Utilidad', 'Margen %'],
              (item) => [
                    _formatearNumero(item['numeroPedidos']),
                    _formatearMoneda(item['ventas']),
                    _formatearMoneda(item['utilidad']),
                    '${((item['margenPorcentaje'] ?? 0.0) as num).toStringAsFixed(1)}%',
                  ],
              font, fontBold),
          pw.SizedBox(height: 12),
          _buildPiePagina(nombreNegocio, font),
        ],
      ),
    );

    return pdf.save();
  }

  /// Tabla generica de ranking: primera columna es el nombre (producto o
  /// cliente), las siguientes columnas vienen dadas por [encabezados] y
  /// [filaValores] (una funcion que arma los valores de cada fila a partir
  /// del item). Reutilizable para productos y clientes sin duplicar la
  /// construccion de la tabla completa.
  pw.Widget _buildTablaRanking(
    List<dynamic> items,
    String nombreKey,
    List<String> encabezados,
    List<String> Function(Map<String, dynamic>) filaValores,
    pw.Font font,
    pw.Font fontBold,
  ) {
    if (items.isEmpty) {
      return pw.Text('Sin datos en este periodo.', style: pw.TextStyle(font: font, fontSize: 9));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        for (var i = 0; i < encabezados.length; i++) i + 1: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
          children: [
            _buildTableHeader('NOMBRE', fontBold),
            ...encabezados.map((e) => _buildTableHeader(e.toUpperCase(), fontBold)),
          ],
        ),
        ...items.map((raw) {
          final item = raw as Map<String, dynamic>;
          return pw.TableRow(children: [
            _buildTableCell(_toSafeString(item[nombreKey], '-'), font, align: pw.TextAlign.left),
            ...filaValores(item).map((v) => _buildTableCell(v, font)),
          ]);
        }),
      ],
    );
  }

  Future<void> mostrarVistaPreviewInformeRentabilidad(Map<String, dynamic> resumen) async {
    try {
      final pdfBytes = await generarInformeRentabilidadPDF(resumen: resumen);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Informe_Rentabilidad_${DateTime.now().millisecondsSinceEpoch}',
        format: PdfPageFormat.letter,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Informe de Comparación de Períodos: ventas, costo, utilidad y margenes
  /// del período actual contra el período de comparación (mes anterior o
  /// mismo rango del año anterior, segun lo que haya elegido el usuario).
  Future<Uint8List> generarInformeComparativoPDF({
    required Map<String, dynamic> resumen,
  }) async {
    final pdf = pw.Document();
    final font = await _getFontRegular();
    final fontBold = await _getFontBold();

    final nombreNegocio = _toSafeString(resumen['nombreNegocio'], 'VERCY MOTOS');
    final fecha = _toSafeString(resumen['fecha']);
    final hora = _toSafeString(resumen['hora']);
    final tipoComparacion = _toSafeString(resumen['tipoComparacion'], 'Comparacion de periodos');

    final actual = resumen['periodoActual'] as Map<String, dynamic>? ?? {};
    final anterior = resumen['periodoAnterior'] as Map<String, dynamic>? ?? {};

    String variacionTexto(dynamic v) {
      if (v == null) return 'N/A';
      final val = (v as num).toDouble();
      final signo = val > 0 ? '+' : '';
      return '$signo${val.toStringAsFixed(1)}%';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          _buildEncabezadoInforme(nombreNegocio, 'Comparacion de Periodos ($tipoComparacion)', fecha, hora, '-', '-',
              font, fontBold),
          pw.SizedBox(height: 4),
          _buildSeccionTitulo('RESULTADOS', fontBold),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1.3),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
                children: [
                  _buildTableHeader('CONCEPTO', fontBold),
                  _buildTableHeader('ACTUAL', fontBold),
                  _buildTableHeader('ANTERIOR', fontBold),
                  _buildTableHeader('VARIACION', fontBold),
                ],
              ),
              pw.TableRow(children: [
                _buildTableCell('Ventas', font, align: pw.TextAlign.left),
                _buildTableCell(_formatearMoneda(actual['ventasPeriodo']), font),
                _buildTableCell(_formatearMoneda(anterior['ventasPeriodo']), font),
                _buildTableCell(variacionTexto(resumen['variacionVentasPorcentaje']), font),
              ]),
              pw.TableRow(children: [
                _buildTableCell('Costo de Mercancia Vendida', font, align: pw.TextAlign.left),
                _buildTableCell(_formatearMoneda(actual['costoMercanciaVendida']), font),
                _buildTableCell(_formatearMoneda(anterior['costoMercanciaVendida']), font),
                _buildTableCell('-', font),
              ]),
              pw.TableRow(children: [
                _buildTableCell('Utilidad Bruta', font, align: pw.TextAlign.left),
                _buildTableCell(_formatearMoneda(actual['utilidadBruta']), font),
                _buildTableCell(_formatearMoneda(anterior['utilidadBruta']), font),
                _buildTableCell(variacionTexto(resumen['variacionUtilidadBrutaPorcentaje']), font),
              ]),
              pw.TableRow(children: [
                _buildTableCell('Utilidad Neta', font, align: pw.TextAlign.left),
                _buildTableCell(_formatearMoneda(actual['utilidadNeta']), font),
                _buildTableCell(_formatearMoneda(anterior['utilidadNeta']), font),
                _buildTableCell(variacionTexto(resumen['variacionUtilidadNetaPorcentaje']), font),
              ]),
              pw.TableRow(children: [
                _buildTableCell('Margen Bruto', font, align: pw.TextAlign.left),
                _buildTableCell('${((actual['margenBrutoPorcentaje'] ?? 0.0) as num).toStringAsFixed(1)}%', font),
                _buildTableCell('${((anterior['margenBrutoPorcentaje'] ?? 0.0) as num).toStringAsFixed(1)}%', font),
                _buildTableCell('-', font),
              ]),
            ],
          ),
          pw.SizedBox(height: 12),
          _buildPiePagina(nombreNegocio, font),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> mostrarVistaPreviewInformeComparativo(Map<String, dynamic> resumen) async {
    try {
      final pdfBytes = await generarInformeComparativoPDF(resumen: resumen);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Informe_Comparativo_${DateTime.now().millisecondsSinceEpoch}',
        format: PdfPageFormat.letter,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Lista de anomalias de un tipo: si esta vacia muestra "Sin anomalias
  /// detectadas", si no cada item se imprime con su "mensaje" ya redactado
  /// por el backend (evita duplicar el formateo del texto en el PDF).
  pw.Widget _buildListaAnomalias(List<dynamic> items, pw.Font font) {
    if (items.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text('Sin anomalias detectadas en este periodo.',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((raw) {
        final item = raw as Map<String, dynamic>;
        final mensaje = _toSafeString(item['mensaje'], '-');
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('- ', style: pw.TextStyle(font: font, fontSize: 9)),
              pw.Expanded(child: pw.Text(mensaje, style: pw.TextStyle(font: font, fontSize: 9))),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Informe de Alertas y Anomalias: gastos anormales, caida de ventas,
  /// clientes que compran menos, facturas inusuales, proveedores con
  /// aumento de precio y meses con perdida, cada uno con su explicacion.
  Future<Uint8List> generarInformeAnomaliasPDF({
    required Map<String, dynamic> resumen,
  }) async {
    final pdf = pw.Document();
    final font = await _getFontRegular();
    final fontBold = await _getFontBold();

    final nombreNegocio = _toSafeString(resumen['nombreNegocio'], 'VERCY MOTOS');
    final fecha = _toSafeString(resumen['fecha']);
    final hora = _toSafeString(resumen['hora']);
    final fechaDesde = _toSafeString(resumen['fechaDesde']);
    final fechaHasta = _toSafeString(resumen['fechaHasta']);

    final gastosAnormales = (resumen['gastosAnormales'] as List?) ?? [];
    final caidaVentas = resumen['caidaVentas'] as Map<String, dynamic>? ?? {};
    final clientesComprandoMenos = (resumen['clientesComprandoMenos'] as List?) ?? [];
    final facturasInusuales = (resumen['facturasInusuales'] as List?) ?? [];
    final proveedoresConAumentoPrecio = (resumen['proveedoresConAumentoPrecio'] as List?) ?? [];
    final mesesConPerdida = (resumen['mesesConPerdida'] as List?) ?? [];
    final totalAnomalias = resumen['totalAnomalias'] ?? 0;

    final caidaVentasEsAnomalia = caidaVentas['esAnomalia'] == true;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          _buildEncabezadoInforme(nombreNegocio, 'Alertas y Anomalias Contables', fecha, hora, fechaDesde,
              fechaHasta, font, fontBold),
          pw.SizedBox(height: 4),
          pw.Text('Total de anomalias detectadas: $totalAnomalias',
              style: pw.TextStyle(font: fontBold, fontSize: 10)),
          pw.SizedBox(height: 8),
          _buildSeccionTitulo('GASTOS ANORMALES POR CATEGORIA', fontBold),
          _buildListaAnomalias(gastosAnormales, font),
          pw.SizedBox(height: 8),
          _buildSeccionTitulo('CAIDA DE VENTAS', fontBold),
          _buildListaAnomalias(caidaVentasEsAnomalia ? [caidaVentas] : [], font),
          pw.SizedBox(height: 8),
          _buildSeccionTitulo('CLIENTES QUE COMPRAN MENOS', fontBold),
          _buildListaAnomalias(clientesComprandoMenos, font),
          pw.SizedBox(height: 8),
          _buildSeccionTitulo('FACTURAS INUSUALMENTE ALTAS', fontBold),
          _buildListaAnomalias(facturasInusuales, font),
          pw.SizedBox(height: 8),
          _buildSeccionTitulo('PROVEEDORES CON AUMENTO DE PRECIO', fontBold),
          _buildListaAnomalias(proveedoresConAumentoPrecio, font),
          pw.SizedBox(height: 8),
          _buildSeccionTitulo('MESES CON PERDIDA', fontBold),
          _buildListaAnomalias(mesesConPerdida, font),
          pw.SizedBox(height: 12),
          _buildPiePagina(nombreNegocio, font),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> mostrarVistaPreviewInformeAnomalias(Map<String, dynamic> resumen) async {
    try {
      final pdfBytes = await generarInformeAnomaliasPDF(resumen: resumen);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Informe_Anomalias_${DateTime.now().millisecondsSinceEpoch}',
        format: PdfPageFormat.letter,
      );
    } catch (e) {
      rethrow;
    }
  }
}
