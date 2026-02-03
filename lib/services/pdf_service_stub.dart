import 'pdf_service_factory.dart';

// Stub implementation for mobile platforms
class PDFServiceWeb implements PDFServiceInterface {
  @override
  void generarYDescargarPDF({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {}

  @override
  void abrirVentanaImpresion({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {}

  @override
  void descargarComoTexto({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {}

  @override
  Future<void> compartirTexto({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) async {}
}

// Stub para pdf_service_web en plataformas móviles - compatibilidad hacia atrás
class PdfServiceWeb {
  static Future<void> imprimirFactura(
    dynamic mesa,
    List<dynamic> documentos,
  ) async {
    throw UnsupportedError('PDF printing not supported in this platform');
  }

  static Future<void> imprimirFacturaConAuto(
    dynamic mesa,
    List<dynamic> documentos,
  ) async {
    throw UnsupportedError('PDF printing not supported in this platform');
  }
}
