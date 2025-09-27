// Archivo de factoría que crea la implementación correcta según la plataforma
import 'pdf_service_web.dart' if (dart.library.io) 'pdf_service_stub.dart';

abstract class PDFServiceInterface {
  void generarYDescargarPDF({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  });
  void abrirVentanaImpresion({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  });
  void descargarComoTexto({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  });
  Future<void> compartirTexto({
    required Map<String, dynamic> resumen,
    bool esFactura = false,
  });
}

class PDFServiceFactory {
  static PDFServiceInterface create() {
    return createPDFService();
  }
}

// Función de factory que se importa condicionalmente
PDFServiceInterface createPDFService() {
  throw UnimplementedError(
    'Platform-specific implementation should override this',
  );
}
