import 'dart:typed_data';
import 'dart:html' as html;

/// Descargar PDF en navegador web
void descargarPDFWeb(Uint8List pdfBytes, String nombreArchivo) {
  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', nombreArchivo)
    ..click();
  html.Url.revokeObjectUrl(url);
}
