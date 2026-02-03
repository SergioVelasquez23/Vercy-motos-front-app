import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'pdf_service_factory.dart';

class PDFServiceWeb implements PDFServiceInterface {
  /// Generar contenido como HTML para impresión en web
  String generarHTMLParaImpresion({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {
    // Intentar obtener items de diferentes campos posibles
    final items =
        (resumen['items'] as List<Map<String, dynamic>>?) ??
        (resumen['detalleProductos'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final subtotal = (resumen['subtotal'] as num?)?.toDouble() ?? 0.0;
    final propina = (resumen['propina'] as num?)?.toDouble() ?? 0.0;
    final total = (resumen['total'] as num?)?.toDouble() ?? 0.0;

    String itemsHtml = '';
    for (var item in items) {
      final nombre = item['nombre'] ?? '';
      final cantidad = item['cantidad'] ?? 1;
      // Probar diferentes campos para el precio
      final precioUnitario =
          (item['precio'] as num?)?.toDouble() ??
          (item['precioUnitario'] as num?)?.toDouble() ??
          0.0;
      final totalItem =
          (item['total'] as num?)?.toDouble() ??
          (item['subtotal'] as num?)?.toDouble() ??
          (cantidad * precioUnitario);

      itemsHtml +=
          '''
        <tr>
          <td>$nombre</td>
          <td style="text-align: center;">$cantidad</td>
          <td style="text-align: right;">\$${precioUnitario.toStringAsFixed(0)}</td>
          <td style="text-align: right;">\$${totalItem.toStringAsFixed(0)}</td>
        </tr>
      ''';
    }

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>${esFactura ? 'Factura' : 'Resumen de Pedido'}</title>
        <style>
            @page { 
                size: A4; 
                margin: 20mm; 
            }
            body { 
                font-family: 'Courier New', monospace; 
                font-size: 14px; 
                margin: 0; 
                padding: 20px;
                max-width: 100%;
                color: #333;
            }
            .header { 
                text-align: center; 
                margin-bottom: 25px;
                border-bottom: 2px solid #000;
                padding-bottom: 15px;
            }
            .restaurant-name { 
                font-size: 22px; 
                font-weight: bold; 
                margin-bottom: 10px;
                color: #000;
            }
            .contact-info { 
                font-size: 16px; 
                margin-bottom: 8px;
                color: #444;
                line-height: 1.6;
            }
            .document-info { 
                text-align: center; 
                margin: 25px 0;
                font-weight: bold;
                font-size: 20px;
                color: #000;
                background: #f5f5f5;
                padding: 15px;
                border-radius: 8px;
            }
            .items-table { 
                width: 100%; 
                border-collapse: collapse;
                margin: 20px 0;
                border-radius: 8px;
                overflow: hidden;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .items-table th, .items-table td { 
                padding: 15px 12px; 
                font-size: 16px;
                border-bottom: 1px solid #ddd;
                color: #333;
            }
            .items-table th { 
                font-weight: bold; 
                border-bottom: 2px solid #000;
                background: #f8f9fa;
                font-size: 17px;
            }
            .totals { 
                margin-top: 20px;
                border-top: 2px solid #000;
                padding-top: 15px;
                background: #f9f9f9;
                padding: 20px;
                border-radius: 8px;
            }
            .total-row { 
                display: flex; 
                justify-content: space-between;
                margin: 10px 0;
                font-size: 18px;
                padding: 5px 0;
            }
                color: #666;
            }
            .final-total { 
                font-weight: bold; 
                font-size: 22px;
                border-top: 3px solid #000;
                padding: 18px;
                margin-top: 20px;
                color: #000;
                background-color: #e8f4f8;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .footer { 
                text-align: center; 
                margin-top: 40px;
                font-size: 16px;
                border-top: 2px solid #000;
                padding-top: 20px;
                color: #555;
            }
            @media print {
                .no-print { display: none; }
            }
        </style>
    </head>
    <body>
        <div class="no-print" style="text-align: center; margin-bottom: 10px;">
            <button onclick="window.               };
        </script>
    </body>
    </html>
    ''';
  }

  /// Abrir ventana de impresión con HTML
  void abrirVentanaImpresion({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {
    if (kIsWeb) {
      final htmlContent = generarHTMLParaImpresion(
        resumen: resumen,
        esFactura: esFactura,
      );

      // Crear ventana nueva para impresión
      try {
        // Crear blob con el contenido HTML
        final blob = html.Blob([htmlContent], 'text/html');
        final url = html.Url.createObjectUrlFromBlob(blob);

        // Abrir en nueva ventana
        html.window.open(url, '_blank', 'width=400,height=600');

        // Limpiar URL después de un momento
        Future.delayed(Duration(seconds: 2), () {
          html.Url.revokeObjectUrl(url);
        });
      } catch (e) {
          
      }
    }
  }

  /// Generar y descargar PDF real para web
  void generarYDescargarPDF({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {
    if (kIsWeb) {
      // Usar el mismo HTML que para impresión pero con auto-print para PDF
      final htmlContent = generarHTMLParaImpresion(
        resumen: resumen,
        esFactura: esFactura,
      );

      // Modificar el HTML para auto-generar PDF
      final htmlConAutoPDF = htmlContent.replaceFirst(
        'window.onload = function() {',
        '''window.onload = function() {
            // Esperar un momento y luego imprimir automáticamente
            setTimeout(function() {
                window.  
            }, 1000);''',
      );

      try {
        final blob = html.Blob([htmlConAutoPDF], 'text/html');
        final url = html.Url.createObjectUrlFromBlob(blob);

        // Abrir en nueva ventana
        html.window.open(url, '_blank', 'width=800,height=600');

        // Limpiar URL después de un momento
        Future.delayed(Duration(seconds: 3), () {
          html.Url.revokeObjectUrl(url);
        });
      } catch (e) {
          
      }
    }
  }

  void descargarComoTexto({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {
    if (kIsWeb) {
      final contenido = generarTextoPlano(
        resumen: resumen,
        esFactura: esFactura,
      );

      final bytes = utf8.encode(contenido);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          '${esFactura ? 'factura' : 'resumen'}_${resumen['pedidoId'] ?? DateTime.now().millisecondsSinceEpoch}.txt',
        )
        ..click();

      html.Url.revokeObjectUrl(url);
    }
  }

  /// Generar contenido en texto plano
  String generarTextoPlano({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {
    // Intentar obtener items de diferentes campos posibles
    final items =
        (resumen['items'] as List<Map<String, dynamic>>?) ??
        (resumen['detalleProductos'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final subtotal = (resumen['subtotal'] as num?)?.toDouble() ?? 0.0;
    final propina = (resumen['propina'] as num?)?.toDouble() ?? 0.0;
    final total = (resumen['total'] as num?)?.toDouble() ?? 0.0;

    String contenido =
        '''
${resumen['nombreRestaurante'] ?? 'SOPA Y CARBÓN'}
${resumen['direccionRestaurante'] ?? 'Dirección del restaurante'}
Tel: ${resumen['telefonoRestaurante'] ?? 'Teléfono'}

==========================================
${esFactura ? 'FACTURA OFICIAL' : 'RESUMEN DE PEDIDO'}
==========================================

${_generarSeccionClienteTexto(resumen)}

Mesa: ${resumen['mesa'] ?? 'N/A'}
Fecha: ${resumen['fecha'] ?? DateTime.now().toString().split(' ')[0]}
Hora: ${resumen['hora'] ?? DateTime.now().toString().split(' ')[1].substring(0, 5)}
${resumen['pedidoId'] != null ? 'Pedido: ${resumen['pedidoId']}\n' : ''}
------------------------------------------
PRODUCTOS:
------------------------------------------
''';

    for (var item in items) {
      final nombre = item['nombre'] ?? '';
      final cantidad = item['cantidad'] ?? 1;
      // Probar diferentes campos para el precio
      final precioUnitario =
          (item['precio'] as num?)?.toDouble() ??
          (item['precioUnitario'] as num?)?.toDouble() ??
          0.0;
      final totalItem =
          (item['total'] as num?)?.toDouble() ??
          (item['subtotal'] as num?)?.toDouble() ??
          (cantidad * precioUnitario);

      contenido +=
          '''
$nombre
  $cantidad x \$${precioUnitario.toStringAsFixed(0)} = \$${totalItem.toStringAsFixed(0)}
''';
    }

    contenido += '''
------------------------------------------
Subtotal: \$${subtotal.toStringAsFixed(0)}''';

    if (propina > 0) {
      contenido += '''
Propina: \$${propina.toStringAsFixed(0)}''';
    }

    contenido +=
        '''
==========================================
TOTAL: \$${total.toStringAsFixed(0)}
==========================================

¡Gracias por su visita!
${DateTime.now().toString().split('.')[0]}
''';

    return contenido;
  }

  /// Compartir contenido como texto (para web)
  Future<void> compartirTexto({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) async {
    if (kIsWeb) {
      final contenido = generarTextoPlano(
        resumen: resumen,
        esFactura: esFactura,
      );

      // Intentar usar Web Share API si está disponible
      try {
        // Usar dynamic para evitar errores de tipo
        final navigator = html.window.navigator as dynamic;
        if (navigator.canShare != null) {
          await navigator.share({
            'title': esFactura ? 'Factura' : 'Resumen de Pedido',
            'text': contenido,
          });
          return;
        }
      } catch (e) {
          
      }

      // Fallback: copiar al portapapeles
      await html.window.navigator.clipboard?.writeText(contenido);

      // Mostrar notificación visual
      final div = html.DivElement()
        ..style.position = 'fixed'
        ..style.top = '20px'
        ..style.right = '20px'
        ..style.background = '#4CAF50'
        ..style.color = 'white'
        ..style.padding = '10px 20px'
        ..style.borderRadius = '5px'
        ..style.zIndex = '10000'
        ..text = 'Contenido copiado al portapapeles';

      html.document.body?.append(div);

      // Remover notificación después de 3 segundos
      Future.delayed(Duration(seconds: 3), () {
        div.remove();
      });
    }
  }

  /// ✅ NUEVO: Generar sección con información del cliente
  String _generarSeccionCliente(Map<String, dynamic> resumen) {
    // Verificar si se deben incluir datos del cliente
    if (resumen['incluirDatosCliente'] != true) {
      return '';
    }

    final clienteNombre = resumen['clienteNombre'] ?? '';
    final clienteNit = resumen['clienteNit'] ?? '';
    final clienteCorreo = resumen['clienteCorreo'] ?? '';
    final clienteTelefono = resumen['clienteTelefono'] ?? '';
    final clienteDireccion = resumen['clienteDireccion'] ?? '';

    // Si no hay ningún dato del cliente, no mostrar la sección
    if (clienteNombre.isEmpty &&
        clienteNit.isEmpty &&
        clienteCorreo.isEmpty &&
        clienteTelefono.isEmpty &&
        clienteDireccion.isEmpty) {
      return '';
    }

    String clienteInfo = '';

    if (clienteNombre.isNotEmpty) {
      clienteInfo +=
          '<div style="margin-bottom: 8px;"><strong>Cliente:</strong> $clienteNombre</div>';
    }

    if (clienteNit.isNotEmpty) {
      clienteInfo +=
          '<div style="margin-bottom: 8px;"><strong>NIT/CC:</strong> $clienteNit</div>';
    }

    if (clienteCorreo.isNotEmpty) {
      clienteInfo +=
          '<div style="margin-bottom: 8px;"><strong>Correo:</strong> $clienteCorreo</div>';
    }

    if (clienteTelefono.isNotEmpty) {
      clienteInfo +=
          '<div style="margin-bottom: 8px;"><strong>Teléfono:</strong> $clienteTelefono</div>';
    }

    if (clienteDireccion.isNotEmpty) {
      clienteInfo +=
          '<div style="margin-bottom: 8px;"><strong>Dirección:</strong> $clienteDireccion</div>';
    }

    return '''
        <div style="margin: 25px 0; padding: 20px; background: #f8f9fa; border-radius: 10px; border: 2px solid #e9ecef; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
            <div style="text-align: center; font-size: 18px; font-weight: bold; color: #000; margin-bottom: 15px; border-bottom: 2px solid #ddd; padding-bottom: 10px;">
                📋 INFORMACIÓN DEL CLIENTE
            </div>
            <div style="font-size: 16px; color: #2c3e50; line-height: 1.6;">
                $clienteInfo
            </div>
        </div>
    ''';
  }

  /// ✅ NUEVO: Generar sección del cliente para texto plano
  String _generarSeccionClienteTexto(Map<String, dynamic> resumen) {
    // Verificar si se deben incluir datos del cliente
    if (resumen['incluirDatosCliente'] != true) {
      return '';
    }

    final clienteNombre = resumen['clienteNombre'] ?? '';
    final clienteNit = resumen['clienteNit'] ?? '';
    final clienteCorreo = resumen['clienteCorreo'] ?? '';
    final clienteTelefono = resumen['clienteTelefono'] ?? '';
    final clienteDireccion = resumen['clienteDireccion'] ?? '';

    // Si no hay ningún dato del cliente, no mostrar la sección
    if (clienteNombre.isEmpty &&
        clienteNit.isEmpty &&
        clienteCorreo.isEmpty &&
        clienteTelefono.isEmpty &&
        clienteDireccion.isEmpty) {
      return '';
    }

    String clienteInfo = '''
------------------------------------------
📋 INFORMACIÓN DEL CLIENTE
------------------------------------------
''';

    if (clienteNombre.isNotEmpty) {
      clienteInfo += 'Cliente: $clienteNombre\n';
    }

    if (clienteNit.isNotEmpty) {
      clienteInfo += 'NIT/CC: $clienteNit\n';
    }

    if (clienteCorreo.isNotEmpty) {
      clienteInfo += 'Correo: $clienteCorreo\n';
    }

    if (clienteTelefono.isNotEmpty) {
      clienteInfo += 'Teléfono: $clienteTelefono\n';
    }

    if (clienteDireccion.isNotEmpty) {
      clienteInfo += 'Dirección: $clienteDireccion\n';
    }

    return clienteInfo;
  }
}

// Factory function for conditional imports
PDFServiceInterface createPDFService() {
  return PDFServiceWeb();
}
