import 'pdf_service_factory.dart';

// Stub implementation for mobile platforms
class PDFServiceWeb implements PDFServiceInterface {
  @override
  void generarYDescargarPDF({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {
    print('PDF generation not supported on mobile platform');
  }

  @override
  void abrirVentanaImpresion({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {
    print('PDF print window not supported on mobile platform');
  }

  @override
  void descargarComoTexto({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) {
    print('Text download not supported on mobile platform');
  }

  @override
  Future<void> compartirTexto({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  }) async {
    print('Text sharing not supported on mobile platform');
  }
}

// Stub para pdf_service_web en plataformas móviles - compatibilidad hacia atrás
class PdfServiceWeb {
  static Future<void> imprimirFactura(
    dynamic mesa,
    List<dynamic> documentos,
  ) async {
    print('Impresión de factura no disponible en móvil');
  }

  static Future<void> imprimirFacturaConAutoPrint(
    dynamic mesa,
    List<dynamic> documentos,
  ) async {
    print('Impresión automática de factura no disponible en móvil');
  }

  static Future<void> imprimirComanda(dynamic pedido) async {
    print('Impresión de comanda no disponible en móvil');
  }

  static Future<void> imprimirCierreTransaccional(dynamic resumen) async {
    print('Impresión de cierre transaccional no disponible en móvil');
  }

  static Future<void> copiarContenidoAlPortapapeles(String contenido) async {
    print('Copia al portapapeles no disponible en móvil');
  }
}

// Factory function for conditional imports
PDFServiceInterface createPDFService() {
  return PDFServiceWeb();
}
