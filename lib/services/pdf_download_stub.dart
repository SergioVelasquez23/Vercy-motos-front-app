import 'dart:typed_data';

/// Stub para plataformas no-web
void descargarPDFWeb(Uint8List pdfBytes, String nombreArchivo) {
  throw UnsupportedError('descargarPDFWeb solo está disponible en web');
}
