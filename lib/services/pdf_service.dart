import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class PDFService {
  /// Generar PDF de resumen de pedido
  Future<Uint8List> generarResumenPedidoPDF({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) async {
    final pdf = pw.Document();

    // Cargar fuente personalizada si es necesario
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

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
        format: PdfPageFormat.roll80,
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
  Future<void> mostrarVistaPrevia({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) async {
    try {
      final pdfBytes = await generarResumenPedidoPDF(
        resumen: resumen,
        esFactura: esFactura,
      );

      // Siempre usar el método de guardado para evitar errores de plataforma
      await _guardarYAbrirPDFWindows(pdfBytes, resumen, esFactura);
    } catch (e) {
      print('❌ Error en vista previa: $e');
      // Si falla el guardado, intentar solo generar el PDF
      try {
        final pdfBytes = await generarResumenPedidoPDF(
          resumen: resumen,
          esFactura: esFactura,
        );
        print('✅ PDF generado correctamente (${pdfBytes.length} bytes)');
        print('💡 Error al guardar archivo. PDF generado pero no guardado.');
      } catch (e2) {
        print('❌ Error generando PDF: $e2');
        rethrow;
      }
      rethrow;
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
      print('💡 Abrir manualmente el archivo desde: ${file.path}');
    } catch (e) {
      print('❌ Error guardando PDF: $e');
      rethrow;
    }
  }
}
